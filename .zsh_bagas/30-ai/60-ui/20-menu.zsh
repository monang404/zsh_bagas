# ============================================================
#  30-ai/60-ui/20-menu.zsh — AI Workspace (AI-FIRST UX)
#  Commit 7 (implementasi_plan.md): konsolidasi entry point.
#  _ai_workspace sekarang DELEGATE ke ui_home() dari screens/home.zsh
#  sebagai satu-satunya sumber render layar awal — menghilangkan
#  duplikasi prompt logic antara dua file ini.
# ============================================================

# _ai_workspace() — entry point tunggal untuk layar awal AI.
# Delegate rendering ke ui_home() (screens/home.zsh) yang sudah
# punya git context, session hint, dan prompt. Routing tetap di sini.
_ai_workspace() {
    local ZSH_BAGAS_DIR="${ZSH_BAGAS:-$HOME/.zsh_bagas}"

    # Load komponen UI + screen home
    source "$ZSH_BAGAS_DIR/30-ai/60-ui/components/header.zsh"    2>/dev/null || true
    source "$ZSH_BAGAS_DIR/30-ai/60-ui/components/palette.zsh"   2>/dev/null || true
    source "$ZSH_BAGAS_DIR/30-ai/60-ui/components/state.zsh"     2>/dev/null || true
    source "$ZSH_BAGAS_DIR/30-ai/60-ui/components/disclosure.zsh" 2>/dev/null || true
    source "$ZSH_BAGAS_DIR/30-ai/60-ui/components/verbosity.zsh" 2>/dev/null || true
    source "$ZSH_BAGAS_DIR/30-ai/60-ui/router.zsh"               2>/dev/null || true
    source "$ZSH_BAGAS_DIR/30-ai/60-ui/screens/home.zsh"         2>/dev/null || true

    # Delegate render + prompt ke ui_home (single source of truth).
    # ui_home() mengembalikan teks yang diketik user via echo.
    local user_input=""
    if type ui_home >/dev/null 2>&1; then
        user_input=$(ui_home)
    else
        # Fallback minimal jika screens/home.zsh belum ter-load
        ui_header 2>/dev/null || true
        echo ""
        printf '%s> %s' "${AI_C_PRIMARY:-}" "${AI_C_RESET:-}"
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
            printf '%sRouter tidak tersedia.%s\n' "${AI_C_WARN:-}" "${AI_C_RESET:-}"
        fi
        return
    fi

    # Semua input lain → langsung dispatch ke engine AI
    ai "$user_input"
}

# Alias lama _ai_menu → tetap berfungsi untuk backward-compat
_ai_menu() { _ai_workspace "$@"; }
