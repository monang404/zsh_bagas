# ============================================================
# 30-ai/60-ui/screens/agent.zsh — Agent Workspace
# ============================================================

ui_agent_dashboard() {
    local action="$1"
    local steps_str="$2"
    local current_idx="$3"
    local output="$4"
    local next_action="$5"
    
    # Clear screen for dashboard feeling
    clear
    
    # 1. Header
    if typeset -f ui_header >/dev/null; then
        ui_header
    fi
    echo ""
    
    # 2. Current Action & Progress
    if typeset -f ui_progress >/dev/null; then
        local total
        if [[ -n "$steps_str" ]]; then
            # Count non-empty lines
            total=$(echo "$steps_str" | grep -c "^" || echo 1)
        else
            total=1
        fi
        ui_progress "$current_idx" "$total" "$action"
    else
        echo -e "$(ui_color primary)▶ Action:$(ui_color reset) $action"
    fi
    echo ""
    
    # 3. Timeline
    if typeset -f ui_timeline >/dev/null; then
        ui_timeline "$steps_str" "$current_idx"
    fi
    echo ""
    
    # 4. Tool Output (if any)
    if [[ -n "$output" ]]; then
        echo -e "$(ui_color muted)╭── Tool Output ────────────────────────────────────────────────────────$(ui_color reset)"
        # Simple indentation for output
        echo "$output" | sed 's/^/│ /'
        echo -e "$(ui_color muted)╰───────────────────────────────────────────────────────────────────────$(ui_color reset)"
        echo ""
    fi
    
    # 5. Next Action
    if [[ -n "$next_action" ]]; then
        echo -e "$(ui_color warning)⏭ Next:$(ui_color reset) $(ui_color text)$next_action$(ui_color reset)"
    fi
}
