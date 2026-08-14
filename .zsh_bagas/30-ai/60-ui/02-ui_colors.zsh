# ============================================================
#  30-ai/60-ui/02-ui_colors.zsh — palet warna buat semua UI helper
#  (box, line, tree-step, header). Murni tambahan visual -- gak
#  ngubah teks/struktur apa pun, cuma nyisipin kode warna ANSI.
#
#  Prinsip aman: SEMUA perhitungan lebar/padding (buat wrap & box)
#  HARUS dihitung dari teks POLOS dulu, baru sesudahnya teks itu
#  dibungkus warna pas mau di-echo. Jangan pernah masukin kode
#  warna ke string SEBELUM ${#...} / _ai_ui_wrap ngitung
#  panjangnya -- kode ANSI itu karakter juga buat zsh, bisa bikin
#  box miring/kepotong kalau ke-hitung sebagai lebar visual.
# ============================================================

typeset -g AI_C_RESET AI_C_BOLD AI_C_DIM
typeset -g AI_C_PRIMARY AI_C_ACCENT AI_C_OK AI_C_ERR AI_C_WARN AI_C_INFO AI_C_MUTED

# Deteksi dukungan warna:
#  1. AI_UI_NO_COLOR=1 / $NO_COLOR (konvensi standar) -> paksa mati.
#  2. Bukan interactive tty (stdout di-pipe/redirect) -> mati (jangan
#     nyampah kode ANSI mentah ke file/log).
#  3. TERM=dumb / kosong -> mati.
_ai_ui_supports_color() {
    if [ "${AI_UI_NO_COLOR:-0}" = "1" ] || [ -n "${NO_COLOR:-}" ]; then
        return 1
    fi
    [ -t 1 ] || return 1
    case "${TERM:-}" in
        dumb|"") return 1 ;;
    esac
    return 0
}

_ai_ui_colors_init() {
    if _ai_ui_supports_color; then
        AI_C_RESET=$'\e[0m'
        AI_C_BOLD=$'\e[1m'
        AI_C_DIM=$'\e[2m'
        # v-fix (UI polish, item #5): pindah dari kode 256-warna
        # (38;5;N) ke kode ANSI dasar (30-37/90-97). Kode dasar
        # di-remap terminal sesuai TEMA warna user sendiri (banyak
        # setup Termux/terminal punya palet 16-warna custom biar
        # kontras pas di light/dark), sedangkan 256-warna selalu pakai
        # RGB xterm baku apa adanya -- gampang keliatan pucat/kurang
        # kontras kalau usernya pakai terminal background terang.
        AI_C_PRIMARY=$'\e[94m'   # biru terang -- info umum
        AI_C_ACCENT=$'\e[95m'    # magenta terang -- aksen header/hero
        AI_C_OK=$'\e[92m'        # hijau terang -- sukses/approve
        AI_C_ERR=$'\e[91m'       # merah terang -- gagal/blocked
        AI_C_WARN=$'\e[93m'      # kuning terang -- BUTUH AKSI (approval)
        AI_C_INFO=$'\e[94m'      # biru terang -- reasoning/progress (beda dari WARN)
        AI_C_MUTED=$'\e[90m'     # abu-abu terang -- label/garis/teks sekunder
    else
        AI_C_RESET=""; AI_C_BOLD=""; AI_C_DIM=""
        AI_C_PRIMARY=""; AI_C_ACCENT=""; AI_C_OK=""; AI_C_ERR=""
        AI_C_WARN=""; AI_C_INFO=""; AI_C_MUTED=""
    fi
}
_ai_ui_colors_init

# _ai_ui_c(color_var_value, text...) — bungkus teks dengan warna +
# auto-reset. Aman dipakai walau warna lagi mati (var kosong -> no-op).
_ai_ui_c() {
    local color="$1"
    shift
    printf '%s%s%s' "$color" "$*" "$AI_C_RESET"
}

# _ai_ui_highlight_body(text) — highlight ringan buat 1 baris body box
# yang SUDAH di-wrap & sudah dihitung padding-nya (dipanggil TEPAT
# sebelum echo, bukan sebelum ukur panjang -- lihat catatan di
# _ai_ui_box). Dua pola yang dikenali:
#   "$ command"        -> tanda "$" dikasih warna aksen, sisanya polos
#   "Label: nilai..."  -> "Label:" diredupin (AI_C_MUTED), nilainya
#                          dibiarin terang -- biar mata langsung ke
#                          nilai (path, angka, dll) bukan ke labelnya.
# Kalau gak match pola manapun, teks dikembaliin apa adanya (no-op).
_ai_ui_highlight_body() {
    local t="$1"
    case "$t" in
        '$ '*)
            printf '%s$%s %s' "$AI_C_ACCENT" "$AI_C_RESET" "${t#\$ }"
            ;;
        *": "*)
            local label="${t%%: *}" rest="${t#*: }"
            printf '%s%s:%s %s' "$AI_C_MUTED" "$label" "$AI_C_RESET" "$rest"
            ;;
        *)
            printf '%s' "$t"
            ;;
    esac
}
