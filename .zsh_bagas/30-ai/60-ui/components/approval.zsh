# ============================================================
# 30-ai/60-ui/components/approval.zsh — Approval Component
# ============================================================

ui_approve() {
    local command_to_run="$1"
    
    _ai_ui_box "Command requires approval" \
        "$command_to_run"
    
    if command -v gum >/dev/null 2>&1; then
        local choice
        choice=$(gum choose "[Approve]" "[Deny]")
        if [ "$choice" = "[Approve]" ]; then
            return 0
        else
            return 1
        fi
    else
        # Fallback if gum is not available
        echo -n "${AI_C_WARN}?${AI_C_RESET} Allow execution? [y/N] "
        local answer
        read -r answer
        if [[ "$answer" =~ ^[Yy]$ ]]; then
            return 0
        else
            return 1
        fi
    fi
}
