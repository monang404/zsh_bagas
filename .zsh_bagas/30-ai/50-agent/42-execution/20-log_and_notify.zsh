# ============================================================
#  30-ai/50-agent/42-execution/20-log_and_notify.zsh — log hasil tool
#  ke runs_logfile (jsonl), cetak baris ✓/✗ compact, kirim notifikasi
#  progress (rate-limited).
#  (split out of the old monolithic 30-ai/50-agent/42-execution.zsh)
# ============================================================

_ai_agent_exec_log_and_notify() {
    setopt localoptions noxtrace
    local args_summary res_summary ft_json result_disp
    local -i _now_ts

    # Logging session human-readable
    # FIX BUG-2: pakai $runs_logfile yang sudah dideklarasikan di luar loop
    args_summary=$(echo "$args" | jq -c '.' 2>/dev/null | cut -c 1-50)
    res_summary="ok"
    [ "$exit_status" -ne 0 ] && res_summary="error (exit $exit_status)"

    ft_json="[]"
    if [ "$exit_status" -eq 0 ] && [ -n "$filepath" ] && \
       [[ "$tool" == "write_file" || "$tool" == "edit_file" ]]; then
        ft_json=$(jq -n --arg p "$filepath" '[$p]')
        changed_files[$filepath]=1
    fi

    # Task 1.3: $output PENUH (sudah di-cap 3000 char dari sebelumnya,
    # kebijakan lama, gak berubah) tetap disimpan di log jsonl yang
    # sudah ada ini -- biar terminal cuma nampilin ringkasan ✓/✗ tapi
    # detail lengkap tetap bisa dilihat lewat 'ai agent --log <slug>'.
    jq -nc --argjson s "$step" --arg t "$tool" --arg a "${args_summary}..." \
        --arg r "$res_summary" --arg ts "$(_ai_ts)" \
        --argjson ft "$ft_json" --arg out "$output" \
        '{step:$s, tool:$t, args_summary:$a, result:$r, files_touched:$ft, ts:$ts, output:$out}' >> "$runs_logfile"

    # Task 1.3: baris hasil compact "✓ ringkasan" / "✗ pesan_error" --
    # tool result (JSON/teks mentah) TIDAK di-print apa adanya ke
    # user. $output lengkap (sampai 3000 char, sama kayak sebelumnya)
    # tetap jalan terus ke jsonl log (field "output" di atas) & ke
    # konteks pesan buat LLM di bawah, cuma yang nyampe ke layar
    # yang diringkas. Dicetak SEBELUM cek same_fail_count biar tetap
    # keliatan walau langkah ini yang bikin loop berhenti.
    result_disp=$(_ai_agent_result_summary "$tool" "$output" "$exit_status")
    if [ "$exit_status" -eq 0 ]; then
        _ai_ui_line "✓" "$result_disp"
    else
        _ai_ui_line "✗" "$result_disp"
    fi

    # Task 12.2: update notifikasi progress (id tetap aiagent_progress,
    # lihat _ai_notify_progress di 10-core.zsh) SETELAH baris ✓/✗
    # dicetak, biar isinya reflect status step ini (ok/gagal) --
    # SAMA seperti $result_disp yang barusan ditampilkan ke layar,
    # bukan konteks/reasoning tambahan baru. Rate-limit pakai
    # AI_NOTIFY_MIN_INTERVAL_SEC biar step yang sangat cepat
    # berturut-turut gak spam update; step pertama (last_notify_ts=0)
    # SELALU langsung kirim. Ini SENGAJA dicetak SEBELUM cek
    # same_fail_count di bawah, biar step yang bikin loop berhenti pun
    # tetap ke-notify.
    _now_ts=$(date +%s)
    if [ $(( _now_ts - last_notify_ts )) -ge "${AI_NOTIFY_MIN_INTERVAL_SEC:-3}" ]; then
        local _notify_status="ok"
        [ "$exit_status" -ne 0 ] && _notify_status="gagal"
        _ai_notify_progress "AI Agent: step $step/$max_step" "$tool -> $_notify_status"
        last_notify_ts=$_now_ts
    fi
}
