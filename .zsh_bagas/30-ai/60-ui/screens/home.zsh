# ============================================================
# 30-ai/60-ui/screens/home.zsh — Home Workspace Screen
# ============================================================

ui_home() {
    clear
    
    if typeset -f ui_header >/dev/null; then
        ui_header
    fi
    echo ""
    
    echo -e "$(ui_color primary)▶ Quick Actions:$(ui_color reset)"
    echo -e "  $(ui_color muted)/chat$(ui_color reset)  - Chat with AI"
    echo -e "  $(ui_color muted)/code$(ui_color reset)  - Generate code"
    echo -e "  $(ui_color muted)/fix$(ui_color reset)   - Auto fix project"
    echo -e "  $(ui_color muted)/scan$(ui_color reset)  - Scan project"
    echo -e "  $(ui_color muted)/tools$(ui_color reset) - Manage tools"
    echo ""
    
    echo -e "$(ui_color primary)▶ Workspace Info:$(ui_color reset)"
    echo -e "  $(ui_color muted)Dir:$(ui_color reset) $PWD"
    if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        local modified_files
        modified_files=$(git status -s | wc -l)
        echo -e "  $(ui_color muted)Git:$(ui_color reset) $modified_files modified files"
    fi
    echo ""
    
    echo -e "$(ui_color muted)Hint: Type '/' to open Command Palette$(ui_color reset)"
    echo ""
    
    # Returning the input for the dispatcher to use
    if command -v gum >/dev/null 2>&1; then
        gum input --placeholder "Ask Bagas AI anything..."
    else
        local user_input
        echo -n "$(ui_color primary)>$(ui_color reset) "
        read -r user_input
        echo "$user_input"
    fi
}
