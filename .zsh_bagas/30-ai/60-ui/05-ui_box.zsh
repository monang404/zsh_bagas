# ============================================================
#  30-ai/60-ui/05-ui_box.zsh — box-drawing + horizontal rule
#  (split out of the old monolithic 30-ai/60-ui.zsh)
# ============================================================

# _ai_ui_box_accent(title) — pilih warna box berdasarkan title, biar
# mata langsung bisa bedain approval (kuning) vs sukses (hijau) vs
# blocked (merah) vs header/hero (aksen) tanpa baca teksnya dulu.
# Heuristik dari title doang -- gak nambah parameter baru ke caller
# manapun, semua pemanggil _ai_ui_box existing tetap jalan apa adanya.
_ai_ui_box_accent() {
    local title="$1"
    case "$title" in
        "AI Agent"*) echo "$AI_C_ACCENT" ;;
        *"requires approval"*) echo "$AI_C_WARN" ;;
        "✓"*|"+"*|*"Completed"*) echo "$AI_C_OK" ;;
        "✗"*|"x "*|*"blocked"*|*"Blocked"*) echo "$AI_C_ERR" ;;
        *) echo "$AI_C_MUTED" ;;
    esac
}

# _ai_ui_box(title, lines...) — cetak box rapi berisi title + lines,
# unicode (╭─╮│╰╯) atau ASCII fallback (+-|) tergantung
# _ai_ui_supports_unicode, lebar ngikutin _ai_ui_width (bukan hardcode).
#
# v-fix (UI polish): tiap elemen di `lines` dulu di-word-reflow apa
# adanya lewat _ai_ui_wrap, termasuk newline literal di dalamnya --
# kalau satu elemen isinya "Label: nilai\nnilai_lain" (mis. nilai yang
# ternyata multi-baris), hasilnya kegabung jadi satu "kalimat" panjang
# yang di-reflow ulang, bukan tetap 2 baris terpisah. Sekarang tiap
# elemen dipecah dulu per newline ASLI (${(f)line}) SEBELUM di-wrap,
# jadi baris yang memang dimaksud terpisah tetap terpisah -- cuma tiap
# sub-baris sendiri yang di-word-wrap kalau kepanjangan.
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

    local accent
    accent=$(_ai_ui_box_accent "$title")

    # top border, judul ditempel di kiri: ╭─ TITLE ──────╮
    # (lebar/fill dihitung dari title POLOS dulu, warna baru
    # ditempel pas echo -- lihat catatan di 02-ui_colors.zsh)
    local title_str="" title_len=0
    if [ -n "$title" ]; then
        title_str=" $title "
        title_len=${#title_str}
    fi
    local fill=$(( inner - 1 - title_len ))
    [ "$fill" -lt 0 ] && fill=0
    local top_fill="" i
    for (( i = 0; i < fill; i++ )); do top_fill+="$hz"; done
    echo "${accent}${tl}${hz}${AI_C_BOLD}${title_str}${AI_C_RESET}${accent}${top_fill}${tr}${AI_C_RESET}"

    # body: tiap line dipecah per newline ASLI dulu, tiap sub-baris
    # di-wrap ke inner width dikurangi padding " x "
    local avail=$(( inner - 2 ))
    [ "$avail" -lt 4 ] && avail=4
    local line subline wrapped pad padstr
    for line in "${lines[@]}"; do
        for subline in "${(f)line}"; do
            while IFS= read -r wrapped; do
                pad=$(( avail - ${#wrapped} ))
                [ "$pad" -lt 0 ] && pad=0
                padstr=""
                for (( i = 0; i < pad; i++ )); do padstr+=" "; done
                echo "${accent}${vt}${AI_C_RESET} $(_ai_ui_highlight_body "$wrapped")${padstr} ${accent}${vt}${AI_C_RESET}"
            done < <(_ai_ui_wrap "$subline" "$avail")
        done
    done

    local bottom_fill="" j
    for (( j = 0; j < inner; j++ )); do bottom_fill+="$hz"; done
    echo "${accent}${bl}${bottom_fill}${br}${AI_C_RESET}"
}

# _ai_ui_step_rule(step, max_step) — garis pemisah tipis + progres
# "Step N/MAX" di tengah, dipakai loop agent SEBELUM tiap step baru
# (Task/item #3 dan #4 gabungan: separator visual antar step + posisi
# sekarang gampang keliatan pas scroll cepat di layar HP). Lebar
# ngikutin _ai_ui_width sama kayak box, warnanya AI_C_MUTED (garis) +
# AI_C_BOLD (label) biar gak menyaingi warna status box di sekitarnya.
_ai_ui_step_rule() {
    local step="$1" max="$2"
    local hz
    if _ai_ui_supports_unicode; then hz="─"; else hz="-"; fi
    local label=" Step ${step}/${max} "
    local width total llen side rightlen i left="" right=""
    width=$(_ai_ui_width)
    total=$width
    llen=${#label}
    [ "$llen" -ge "$total" ] && { echo "${AI_C_MUTED}${AI_C_BOLD}${label}${AI_C_RESET}"; return; }
    side=$(( (total - llen) / 2 ))
    rightlen=$(( total - llen - side ))
    for (( i = 0; i < side; i++ )); do left+="$hz"; done
    for (( i = 0; i < rightlen; i++ )); do right+="$hz"; done
    echo "${AI_C_MUTED}${left}${AI_C_RESET}${AI_C_BOLD}${label}${AI_C_RESET}${AI_C_MUTED}${right}${AI_C_RESET}"
}

# _ai_ui_line(icon, text) — satu baris ringkas dengan icon di depan
# (dipakai fase 1.3-1.5 buat tool-exec/reasoning/skill-list). Icon
# unicode (→ ✓ ✗ ◌ •) otomatis diganti padanan ASCII kalau
# _ai_ui_supports_unicode bilang enggak didukung. Tiap icon juga
# dikasih warna semantik (icon doang, bukan teksnya, biar teks
# panjang tetap gampang dibaca di terminal gelap/terang manapun).
_ai_ui_line() {
    local icon="$1"
    local text="$2"
    local color="$AI_C_MUTED"
    case "$icon" in
        "→") color="$AI_C_INFO" ;;
        "✓") color="$AI_C_OK" ;;
        "✗") color="$AI_C_ERR" ;;
        # v-fix (item #2): "◌" (reasoning/thinking) dulu pakai warna
        # WARN yang sama kayak box approval -- bikin bingung, kuning
        # keliatan seolah "butuh aksi kamu" padahal cuma "AI lagi
        # mikir". Sekarang pakai INFO (biru), kuning murni khusus buat
        # approval aja.
        "◌") color="$AI_C_INFO" ;;
        "•") color="$AI_C_MUTED" ;;
    esac
    if ! _ai_ui_supports_unicode; then
        case "$icon" in
            "→") icon=">" ;;
            "✓") icon="+" ;;
            "✗") icon="x" ;;
            "◌") icon="~" ;;
            "•") icon="*" ;;
        esac
    fi
    echo "${color}${icon}${AI_C_RESET} ${text}"
}
