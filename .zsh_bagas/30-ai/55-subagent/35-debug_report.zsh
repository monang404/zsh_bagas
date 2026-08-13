# ============================================================
#  30-ai/55-subagent/35-debug_report.zsh — final `ai debug` report printer
#  (split out of the old monolithic 30-ai/55-subagent.zsh)
# ============================================================

# Pure output helper for aidebug() (40-debug.zsh). Reads the caller's
# (dynamically-scoped) $final_thought/$error/$affected_files/$reproduction
# — does not mutate anything.
_ai_debug_print_report() {
    echo "Diagnosis:"
    if [ -n "$final_thought" ]; then
        echo "$final_thought"
    elif [ -n "$error" ]; then
        echo "Unable to determine root cause."
    else
        echo "Unable to determine root cause."
    fi
    echo
    echo "Evidence:"
    if [ "${#affected_files[@]}" -gt 0 ]; then
        printf '%s\n' "${(k)affected_files}"
    else
        echo "No affected files identified."
    fi
    if [ -n "$error" ]; then
        echo "$error"
    fi
    echo
    echo "Reproduction:"
    if [ "${#reproduction[@]}" -gt 0 ]; then
        printf '%s\n' "${reproduction[@]}"
    else
        echo "No test/command executed."
    fi
    echo
    echo "Affected files:"
    if [ "${#affected_files[@]}" -gt 0 ]; then
        printf '%s\n' "${(k)affected_files}"
    else
        echo "None identified."
    fi
    echo
    echo "Recommended next step:"
    if [ -n "$final_thought" ]; then
        echo "Review the diagnosis above and decide the next action manually; no fix was applied."
    else
        echo "Collect more evidence and rerun the debug investigation; no fix was applied."
    fi
}
