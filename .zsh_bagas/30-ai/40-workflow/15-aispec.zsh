# ============================================================
#  30-ai/40-workflow/15-aispec.zsh — aispec — spec aplikasi terstruktur dari deskripsi
#  (split out of the old monolithic 30-ai/40-workflow.zsh)
# ============================================================

aispec() {
    _ai_need_any_key || return 1
    if [ -z "$1" ]; then
        echo "Usage: ai spec <deskripsi aplikasi>"
        return 1
    fi
    mkdir -p "$AI_PROMPT_DIR"
    local task=$(_ai_resolve_prompt "$@")
    local slug=$(echo "$task" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '_' | cut -c1-40)
    local outfile="$AI_PROMPT_DIR/${slug}_spec_$(_ai_ts).txt"
    local msgfile=$(mktemp)
    # v-fix (bug #21 audit): sysprompt ini dulu diketik ulang PERSIS
    # sama di aispec dan aibuild -- sekarang satu sumber kebenaran di
    # AI_SPEC_SYSPROMPT (30-ai/00-config.zsh), dipakai bareng biar gak
    # ada drift kalau salah satu diubah dan yang lain lupa di-update.
    jq -n --arg p "$AI_SPEC_SYSPROMPT" \
        --arg t "Deskripsi aplikasi: $task" \
        '[{role:"system",content:$p},{role:"user",content:$t}]' > "$msgfile"

    echo "Generating spec aplikasi..."
    local reply
    reply=$(_ai_chat_request "$msgfile" "" smart "${AI_TASK_PROVIDER_ORDER_BIG[*]}")
    rm -f "$msgfile"

    # v-fix (audit lanjutan): zsh `echo` nge-interpret backslash-escape
    # (\n dsb) secara default -- $reply teks spec hasil AI yang nantinya
    # DIBACA LAGI sebagai input aiproject (parsing [FILES]/dst), jadi
    # literal \n yang kebetulan ada di teksnya bisa diam-diam ngerusak
    # spec file ini dan nular ke step generate project berikutnya.
    # printf '%s\n' nulis apa adanya, tanpa interpretasi escape.
    printf '%s\n' "$reply" | tee "$outfile"
    echo ""
    echo "Spec tersimpan di: $outfile"
    echo "Lanjut: ai project <nama_folder> $outfile"
    if command -v termux-clipboard-set >/dev/null; then
        printf '%s\n' "$reply" | termux-clipboard-set
        echo "(udah kecopy ke clipboard)"
    fi
    _ai_log "spec" "$task" "saved to $outfile"
}

