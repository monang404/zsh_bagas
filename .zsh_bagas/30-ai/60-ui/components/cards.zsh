# ============================================================
# 30-ai/60-ui/components/cards.zsh — Summary and Stats Cards
# ============================================================

ui_card_summary() {
    local title="$1"
    local content="$2"
    
    echo -e "$(ui_color border)╭── $(ui_color primary)$title$(ui_color border) ────────────────────────────────────────────────────────$(ui_color reset)"
    # Prefix each line with border
    echo "$content" | while IFS= read -r line || [[ -n "$line" ]]; do
        echo -e "$(ui_color border)│$(ui_color reset) $line"
    done
    echo -e "$(ui_color border)╰──────────────────────────────────────────────────────────────────────$(ui_color reset)"
}

ui_card_stats() {
    local files="$1"
    local runtime="$2"
    local tools="$3"
    
    echo -e "$(ui_color muted)📊 Stats: $(ui_color success)$files files changed$(ui_color muted) | ⏱  Runtime: $(ui_color text)$runtime$(ui_color muted) | 🛠  Tools: $(ui_color text)$tools$(ui_color reset)"
}
