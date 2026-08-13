# ============================================================
#  30-ai/10-core/30-diff_notify.zsh — diff guard + termux notifications
#  (split out of the old monolithic 30-ai/10-core.zsh)
# ============================================================

# v-fix: aicommit/aireview dulu kirim `git diff` mentah ke AI tanpa guard
# panjang sama sekali (beda dengan aisummarize yang udah ada chunking) —
# diff gede bisa langsung kena 413/context overflow. Truncate ke
# AI_DIFF_MAX_CHARS dan tempelin `git diff --stat` di depan biar model
# tetap punya gambaran file mana aja yang kena walau detailnya kepotong.
_ai_guard_diff() {
    local diff="$1" statinfo="$2"
    local max_chars="${AI_DIFF_MAX_CHARS:-15000}"
    if [ ${#diff} -gt "$max_chars" ]; then
        echo "[diff kegedean (${#diff} char), dipotong ke $max_chars char. Ringkasan file yang berubah:]"
        echo "$statinfo"
        echo ""
        echo "${diff:0:$max_chars}"
        echo ""
        echo "[...diff dipotong di sini, sisanya gak ditampilkan...]"
    else
        echo "$diff"
    fi
}

# ─── Utilitas: notifikasi, logging, cek dependency ───────────
_ai_notify() {
    command -v termux-notification >/dev/null 2>&1 && \
        termux-notification --title "$1" --content "$2" >/dev/null 2>&1
}

# Task 12.1: notifikasi progress per-step buat aiagent -- REUSE pola
# silent-pass _ai_notify di atas, tapi pakai --id TETAP (aiagent_progress)
# biar Android nge-UPDATE satu notifikasi yang sama, bukan numpuk satu
# notifikasi baru tiap step. Ini SENGAJA terpisah dari _ai_notify (yang
# dipakai buat notifikasi akhir "AI Agent selesai") supaya keduanya tetap
# jadi dua notifikasi yang beda (progress vs hasil akhir), sesuai spec
# fase 12 ("Notifikasi akhir tetap ada seperti sekarang").
_ai_notify_progress() {
    command -v termux-notification >/dev/null 2>&1 && \
        termux-notification --id aiagent_progress --title "$1" --content "$2" >/dev/null 2>&1
}
