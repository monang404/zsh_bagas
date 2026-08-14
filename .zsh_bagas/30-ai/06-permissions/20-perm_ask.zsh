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

    # Phase 4 (audit.md §9): no dedicated box shape is specified for
    # `process` in the brief -- recommended reuse of the "Command
    # requires approval" box shape with <actual command> replaced by
    # <program> (and args, if available, same extraction pattern
    # 05-tools/30-tool_process.zsh already uses).
    local args_disp=""
    if command -v jq >/dev/null 2>&1; then
        local args_line
        args_line=$(jq -r '(.args // []) | join(" ")' <<<"$args_json" 2>/dev/null)
        [ -n "$args_line" ] && args_disp=" $args_line"
    fi
    local proc_cwd="${AI_AGENT_PROJECT_ROOT:-.}"
    _ai_ui_box "Command requires approval" "\$ ${program}${args_disp}" "" "Working directory: ${proc_cwd}" >/dev/tty
    _ai_perm_ask "Run process?"
}

_ai_perm_ask() {
    local msg="$1"
    # Phase 4 (audit.md §9/§20): decision logic (gum/read/timeout)
    # untouched -- only the fixed message prefix changes shape: the
    # raw "[AGENT][PERMISSION]" tag + "Allow <msg>" sentence wrapper
    # are dropped in favor of a bare question line, per the brief's
    # reference UX where the question sits *outside* the caller's own
    # approval box (built by _ai_perm_ask_write/_ai_perm_ask_shell/
    # _ai_perm_ask_process before calling this). Prompt interaktif
    # harus selalu muncul di terminal, meskipun fungsi ini dipanggil
    # di dalam block yang stderr-nya di-redirect (mis. 2>_perm_errfile
    # di _ai_tool_dispatch) -- makanya tetap ke /dev/tty langsung.
    if [[ "${AI_VERBOSE:-0}" == "1" ]]; then
        printf "  Policy: manual\n  Decision: ASK\n" >/dev/tty
    fi
    printf "\n%s [y/N] " "$msg" >/dev/tty

    if command -v gum >/dev/null; then
        # gum confirm doesn't use the custom prompt we just printed, but we print it anyway for context
        gum confirm "$msg" </dev/tty >/dev/tty 2>/dev/tty
    else
        local confirm=""
        if read -t 60 "confirm?" </dev/tty 2>/dev/tty; then
            [[ "$confirm" == "y" ]]
        else
            echo "Timeout menunggu konfirmasi." >/dev/tty
            return 1
        fi
    fi
}

