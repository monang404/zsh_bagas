# ============================================================
#  30-ai/40-workflow/25-aireview.zsh — aireview + _ai_review_diff_core — review diff git terstruktur
#  (split out of the old monolithic 30-ai/40-workflow.zsh)
# ============================================================

aireview() {
    _ai_need_any_key || return 1
    if ! command -v git >/dev/null || ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "Bukan git repo."
        return 1
    fi
    local diff was_staged=1
    diff=$(git diff --cached)
    if [ -z "$diff" ]; then
        diff=$(git diff)
        was_staged=0
    fi
    [ -z "$diff" ] && { echo "Gak ada perubahan buat direview."; return 1; }

    local diffstat
    if [ "$was_staged" -eq 1 ]; then
        diffstat=$(git diff --cached --stat)
    else
        diffstat=$(git diff --stat)
    fi

    # Task 4.1 (fase4_reviewer_integration): bagian "guard diff -> kirim
    # ke LLM -> return teks review" DIPINDAH ke _ai_review_diff_core()
    # di bawah (REUSABLE, dipanggil dari sini apa adanya). Deteksi
    # staged/unstaged & pengambilan diff/diffstat TETAP di sini --
    # itu spesifik ke pemanggilan manual CLI, bukan bagian "core".
    local reply
    reply=$(_ai_review_diff_core "$diff" "$diffstat")

    echo "$reply"
    _ai_log "review" "diff review" "$reply"
}

# _ai_review_diff_core <diff> <diffstat>
# Task 4.1 (fase4_reviewer_integration): ekstraksi bagian MURNI dari
# aireview() lama -- guard diff (_ai_guard_diff, existing, TIDAK
# diubah) -> bangun prompt review terstruktur -> kirim ke LLM lewat
# _ai_chat_request (existing, TIDAK diubah) -> return teks review
# (echo ke stdout). Prompt & parameter model (smart,
# AI_TASK_PROVIDER_ORDER_SMART) SAMA PERSIS seperti aireview() sebelum
# refactor -- TIDAK ADA perubahan behavior, murni pemindahan kode.
#
# SENGAJA TIDAK melakukan git diff retrieval / deteksi staged-vs-
# unstaged di sini -- itu tetap tanggung jawab pemanggil (aireview()
# di atas untuk CLI manual; nantinya aiagent di Task 4.2, BELUM
# dikerjakan di sesi ini, bisa pakai sumber diff sendiri tanpa harus
# lewat git staging area).
_ai_review_diff_core() {
    local diff="$1"
    local diffstat="$2"

    local guarded_diff
    guarded_diff=$(_ai_guard_diff "$diff" "$diffstat")

    local msgfile=$(mktemp)
    jq -n --arg p "Kamu senior code reviewer. Review diff git berikut dan kasih feedback terstruktur dengan bagian: 1) Bug/error potensial. 2) Masalah security. 3) Saran perbaikan style/readability. 4) Hal yang udah bagus (singkat aja). Bahasa Indonesia, to the point, pakai penomoran, tanpa markdown backtick." \
        --arg d "$guarded_diff" \
        '[{role:"system",content:$p},{role:"user",content:$d}]' > "$msgfile"

    local reply
    reply=$(_ai_chat_request "$msgfile" "" smart "${AI_TASK_PROVIDER_ORDER_SMART[*]}")
    rm -f "$msgfile"

    echo "$reply"
}

