# ============================================================
#  30-ai/50-agent/42-execution/25-track_and_continue.zsh — track
#  pengulangan kegagalan tool yang sama, block kalau gak ada progress,
#  append giliran ke session + checkpoint.
#  (split out of the old monolithic 30-ai/50-agent/42-execution.zsh)
#
#  Return code: 0 = lanjut normal, 1 = harus `break` loop (dari
#  caller, gagal berulang tanpa progress).
# ============================================================

_ai_agent_exec_track_and_continue() {
    if [ "$exit_status" -ne 0 ]; then
        if [ "$tool" = "$last_failed_tool" ] && [ "$args" = "$last_failed_args" ]; then
            same_fail_count=$((same_fail_count+1))
        else
            same_fail_count=1
            last_failed_tool="$tool"
            last_failed_args="$args"
        fi
        if [ "$same_fail_count" -ge "$AI_AGENT_MAX_SAME_FAIL" ]; then
            echo ""
            echo "[berhenti: panggilan tool yang sama gagal $same_fail_count kali berturut-turut, gak ada progress. Cek manual.]"
            _ai_ui_line "✗" "$tool -- berhenti, gagal berulang"
            block_reason="Tool '$tool' gagal $same_fail_count kali berturut-turut (step $step)"
            _ai_agent_state_transition "$state_dir" BLOCKED 2>/dev/null || true
            return 1
        fi
    else
        same_fail_count=0
        last_failed_tool=""
        last_failed_args=""
    fi

    jq --arg a "$reply" --arg r "Output:
$output" \
        '. + [{"role":"assistant","content":$a},{"role":"user","content":$r}]' \
        "$msgfile" > "$msgfile.tmp.$$" && command mv -f "$msgfile.tmp.$$" "$msgfile"
    _ai_trim_session "$msgfile"
    _ai_agent_checkpoint_save "$checkpoint_file" "$goal" "$step" "$msgfile"
    return 0
}
