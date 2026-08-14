# ============================================================
#  30-ai/60-ui/screens/home.zsh — AI Workspace Home Screen
#  AI-FIRST UX: Header → Context bar → Prompt. Tidak ada menu list.
# ============================================================

ui_home() {
    clear
    local ZSH_BAGAS_DIR="${ZSH_BAGAS:-$HOME/.zsh_bagas}"
    source "$ZSH_BAGAS_DIR/30-ai/60-ui/components/header.zsh" 2>/dev/null || true

    # --- Header ---
    if type ui_header >/dev/null 2>&1; then
        ui_header
    fi

    echo ""

    # --- Workspace context (jika ada recent session atau git info) ---
    local has_context=0
    if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        local modified
        modified=$(git status -s 2>/dev/null | wc -l | tr -d ' ')
        if [ "$modified" -gt 0 ]; then
            echo "  ${AI_C_WARN}●${AI_C_RESET} ${modified} file belum di-commit"
            has_context=1
        fi
    fi
    if [ -n "${AI_CURRENT_SESSION:-}" ] && [ "${AI_CURRENT_SESSION}" != "main" ]; then
        echo "  ${AI_C_INFO}●${AI_C_RESET} Session aktif: ${AI_C_BOLD}${AI_CURRENT_SESSION}${AI_C_RESET}"
        has_context=1
    fi
    [ "$has_context" -eq 1 ] && echo ""

    # --- Hint minimal ---
    echo "  ${AI_C_MUTED}Ketik prompt atau ${AI_C_RESET}/${AI_C_MUTED} untuk Command Palette${AI_C_RESET}"
    echo ""

    # --- Single prompt ---
    local user_input=""
    if command -v gum >/dev/null 2>&1; then
        user_input=$(gum input \
            --placeholder "Ask Bagas AI anything..." \
            --prompt "${AI_C_PRIMARY}> ${AI_C_RESET}" \
            --width 0)
    else
        printf '%s> %s' "${AI_C_PRIMARY}" "${AI_C_RESET}"
        read -r user_input
    fi

    echo "$user_input"
}
