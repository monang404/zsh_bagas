# ============================================================
#  00-core/env.zsh — locale, history, opsi shell, PATH, editor
#  (dipecah dari .zshrc lama, isinya sama persis, cuma dipindah)
# ============================================================

# ─── Locale ─────────────────────────────────────────────────
export LANG=C.UTF-8
export LC_CTYPE=C.UTF-8

# ─── History ────────────────────────────────────────────────
export HISTFILE="$HOME/.zsh_history"
export HISTSIZE=50000
export SAVEHIST=100000
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_FIND_NO_DUPS
setopt EXTENDED_HISTORY
setopt APPEND_HISTORY
setopt SHARE_HISTORY
setopt INC_APPEND_HISTORY_TIME   # nulis ke histfile real-time (bukan cuma pas share)
# tambahin prefix ai* biar prompt2 obrolan gak numpuk di history
# "ai*" generik biar nyakup semua alias/subcommand ai (aic, aicl, ail,
# aish, aiask, aicode, aiagent, dst) tanpa perlu update list ini tiap
# kali nambah command baru
export HISTORY_IGNORE="(ls|ll|la|cd|pwd|clear|c|exit|history|ai*)"

# ─── Opsi shell (setara shopt bash) ──────────────────────────
setopt AUTO_CD
setopt CDABLE_VARS
# setopt NO_CASE_GLOB  # dimatikan, bikin syntax-highlighting gagal load di Termux
setopt EXTENDED_GLOB
# setopt CORRECT   # dimatiin: suka "koreksi" command custom / git subcommand jadi salah tebak
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS

# Ctrl+W berhenti per-folder, bukan makan seluruh path sekaligus
export WORDCHARS=${WORDCHARS//[\/]/}

# ─── Environment ────────────────────────────────────────────
export PATH="$HOME/.local/bin:$HOME/go/bin:$PATH"
export EDITOR='nvim'
export VISUAL='nvim'
export MANPAGER="sh -c 'col -bx | bat -l man -p'"
export BAT_THEME="TwoDark"

# ─── Auto ls setiap pindah direktori ─────────────────────────
# skip auto-ls kalau isi folder kegedean (node_modules, .git, dll)
# biar gak flood layar tiap cd
chpwd() {
    local count
    count=$(command ls -A 2>/dev/null | wc -l)
    if (( count <= 40 )); then
        # pakai eza (alias ls) kalau ada, fallback ke ls bawaan biar
        # gak spam "command not found" di device baru sebelum eza ke-install
        if command -v eza >/dev/null 2>&1; then
            ls
        else
            command ls
        fi
    else
        echo "($count item di folder ini, ls di-skip — pakai 'll' manual)"
    fi
}
