# ============================================================
#  30-ai/35-files/15-aiundo.zsh — aiundo — restore file dari backup terbaru
#  (split out of the old monolithic 30-ai/35-files.zsh)
# ============================================================

# v-fix (bug #58 audit): banyak fungsi (aipatch/aifix/airun/aiproject/
# aicode -o) numpuk backup ".bak.<timestamp>" tapi gak ada cara gampang
# buat restore-nya balik selain cari manual + cp sendiri, dan gak ada
# housekeeping buat beresin backup lama yang numpuk. aiundo ambil
# backup TERBARU buat file itu; aibakclean beresin yang udah lama.
aiundo() {
    local file="$1"
    if [ -z "$file" ]; then
        echo "Usage: aiundo <file>"
        return 1
    fi
    local latest
    latest=$(command ls -t "${file}".bak.* 2>/dev/null | head -1)
    if [ -z "$latest" ]; then
        echo "Gak ada backup buat $file (pola: $file.bak.*)"
        return 1
    fi
    echo "Restore $file dari $latest ?"
    if command -v gum >/dev/null; then
        gum confirm "Restore?" || { echo "Dibatalkan."; return 1; }
    else
        local confirm
        if ! read -t 30 "confirm?Restore? (y/n) "; then
            echo "Timeout, dianggap batal."
            return 1
        fi
        [[ "$confirm" == "y" ]] || { echo "Dibatalkan."; return 1; }
    fi
    # state SEBELUM undo juga disimpen -- biar 'undo dari undo' tetap mungkin
    local safety="${file}.bak.$(_ai_ts).before_undo"
    cp "$file" "$safety" 2>/dev/null
    command cp -f "$latest" "$file"
    echo "Direstore dari $latest. (state sebelum undo disimpan di $safety)"
    _ai_log "undo" "$file" "restored from $latest"
}

