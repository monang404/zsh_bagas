# ============================================================
#  30-ai/60-ui/screens/agent.zsh — Agent Dashboard
#  AI-FIRST UX: satu hero box dengan internal divider (---).
#  State functions dari components/state.zsh dipakai di luar box
#  untuk live streaming updates; hero box dirender hanya di awal
#  dan di akhir (Done/Error).
# ============================================================

# ui_agent_start(goal, total_steps) — render hero box awal agent
ui_agent_start() {
    local goal="${1:-Running...}"
    local total="${2:-?}"

    _ai_ui_box "AI Agent" \
        "Goal: $goal" \
        "---" \
        "Steps: $total" \
        "Status: RUNNING"
    echo ""
}

# ui_agent_dashboard(action, steps_str, current_idx, output, next_action)
# Render hero box penuh dengan progress + timeline. Cocok dipanggil
# saat agent selesai atau saat perlu tampilkan state lengkap.
ui_agent_dashboard() {
    local action="$1"
    local steps_str="$2"
    local current_idx="${3:-1}"
    local output="$4"
    local next_action="$5"

    clear

    local -a lines=()
    lines+=("$action")
    lines+=("---")

    # Progress
    local total=1
    if [[ -n "$steps_str" ]]; then
        total=$(printf '%s\n' "$steps_str" | grep -c '.' || echo 1)
    fi
    lines+=("Progress $current_idx/$total")

    # Progress bar (max 20 chars, aman di 80 cols)
    local bar_len=20
    local filled=$(( bar_len * current_idx / (total > 0 ? total : 1) ))
    local bar="" i
    for (( i = 0; i < filled; i++ )); do bar+="█"; done
    for (( i = filled; i < bar_len; i++ )); do bar+="░"; done
    lines+=("$bar")
    lines+=("---")

    # Timeline
    if [[ -n "$steps_str" ]]; then
        local idx=1
        while IFS= read -r step_line; do
            [ -z "$step_line" ] && continue
            if (( idx < current_idx )); then
                lines+=("✓ $step_line")
            elif (( idx == current_idx )); then
                lines+=("● $step_line")
            else
                lines+=("○ $step_line")
            fi
            (( idx++ ))
        done <<< "$steps_str"
    fi

    # Current command / tool output
    if [[ -n "$output" ]]; then
        lines+=("---")
        lines+=("Current command")
        lines+=("$output")
    fi

    # Next action
    if [[ -n "$next_action" ]]; then
        lines+=("---")
        lines+=("Next")
        lines+=("$next_action")
    fi

    _ai_ui_box "AI Agent RUNNING" "${lines[@]}"
    echo ""
}

# ui_agent_done(files_changed, runtime, summary_items...)
# Render final SUCCESS box sesuai mockup blueprint.
ui_agent_done() {
    local files_changed="${1:-0}"
    local runtime="${2:-?}"
    shift 2
    local -a items=("$@")

    local -a lines=()
    lines+=("Files: $files_changed")
    lines+=("Time:  $runtime")

    if [ "${#items[@]}" -gt 0 ]; then
        lines+=("---")
        local item
        for item in "${items[@]}"; do
            lines+=("✓ $item")
        done
    fi

    _ai_ui_box "SUCCESS" "${lines[@]}"
    echo ""
}

# ui_agent_error(reason)
ui_agent_error() {
    local reason="${1:-Unknown error}"
    _ai_ui_box "FAILED" "$reason"
    echo ""
}
