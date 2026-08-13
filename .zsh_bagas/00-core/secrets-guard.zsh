# ============================================================
#  00-core/secrets-guard.zsh — cek permission lalu source secrets
#
#  PENTING: file ~/.secrets.zsh SENGAJA TETAP DI $HOME, DI LUAR
#  folder ~/.zsh_bagas ini. Kalau ~/.zsh_bagas suatu saat di-git-init
#  buat versioning/trace, API key gak boleh ikut ke-commit — sekali
#  masuk git history, dia nempel di situ selamanya walau filenya
#  dihapus belakangan. Jadi modul ini cuma LOGIC pengecekannya;
#  isi kuncinya sendiri hidup di luar folder yang di-tracking.
# ============================================================

if [ -f "$HOME/.secrets.zsh" ]; then
    _perm=$(stat -c '%a' "$HOME/.secrets.zsh" 2>/dev/null || stat -f '%Lp' "$HOME/.secrets.zsh" 2>/dev/null)
    if [ -z "$_perm" ]; then
        # filesystem ini gak expose POSIX permission bits (mis. shared
        # storage Termux) — stat gagal total, jangan diam-diam skip
        print -P "%F{yellow}⚠ Gak bisa cek permission ~/.secrets.zsh di filesystem ini (stat gagal) — pastikan manual file ini gak kebaca app lain.%f"
    elif [ "$_perm" != "600" ] && [ "$_perm" != "400" ]; then
        print -P "%F{red}⚠ ~/.secrets.zsh permission $_perm (bukan 600), isinya API key.%f"
        if [ -z "$AI_SECRETS_NO_AUTOCHMOD" ]; then
            if chmod 600 "$HOME/.secrets.zsh" 2>/dev/null; then
                print -P "%F{green}  → otomatis di-chmod 600.%f"
            else
                print -P "%F{red}  → auto-chmod gagal, jalanin manual: chmod 600 ~/.secrets.zsh%f"
            fi
        else
            print -P "%F{red}  → auto-chmod dimatiin (AI_SECRETS_NO_AUTOCHMOD set). Jalanin: chmod 600 ~/.secrets.zsh%f"
        fi
    fi
    unset _perm
    source "$HOME/.secrets.zsh"
fi
