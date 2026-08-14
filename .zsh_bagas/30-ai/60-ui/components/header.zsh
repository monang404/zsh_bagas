# ============================================================
# 30-ai/60-ui/components/header.zsh — Session Header
# ============================================================

ui_header() {
    local project_name=$(basename "$PWD")
    local branch_name="-"
    if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        branch_name=$(git branch --show-current 2>/dev/null)
        [ -z "$branch_name" ] && branch_name="-"
    fi
    
    local model="${AI_MODEL:-default}"
    local mode="${AI_MODE:-chat}"
    local runtime="${AI_RUNTIME:-0s}"
    local token="${AI_TOKEN_USAGE:-0}"

    echo -e "$(ui_color border)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(ui_color reset)"
    echo -e "$(ui_color primary) 📁 Project:$(ui_color reset) $(ui_color bold)$project_name$(ui_color reset) $(ui_color muted)($branch_name)$(ui_color reset)   \
$(ui_color primary)🤖 Model:$(ui_color reset) $model   \
$(ui_color primary)⚡ Mode:$(ui_color reset) $mode"
    echo -e "$(ui_color muted) ⏱  Runtime: $runtime  |  🪙 Tokens: $token$(ui_color reset)"
    echo -e "$(ui_color border)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(ui_color reset)"
}
