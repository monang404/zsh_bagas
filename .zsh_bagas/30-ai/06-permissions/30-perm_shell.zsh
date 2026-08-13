# ============================================================
#  30-ai/06-permissions/30-perm_shell.zsh — _ai_perm_ask_shell
#  (split out of the old monolithic 30-ai/06-permissions.zsh)
# ============================================================

_ai_perm_ask_shell() {
    local tool_name="$1"
    local args_json="$2"

    local command
    command=$(jq -r '.command // empty' <<<"$args_json" 2>/dev/null)
    if [[ "${AI_AGENT_YOLO_MODE:-0}" == "1" || "${AI_PERM_SHELL_MODE}" == "yolo" ]]; then
        # YOLO is an authorization shortcut, not a bypass around the shell
        # capability policy. Arbitrary shell composition still needs a manual gate.
        if [[ "$tool_name" == "run_command" && -n "$command" ]] && _ai_yolo_shell_safe "$command"; then
            return 0
        fi
        if [[ "$tool_name" != "run_command" ]]; then
            return 0
        fi
    fi
    local desc="Jalankan command: $command ?"
    _ai_perm_ask "$desc"
}

