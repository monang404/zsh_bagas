# ============================================================
#  30-ai/60-ui/screens/agent.zsh — Agent State Renderer
#  Blueprint v2 §4: Agent memakai state machine, tanpa hero box.
#  States: Idle → Thinking → Acting → Approval → Done/Error
# ============================================================

# ui_agent_start(goal, total_steps) — Blueprint v2 §4: compact state
ui_agent_start() {
    local goal="${1:-Running...}"
    local total="${2:-?}"
    _ai_state_step "$goal"
    if [ "$total" != "?" ] && [ "$total" != "" ]; then
        printf '  %sSteps: %s%s\n' "${AI_C_MUTED:-}" "$total" "${AI_C_RESET:-}"
    fi
    echo ""
}

# ui_agent_dashboard(action, steps_str, current_idx, output, next_action)
# Blueprint v2 §4: compact timeline tanpa box besar.
ui_agent_dashboard() {
    local action="$1"
    local steps_str="$2"
    local current_idx="${3:-1}"
    local output="$4"
    local next_action="$5"

    # Status aksi saat ini
    _ai_state_step "$action"

    # Timeline compact
    if [[ -n "$steps_str" ]]; then
        local total=1
        total=$(printf '%s\n' "$steps_str" | grep -c '.' || echo 1)
        printf '  Progress %s/%s\n' "$current_idx" "$total"

        local idx=1
        while IFS= read -r step_line; do
            [ -z "$step_line" ] && continue
            if (( idx < current_idx )); then
                printf '  %s✓%s %s\n' "${AI_C_OK:-}" "${AI_C_RESET:-}" "$step_line"
            elif (( idx == current_idx )); then
                printf '  %s●%s %s\n' "${AI_C_INFO:-}" "${AI_C_RESET:-}" "$step_line"
            else
                printf '  %s○%s %s\n' "${AI_C_MUTED:-}" "${AI_C_RESET:-}" "$step_line"
            fi
            (( idx++ ))
        done <<< "$steps_str"
    fi

    # Output / command saat ini
    if [[ -n "$output" ]]; then
        echo ""
        printf '  %s%s%s\n' "${AI_C_MUTED:-}" "$output" "${AI_C_RESET:-}"
    fi

    echo ""
}

# ui_agent_done(files_changed, runtime, summary_items...)
# Blueprint v2: compact done report tanpa box besar.
ui_agent_done() {
    local files_changed="${1:-0}"
    local runtime="${2:-?}"
    shift 2
    local -a items=("$@")

    _ai_state_done "Files: $files_changed" "$runtime"

    if [ "${#items[@]}" -gt 0 ]; then
        local item
        for item in "${items[@]}"; do
            printf '  %s✓%s %s\n' "${AI_C_OK:-}" "${AI_C_RESET:-}" "$item"
        done
    fi
    echo ""
}

# ui_agent_error(reason)
ui_agent_error() {
    local reason="${1:-Unknown error}"
    _ai_state_error "$reason"
    echo ""
}
