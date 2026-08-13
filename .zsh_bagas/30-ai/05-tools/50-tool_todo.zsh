# ============================================================
#  30-ai/05-tools/50-tool_todo.zsh — todo_write / todo_read (session checklist)
#  (split out of the old monolithic 30-ai/05-tools.zsh)
# ============================================================

# ─── Tool Baru: todo_write / todo_read ────────────────────────
# Checklist rencana kerja SESI ini -- BUKAN file project (gak nyentuh
# filesystem project user), jadi level "readonly" (auto-approve, gak
# perlu konfirmasi tiap update). Tujuannya dua: (1) bantu agent sendiri
# tetap ingat rencana multi-step di task panjang, (2) nampilin progress
# yang keliatan ke user tiap langkah -- bukan cuma diem sampe selesai.
# Disimpan per-sesi ($_AI_AGENT_SESSION_SLUG, di-set aiagent()), array
# JSON: [{"text":"...", "status":"pending|doing|done"}].
_ai_tool_todo_write() {
    local args_json="$1"
    local items todo_file slug
    items=$(printf '%s' "$args_json" | jq -c '.items // empty' 2>/dev/null)

    if [ -z "$items" ] || [ "$items" = "null" ]; then
        echo "ERROR: args.items (array todo) harus diisi, contoh: [{\"text\":\"baca config\",\"status\":\"pending\"}]"
        return 1
    fi
    if ! echo "$items" | jq -e 'type == "array"' >/dev/null 2>&1; then
        echo "ERROR: items harus berupa array JSON"
        return 1
    fi

    slug="${_AI_AGENT_SESSION_SLUG:-default}"
    mkdir -p "$AI_TODO_DIR"
    todo_file="$AI_TODO_DIR/${slug}.json"
    # v-fix (audit lanjutan): zsh builtin `echo` (beda dari bash) nge-
    # interpret backslash-escape (\n, \t, dst) secara default. $items itu
    # JSON valid dari `jq -c` -- kalau isi text-nya kebetulan ada `\n`
    # literal (escape JSON yang sah buat newline di dalam string), `echo`
    # bakal ubah itu jadi newline BENERAN di tengah file, ngerusak JSON
    # (newline mentah di dalam string JSON itu ILEGAL -> parse gagal).
    # printf '%s\n' nulis apa adanya, tanpa interpretasi escape.
    printf '%s\n' "$items" > "$todo_file"
    _ai_tool_todo_read "$args_json"
}

_ai_tool_todo_read() {
    local slug todo_file
    slug="${_AI_AGENT_SESSION_SLUG:-default}"
    todo_file="$AI_TODO_DIR/${slug}.json"

    if [ ! -f "$todo_file" ]; then
        echo "OK: belum ada todo list buat sesi ini."
        return 0
    fi

    jq -r '.[] | (if .status == "done" then "[x] " elif .status == "doing" then "[~] " else "[ ] " end) + .text' \
        "$todo_file" 2>/dev/null || cat "$todo_file"
}
