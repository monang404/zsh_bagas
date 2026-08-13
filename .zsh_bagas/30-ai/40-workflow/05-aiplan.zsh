# ============================================================
#  30-ai/40-workflow/05-aiplan.zsh — aiplan — rencana terstruktur dari goal
#  (split out of the old monolithic 30-ai/40-workflow.zsh)
# ============================================================

# ─── Fungsi (v2): planning, prompt engineering, review, dll ──

aiplan() {
    _ai_need_any_key || return 1
    if [ -z "$1" ]; then
        echo "Usage: ai plan <goal/tujuan>"
        return 1
    fi
    mkdir -p "$AI_PLAN_DIR"
    local goal="$*"
    local slug=$(echo "$goal" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '_' | cut -c1-40)
    local outfile="$AI_PLAN_DIR/${slug}_$(_ai_ts).md"
    local msgfile=$(mktemp)
    jq -n --arg p "Kamu expert perencana produktivitas. Diberikan sebuah goal, buat rencana terstruktur dalam format Markdown dengan bagian: 1) Ringkasan singkat goal (2 kalimat). 2) Breakdown milestone (fase-fase besar, urut). 3) Checklist task per milestone pakai format '- [ ] task', konkret dan actionable. 4) Estimasi waktu tiap milestone kalau relevan. 5) Potensi hambatan & cara mitigasinya. Bahasa Indonesia, langsung ke inti, tanpa basa-basi pembuka." \
        --arg g "Goal: $goal" \
        '[{role:"system",content:$p},{role:"user",content:$g}]' > "$msgfile"

    echo "Generating rencana..."
    local reply
    reply=$(_ai_chat_request "$msgfile" "" smart "${AI_TASK_PROVIDER_ORDER_SMART[*]}")
    rm -f "$msgfile"

    # v-fix (audit lanjutan): zsh `echo` nge-interpret backslash-escape
    # (\n dsb) secara default -- kalau $reply (teks Markdown hasil AI)
    # kebetulan ada literal \n di isinya, `echo` diam-diam ngubahnya jadi
    # newline beneran di file tersimpan. printf '%s\n' nulis apa adanya.
    printf '%s\n' "$reply" > "$outfile"
    echo "$reply"
    echo ""
    echo "Rencana tersimpan di: $outfile"
    _ai_notify "Rencana siap" "$goal"
    _ai_log "plan" "$goal" "saved to $outfile"
}

