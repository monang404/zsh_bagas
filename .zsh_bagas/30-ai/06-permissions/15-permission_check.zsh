# ============================================================
#  30-ai/06-permissions/15-permission_check.zsh — _ai_permission_check — path validation + capability + level dispatch
#  (split out of the old monolithic 30-ai/06-permissions.zsh)
# ============================================================

_ai_permission_check() {
    local tool_name="$1"
    local args_json="$2"
    local level="${AI_TOOL_REGISTRY[$tool_name]#*|}"
    local path dest

    # ── Filesystem path containment ──────────────────────────────
    # Every filesystem capability gets canonical path containment BEFORE
    # the interactive permission decision. Relative paths, .., prefix
    # collisions and symlink escapes therefore cannot bypass the policy.
    case "$tool_name" in
        read_file|write_file|edit_file|patch_file|count_lines|delete_file)
            # PATH IS MANDATORY for these tools
            path=$(_ai_tool_extract_path "$args_json")
            if [ -z "$path" ]; then
                echo "ERROR: tool '$tool_name' membutuhkan args.path (string non-empty). Diterima: $(printf '%s' "$args_json" | head -c 200)" >&2
                return 1
            fi
            _ai_validate_project_path "$path" "$tool_name" || return 1
            ;;
        list_dir|glob_search|grep_search)
            # PATH IS OPTIONAL for these tools — empty = "." (current dir)
            path=$(_ai_tool_extract_path "$args_json")
            if [ -n "$path" ]; then
                _ai_validate_project_path "$path" "$tool_name" || return 1
            fi
            # Empty path is perfectly valid → default to "."
            ;;
        move_file)
            path=$(_ai_tool_extract_path "$args_json")
            dest=$(_ai_tool_extract_field "$args_json" dest destination)
            if [ -z "$path" ]; then
                echo "ERROR: tool 'move_file' membutuhkan args.path (sumber, string non-empty). Diterima: $(printf '%s' "$args_json" | head -c 200)" >&2
                return 1
            fi
            if [ -z "$dest" ]; then
                echo "ERROR: tool 'move_file' membutuhkan args.dest (tujuan, string non-empty). Diterima: $(printf '%s' "$args_json" | head -c 200)" >&2
                return 1
            fi
            _ai_validate_project_path "$path" "move_file source" || return 1
            _ai_validate_project_path "$dest" "move_file destination" || return 1
            ;;
        run_test)
            # PATH IS OPTIONAL for run_test — empty = "."
            path=$(_ai_tool_extract_path "$args_json")
            if [ -n "$path" ]; then
                _ai_validate_project_path "$path" "run_test" || true
            fi
            ;;
    esac

    # ── Capability gate (YOLO mode) ──────────────────────────────
    local capability="${AI_TOOL_CAPABILITY[$tool_name]:-}"
    if [[ "${AI_AGENT_YOLO_MODE:-0}" == "1" && -n "$capability" ]] && ! _ai_agent_capability_allowed "$capability"; then
        # YOLO is deliberately capability-limited.  A missing capability falls
        # back to an explicit confirmation instead of becoming an implicit
        # privilege escalation.
        _ai_perm_ask "Agent meminta capability '$capability' untuk tool '$tool_name'. Izinkan sekali?" || return 1
    fi

    # ── Permission level dispatch ────────────────────────────────
    case "$level" in
        readonly) return 0 ;;
        write)    _ai_perm_ask_write "$tool_name" "$args_json" ;;
        process)  _ai_perm_ask_process "$tool_name" "$args_json" ;;
        shell)    _ai_perm_ask_shell "$tool_name" "$args_json" ;;
        *)        echo "ERROR: permission level tidak dikenal untuk '$tool_name'" >&2; return 1 ;;
    esac
}
