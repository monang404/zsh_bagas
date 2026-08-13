# ============================================================
#  30-ai/06-permissions/20-perm_ask.zsh — _ai_perm_ask + _ai_perm_ask_process
#  (split out of the old monolithic 30-ai/06-permissions.zsh)
# ============================================================

_ai_perm_ask_process() {
    local tool_name="$1" args_json="$2" program
    program=$(jq -r '.program // .runner // "unknown"' <<<"$args_json" 2>/dev/null)
    if [[ "$tool_name" == "run_test" ]]; then
        program=$(jq -r '.runner // .cmd // "auto-detect"' <<<"$args_json" 2>/dev/null)
    fi
    if [[ "${AI_AGENT_YOLO_MODE:-0}" == "1" || "${AI_PERM_PROCESS_MODE:-ask_always}" == "yolo" ]]; then
        return 0
    fi
    _ai_perm_ask "Jalankan process '$program' dalam project?"
}

_ai_perm_ask() {
    local msg="$1"
    # Prompt interaktif harus selalu muncul di terminal, meskipun
    # fungsi ini dipanggil di dalam block yang stderr-nya di-redirect
    # (mis. 2>_perm_errfile di _ai_tool_dispatch).
    if command -v gum >/dev/null; then
        gum confirm "$msg" </dev/tty >/dev/tty 2>/dev/tty
    else
        local confirm=""
        # prompt 'read' di zsh otomatis ditulis ke stderr
        if read -t 60 "confirm?$msg (y/n) " </dev/tty 2>/dev/tty; then
            [[ "$confirm" == "y" ]]
        else
            echo "Timeout menunggu konfirmasi." >/dev/tty
            return 1
        fi
    fi
}

