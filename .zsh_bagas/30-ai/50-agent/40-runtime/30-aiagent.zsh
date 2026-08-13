# ============================================================
#  30-ai/50-agent/40-runtime/30-aiagent.zsh — aiagent() main orchestrator
#  (split out of the old monolithic 30-ai/50-agent/40-runtime.zsh; every
#  major phase now lives in its own 00-25-*.zsh helper next to this file)
# ============================================================

aiagent() {
    setopt localtraps
    _ai_need_any_key || return 1

    if [[ "$1" == "--list-checkpoints" ]]; then
        _ai_agent_list_checkpoints
        return $?
    fi

    if [[ "$1" == "--list-logs" ]]; then
        _ai_agent_list_logs
        return $?
    fi

    if [[ "$1" == "--log" ]]; then
        _ai_agent_show_log "$@"
        return $?
    fi

    local yolo=0 resume_slug=""
    # Task 4.3 (fase4_reviewer_integration): flag --no-review, independen
    # dari --yolo/--resume (case terpisah di while yang sama, urutan
    # kombinasi flag apa pun tetap kepasang bener). Default TETAP nyala
    # (no_review=0) -- review otomatis (Task 4.2) cuma di-skip kalau flag
    # ini eksplisit dipasang.
    local no_review=0
    while [[ "$1" == --* ]]; do
        case "$1" in
            --yolo) yolo=1; shift ;;
            --no-review) no_review=1; shift ;;
            --resume)
                resume_slug="$2"
                shift 2
                ;;
            *) break ;;
        esac
    done

    mkdir -p "$AI_AGENT_CHECKPOINT_DIR"
    local goal="" msgfile step_offset=0 checkpoint_file="" run_slug=""
    # Task 1.5: nama-nama skill yang ke-load, buat baris compact
    # "skills: ✓ ..." sesudah header box -- cuma keisi di jalur goal
    # baru (di bawah), tetep kosong pas --resume (skill emang gak
    # di-load ulang pas resume, konsisten sama behavior skillctx yang
    # udah ada).
    local skillsline=""

    # FIX BUG-7 companion: unique slug per sesi buat session-scoped permission state
    # (lihat 06-permissions.zsh _ai_perm_ask_write)
    # Di-set setelah goal diketahui (lihat bawah), tapi declare dulu biar tersedia.
    local _AI_AGENT_SESSION_SLUG=""

    if [ -n "$resume_slug" ]; then
        _ai_agent_load_checkpoint "$resume_slug" || return 1
    else
        _ai_agent_prepare_new_goal "$@" || return 1
    fi

    _ai_agent_print_header

    _ai_agent_run_execution
}
