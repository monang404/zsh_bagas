# ============================================================
#  30-ai/60-ui/05-ui_box.zsh — box-drawing + horizontal rule
#  (split out of the old monolithic 30-ai/60-ui.zsh)
# ============================================================

# _ai_ui_box(title, lines...) — cetak box rapi berisi title + lines,
# unicode (╭─╮│╰╯) atau ASCII fallback (+-|) tergantung
# _ai_ui_supports_unicode, lebar ngikutin _ai_ui_width (bukan hardcode).
_ai_ui_box() {
    local title="$1"
    shift
    local -a lines=("$@")

    local width inner
    width=$(_ai_ui_width)
    inner=$(( width - 2 ))
    [ "$inner" -lt 10 ] && inner=10

    local tl tr bl br hz vt
    if _ai_ui_supports_unicode; then
        tl="╭"; tr="╮"; bl="╰"; br="╯"; hz="─"; vt="│"
    else
        tl="+"; tr="+"; bl="+"; br="+"; hz="-"; vt="|"
    fi

    # top border, judul ditempel di kiri: ╭─ TITLE ──────╮
    local title_str="" title_len=0
    if [ -n "$title" ]; then
        title_str=" $title "
        title_len=${#title_str}
    fi
    local fill=$(( inner - 1 - title_len ))
    [ "$fill" -lt 0 ] && fill=0
    local top="${tl}${hz}${title_str}" i
    for (( i = 0; i < fill; i++ )); do top+="$hz"; done
    top+="$tr"
    echo "$top"

    # body: tiap line di-wrap ke inner width dikurangi padding " x "
    local avail=$(( inner - 2 ))
    [ "$avail" -lt 4 ] && avail=4
    local line wrapped pad padstr
    for line in "${lines[@]}"; do
        while IFS= read -r wrapped; do
            pad=$(( avail - ${#wrapped} ))
            [ "$pad" -lt 0 ] && pad=0
            padstr=""
            for (( i = 0; i < pad; i++ )); do padstr+=" "; done
            echo "${vt} ${wrapped}${padstr} ${vt}"
        done < <(_ai_ui_wrap "$line" "$avail")
    done

    local bottom="$bl" j
    for (( j = 0; j < inner; j++ )); do bottom+="$hz"; done
    bottom+="$br"
    echo "$bottom"
}

# _ai_ui_line(icon, text) — satu baris ringkas dengan icon di depan
# (dipakai fase 1.3-1.5 buat tool-exec/reasoning/skill-list). Icon
# unicode (→ ✓ ✗ ◌ •) otomatis diganti padanan ASCII kalau
# _ai_ui_supports_unicode bilang enggak didukung.
_ai_ui_line() {
    local icon="$1"
    local text="$2"
    if ! _ai_ui_supports_unicode; then
        case "$icon" in
            "→") icon=">" ;;
            "✓") icon="+" ;;
            "✗") icon="x" ;;
            "◌") icon="~" ;;
            "•") icon="*" ;;
        esac
    fi
    echo "${icon} ${text}"
}
