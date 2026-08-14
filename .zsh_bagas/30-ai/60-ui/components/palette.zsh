# ============================================================
# 30-ai/60-ui/components/palette.zsh — Command Palette
# ============================================================

ui_palette() {
    local -a items=("$@")
    
    if ! command -v gum >/dev/null; then
        echo "gum tidak ditemukan. Install dengan: pkg install gum"
        return 1
    fi
    
    # Format untuk gum filter: "Label • Deskripsi"
    local choice
    choice=$(printf "%s\n" "${items[@]}" | gum filter --placeholder "Search command..." --indicator=">" --height=15)
    
    # Return hanya label utamanya (sebelum •)
    if [ -n "$choice" ]; then
        echo "${choice%% •*}" | xargs
    fi
}
