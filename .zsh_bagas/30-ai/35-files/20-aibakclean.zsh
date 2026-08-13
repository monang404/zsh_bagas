# ============================================================
#  30-ai/35-files/20-aibakclean.zsh — aibakclean — housekeeping file .bak.* dan cache lama
#  (split out of the old monolithic 30-ai/35-files.zsh)
# ============================================================

# aibakclean [hari] -- hapus file .bak.* (rekursif dari cwd) dan cache
# prompt lama di generate/cache/ yang lebih tua dari N hari (default 14).
# Dry-run dulu (nampilin daftar) sebelum confirm. Cache tetap dibatasi hanya
# pada generate/cache/; file non-cache dan cache fresh tidak disentuh.
aibakclean() {
    local days="${1:-14}"
    local -a old cache_old
    local cache_dir="${AI_CACHE_DIR:-$AI_GENERATE_DIR/cache}"
    old=(**/*.bak.*(N.mh+$((days*24))))
    cache_old=()
    if [ -d "$cache_dir" ]; then
        cache_old=("$cache_dir"/*.json(N.mh+$((days*24))))
    fi

    if [ ${#old[@]} -eq 0 ] && [ ${#cache_old[@]} -eq 0 ]; then
        echo "Gak ada file backup/cache lebih tua dari $days hari di sini."
        return 0
    fi

    if [ ${#old[@]} -gt 0 ]; then
        echo "File .bak.* lebih tua dari $days hari (${#old[@]} file):"
        printf '  %s\n' "${old[@]}"
    fi
    if [ ${#cache_old[@]} -gt 0 ]; then
        echo "Cache prompt lama di $cache_dir (${#cache_old[@]} file):"
        printf '  %s\n' "${cache_old[@]}"
    fi

    if command -v gum >/dev/null; then
        gum confirm "Hapus semua di atas?" || { echo "Dibatalkan."; return 1; }
    else
        local confirm
        if ! read -t 30 "confirm?Hapus semua di atas? (y/n) "; then
            echo "Timeout, dianggap batal."
            return 1
        fi
        [[ "$confirm" == "y" ]] || { echo "Dibatalkan."; return 1; }
    fi

    [ ${#old[@]} -gt 0 ] && rm -f -- "${old[@]}"
    [ ${#cache_old[@]} -gt 0 ] && rm -f -- "${cache_old[@]}"
    echo "Dihapus ${#old[@]} file backup lama dan ${#cache_old[@]} cache lama."
}

