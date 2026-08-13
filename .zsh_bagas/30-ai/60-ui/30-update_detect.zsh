# ============================================================
#  30-ai/60-ui/30-update_detect.zsh — update detection + local-config backup
#  (split out of the old monolithic 30-ai/60-ui.zsh)
# ============================================================

# Task 11.1/11.2 — update detection + safe confirmation/pull flow.
# Target selalu repository project ~/.zsh_bagas; ZSH_BAGAS dipakai bila
# project sudah mendefinisikannya, dengan fallback ke lokasi standar.
_ai_update_detect() {
    local repo="${ZSH_BAGAS:-$HOME/.zsh_bagas}"
    local worktree status_output branch upstream remote aheadbehind
    local local_count remote_count

    echo "Repository update: $repo"
    if [ -f "$repo/90-local/local.zsh" ]; then
        echo "Local configuration: 90-local/local.zsh terdeteksi."
    else
        echo "Local configuration: 90-local/local.zsh tidak ada."
    fi

    worktree=$(git -C "$repo" rev-parse --is-inside-work-tree 2>/dev/null)
    if [ "$worktree" != "true" ]; then
        echo "Repository bukan Git repository."
        echo "Update otomatis tidak tersedia."
        echo "Silakan lakukan update secara manual."
        return 0
    fi

    echo "Git repository terdeteksi."
    status_output=$(git -C "$repo" status --porcelain 2>/dev/null)
    if [ -n "$status_output" ]; then
        echo "Working tree: DIRTY"
        echo "WARNING: repository memiliki perubahan lokal yang belum di-commit."
        echo "Git pull membutuhkan working tree yang clean."
    else
        echo "Working tree: clean"
    fi

    branch=$(git -C "$repo" symbolic-ref --quiet --short HEAD 2>/dev/null)
    if [ -z "$branch" ]; then
        echo "Branch: detached HEAD"
        echo "Remote/update status: tidak dapat ditentukan tanpa branch tracking."
        return 0
    fi
    echo "Branch: $branch"

    upstream=$(git -C "$repo" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)
    if [ -z "$upstream" ]; then
        remote=$(git -C "$repo" config --get "branch.$branch.remote" 2>/dev/null)
        if [ -n "$remote" ]; then
            echo "Remote: $remote (tidak ada upstream branch yang dapat dibandingkan)"
        else
            echo "Remote/update status: tidak ada upstream branch."
        fi
        return 0
    fi

    remote="${upstream%%/*}"
    echo "Upstream: $upstream"
    if ! git -C "$repo" fetch --quiet "$remote" >/dev/null 2>&1; then
        echo "Remote/update status: gagal memeriksa remote."
        echo "Update belum dilakukan. Periksa koneksi atau konfigurasi Git secara manual."
        return 0
    fi

    aheadbehind=$(git -C "$repo" rev-list --left-right --count HEAD..."$upstream" 2>/dev/null)
    if [ -z "$aheadbehind" ]; then
        echo "Remote/update status: tidak dapat dibandingkan."
        return 0
    fi

    # gunakan awk untuk mengatasi tab output git rev-list
    local_count=$(echo "$aheadbehind" | awk '{print $1}')
    remote_count=$(echo "$aheadbehind" | awk '{print $2}')
    if [ "$local_count" = "0" ] && [ "$remote_count" = "0" ]; then
        echo "Remote/update status: up to date."
    elif [ "$local_count" = "0" ]; then
        echo "Remote/update status: tersedia $remote_count commit baru di remote."
    elif [ "$remote_count" = "0" ]; then
        echo "Remote/update status: local memiliki $local_count commit yang belum ada di remote."
    else
        echo "Remote/update status: diverged ($local_count commit di belakang, $remote_count commit di depan)."
    fi
    return 0
}

# Task 11.2 — backup config lokal sebelum git pull.
# Backup ditempatkan di luar repository agar backup tidak membuat working tree
# menjadi dirty sebelum pull. Hanya configuration lokal yang diketahui project
# dan berpotensi tidak berada di Git history yang dibackup.
_ai_update_backup_local_config() {
    local repo="$1"
    local local_config="$repo/90-local/local.zsh"
    local backup_root="$HOME/.zsh_bagas-update-backups"
    local backup_file stamp

    if [ ! -f "$local_config" ]; then
        echo "Backup: tidak ada 90-local/local.zsh yang perlu dibackup."
        return 0
    fi

    stamp=$(_ai_ts)
    backup_file="$backup_root/local.zsh.$stamp.bak"
    if ! mkdir -p "$backup_root" || ! chmod 700 "$backup_root"; then
        echo "GAGAL: direktori backup update tidak dapat dibuat."
        return 1
    fi

    # command cp: WAJIB bypass alias `cp='cp -i'` — kalau backup_file
    # kebetulan sudah ada, alias -i bikin cp minta konfirmasi ke stdin
    # dan bisa hang di jalur non-interaktif.
    if ! command cp -p -f "$local_config" "$backup_file"; then
        echo "GAGAL: backup 90-local/local.zsh tidak berhasil dibuat."
        rm -f "$backup_file" 2>/dev/null
        return 1
    fi

    echo "Backup lokal berhasil: $backup_file"
    return 0
}
