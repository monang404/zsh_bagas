# ============================================================
#  30-ai/06-permissions/25-perm_write.zsh — _ai_perm_ask_write (ask_once_per_file state)
#  (split out of the old monolithic 30-ai/06-permissions.zsh)
# ============================================================

# FIX BUG-7: _ai_approved_files_this_session TIDAK lagi di-declare global di sini.
# Di-declare di dalam aiagent() sebagai local -A, dan di-pass via nama
# ke _ai_perm_ask_write lewat parameter ke-3. Kalau dua session jalan
# parallel di tmux, state-nya gak bocor antar session.
# Session approval state is kept in one associative array; never construct shell code from a path.

_ai_perm_ask_write() {
    local tool_name="$1"
    local args_json="$2"

    if [[ "${AI_AGENT_YOLO_MODE:-0}" == "1" ]] || [[ "${AI_PERM_WRITE_MODE}" == "yolo" ]]; then
        if [[ "${AI_VERBOSE:-0}" == "1" ]]; then
            printf "\n[AGENT][PERMISSION]\nTool : %s\nScope: project\nPolicy: yolo\nDecision: ALLOW\n" "$tool_name" >/dev/tty
        fi
        return 0
    fi
    if [[ "${AI_PERM_WRITE_MODE}" == "auto" ]]; then
        if [[ "${AI_VERBOSE:-0}" == "1" ]]; then
            printf "\n[AGENT][PERMISSION]\nTool: %s\nScope: project\nPolicy: auto\nDecision: ALLOW\n" "$tool_name" >/dev/tty
        fi
        return 0
    fi

    local path
    if command -v _ai_tool_extract_path >/dev/null 2>&1; then
        path=$(_ai_tool_extract_path "$args_json")
    else
        path=$(echo "$args_json" | jq -r '.path // empty' 2>/dev/null)
    fi

    # ask_once_per_file: cek apakah file ini sudah diapprove di sesi ini
    if [[ "${AI_PERM_WRITE_MODE}" == "ask_once_per_file" ]] && [ -n "$path" ]; then
        local approval_key="${_AI_AGENT_SESSION_SLUG}|${path}"
        if [[ -n "${_AI_SESSION_APPROVED[$approval_key]:-}" ]]; then
            return 0
        fi
    fi

    local desc="Tulis/edit file: $path ?"
    if _ai_perm_ask "$desc"; then
        if [[ "${AI_PERM_WRITE_MODE}" == "ask_once_per_file" ]] && [ -n "$path" ]; then
            local approval_key="${_AI_AGENT_SESSION_SLUG}|${path}"
            typeset -gA _AI_SESSION_APPROVED
            _AI_SESSION_APPROVED[$approval_key]=1
        fi
        return 0
    else
        return 1
    fi
}

