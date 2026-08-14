# ============================================================
#  30-ai/60-ui/components/timeline.zsh — Agent Timeline
#  AI-FIRST UX: gunakan _ai_ui_line dari 05-ui_box.zsh
#  untuk konsistensi ikon dan warna dengan design system.
# ============================================================

ui_timeline() {
    local steps_str="$1"
    local current_idx="${2:-1}"

    [ -z "$steps_str" ] && return

    local -a steps
    steps=("${(@f)steps_str}")

    local i=1
    for step in "${steps[@]}"; do
        [ -z "$step" ] && (( i++ )) && continue
        if (( i < current_idx )); then
            # Done — ✓ dengan AI_C_OK
            if type _ai_ui_line >/dev/null 2>&1; then
                printf '  '; _ai_ui_line "✓" "$step"
            else
                printf '  %s✓%s %s\n' "${AI_C_OK:-}" "${AI_C_RESET:-}" "$step"
            fi
        elif (( i == current_idx )); then
            # Active — ● bold
            printf '  %s●%s %s%s%s\n' \
                "${AI_C_PRIMARY:-}" "${AI_C_RESET:-}" \
                "${AI_C_BOLD:-}" "$step" "${AI_C_RESET:-}"
        else
            # Pending — ○ muted
            printf '  %s○ %s%s\n' \
                "${AI_C_MUTED:-}" "$step" "${AI_C_RESET:-}"
        fi
        (( i++ ))
    done
}
