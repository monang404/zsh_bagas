# ============================================================
# 30-ai/60-ui/components/progress.zsh — Progress Bar
# ============================================================

ui_progress() {
    local current=$1
    local total=$2
    local message=$3
    
    if [[ -z "$total" || "$total" -eq 0 ]]; then
        total=1
    fi
    if [[ -z "$current" ]]; then
        current=0
    fi
    
    local width=20
    local filled=$(( current * width / total ))
    local empty=$(( width - filled ))
    
    local bar=""
    local i
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done
    
    echo -e "$(ui_color primary)⟳$(ui_color reset) $(ui_color text)$message$(ui_color reset) $(ui_color muted)[$current/$total]$(ui_color reset) $(ui_color success)$bar$(ui_color reset)"
}
