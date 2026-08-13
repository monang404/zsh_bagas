# ============================================================
#  30-ai/60-ui/10-help_stats.zsh — aih / aistats / _ai_help
#  (split out of the old monolithic 30-ai/60-ui.zsh)
# ============================================================

# cari & lihat riwayat AI lewat fzf (baca dari JSONL)
aih() {
    [ -f "$AI_HISTORY_LOG" ] || { echo "Belum ada riwayat AI."; return 1; }
    # v-fix (bug #37 audit): path log di-inject ke string --preview yang
    # nantinya dieksekusi ulang lewat `sh -c` oleh fzf -- kalau path-nya
    # pernah mengandung tanda kutip tunggal, quoting '$AI_HISTORY_LOG'
    # bisa pecah. Di-escape eksplisit (setiap ' diganti '\'') biar aman
    # apapun isi path-nya, bukan cuma diasumsikan "gak akan ada spasi".
    local escaped_log="${AI_HISTORY_LOG//\'/\'\\\'\'}"
    local idx
    idx=$(jq -rs 'to_entries[] | "\(.key)\t[\(.value.time)] (\(.value.kind)) \(.value.prompt)"' "$AI_HISTORY_LOG" \
        | fzf --delimiter '\t' --with-nth=2 \
              --preview "jq -s '.[{1}]' '$escaped_log'" \
              --preview-window=down:12:wrap --height=90% \
        | cut -f1)
    [ -z "$idx" ] && return
    jq -s ".[$idx]" "$AI_HISTORY_LOG"
}

# dashboard pemakaian token — total per-provider + pemakaian hari ini
aistats() {
    [ -f "$AI_USAGE_LOG" ] || { echo "Belum ada data usage. Pakai dulu ai plan/prompt/review/agent/session (yang lewat _ai_chat_request)."; return 1; }
    echo "=== Total pemakaian per-provider ==="
    jq -s '
        group_by(.provider) |
        map({
            provider: .[0].provider,
            calls: length,
            total_tokens: (map(.usage.total_tokens // 0) | add)
        })
    ' "$AI_USAGE_LOG"
    echo ""
    echo "=== Pemakaian hari ini ($(date +%Y-%m-%d)) ==="
    jq -s --arg today "$(date +%Y-%m-%d)" '
        map(select(.time | startswith($today))) |
        {calls: length, total_tokens: (map(.usage.total_tokens // 0) | add)}
    ' "$AI_USAGE_LOG"
}

# Task 4.4 (fase4_reviewer_integration): "ai h" -- teks bantuan ringkas
# yang menampilkan (1) daftar subcommand yang tersedia, di-generate dari
# `_AI_SUBCOMMANDS` yang SUDAH ADA (bukan diketik ulang manual -- jadi
# gak akan ketinggalan/nyimpang kalau daftar itu berubah lagi nanti) dan
# (2) behavior review otomatis `ai agent` (Task 4.2) + flag `--no-review`
# (Task 4.3), sesuai yang diminta task ini. CATATAN JUJUR: nama fungsi
# `aih()` di file ini SUDAH DIPAKAI buat "cari riwayat AI lewat fzf"
# (lihat komentar di atasnya + README.md, konsisten --
# BUKAN typo/bug), jadi task ini TIDAK menimpa/mengganti `aih()` yang
# sudah ada (itu akan menghapus fitur history yang jalan, bukan cuma
# nambah info). Sebagai gantinya subcommand baru `h` (`ai h`) ditambah
# ke `_AI_SUBCOMMANDS`/`ai()` di bawah, ngikutin pola dispatcher yang
# SAMA PERSIS dipakai 32 subcommand lain di file ini -- bukan mekanisme
# baru.
_ai_help() {
    echo "Subcommand yang tersedia (ai <subcommand> ...):"
    echo "  ${_AI_SUBCOMMANDS[*]}"
    echo ""
    echo "Agent modes (permission boundary):"
    echo "  ai chat <message>       conversation only; tidak mengubah file"
    echo "  ai code <goal>          generate code; dapat membuat/menulis output kode"
    echo "  ai agent <goal>        general coding agent; permission existing dapat menulis file"
    echo "  ai review               review diff; read-only, tidak memodifikasi file"
    echo "  ai debug <problem>      diagnosis + test/command; no file-mutation tools / no auto-fix"
    echo "  ai research <goal>      standalone readonly researcher; tidak memodifikasi file"
    echo ""
    echo "Contoh: ai review | ai debug \"test authentication gagal\" | ai research \"cari alur authentication\" | ai agent \"perbaiki bug\""
    echo ""
    echo "ai agent [--yolo] [--no-review] <goal>"
    echo "  Setelah task selesai + verifikasi sukses DAN ada file yang berubah,"
    echo "  aiagent otomatis jalanin code review (aireview) sekali di ringkasan"
    echo "  akhir (bagian 'Review'). Informational doang -- gak nunggu jawaban,"
    echo "  gak auto-lanjut edit lagi walau review nemuin masalah."
    echo "  --no-review = skip review otomatis ini (hemat token/waktu)."
    echo "  --yolo = command jalan otomatis tanpa konfirmasi manual."
    echo "  --resume <slug> / --list-checkpoints = lanjutin/lihat checkpoint."
    echo ""
    echo "'ai <subcommand>' tanpa argumen biasanya nampilin usage detailnya"
    echo "sendiri (mis. 'ai agent' doang, 'ai plan' doang, dst)."
}
