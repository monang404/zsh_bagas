# ============================================================
#  30-ai/60-ui/00-ui_text.zsh — terminal capability detection + text width/wrap
#  (split out of the old monolithic 30-ai/60-ui.zsh)
# ============================================================

# ============================================================
#  30-ai/60-ui.zsh — hub dispatcher, menu interaktif, stats
#  ai() (satu pintu masuk semua subcommand), _ai_menu (gum), aidev (tmux workspace), aih, aistats, ai_check_deps, tab-completion.
#  Task 4.4 (fase4_reviewer_integration): _ai_help ("ai h") -- ringkasan
#  subcommand + behavior review otomatis/--no-review.
#
#  v3.1 (improvement): nambah 3 subcommand baru -- edit/view/scan
#  -- yang manggil modul 35-files.zsh & 45-project.zsh. Dipisah
#  dari `code`/`fix` yang lama karena beda tujuan: `code` generate
#  file BARU dari nol, `edit` ubah file yang SUDAH ADA dengan
#  review diff wajib sebelum ditimpa.
#
#  Task 1.1 (fase1_ui_ux_overhaul): helper box-drawing (_ai_ui_box,
#  _ai_ui_line) dipakai fase 1.2-1.6 buat header/tool-line/reasoning/
#  final box. Dukungan unicode DIDETEKSI runtime (bukan diasumsikan
#  semua device Termux support penuh), plus override manual lewat
#  AI_UI_ASCII_FALLBACK=1 (lihat 00-config.zsh).
# ============================================================


# ─── Box-drawing UI helper (Task 1.1) ──────────────────────────

# Deteksi dukungan unicode box-drawing:
#   1. AI_UI_ASCII_FALLBACK=1 (env/config override manual) -> paksa ASCII.
#   2. Kalau enggak, cek locale (LC_ALL > LC_CTYPE > LANG) ngandung UTF-8.
#      Locale non-UTF-8 (mis. "C", "POSIX") biasanya berarti terminal/font
#      gak dijamin render ╭╰│─→✓◌ dengan benar -> jatuh ke ASCII juga.
# Return: 0 (true) kalau unicode didukung, 1 (false) kalau harus ASCII.
_ai_ui_supports_unicode() {
    if [ "${AI_UI_ASCII_FALLBACK:-0}" = "1" ]; then
        return 1
    fi
    local loc="${LC_ALL:-${LC_CTYPE:-${LANG:-}}}"
    case "$loc" in
        *[Uu][Tt][Ff]-8*|*[Uu][Tt][Ff]8*) return 0 ;;
        *) return 1 ;;
    esac
}

# Lebar box: pakai $COLUMNS (zsh biasanya auto-set ini), fallback ke
# `tput cols` kalau kosong (mis. dipanggil dari non-interactive shell),
# fallback terakhir 40 kalau keduanya gak kedeteksi -- JANGAN hardcode
# lebar tetap yang bisa kepotong di layar HP sempit (tapi juga jangan
# biarin box jadi cuma beberapa karakter kalau $COLUMNS kebaca aneh,
# makanya di-clamp minimum 20).
_ai_ui_width() {
    local w="${COLUMNS:-}"
    if [ -z "$w" ] && command -v tput >/dev/null 2>&1; then
        w=$(tput cols 2>/dev/null)
    fi
    case "$w" in
        (''|*[!0-9]*) w=40 ;;
    esac
    [ "$w" -lt 20 ] && w=20
    echo "$w"
}

# Word-wrap 1 baris teks ke lebar tertentu, print tiap potongan di
# baris sendiri. Kata tunggal yang lebih panjang dari width di-hard-cut
# (bukan biarin box jebol lebarnya).
_ai_ui_wrap() {
    local text="$1"
    local width="$2"
    [ "$width" -lt 1 ] && width=1
    if [ -z "$text" ]; then
        echo ""
        return
    fi
    local -a words
    words=(${=text})
    local cur="" w
    for w in "${words[@]}"; do
        while [ "${#w}" -gt "$width" ]; do
            if [ -n "$cur" ]; then
                echo "$cur"
                cur=""
            fi
            echo "${w[1,$width]}"
            w="${w[$((width + 1)),-1]}"
        done
        if [ -z "$cur" ]; then
            cur="$w"
        elif [ $(( ${#cur} + 1 + ${#w} )) -le "$width" ]; then
            cur="$cur $w"
        else
            echo "$cur"
            cur="$w"
        fi
    done
    [ -n "$cur" ] && echo "$cur"
}
