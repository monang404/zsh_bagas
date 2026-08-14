# ============================================================
# 30-ai/60-ui/components/approval.zsh — Approval Component
# ============================================================

ui_approve() {
    local command_to_run="$1"
    
    echo -e "$(ui_color warning)╭── Action Required ───────────────────────────────────────────────────$(ui_color reset)"
    echo -e "$(ui_color warning)│$(ui_color reset) $(ui_color bold)Bagas AI$(ui_color reset) wants to execute:"
    echo -e "$(ui_color warning)│$(ui_color reset) $(ui_color text)$command_to_run$(ui_color reset)"
    echo -e "$(ui_color warning)╰──────────────────────────────────────────────────────────────────────$(ui_color reset)"
    echo ""
    
    if command -v gum >/dev/null 2>&1; then
        if gum confirm "Allow execution?"; then
            return 0
        else
            return 1
        fi
    else
        # Fallback if gum is not available
        echo -n "$(ui_color warning)?$(ui_color reset) Allow execution? [y/N] "
        local answer
        read -r answer
        if [[ "$answer" =~ ^[Yy]$ ]]; then
            return 0
        else
            return 1
        fi
    fi
}
