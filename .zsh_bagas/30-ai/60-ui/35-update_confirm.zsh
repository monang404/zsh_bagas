# ============================================================
#  30-ai/60-ui/35-update_confirm.zsh — update confirm/pull flow
#  (split out of the old monolithic 30-ai/60-ui.zsh)
# ============================================================

_ai_update_confirm_pull() {
    local repo="${ZSH_BAGAS:-$HOME/.zsh_bagas}"
    local worktree status_output branch upstream aheadbehind
    local local_count remote_count confirm pull_output pull_status
    local remote

    echo "Repository update: $repo"
    worktree=$(git -C "$repo" rev-parse --is-inside-work-tree 2>/dev/null)
    if [ "$worktree" != "true" ]; then
        echo "Repository bukan Git repository."
        echo "Update otomatis tidak tersedia."
        echo "Silakan lakukan update secara manual."
        return 0
    fi

    status_output=$(git -C "$repo" status --porcelain 2>/dev/null)
    if [ -n "$status_output" ]; then
        echo "Working tree: DIRTY"
        echo "WARNING: repository memiliki perubahan lokal yang belum di-commit."
        echo "Untuk keamanan, git pull diblokir sampai perubahan lokal diamankan secara manual."
        echo "Tidak ada stash, reset, clean, commit, atau overwrite otomatis."
        return 1
    fi
    echo "Working tree: clean"

    branch=$(git -C "$repo" symbolic-ref --quiet --short HEAD 2>/dev/null)
    if [ -z "$branch" ]; then
        echo "Branch: detached HEAD"
        echo "Update otomatis tidak tersedia tanpa branch tracking."
        return 1
    fi
    echo "Branch: $branch"

    upstream=$(git -C "$repo" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)
    if [ -z "$upstream" ]; then
        echo "Remote/update status: tidak ada upstream branch."
        echo "Update otomatis tidak tersedia."
        return 1
    fi
    echo "Upstream: $upstream"

    remote="${upstream%%/*}"
    if ! git -C "$repo" fetch --quiet "$remote" >/dev/null 2>&1; then
        echo "Gagal memeriksa status remote."
        echo "Tidak ada pull yang dijalankan. Periksa koneksi atau konfigurasi Git secara manual."
        return 1
    fi

    aheadbehind=$(git -C "$repo" rev-list --left-right --count HEAD..."$upstream" 2>/dev/null)
    if [ -z "$aheadbehind" ]; then
        echo "Remote/update status: tidak dapat dibandingkan."
        echo "Tidak ada pull yang dijalankan."
        return 1
    fi

    # gunakan awk atau hapus tab/spasi agar aman
    local_count=$(echo "$aheadbehind" | awk '{print $1}')
    remote_count=$(echo "$aheadbehind" | awk '{print $2}')
    echo "Remote/update status: local=$local_count, remote=$remote_count"

    if [ "$remote_count" = "0" ]; then
        if [ "$local_count" = "0" ]; then
            echo "Repository sudah up to date. Tidak ada pull yang diperlukan."
        else
            echo "Remote tidak memiliki commit baru. Local memiliki $local_count commit yang belum ada di remote."
        fi
        return 0
    fi

    if [ -f "$repo/90-local/local.zsh" ]; then
        echo "WARNING: local configuration terdeteksi: 90-local/local.zsh"
        echo "Git pull dapat memerlukan penanganan manual bila configuration lokal berkonflik."
    fi

    echo "Update tersedia: $remote_count commit baru di remote."
    echo "Tidak ada perubahan repository yang akan dilakukan tanpa konfirmasi."
    if ! read -t 60 "confirm?Jalankan git pull sekarang? (y/n) "; then
        echo "Timeout atau input tidak tersedia. Update dibatalkan."
        return 1
    fi
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Update dibatalkan. git pull tidak dijalankan."
        return 0
    fi

    if ! _ai_update_backup_local_config "$repo"; then
        echo "Update dibatalkan karena backup sebelum pull gagal."
        return 1
    fi

    echo "Menjalankan git pull..."
    pull_output=$(git -C "$repo" pull 2>&1)
    pull_status=$?
    if [ "$pull_status" -ne 0 ]; then
        echo "Update gagal: git pull mengembalikan exit status $pull_status."
        echo "Repository tidak di-reset, di-clean, atau dipulihkan secara destruktif."
        if [ -n "$pull_output" ]; then
            echo "Detail Git:"
            printf '%s\n' "$pull_output"
        fi
        echo "Jika backup config dibuat, backup tetap tersedia di lokasi yang dilaporkan di atas."
        return "$pull_status"
    fi

    echo "Update berhasil."
    if [ -n "$pull_output" ]; then
        echo "Ringkasan git pull:"
        printf '%s\n' "$pull_output"
    fi
    
    echo ""
    if read -t 60 "reload?Reload zsh sekarang untuk menerapkan pembaruan (exec zsh)? (y/n) "; then
        if [[ "$reload" == "y" || "$reload" == "Y" ]]; then
            echo ""
            echo "Memuat ulang zsh..."
            exec zsh
        fi
    fi
    echo ""
    
    return 0
}
