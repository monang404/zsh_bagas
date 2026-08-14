# ============================================================
#  30-ai/60-ui/components/header.zsh — Compact Sticky Header
#  AI-FIRST UX: satu baris tipis, selalu tampil, tanpa hero box besar.
#  Format: Bagas AI · session · model · ~/path [dirty N files] · Ntok
# ============================================================

ui_header() {
    local model="${AI_MODEL:-GPT-5.6}"
    local session="${AI_CURRENT_SESSION:-main}"
    local pwd_str="${PWD/#$HOME/~}"
    local token_str="${AI_TOKEN_USAGE:-}"

    local branch_info=""
    if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        local branch
        branch=$(git branch --show-current 2>/dev/null)
        local changed
        changed=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
        if [ "$changed" -gt 0 ]; then
            branch_info="${branch:+$branch }${AI_C_WARN}dirty ${changed}f${AI_C_RESET}"
        else
            branch_info="${branch:-}"
        fi
    fi

    local width inner hz
    width=$(_ai_ui_width)
    inner=$(( width - 2 ))
    if _ai_ui_supports_unicode; then hz="─"; else hz="-"; fi

    # Compose compact line
    local parts="${AI_C_BOLD}Bagas AI${AI_C_RESET}"
    parts+=" ${AI_C_MUTED}·${AI_C_RESET} ${AI_C_PRIMARY}$session${AI_C_RESET}"
    parts+=" ${AI_C_MUTED}·${AI_C_RESET} $model"
    parts+=" ${AI_C_MUTED}·${AI_C_RESET} ${AI_C_MUTED}$pwd_str${AI_C_RESET}"
    [ -n "$branch_info" ] && parts+=" ${AI_C_MUTED}·${AI_C_RESET} $branch_info"
    [ -n "$token_str" ]   && parts+=" ${AI_C_MUTED}·${AI_C_RESET} ${AI_C_MUTED}${token_str}tok${AI_C_RESET}"

    # Divider
    local fill="" i
    for (( i = 0; i < inner; i++ )); do fill+="$hz"; done
    echo "${AI_C_MUTED}${fill}${AI_C_RESET}"
    echo " $parts"
    echo "${AI_C_MUTED}${fill}${AI_C_RESET}"
}
