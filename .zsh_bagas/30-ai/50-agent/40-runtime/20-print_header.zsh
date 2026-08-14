# ============================================================
#  30-ai/50-agent/40-runtime/20-print_header.zsh — agent header
#  Blueprint v2 §4: Agent memakai state machine, bukan hero box besar.
#  Header cukup satu baris + metadata compact.
# ============================================================

# Reads $goal/$resume_slug/$yolo/$skillsline (caller locals, dynamic
# scope). Pure output, printed exactly once per run (never inside the
# step loop).
_ai_agent_print_header() {
    local hdr_project hdr_model hdr_mode hdr_goal_label
    hdr_project=$(_ai_agent_project_name)
    hdr_model=$(_ai_agent_primary_model)
    if [ "$yolo" -eq 1 ]; then
        hdr_mode="yolo"
    else
        hdr_mode="autonomous"
    fi
    if [ $step_offset -eq 0 ]; then
        hdr_goal_label="$goal"
    else
        hdr_goal_label="Resuming: $goal"
    fi

    # Blueprint v2 §4: compact header, tanpa box besar
    # Format: ● goal
    #           Model  provider/model  Project  name  Mode  yolo/autonomous
    if _ai_ui_supports_unicode 2>/dev/null; then
        printf '%s●%s %s%s%s\n' "$AI_C_INFO" "$AI_C_RESET" "$AI_C_BOLD" "$hdr_goal_label" "$AI_C_RESET"
    else
        printf '* %s\n' "$hdr_goal_label"
    fi
    echo "  ${AI_C_MUTED}Model${AI_C_RESET}    $hdr_model"
    echo "  ${AI_C_MUTED}Project${AI_C_RESET}  $hdr_project"
    echo "  ${AI_C_MUTED}Mode${AI_C_RESET}     $hdr_mode"
    if [ -n "$skillsline" ]; then
        echo "  ${AI_C_MUTED}Skills${AI_C_RESET}   $skillsline"
    fi
    echo ""
}
