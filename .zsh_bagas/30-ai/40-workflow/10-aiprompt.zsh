# ============================================================
#  30-ai/40-workflow/10-aiprompt.zsh — aiprompt — prompt engineering siap pakai dari deskripsi tugas
#  (split out of the old monolithic 30-ai/40-workflow.zsh)
# ============================================================

aiprompt() {
    _ai_need_any_key || return 1
    if [ -z "$1" ]; then
        echo "Usage: ai prompt <deskripsi tugas>"
        return 1
    fi
    mkdir -p "$AI_PROMPT_DIR"
    local task="$*"
    local slug=$(echo "$task" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '_' | cut -c1-40)
    local outfile="$AI_PROMPT_DIR/${slug}_$(_ai_ts).txt"
    local msgfile=$(mktemp)
    jq -n --arg p "Kamu expert prompt engineering. Diberikan deskripsi tugas dari user, buat SATU prompt terstruktur dan siap pakai untuk dikasih ke LLM lain. Wajib ada bagian dengan header berikut, dalam bahasa Indonesia atau Inggris sesuai konteks tugas: [ROLE] peran spesifik yang harus dimainkan AI. [CONTEXT] konteks relevan yang perlu diketahui. [TASK] instruksi tugas yang spesifik, jelas, gak ambigu. [FORMAT] format output yang diinginkan (struktur, panjang, gaya). [CONSTRAINTS] batasan/aturan penting yang harus dipatuhi. Output HANYA prompt final yang siap copy-paste, tanpa penjelasan tambahan, tanpa markdown backtick." \
        --arg t "Deskripsi tugas: $task" \
        '[{role:"system",content:$p},{role:"user",content:$t}]' > "$msgfile"

    local reply
    reply=$(_ai_chat_request "$msgfile" "" smart "${AI_TASK_PROVIDER_ORDER_SMART[*]}")
    rm -f "$msgfile"

    # v-fix (audit lanjutan): zsh `echo` nge-interpret backslash-escape
    # (\n dsb) secara default -- $reply teks hasil AI, literal \n yang
    # kebetulan ada di isinya bisa diam-diam ngerusak file tersimpan.
    # printf '%s\n' nulis apa adanya, tanpa interpretasi escape.
    printf '%s\n' "$reply" | tee "$outfile"
    echo ""
    echo "Prompt tersimpan di: $outfile"
    if command -v termux-clipboard-set >/dev/null; then
        printf '%s\n' "$reply" | termux-clipboard-set
        echo "(udah kecopy ke clipboard)"
    fi
    _ai_log "prompt" "$task" "saved to $outfile"
}

