# ============================================================
#  30-ai/60-ui/components/state.zsh — State UI Renderer
#  AI-FIRST UX v2: Blueprint §7 status line compact.
#  Semua log [AI][...] diganti dengan icon inline:
#
#    [AI][WAIT]    →  ● Thinking...
#    [AI][REQUEST] →  ● Sending...
#    [AI][DONE]    →  ✓ Done
#    [AI][ERROR]   →  ✗ Error
#
#  API:
#    _ai_state_thinking "Searching files..."
#    _ai_state_sending  "groq"
#    _ai_state_acting   "Using rg" "Found 24 files"
#    _ai_state_waiting  "rm -rf build/"
#    _ai_state_done     "3 files changed" "42s"
#    _ai_state_error    "Permission denied"
#    _ai_state_step     "Planning..."   (level-1 verbosity)
#    _ai_state_tool     "rg" "pattern"  (level-2 verbosity)
# ============================================================

# Pastikan design tokens dari 02-ui_colors.zsh sudah dimuat
: "${AI_C_RESET:=}" "${AI_C_BOLD:=}" "${AI_C_MUTED:=}"
: "${AI_C_PRIMARY:=}" "${AI_C_OK:=}" "${AI_C_WARN:=}" "${AI_C_ERR:=}" "${AI_C_INFO:=}"

# Verbosity level default = 0 (Minimal) jika belum di-set
: "${AI_VERBOSITY:=0}"

# Buffer log detail untuk /details
typeset -g AI_LAST_DETAIL_LOG=""

_ai_state_thinking() {
    local msg="${1:-Thinking...}"
    # Level 1+: tampilkan status proses; level 0 (Minimal) = diam
    # Blueprint v2 §7: reasoning internal disembunyikan di default (level 0)
    if [ "${AI_VERBOSITY:-0}" -ge 1 ]; then
        if _ai_ui_supports_unicode 2>/dev/null; then
            printf '%s●%s %s\n' "$AI_C_INFO" "$AI_C_RESET" "$msg"
        else
            printf '* %s\n' "$msg"
        fi
    fi
    AI_LAST_DETAIL_LOG+="[thinking] $msg"$'\n'
}

# _ai_state_sending(provider?) — Blueprint v2 §7: [AI][REQUEST] → ● Sending...
_ai_state_sending() {
    local provider="${1:-}"
    local msg="Sending..."
    [ -n "$provider" ] && msg="Sending to ${provider}..."
    # Level 1+: tampilkan saja di atas verbosity minimal
    if [ "${AI_VERBOSITY:-0}" -ge 1 ]; then
        if _ai_ui_supports_unicode 2>/dev/null; then
            printf '%s●%s %s\n' "$AI_C_INFO" "$AI_C_RESET" "$msg"
        else
            printf '* %s\n' "$msg"
        fi
    fi
    AI_LAST_DETAIL_LOG+="[sending] $msg"$'\n'
}

_ai_state_acting() {
    local tool="${1:-}"
    local detail="${2:-}"
    # Level 1+: tampilkan aksi
    if [ "${AI_VERBOSITY:-0}" -ge 1 ]; then
        if _ai_ui_supports_unicode 2>/dev/null; then
            if [ -n "$detail" ]; then
                printf '%s→%s %s  %s%s%s\n' "$AI_C_PRIMARY" "$AI_C_RESET" "$tool" "$AI_C_MUTED" "$detail" "$AI_C_RESET"
            else
                printf '%s→%s %s\n' "$AI_C_PRIMARY" "$AI_C_RESET" "$tool"
            fi
        else
            printf '> %s  %s\n' "$tool" "$detail"
        fi
    fi
    AI_LAST_DETAIL_LOG+="[acting] $tool ${detail:+| $detail}"$'\n'
}

_ai_state_waiting() {
    local cmd="${1:-}"
    # Approval state — selalu tampil
    if _ai_ui_supports_unicode 2>/dev/null; then
        printf '%s⚠%s  Needs approval\n' "$AI_C_WARN" "$AI_C_RESET"
        printf '  %s%s%s\n' "$AI_C_BOLD" "$cmd" "$AI_C_RESET"
    else
        printf '! Needs approval: %s\n' "$cmd"
    fi
    AI_LAST_DETAIL_LOG+="[approval] $cmd"$'\n'
}

_ai_state_done() {
    local summary="${1:-}"
    local runtime="${2:-}"
    # Selalu tampil
    local line="Done"
    [ -n "$summary" ] && line+="  ·  $summary"
    [ -n "$runtime" ] && line+="  ·  $runtime"
    if _ai_ui_supports_unicode 2>/dev/null; then
        printf '%s✓%s %s\n' "$AI_C_OK" "$AI_C_RESET" "$line"
    else
        printf '+ %s\n' "$line"
    fi
    AI_LAST_DETAIL_LOG+="[done] $line"$'\n'
}

_ai_state_error() {
    local msg="${1:-Error}"
    if _ai_ui_supports_unicode 2>/dev/null; then
        printf '%s✗%s %s\n' "$AI_C_ERR" "$AI_C_RESET" "$msg"
    else
        printf 'x %s\n' "$msg"
    fi
    AI_LAST_DETAIL_LOG+="[error] $msg"$'\n'
}

# Level-1 verbosity: step progress
_ai_state_step() {
    local msg="$1"
    if [ "${AI_VERBOSITY:-0}" -ge 1 ]; then
        if _ai_ui_supports_unicode 2>/dev/null; then
            printf '%s●%s %s\n' "$AI_C_INFO" "$AI_C_RESET" "$msg"
        else
            printf '* %s\n' "$msg"
        fi
    fi
    AI_LAST_DETAIL_LOG+="[step] $msg"$'\n'
}

# Level-2 verbosity: tool detail
_ai_state_tool() {
    local tool="$1" args="$2"
    if [ "${AI_VERBOSITY:-0}" -ge 2 ]; then
        printf '%sTool:%s %s  %s%s%s\n' \
            "$AI_C_MUTED" "$AI_C_RESET" \
            "$tool" \
            "$AI_C_MUTED" "$args" "$AI_C_RESET"
    fi
    AI_LAST_DETAIL_LOG+="[tool] $tool $args"$'\n'
}

# Level-3: raw debug line
_ai_state_debug() {
    local msg="$1"
    if [ "${AI_VERBOSITY:-0}" -ge 3 ]; then
        printf '%s[DEBUG] %s%s\n' "$AI_C_MUTED" "$msg" "$AI_C_RESET"
    fi
    AI_LAST_DETAIL_LOG+="[debug] $msg"$'\n'
}
