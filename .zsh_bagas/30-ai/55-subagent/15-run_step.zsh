# ============================================================
#  30-ai/55-subagent/15-run_step.zsh — one step of the subagent loop
#  (split out of the old monolithic 30-ai/55-subagent.zsh)
# ============================================================

# Runs a single chat+tool step for _ai_subagent_run (20-run.zsh). Reads
# $role/$msgfile/$runs_logfile/$max_same_fail and writes back into the
# CALLER's locals (zsh locals are dynamically scoped, so a called
# function reaches the caller's frame as long as it doesn't re-declare
# the same names with `local`): reply, chat_status, thought, tool, args,
# done_flag, output, exit_status, filepath, sub_status, summary, error,
# final_thought, last_failed_tool, last_failed_args, same_fail_count,
# files_affected (assoc array).
#
#   return 0 -> caller should keep looping
#   return 1 -> caller should break (a terminal state was set)
_ai_subagent_step() {
    local pdir args_summary res_summary ft_json

    reply=$(_ai_chat_request "$msgfile" "json" smart "${AI_TASK_PROVIDER_ORDER_AGENT[*]}")
    chat_status=$?
    if [ "$chat_status" -ne 0 ]; then
        sub_status="failed"
        summary="Subagent gagal mendapatkan respons dari AI."
        error="_ai_chat_request gagal (step ${step})"
        return 1
    fi

    pdir=$(_ai_agent_parse "$reply")
    thought=$(<"$pdir/thought")
    tool=$(<"$pdir/tool")
    args=$(<"$pdir/args")
    done_flag=$(<"$pdir/done")
    rm -rf "$pdir"

    if [ -z "$thought" ] && [ -z "$tool" ] && [ "$done_flag" != "true" ]; then
        sub_status="failed"
        summary="Subagent berhenti, balasan AI bukan JSON yang valid."
        error="format JSON tidak valid (step ${step})"
        return 1
    fi

    [ -n "$thought" ] && final_thought="$thought"

    if [ "$done_flag" = "true" ]; then
        sub_status="success"
        summary="${thought:-Subagent selesai tanpa catatan tambahan.}"
        return 1
    fi

    if [ -z "$tool" ]; then
        sub_status="failed"
        summary="Subagent berhenti tanpa memilih tool dan tanpa menyatakan selesai."
        error="tidak ada tool & done=false (step ${step})"
        return 1
    fi

    # ── urutan WAJIB: tool valid -> role permission -> dispatch ──
    if [[ -z "${AI_TOOL_REGISTRY[$tool]}" ]]; then
        output="ERROR: tool '${tool}' tidak dikenal."
        exit_status=1
    elif ! _ai_subagent_tool_allowed "$role" "$tool"; then
        output="ERROR: tool '${tool}' tidak diizinkan untuk role '${role}'."
        exit_status=1
    else
        output=$(_ai_tool_dispatch "$tool" "$args" 2>&1)
        exit_status=$?
    fi
    output=$(printf '%s' "$output" | _ai_head_c 3000)

    # v-fix (audit lanjutan, sama kelas bug kayak 42-execution/15-run_tool.zsh
    # main agent): "move_file" args-nya {path: SUMBER, dest: TUJUAN}. Ambil
    # ".path" doang di sini bikin "files_affected" (yang dilaporkan balik ke
    # main agent sebagai "daftar path yang dibaca/diubah") nyebutin path
    # SUMBER yang udah gak eksis lagi setelah move sukses -- bukan lokasi
    # file yang beneran ada sekarang. Fallback ".dest // .path" generik:
    # cuma move_file yang punya field "dest", tool lain otomatis fallback
    # ke ".path" seperti biasa.
    filepath=$(echo "$args" | jq -r '.dest // .path // empty' 2>/dev/null)
    [ -n "$filepath" ] && files_affected[$filepath]=1

    # ── log ke directory existing, schema field existing + tag
    #    subagent (agent_type/role) tanpa merusak format main agent ──
    args_summary=$(echo "$args" | jq -c '.' 2>/dev/null | cut -c 1-50)
    res_summary="ok"
    [ "$exit_status" -ne 0 ] && res_summary="error (exit ${exit_status})"
    ft_json="[]"
    [ -n "$filepath" ] && ft_json=$(jq -n --arg p "$filepath" '[$p]')
    jq -nc --argjson s "$step" --arg t "$tool" --arg a "${args_summary}" \
        --arg r "$res_summary" --arg ts "$(_ai_ts)" \
        --argjson ft "$ft_json" --arg out "$output" \
        --arg at "subagent" --arg rl "$role" \
        '{step:$s, tool:$t, args_summary:$a, result:$r, files_touched:$ft, ts:$ts, output:$out, agent_type:$at, role:$rl}' \
        >> "$runs_logfile"

    # ── guard sederhana: tool sama gagal berulang -> stop, jangan
    #    loop forever nyoba tool yang sama (pola sama kayak
    #    aiagent(), pakai AI_AGENT_MAX_SAME_FAIL kalau tersedia) ──
    if [ "$exit_status" -ne 0 ]; then
        if [ "$tool" = "$last_failed_tool" ] && [ "$args" = "$last_failed_args" ]; then
            same_fail_count=$((same_fail_count + 1))
        else
            same_fail_count=1
            last_failed_tool="$tool"
            last_failed_args="$args"
        fi
        if [ "$same_fail_count" -ge "$max_same_fail" ]; then
            sub_status="failed"
            summary="Subagent berhenti, tool '${tool}' gagal ${same_fail_count}x berturut-turut."
            error="tool '${tool}' gagal berulang (step ${step})"
            return 1
        fi
    else
        same_fail_count=0
        last_failed_tool=""
        last_failed_args=""
    fi

    # ── hasil tool masuk context (pola sama kayak aiagent()) ──
    jq --arg a "$reply" --arg r "Output:
${output}" \
        '. + [{"role":"assistant","content":$a},{"role":"user","content":$r}]' \
        "$msgfile" > "$msgfile.tmp.$$" && command mv -f "$msgfile.tmp.$$" "$msgfile"
    _ai_trim_session "$msgfile"
    return 0
}
