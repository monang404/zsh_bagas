# ============================================================
#  30-ai/60-ui/20-menu.zsh — AI Workspace (AI-FIRST UX)
#  Paradigma baru: satu prompt utama, AI menentukan mode.
#  Menggantikan menu panjang 27-item dengan workspace prompt.
# ============================================================

# _ai_workspace() — tampilkan AI Workspace dengan single prompt.
# Input user langsung di-dispatch ke engine AI yang sudah ada.
# Prefix "/" membuka Command Palette.
_ai_workspace() {
    local ZSH_BAGAS_DIR="${ZSH_BAGAS:-$HOME/.zsh_bagas}"

    # Load komponen UI
    source "$ZSH_BAGAS_DIR/30-ai/60-ui/components/header.zsh" 2>/dev/null || true
    source "$ZSH_BAGAS_DIR/30-ai/60-ui/components/palette.zsh" 2>/dev/null || true
    source "$ZSH_BAGAS_DIR/30-ai/60-ui/components/state.zsh" 2>/dev/null || true
    source "$ZSH_BAGAS_DIR/30-ai/60-ui/components/disclosure.zsh" 2>/dev/null || true
    source "$ZSH_BAGAS_DIR/30-ai/60-ui/components/verbosity.zsh" 2>/dev/null || true
    source "$ZSH_BAGAS_DIR/30-ai/60-ui/router.zsh" 2>/dev/null || true

    # --- Render Workspace Header ---
    if type ui_header >/dev/null 2>&1; then
        ui_header
    else
        # Minimal fallback header
        local model="${AI_MODEL:-GPT-5.6}"
        local session="${AI_CURRENT_SESSION:-main}"
        local pwd_str="${PWD/#$HOME/~}"
        echo "${AI_C_MUTED}─────────────────────────────────────────${AI_C_RESET}"
        echo "${AI_C_BOLD}Bagas AI${AI_C_RESET}  ${AI_C_MUTED}$session • $model • $pwd_str${AI_C_RESET}"
        echo "${AI_C_MUTED}─────────────────────────────────────────${AI_C_RESET}"
    fi

    # --- Recent context (jika ada session aktif) ---
    if [ -n "${AI_CURRENT_SESSION:-}" ] && [ "${AI_CURRENT_SESSION}" != "main" ]; then
        echo "${AI_C_MUTED}  Session: ${AI_CURRENT_SESSION}${AI_C_RESET}"
    fi

    # --- Prompt utama ---
    echo ""
    local user_input=""

    if command -v gum >/dev/null 2>&1; then
        user_input=$(gum input \
            --placeholder "Ask Bagas AI anything... (/ untuk Command Palette)" \
            --prompt "${AI_C_PRIMARY}> ${AI_C_RESET}" \
            --width 0)
    else
        printf '%s> %s' "${AI_C_PRIMARY}" "${AI_C_RESET}"
        read -r user_input
    fi

    [ -z "$user_input" ] && return 0

    # --- Routing ---
    # Prefix "/" → Command Palette
    if [[ "$user_input" == /* ]]; then
        local slash_cmd="${user_input#/}"
        if type ui_router >/dev/null 2>&1; then
            ui_router "$slash_cmd"
        else
            echo "${AI_C_WARN}Router tidak tersedia.${AI_C_RESET}"
        fi
        return
    fi

    # Semua input lain → langsung dispatch ke engine AI
    # Engine (dispatcher) sudah punya logika: subcommand typo-check,
    # fallback ke aic() (chat), dan AI otomatis memilih mode via prompt.
    ai "$user_input"
}

# Alias lama _ai_menu → tetap berfungsi untuk backward-compat
_ai_menu() { _ai_workspace "$@"; }
