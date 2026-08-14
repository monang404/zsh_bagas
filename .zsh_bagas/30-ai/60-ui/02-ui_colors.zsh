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
        
        # Design System Terminal Color Tokens
        AI_C_BG=$'\e[48;2;13;17;23m'          # Background #0D1117
        AI_C_SURFACE=$'\e[48;2;22;27;34m'     # Surface #161B22
        AI_C_BORDER=$'\e[38;2;48;54;61m'      # Border #30363D
        AI_C_PRIMARY=$'\e[38;2;47;129;247m'   # Primary #2F81F7
        AI_C_ACCENT=$'\e[38;2;47;129;247m'    # Accent (using Primary)
        AI_C_OK=$'\e[38;2;63;185;80m'         # Success #3FB950
        AI_C_ERR=$'\e[38;2;248;81;73m'        # Error #F85149
        AI_C_WARN=$'\e[38;2;210;153;34m'      # Warning #D29922
        AI_C_INFO=$'\e[38;2;47;129;247m'      # Info (using Primary)
        AI_C_TEXT=$'\e[38;2;230;237;243m'     # Text #E6EDF3
        AI_C_MUTED=$'\e[38;2;139;148;158m'    # Muted #8B949E
    else
        AI_C_RESET=""; AI_C_BOLD=""; AI_C_DIM=""
        AI_C_BG=""; AI_C_SURFACE=""; AI_C_BORDER=""; AI_C_TEXT=""
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
