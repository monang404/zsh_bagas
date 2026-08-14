# ============================================================
#  30-ai/50-agent/44-finalize.zsh — agent completion/reporting
#
# Converts execution state into the user-facing completion/block report.
# It performs no model/tool execution.
# ============================================================

_ai_agent_finalize() {
    # v-fix (BUG#1 audit): guard against inherited xtrace leaking internal
    # assignments to the terminal, same as 42-execution/00-loop_main.zsh.
    setopt localoptions noxtrace

    local state_dir="$1" checkpoint_file="$2" goal="$3" msgfile="$4"
    local no_review="$5" yolo="$6" run_slug="$7"
    local step done_flag block_reason thought lifecycle_state commands_run
    step=$(<"$state_dir/step")
    done_flag=$(<"$state_dir/done")
    lifecycle_state=$(_ai_agent_state_get "$state_dir" 2>/dev/null)
    # Backward-compatible fallback for old state dirs, but new runs must use
    # the formal state machine as the source of truth.
    [ -z "$lifecycle_state" ] && lifecycle_state="$([ "$done_flag" = "true" ] && echo COMPLETE || echo BLOCKED)"
    block_reason=$(<"$state_dir/block_reason")
    thought=$(<"$state_dir/thought")
    # Phase 7 (audit.md §13): commands_run already exists in state_dir
    # (written by the loop) but was never read here before -- REUSE, no
    # new data path, just a one-line addition for the footer metric.
    commands_run=0
    [ -f "$state_dir/commands_run" ] && commands_run=$(<"$state_dir/commands_run")
    [[ "$commands_run" =~ ^[0-9]+$ ]] || commands_run=0
    local -A touched_files changed_files
    local f
    while IFS= read -r f; do [[ -n "$f" ]] && touched_files[$f]=1; done < "$state_dir/touched_files"
    while IFS= read -r f; do [[ -n "$f" ]] && changed_files[$f]=1; done < "$state_dir/changed_files"

    # v-fix (bug #55 audit): checkpoint cuma berguna kalau sesi BELUM
    # selesai -- begitu agent declare done:true (break normal, bukan
    # keabisan step), checkpoint-nya dihapus, gak perlu numpuk selamanya.
    if [ "$lifecycle_state" = "COMPLETE" ]; then
        rm -f -- "$checkpoint_file"
    fi

    # Task 1.6: box status akhir COMPLETE/BLOCKED -- SATU titik akhir
    # yang jelas, dicetak PERSIS SEKALI di sini (bukan di dalam loop),
    # pakai _ai_ui_box yang udah ada (Task 1.1). Keputusan sukses/gagal
    # murni dari $done_flag, state yang SAMA PERSIS dipakai keputusan
    # hapus-checkpoint di atas -- bukan status/exit-code baru.
    local final_icon_ok="✓" final_icon_bad="✗"
    if ! _ai_ui_supports_unicode; then
        # _ai_ui_box gak nge-translate icon di title-nya sendiri (beda
        # dari _ai_ui_line) -- disamain manual di sini pakai padanan
        # ASCII yang SAMA kayak di _ai_ui_line, biar gak ada karakter
        # unicode nyasar pas AI_UI_ASCII_FALLBACK=1 / locale non-UTF-8.
        final_icon_ok="+"
        final_icon_bad="x"
    fi

    if [ "$lifecycle_state" = "COMPLETE" ]; then
        # Commit 4 (implementasi_plan.md): ringkas output COMPLETE.
        # - _ai_state_done (1 baris footer: ✓ Done · N files · Xs)
        # - Maks 5 nama file yang berubah (+N more kalau lebih)
        # - Diff, review, verifikasi → _ai_detail_push (akses via /details)
        # - Box raksasa DIHAPUS, density budget terpenuhi.

        # Hitung runtime
        local _runtime_str=""
        if [ -n "${AI_AGENT_START_TS:-}" ]; then
            local _now_ts; _now_ts=$(date +%s)
            local _elapsed=$(( _now_ts - AI_AGENT_START_TS ))
            _runtime_str="${_elapsed}s"
        fi

        local _nchanged="${#changed_files[@]}"
        local _nactions="$commands_run"
        local _footer_sep="·"
        _ai_ui_supports_unicode || _footer_sep="-"

        # Baris footer ringkas: ✓ Done · N actions · N files changed · Xs
        local _summary="${_nactions} actions ${_footer_sep} ${_nchanged} files changed"
        _ai_state_done "$_summary" "$_runtime_str"

        # Tampilkan maks 5 nama file (indented, muted)
        if [ "$_nchanged" -gt 0 ]; then
            local _shown=0 cf
            for cf in "${(k)changed_files[@]}"; do
                if [ "$_shown" -lt 5 ]; then
                    printf '  %s%s%s\n' "${AI_C_MUTED:-}" "$cf" "${AI_C_RESET:-}"
                    _shown=$(( _shown + 1 ))
                fi
            done
            local _remaining=$(( _nchanged - _shown ))
            if [ "$_remaining" -gt 0 ]; then
                printf '  %s+%d more%s\n' "${AI_C_MUTED:-}" "$_remaining" "${AI_C_RESET:-}"
            fi
        fi

        # Push verifikasi py/js ke detail log
        local py_touched_count=0 ptf
        for ptf in "${(k)touched_files[@]}"; do
            [[ "$ptf" == *.py ]] && py_touched_count=$((py_touched_count+1))
        done
        [ "$py_touched_count" -gt 0 ] && \
            _ai_detail_push "[verify] py_compile OK (${py_touched_count} file python)"

        local js_touched_count=0 jtf
        for jtf in "${(k)touched_files[@]}"; do
            [[ "$jtf" == *.js ]] && js_touched_count=$((js_touched_count+1))
        done
        [ "$js_touched_count" -gt 0 ] && \
            _ai_detail_push "[verify] node --check OK (${js_touched_count} file js)"

        # npm test/lint ke detail log
        local npm_out
        if npm_out=$(_ai_agent_maybe_run_npm_checks "${(k)touched_files[@]}") && [ -n "$npm_out" ]; then
            _ai_detail_push "[verify] npm test/lint:${npm_out}"
        fi

        # Diff + AI review ke detail log (tidak ke layar)
        local _has_detail=0
        if [ "$_nchanged" -gt 0 ] && command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
            local review_diff review_diffstat
            review_diff=$(git diff 2>/dev/null)
            if [ -n "$review_diff" ]; then
                _has_detail=1
                review_diffstat=$(git diff --stat 2>/dev/null)
                local diff_guarded dl
                diff_guarded=$(_ai_guard_diff "$review_diff" "$review_diffstat")
                _ai_detail_push ""
                _ai_detail_push "[changes] git diff:"
                while IFS= read -r dl; do
                    _ai_detail_push "$dl"
                done <<< "$diff_guarded"

                # AI review (gated by --no-review flag)
                if [ "$no_review" -eq 0 ]; then
                    local review_text
                    review_text=$(_ai_review_diff_core "$review_diff" "$review_diffstat" 2>/dev/null)
                    if [ -n "$review_text" ]; then
                        _ai_detail_push ""
                        _ai_detail_push "[review] AI Review:"
                        _ai_detail_push "$review_text"
                        _ai_log "review" "auto review after aiagent" "$review_text"
                    else
                        _ai_detail_push "[review] review gagal dijalankan (provider AI tidak bisa dihubungi)."
                    fi
                fi
            fi
        fi

        # Tampilkan hint /details hanya jika ada konten detail
        if [ "$_has_detail" -eq 1 ]; then
            printf '\n  %sKetik /details untuk lihat diff & review lengkap.%s\n' \
                "${AI_C_MUTED:-}" "${AI_C_RESET:-}"
        fi
    else
        [ -z "$block_reason" ] && block_reason="Agent berhenti (step $step), alasan spesifik gak tercatat."
        # BLOCKED: tetap pakai box ringkas (maks 2 baris isi)
        local hint
        local _show_hint=1
        [[ "$block_reason" == *"LLM/provider request gagal"* ]] && _show_hint=0
        local -a _block_lines
        _block_lines=("$block_reason")
        if [ "$_show_hint" -eq 1 ] && hint=$(_ai_agent_reasoning_display "$thought"); then
            _block_lines+=("Saran: ${hint//$'\n'/ }")
        fi
        _ai_ui_box "${final_icon_bad} Task blocked" "${_block_lines[@]}"
    fi


    return 0
}
