# ============================================================
#  30-ai/50-agent/42-execution/00-loop_main.zsh — agent execution
#  engine: _ai_agent_execute_loop().
#
# Owns only the bounded ReAct execution loop. It receives all runtime
# inputs explicitly and emits a small, machine-readable result into state_dir.
# No UI finalization or lifecycle cleanup belongs here.
#
#  (split out of the old monolithic 30-ai/50-agent/42-execution.zsh —
#  per-step logic moved to 05-get_plan.zsh, 10-reject_checks.zsh,
#  15-run_tool.zsh, 20-log_and_notify.zsh, 25-track_and_continue.zsh.
#  Each helper reads/writes the loop-scoped locals declared below via
#  zsh dynamic scoping (no `local` redeclare in the helper) instead of
#  args/globals -- same pattern already used elsewhere in this file
#  for exit_status/filepath. `break`/`continue` on the outer while
#  loop can't happen inside a called function, so each helper returns
#  a status code that this loop checks and translates back into
#  break/continue/return itself.)
# ============================================================

_ai_agent_execute_loop() {
    # v-fix (BUG#1 audit): the ReAct step loop assigns lots of internal
    # locals every iteration (reasoning_disp, ridx, args_disp, etc). If the
    # caller happens to have global xtrace on, zsh's trace prints every one
    # of those plain assignments to the terminal (e.g. "reasoning_disp=$'...'",
    # "ridx=9", "args_disp=main.py") -- exactly the debug-variable leak from
    # the bug report. Same defensive guard already used elsewhere in 30-ai
    # (e.g. 10-core/15-spinner.zsh, 10-core/50-request_blocking.zsh);
    # this file/44-finalize.zsh were just missing it.
    setopt localoptions noxtrace

    local state_dir="$1" msgfile="$2" checkpoint_file="$3" goal="$4"
    local step_offset="$5" run_slug="$6" runs_logfile="$7" max_step="$8"

    local step=$step_offset reply thought tool args done_flag output pdir chat_status args_disp
    local last_failed_tool="" last_failed_args="" same_fail_count=0 commands_run=0
    local -i last_notify_ts=0
    local block_reason=""
    local -A touched_files changed_files
    local exit_status filepath
    mkdir -p -- "$state_dir" "$AI_TOOL_RUNS_DIR" || return 1
    _ai_agent_state_init "$state_dir" || return 1

    local _gp_status _rej_status

    while [ $step -lt $max_step ]; do
        if [ -f "$state_dir/cancelled" ]; then
            block_reason="Agent dibatalkan oleh SIGINT/SIGTERM (step $step)"
            _ai_agent_state_transition "$state_dir" BLOCKED 2>/dev/null || true
            break
        fi

        _ai_agent_exec_get_plan
        _gp_status=$?
        if [ $_gp_status -eq 2 ]; then
            # Fatal state-transition failure: persist a usable reason before
            # exiting so finalize does not fall back to a bare "status N".
            [ -z "$block_reason" ] && block_reason="State transition gagal di langkah PLAN (step $step)"
            _ai_agent_state_transition "$state_dir" BLOCKED 2>/dev/null || true
            printf '%s\n' "$step" >| "$state_dir/step"
            printf '%s\n' "false" >| "$state_dir/done"
            printf '%s\n' "$block_reason" >| "$state_dir/block_reason"
            return 1
        fi
        [ $_gp_status -eq 1 ] && break

        # Commit 2 (implementasi_plan.md): gate step-rule + reasoning di
        # belakang verbosity check sesuai spec. Level 0 (default Minimal)
        # diam total — garis "Step N/MAX" dan "◌ reasoning" adalah proses-
        # internal noise untuk task sederhana. Level 1+ tetap menampilkannya.
        if [ "${AI_VERBOSITY:-0}" -ge 1 ]; then
            echo ""
            _ai_ui_step_rule "$step" "$max_step"
            local _step_reasoning
            if _step_reasoning=$(_ai_agent_reasoning_display "$thought"); then
                _ai_ui_line "◌" "$_step_reasoning"
            fi
        fi

        _ai_agent_exec_check_done_rejections
        _rej_status=$?
        [ $_rej_status -eq 2 ] && return 1
        [ $_rej_status -eq 1 ] && continue

        if [ "$done_flag" = "true" ] || [ -z "$tool" ]; then
            # Task 1.6: "Agent selesai." lama DIHAPUS di sini -- ini
            # persis "ringkasan akhir" yang diganti box COMPLETE/BLOCKED
            # di akhir fungsi (yaml Task 1.6: "ganti ringkasan akhir
            # pakai _ai_ui_box"), biar gak ada 2 pengumuman status akhir
            # yang tumpang tindih.
            #
            # Edge case: tool kosong TAPI done_flag bukan "true" (LLM
            # gak declare selesai eksplisit) sebenarnya bukan sukses
            # terverifikasi, jadi box akhir tetap BLOCKED buat kasus ini
            # (done_flag tetap sumber kebenarannya, bukan ngubah
            # keputusan break loop yang sudah ada).
            if [ "$done_flag" != "true" ]; then
                block_reason="Agent berhenti tanpa tool berikutnya dan tanpa declare selesai (step $step)"
                _ai_agent_state_transition "$state_dir" BLOCKED 2>/dev/null || true
            fi
            break
        fi

        _ai_agent_state_transition "$state_dir" EXECUTE 2>/dev/null || return 1

        # Phase 0 (audit.md, fixes B-001): args_disp was read but never
        # assigned -- populate it here via the existing (already-built,
        # previously-uncalled) _ai_agent_args_summary helper before
        # rendering the tool line.
        args_disp=$(_ai_agent_args_summary "$tool" "$args")

        # Phase 2: tree-style step renderer, replaces the raw
        # [AGENT][STEP N]/[AGENT][TOOL] tag lines.
        _ai_agent_render_step_start "$step" "$tool" "$args_disp"

        _ai_agent_exec_run_tool || break

        _ai_agent_exec_log_and_notify

        _ai_agent_exec_track_and_continue || break
    done

    if [ $step -ge $max_step ]; then
        echo ""
        echo "[berhenti: sudah $AI_AGENT_MAX_STEPS langkah (dari checkpoint kalau ada), agent gak declare selesai. Cek manual, atau lanjut lagi lewat 'ai agent --resume $(basename "$checkpoint_file" .json)'.]"
        [ "$done_flag" != "true" ] && block_reason="Sudah $AI_AGENT_MAX_STEPS langkah, agent belum declare selesai (step $step)"
        _ai_agent_state_transition "$state_dir" BLOCKED 2>/dev/null || true
    fi

    # Terminal lifecycle is authoritative. A successful verified `done:true`
    # reaches COMPLETE; every other exit path must be BLOCKED.
    if [ "$done_flag" = "true" ] && [ "$(_ai_agent_state_get "$state_dir" 2>/dev/null)" = "VERIFY" ]; then
        _ai_agent_state_transition "$state_dir" COMPLETE 2>/dev/null || true
    elif [ "$(_ai_agent_state_get "$state_dir" 2>/dev/null)" != "BLOCKED" ]; then
        _ai_agent_state_transition "$state_dir" BLOCKED 2>/dev/null || true
    fi

    # Persist only result metadata needed by the orchestrator/finalizer.
    printf '%s\n' "$step" >| "$state_dir/step"
    printf '%s\n' "$done_flag" >| "$state_dir/done"
    printf '%s\n' "$block_reason" >| "$state_dir/block_reason"
    printf '%s\n' "$thought" >| "$state_dir/thought"
    printf '%s\n' "$commands_run" >| "$state_dir/commands_run"
    : >| "$state_dir/touched_files"
    local f
    for f in ${(k)touched_files}; do printf '%s\n' "$f" >> "$state_dir/touched_files"; done
    : >| "$state_dir/changed_files"
    for f in ${(k)changed_files}; do printf '%s\n' "$f" >> "$state_dir/changed_files"; done
    return 0
}
