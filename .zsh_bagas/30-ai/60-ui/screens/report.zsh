# ============================================================
#  30-ai/60-ui/screens/report.zsh — Final Report Screen
#  AI-FIRST UX: compact hero box sesuai mockup blueprint.
# ============================================================

# ui_report(files_changed, runtime, tools_used, next_action, summary_items...)
ui_report() {
    local files_changed="${1:-0}"
    local runtime="${2:-?}"
    local tools_used="${3:-}"
    local next_action="${4:-}"
    shift 4

    local -a summary_items=("$@")

    local -a lines=()
    lines+=("Files: $files_changed")
    lines+=("Time:  $runtime")
    [ -n "$tools_used" ] && lines+=("Tools: $tools_used")
    lines+=("---")

    local item
    for item in "${summary_items[@]}"; do
        lines+=("✓ $item")
    done

    if [ -n "$next_action" ]; then
        lines+=("---")
        lines+=("Next")
        lines+=("$next_action")
    fi

    _ai_ui_box "Task Completed SUCCESS" "${lines[@]}"
    echo ""
}
