# ============================================================
# 30-ai/60-ui/router.zsh — Router for Quick Actions
# ============================================================

ui_router() {
    local cmd="$1"
    shift
    
    # Removing leading slash if any
    cmd="${cmd#/}"
    
    case "$cmd" in
        chat)
            if typeset -f _ai_dispatch >/dev/null; then
                _ai_dispatch chat "$@"
            else
                echo -e "$(ui_color info)Chat mode initialized...$(ui_color reset)"
            fi
            ;;
        code)
            if typeset -f _ai_dispatch >/dev/null; then
                _ai_dispatch code "$@"
            else
                echo -e "$(ui_color info)Code generation initialized...$(ui_color reset)"
            fi
            ;;
        fix)
            if typeset -f _ai_dispatch >/dev/null; then
                _ai_dispatch fix "$@"
            else
                echo -e "$(ui_color info)Auto fix initialized...$(ui_color reset)"
            fi
            ;;
        scan)
            if typeset -f _ai_dispatch >/dev/null; then
                _ai_dispatch scan "$@"
            else
                echo -e "$(ui_color info)Project scan initialized...$(ui_color reset)"
            fi
            ;;
        tools)
            if typeset -f _ai_dispatch >/dev/null; then
                _ai_dispatch tools "$@"
            else
                echo -e "$(ui_color info)Tools menu initialized...$(ui_color reset)"
            fi
            ;;
        *)
            echo -e "$(ui_color danger)Unknown action: $cmd$(ui_color reset)"
            ;;
    esac
}
