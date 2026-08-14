# ============================================================
# 30-ai/60-ui/screens/palette.zsh — Command Palette
# ============================================================

ui_palette() {
    if ! command -v gum >/dev/null 2>&1; then
        echo -e "$(ui_color danger)Error: 'gum' is not installed. Please install gum to use the command palette.$(ui_color reset)"
        return 1
    fi

    local -a options=(
        "chat  - Chat with AI"
        "code  - Generate Code"
        "fix   - Fix Project"
        "scan  - Scan Project"
        "tools - Manage Tools"
    )
    
    local selected
    # Using gum filter to show a palette
    selected=$(printf "%s\n" "${options[@]}" | gum filter --placeholder="Type a command or /action...")
    
    # Extract the command (first word)
    local cmd="${selected%% *}"
    
    if [[ -n "$cmd" ]]; then
        ui_router "$cmd"
    fi
}
