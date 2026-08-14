# ============================================================
#  30-ai/60-ui/screens/report.zsh — Final Report Screen
#  Blueprint v2: compact done report, tanpa box besar.
# ============================================================

# ui_report(files_changed, runtime, tools_used, next_action, summary_items...)
ui_report() {
    local files_changed="${1:-0}"
    local runtime="${2:-?}"
    local tools_used="${3:-}"
    local next_action="${4:-}"
    shift 4

    local -a summary_items=("$@")

    # Baris utama
    local done_summary="Files: $files_changed"
    [ -n "$tools_used" ] && done_summary+="  Tools: $tools_used"
    _ai_state_done "$done_summary" "$runtime"

    # Summary items
    local item
    for item in "${summary_items[@]}"; do
        printf '  %s✓%s %s\n' "${AI_C_OK:-}" "${AI_C_RESET:-}" "$item"
    done

    if [ -n "$next_action" ]; then
        echo ""
        printf '  %sNext:%s %s\n' "${AI_C_MUTED:-}" "${AI_C_RESET:-}" "$next_action"
    fi

    echo ""
}
