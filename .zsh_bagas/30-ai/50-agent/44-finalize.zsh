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
    local step done_flag block_reason thought lifecycle_state
    step=$(<"$state_dir/step")
    done_flag=$(<"$state_dir/done")
    lifecycle_state=$(_ai_agent_state_get "$state_dir" 2>/dev/null)
    # Backward-compatible fallback for old state dirs, but new runs must use
    # the formal state machine as the source of truth.
    [ -z "$lifecycle_state" ] && lifecycle_state="$([ "$done_flag" = "true" ] && echo COMPLETE || echo BLOCKED)"
    block_reason=$(<"$state_dir/block_reason")
    thought=$(<"$state_dir/thought")
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
        local -a final_lines
        final_lines=("Task completed successfully" "Files changed: ${#changed_files[@]}")
        if [ "${#changed_files[@]}" -gt 0 ]; then
            local cf
            for cf in "${(k)changed_files[@]}"; do
                final_lines+=("  - $cf")
            done
        fi
        # Task 2.1: touched_py_files lama diganti touched_files generik --
        # hitung ulang jumlah file .py dari situ biar pesan akhir ("py_
        # compile OK (N file python)") IDENTIK kayak sebelum refactor.
        local py_touched_count=0 ptf
        for ptf in "${(k)touched_files[@]}"; do
            [[ "$ptf" == *.py ]] && py_touched_count=$((py_touched_count+1))
        done
        if [ "$py_touched_count" -gt 0 ]; then
            final_lines+=("Verifikasi: py_compile OK (${py_touched_count} file python)")
        fi
        # Task 2.4: pesan senada buat .js -- cuma nge-hitung ulang dari
        # touched_files (SAMA pola persis kayak py_touched_count di
        # atas), bukan verifikasi baru (sudah lolos di
        # _ai_verify_touched_files sebelum done:true diterima).
        local js_touched_count=0 jtf
        for jtf in "${(k)touched_files[@]}"; do
            [[ "$jtf" == *.js ]] && js_touched_count=$((js_touched_count+1))
        done
        if [ "$js_touched_count" -gt 0 ]; then
            final_lines+=("Verifikasi: node --check OK (${js_touched_count} file js)")
        fi
        # Task 2.4: npm test/lint OPSIONAL, sekali di akhir sesi --
        # lihat komentar _ai_agent_maybe_run_npm_checks() buat syarat
        # lengkapnya. Informational doang, gak ngubah done_flag/
        # block_reason walau hasilnya gagal.
        local npm_out
        if npm_out=$(_ai_agent_maybe_run_npm_checks "${(k)touched_files[@]}") && [ -n "$npm_out" ]; then
            final_lines+=("Verifikasi tambahan (npm test/lint):${npm_out}")
        fi

        # Task 4.2 (fase4_reviewer_integration): review otomatis SEKALI di
        # titik ini -- tepat sesudah agent declare selesai DAN sudah lolos
        # verifikasi syntax (_ai_verify_touched_files, dicek jauh sebelum
        # break loop di atas, TIDAK diulang di sini) DAN beneran ada file
        # yang berubah. `changed_files` REUSE state yang udah ada (Task
        # 1.6, diisi tiap tool tulis sukses) -- BUKAN state baru. Task
        # readonly-only (gak pernah nulis file) -> changed_files kosong ->
        # blok ini di-skip total, review SAMA SEKALI gak kepanggil (gak ada
        # API call tambahan).
        # Task 4.3: flag --no-review ($no_review=1) skip blok ini SAMA
        # PERSIS kayak readonly-task (gak ada API call tambahan, gak ada
        # baris "Review:" di ringkasan akhir) -- default TETAP jalan
        # (no_review=0) kecuali flag-nya eksplisit dipasang.
        if [ "$no_review" -eq 0 ] && [ "${#changed_files[@]}" -gt 0 ]; then
            local review_line=""
            if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
                # `git diff` (unstaged) -- pola yang SAMA persis dipakai tool
                # readonly `git_diff` (05-tools.zsh) buat lihat perubahan
                # kerja aiagent, yang emang nulis langsung ke file tanpa
                # nge-stage. TIDAK bikin mekanisme diff baru.
                local review_diff review_diffstat
                review_diff=$(git diff 2>/dev/null)
                if [ -n "$review_diff" ]; then
                    review_diffstat=$(git diff --stat 2>/dev/null)
                    # _ai_review_diff_core (Task 4.1, dipanggil apa adanya)
                    # -- INFORMATIONAL, agent TIDAK nunggu jawaban buat ini
                    # dan TIDAK pernah auto-lanjut edit lagi walau review
                    # nemuin masalah (gak ada loop review->fix->review di
                    # sini, ini titik BUNTU alur, cuma nambah teks ke box).
                    local review_text
                    review_text=$(_ai_review_diff_core "$review_diff" "$review_diffstat" 2>/dev/null)
                    if [ -n "$review_text" ]; then
                        review_line="${review_text//$'\n'/ }"
                    else
                        # _ai_chat_request gagal total (network/provider down)
                        # -- review-nya dikasih catatan gagal, TAPI aiagent
                        # TETAP lapor hasil task seperti biasa (done_flag &
                        # box COMPLETE gak berubah sama sekali gara-gara ini).
                        review_line="review gagal dijalankan (provider AI gak bisa dihubungi)."
                    fi
                    _ai_log "review" "auto review after aiagent" "$review_line"
                fi
            fi
            [ -n "$review_line" ] && final_lines+=("" "Review:" "$review_line")
        fi
        _ai_log_agent_done "Task completed"
        local l
        for l in "${final_lines[@]}"; do
            echo "[AGENT][SUMMARY] $l" >&2
        done
    else
        [ -z "$block_reason" ] && block_reason="Agent berhenti (step $step), alasan spesifik gak tercatat."
        local -a final_lines
        final_lines=("$block_reason")
        # "Saran next step" dari reasoning TERAKHIR LLM yang udah ada
        # ($thought) -- diringkas pakai helper Task 1.4 yang sama
        # (_ai_agent_reasoning_display), BUKAN LLM call baru.
        # v-fix: jangan tampilkan thought stale kalau block disebabkan
        # kegagalan provider/LLM -- thought itu dari step SEBELUMNYA,
        # bukan dari step yang gagal, jadi menyesatkan jika ditampilkan
        # sebagai "Saran" padahal isinya reasoning yang gak nyambung
        # dengan penyebab kegagalan.
        local hint
        local _show_hint=1
        [[ "$block_reason" == *"LLM/provider request gagal"* ]] && _show_hint=0
        if [ "$_show_hint" -eq 1 ] && hint=$(_ai_agent_reasoning_display "$thought"); then
            final_lines+=("Saran: ${hint//$'\n'/ }")
        fi
        _ai_log_agent_error "Task blocked"
        local l
        for l in "${final_lines[@]}"; do
            echo "[AGENT][SUMMARY] $l" >&2
        done
    fi

    return 0
}
