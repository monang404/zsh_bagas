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
            printf "  Tool : %s\n  Scope: project\n  Policy: yolo\n  Decision: ALLOW\n" "$tool_name" >/dev/tty
        fi
        return 0
    fi
    if [[ "${AI_PERM_WRITE_MODE}" == "auto" ]]; then
        if [[ "${AI_VERBOSE:-0}" == "1" ]]; then
            printf "  Tool: %s\n  Scope: project\n  Policy: auto\n  Decision: ALLOW\n" "$tool_name" >/dev/tty
        fi
        return 0
    fi

    # v-fix (actual bug, pre-existing): `local path` shadows zsh's tied
    # special parameter path/PATH -- merely declaring it (even before
    # assignment) empties $PATH for the rest of this function's dynamic
    # scope, silently breaking every jq call below (including inside
    # _ai_tool_extract_path itself) and leaving the extracted path
    # empty. Not part of this audit's scope by name, but it directly
    # blocks Phase 4's File-change approval box from ever showing a
    # real path, so per the audit's own ZSH-safety exception ("ubah
    # hanya jika ... terdapat actual bug yang menghalangi
    # implementation") the local variable is renamed here only --
    # $tool_name/$args_json contract, $_AI_SESSION_APPROVED state, and
    # ask_once_per_file dedup logic are all otherwise untouched.
    local file_path
    if command -v _ai_tool_extract_path >/dev/null 2>&1; then
        file_path=$(_ai_tool_extract_path "$args_json")
    else
        file_path=$(echo "$args_json" | jq -r '.path // empty' 2>/dev/null)
    fi

    # ask_once_per_file: cek apakah file ini sudah diapprove di sesi ini
    if [[ "${AI_PERM_WRITE_MODE}" == "ask_once_per_file" ]] && [ -n "$file_path" ]; then
        local approval_key="${_AI_AGENT_SESSION_SLUG}|${file_path}"
        if [[ -n "${_AI_SESSION_APPROVED[$approval_key]:-}" ]]; then
            return 0
        fi
    fi

    # Phase 4 (audit.md §9): "File change requires approval" box --
    # <path> already extracted above; the "Operation" label is derived
    # purely from $tool_name (already the first argument here) via a
    # static lookup table, no new plumbing. move_file's destination
    # (".dest") is the one extra field this label needs, extracted the
    # same way $file_path is above.
    local operation
    case "$tool_name" in
        write_file) operation="create/overwrite" ;;
        edit_file)  operation="modify" ;;
        patch_file) operation="patch" ;;
        move_file)
            local dest
            dest=$(echo "$args_json" | jq -r '.dest // empty' 2>/dev/null)
            operation="move to ${dest:-?}"
            ;;
        *) operation="$tool_name" ;;
    esac
    _ai_ui_box "File change requires approval" "File: $file_path" "" "Operation: $operation" >/dev/tty

    if _ai_perm_ask "Write/edit this file?"; then
        if [[ "${AI_PERM_WRITE_MODE}" == "ask_once_per_file" ]] && [ -n "$file_path" ]; then
            local approval_key="${_AI_AGENT_SESSION_SLUG}|${file_path}"
            typeset -gA _AI_SESSION_APPROVED
            _AI_SESSION_APPROVED[$approval_key]=1
        fi
        return 0
    else
        return 1
    fi
}

