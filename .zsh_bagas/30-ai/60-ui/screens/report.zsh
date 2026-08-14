# ============================================================
# 30-ai/60-ui/screens/report.zsh — Final Report Screen
# ============================================================

ui_report() {
    local files_changed="$1"
    local runtime="$2"
    local tools_used="$3"
    local next_action="$4"
    local summary_text="$5"
    
    clear
    
    # Header
    if typeset -f ui_header >/dev/null; then
        ui_header
    fi
    echo ""
    
    # Summary Card
    if typeset -f ui_card_summary >/dev/null; then
        ui_card_summary "Final Report" "$summary_text"
    fi
    echo ""
    
    # Stats Card
    if typeset -f ui_card_stats >/dev/null; then
        ui_card_stats "$files_changed" "$runtime" "$tools_used"
    fi
    echo ""
    
    # Next Action
    if [[ -n "$next_action" ]]; then
        echo -e "$(ui_color primary)▶ Next Action:$(ui_color reset) $next_action"
    fi
}
