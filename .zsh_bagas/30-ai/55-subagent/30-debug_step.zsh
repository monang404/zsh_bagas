# ============================================================
#  30-ai/55-subagent/30-debug_step.zsh — one step of the `ai debug` loop
#  (split out of the old monolithic 30-ai/55-subagent.zsh)
# ============================================================

# Runs a single chat+tool step for aidebug() (40-debug.zsh). Reads
# $msgfile from the caller and writes back into the CALLER's locals
# (dynamically scoped, same pattern as 15-run_step.zsh): reply,
# chat_status, thought, tool, args, done_flag, output, exit_status,
# diagnosis_status, error, final_thought, reproduction (array),
# affected_files (assoc array).
#
#   return 0 -> caller should keep looping
#   return 1 -> caller should break (a terminal state was set)
_ai_debug_step() {
    local pdir filepath

    reply=$(_ai_chat_request "$msgfile" "json" smart "${AI_TASK_PROVIDER_ORDER_AGENT[*]}")
    chat_status=$?
    if [ "$chat_status" -ne 0 ]; then
        error="_ai_chat_request gagal (step ${step})"
        return 1
    fi

    pdir=$(_ai_agent_parse "$reply")
    thought=$(<"$pdir/thought")
    tool=$(<"$pdir/tool")
    args=$(<"$pdir/args")
    done_flag=$(<"$pdir/done")
    rm -rf "$pdir"

    [ -n "$thought" ] && final_thought="$thought"

    if [ "$done_flag" = "true" ]; then
        diagnosis_status="success"
        return 1
    fi

    if [ -z "$tool" ]; then
        error="tidak ada tool & done=false (step ${step})"
        return 1
    fi

    # SECURITY: debug-specific guard MUST run before dispatcher.
    if ! _ai_debug_tool_allowed "$tool"; then
        output="PERMISSION DENIED"
        exit_status=1
    else
        output=$(_ai_tool_dispatch "$tool" "$args" 2>&1)
        exit_status=$?
    fi
    output=$(printf '%s' "$output" | _ai_head_c 3000)

    filepath=$(echo "$args" | jq -r '.path // empty' 2>/dev/null)
    [ -n "$filepath" ] && affected_files[$filepath]=1
    if [ "$tool" = "run_test" ] || [ "$tool" = "run_command" ]; then
        reproduction+=("$tool: $output")
    fi

    jq --arg a "$reply" --arg r "Output:
${output}" \
        '. + [{"role":"assistant","content":$a},{"role":"user","content":$r}]' \
        "$msgfile" > "$msgfile.tmp.$$" && command mv -f "$msgfile.tmp.$$" "$msgfile"
    _ai_trim_session "$msgfile"

    # A denied/failed mutation must never be retried indefinitely.
    if [ "$exit_status" -ne 0 ] && [ "$tool" != "run_command" ] && [ "$tool" != "run_test" ]; then
        error="tool '${tool}' ditolak/gagal pada step ${step}"
        return 1
    fi
    return 0
}
