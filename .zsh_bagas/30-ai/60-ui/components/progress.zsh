# ============================================================
#  30-ai/60-ui/components/progress.zsh — Progress Bar
#  AI-FIRST UX: compact bar, aman di 80-column Termux.
#  Bar width dikunci 20 char — tidak overflow di layar sempit.
# ============================================================

ui_progress() {
    local current="${1:-0}"
    local total="${2:-1}"
    local message="${3:-}"

    [ "$total" -le 0 ] && total=1
    [ "$current" -lt 0 ] && current=0
    [ "$current" -gt "$total" ] && current=$total

    local bar_len=20
    local filled=$(( bar_len * current / total ))
    local empty=$(( bar_len - filled ))

    local bar="" i
    if _ai_ui_supports_unicode 2>/dev/null; then
        for (( i = 0; i < filled; i++ )); do bar+="█"; done
        for (( i = 0; i < empty;  i++ )); do bar+="░"; done
    else
        for (( i = 0; i < filled; i++ )); do bar+="#"; done
        for (( i = 0; i < empty;  i++ )); do bar+="."; done
    fi

    # Format: ● Message  [4/7]  ███████░░░░░░
    if [ -n "$message" ]; then
        printf '%s●%s %s  %s[%s/%s]%s  %s%s%s\n' \
            "${AI_C_INFO:-}" "${AI_C_RESET:-}" \
            "$message" \
            "${AI_C_MUTED:-}" "$current" "$total" "${AI_C_RESET:-}" \
            "${AI_C_OK:-}" "$bar" "${AI_C_RESET:-}"
    else
        printf '%s[%s/%s]%s  %s%s%s\n' \
            "${AI_C_MUTED:-}" "$current" "$total" "${AI_C_RESET:-}" \
            "${AI_C_OK:-}" "$bar" "${AI_C_RESET:-}"
    fi
}
