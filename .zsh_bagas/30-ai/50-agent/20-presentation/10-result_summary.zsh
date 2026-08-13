# ============================================================
#  30-ai/20-presentation/10-result_summary.zsh — _ai_agent_result_summary — ringkasan hasil tool 1 baris buat tampilan compact
#  (split out of the old monolithic 30-ai/50-agent/20-presentation.zsh)
# ============================================================

# Task 1.3: ringkasan hasil tool jadi SATU BARIS buat ditampilin abis
# icon ✓/✗ -- gak pernah nge-dump seluruh $output (apalagi JSON mentah)
# ke layar. Full $output tetap dipakai apa adanya buat konteks LLM
# (dikirim balik ke msgfile) & buat agent_runs/*.jsonl, cuma versi yang
# nyampe ke terminal user yang diringkas di sini.
_ai_agent_result_summary() {
    local tool="$1" output="$2" rc="$3"
    local total_lines first_line

    if [ -z "$output" ]; then
        if [ "$rc" -eq 0 ]; then
            echo "selesai (tidak ada output)"
        else
            echo "gagal (exit $rc)"
        fi
        return
    fi

    # Kasus khusus run_command/run_test dengan output verbose (pytest -v,
    # npm test, go test, dsb): jangan tampilin ratusan baris, cukup baris
    # ringkasan "N passed/failed/..." kalau ketemu (biasanya di baris
    # terakhir output test runner).
    local test_hits
    test_hits=$(printf '%s\n' "$output" | tail -n 8 \
        | grep -Eo '[0-9]+ (passed|failed|error(s)?|skipped|warning(s)?)' \
        | paste -sd', ' - 2>/dev/null)
    if [ -n "$test_hits" ]; then
        echo "$test_hits"
        return
    fi

    total_lines=$(printf '%s\n' "$output" | wc -l | tr -d ' ')
    first_line=$(printf '%s\n' "$output" | sed -n '1p')
    # Prefix "OK:"/"ERROR:" tools udah cukup jelas dari icon ✓/✗ yang
    # nemenin baris ini, jadi gak perlu diulang.
    first_line="${first_line#OK: }"
    first_line="${first_line#ERROR: }"
    first_line="${first_line#ERROR }"

    if [ "${#first_line}" -gt 72 ]; then
        first_line="${first_line[1,72]}…"
    fi
    [ -z "$first_line" ] && first_line="(kosong)"

    if [ "$total_lines" -gt 1 ]; then
        echo "${first_line} (+$((total_lines - 1)) baris lainnya)"
    else
        echo "$first_line"
    fi
}

