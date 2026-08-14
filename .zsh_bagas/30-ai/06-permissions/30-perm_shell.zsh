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

    # Phase 4 (audit.md §9) + implementer note: the tool registry
    # (00-tool_registry.zsh) maps run_command, delete_file, AND
    # web_fetch all to the "shell" permission level -- not just
    # run_command as the audit's §9 discussion assumed before
    # verification (flagged there as UNKNOWN/verify). $command (from
    # args.command) is only meaningful for run_command; delete_file's
    # args only have .path, web_fetch's only have .url. Branch by
    # tool_name so each gets a box with data that actually exists for
    # it, instead of a run_command-shaped box showing an empty command.
    case "$tool_name" in
        run_command)
            local cmd_cwd="${AI_AGENT_PROJECT_ROOT:-.}"
            _ai_ui_box "Command requires approval" "\$ $command" "" "Working directory: ${cmd_cwd}" >/dev/tty
            _ai_perm_ask "Run command?"
            ;;
        delete_file)
            local del_path
            del_path=$(jq -r '.path // empty' <<<"$args_json" 2>/dev/null)
            _ai_ui_box "File change requires approval" "File: $del_path" "" "Operation: delete" >/dev/tty
            _ai_perm_ask "Delete this file?"
            ;;
        web_fetch)
            local fetch_url
            fetch_url=$(jq -r '.url // empty' <<<"$args_json" 2>/dev/null)
            _ai_ui_box "Action requires approval" "Fetch: $fetch_url" >/dev/tty
            _ai_perm_ask "Fetch this URL?"
            ;;
        *)
            # No known tool maps here today, but keep a safe generic
            # fallback rather than silently dropping the prompt if the
            # registry gains another "shell"-level tool later.
            _ai_ui_box "Action requires approval" "Tool: $tool_name" >/dev/tty
            _ai_perm_ask "Proceed?"
            ;;
    esac
}

