# ============================================================
#  30-ai/30-code/45-fix.zsh — aifix
#  (split out of the old monolithic 30-ai/30-code.zsh)
# ============================================================


aifix() {
    _ai_need_any_key || return 1
    if [ -z "$1" ] || [ -z "$2" ]; then
        echo "Usage: aifix <file> \"<pesan error>\""
        return 1
    fi
    local file="$1"
    local error_msg="$2"
    local code=$(cat "$file")
    # v-fix: raw ditangkap TERPISAH dari filter '```' -- kalau digabung
    # lewat pipe (`_ai_quick ... | grep -v ...`), $? abis command
    # substitution itu punya `grep`, bukan `_ai_quick`, jadi kegagalan API
    # gak pernah kedeteksi lewat exit code. Sekarang _ai_quick dipanggil
    # sendirian dulu (exit status-nya asli ke-capture di $status), baru
    # hasilnya difilter belakangan.
    local raw rc reply
    raw=$(_ai_quick "Kamu programmer expert. Diberikan kode dan pesan error, perbaiki kodenya. Output HANYA kode yang sudah diperbaiki secara lengkap, tanpa penjelasan, tanpa markdown/backtick. WAJIB pakai baris baru SUNGGUHAN buat pisah tiap statement/baris kode — JANGAN PERNAH menulis dua karakter literal backslash+n sebagai pengganti baris baru di luar string." \
        "Kode:
$code

Error:
$error_msg" smart "${AI_TASK_PROVIDER_ORDER_BIG[*]}")
    rc=$?
    reply=$(printf '%s\n' "$raw" | grep -v '```')
    # guard: kalau _ai_chat_request gagal total (semua provider/model abis),
    # ATAU balasannya kosong, JANGAN ditulis ke .fixed — dulu ini nembus
    # dan nimpa file asli yang masih valid dengan pesan error/teks kosong,
    # bikin file yang tadinya jalan malah rusak gara-gara auto-fix gagal.
    # Sekarang dicek lewat EXIT CODE asli _ai_chat_request, bukan string-
    # match pesan error (yang rapuh, gampang basi kalau teks pesannya
    # diubah/di-translate di 10-core.zsh).
    if [ "$rc" -ne 0 ] || [ -z "$reply" ]; then
        echo "GAGAL bikin perbaikan (API/provider lagi gagal total, cek 'ai deps'). File asli TIDAK diubah." >&2
        rm -f "${file}.fixed"
        return 1
    fi
    printf '%s\n' "$reply" > "${file}.fixed"
    _ai_sanitize_pycode "${file}.fixed"
    echo "Hasil perbaikan tersimpan di ${file}.fixed - cek dulu sebelum overwrite (diff \"$file\" \"${file}.fixed\")"
}
