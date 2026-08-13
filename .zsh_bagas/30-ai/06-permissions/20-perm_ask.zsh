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
    if command -v gum >/dev/null; then
        gum confirm "$msg"
    else
        local confirm=""
        if read -t 60 "confirm?$msg (y/n) "; then
            [[ "$confirm" == "y" ]]
        else
            echo "Timeout menunggu konfirmasi."
            return 1
        fi
    fi
}

