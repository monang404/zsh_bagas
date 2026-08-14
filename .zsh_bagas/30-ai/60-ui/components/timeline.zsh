# ============================================================
# 30-ai/60-ui/components/timeline.zsh — Agent Timeline
# ============================================================

ui_timeline() {
    local steps_str="$1"
    local current_idx="$2"
    
    if [[ -z "$steps_str" ]]; then
        return
    fi
    
    # Split string by newline into array
    local -a steps
    steps=("${(@f)steps_str}")
    
    local i=1
    for step in "${steps[@]}"; do
        if [[ $i -lt $current_idx ]]; then
            echo -e "  $(ui_color success)✔$(ui_color reset) $(ui_color muted)$step$(ui_color reset)"
        elif [[ $i -eq $current_idx ]]; then
            echo -e "  $(ui_color primary)●$(ui_color reset) $(ui_color bold)${step}$(ui_color reset)"
        else
            echo -e "  $(ui_color muted)○ $step$(ui_color reset)"
        fi
        ((i++))
    done
}
