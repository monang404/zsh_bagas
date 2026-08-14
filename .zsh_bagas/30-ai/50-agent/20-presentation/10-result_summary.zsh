# _ai_agent_result_summary(tool, output, rc)
# Tampilkan ringkasan output tool ke terminal user.
#
# Strategi:
#  - Test runner (pytest/npm/go): selalu ringkas ke "N passed/failed"
#  - Output <= AI_AGENT_SHOW_LINES: tampilkan semua baris (default 20)
#  - Output > AI_AGENT_SHOW_LINES: tampilkan N baris + "(+X baris lainnya)"
#
# AI_AGENT_SHOW_LINES: override lewat env/90-local/local.zsh (default 20)
# Ini berbeda dari cap token LLM (3000 char di 15-run_tool.zsh) yang tidak
# diubah — full output tetap dikirim ke AI, hanya tampilan user yang dibatasi.
_ai_agent_result_summary() {
    setopt localoptions noxtrace
    local tool="$1" output="$2" rc="$3"
    local max_show="${AI_AGENT_SHOW_LINES:-20}"

    if [ -z "$output" ]; then
        if [ "$rc" -eq 0 ]; then
            echo "selesai (tidak ada output)"
        else
            echo "gagal (exit $rc)"
        fi
        return
    fi

    # Kasus khusus: test runner summary (pytest/npm/go test)
    local test_hits
    test_hits=$(printf '%s\n' "$output" | tail -n 8 \
        | grep -Eo '[0-9]+ (passed|failed|error(s)?|skipped|warning(s)?)' \
        | paste -sd', ' - 2>/dev/null)
    if [ -n "$test_hits" ]; then
        echo "$test_hits"
        return
    fi

    local total_lines
    total_lines=$(printf '%s\n' "$output" | wc -l | tr -d ' ')

    # Output pendek: tampilkan semua baris
    if [ "$total_lines" -le "$max_show" ]; then
        printf '%s\n' "$output"
        return
    fi

    # Output panjang: tampilkan max_show baris + counter sisa
    printf '%s\n' "$output" | head -n "$max_show"
    local remaining=$(( total_lines - max_show ))
    printf '%s(+%d baris lainnya — /details untuk lihat semua)%s\n' \
        "${AI_C_MUTED:-}" "$remaining" "${AI_C_RESET:-}"
}

