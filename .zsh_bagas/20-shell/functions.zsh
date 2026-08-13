# ============================================================
#  20-shell/functions.zsh — fungsi utilitas non-AI
# ============================================================

mkcd() {
    mkdir -p "$1" && cd "$1"
}

extract() {
    if [ -z "$1" ]; then
        echo "Usage: extract <file>"
        return 1
    fi
    if [ ! -f "$1" ]; then
        echo "File tidak ditemukan: $1"
        return 1
    fi
    case "$1" in
        *.tar.gz|*.tgz)   tar xzf "$1"   ;;
        *.tar.bz2|*.tbz2) tar xjf "$1"   ;;
        *.tar.xz)          tar xJf "$1"   ;;
        *.tar)             tar xf "$1"    ;;
        *.zip)             unzip "$1"     ;;
        *.gz)              gunzip "$1"    ;;
        *.bz2)             bunzip2 "$1"   ;;
        *.xz)              unxz "$1"      ;;
        *.7z)              7z x "$1"      ;;
        *)                 echo "Format tidak dikenal: $1" ;;
    esac
}

bak() {
    if [ -z "$1" ]; then
        echo "Usage: bak <file>"
        return 1
    fi
    local dest="$1.bak.$(date +%Y%m%d)"
    cp "$1" "$dest"
    echo "Backup: $dest"
}

vf() {
    local file
    file=$(fd --type f | fzf --preview 'bat --color=always --paging=never {}') && v "$file"
}

gacp() {
    if [ -z "$1" ]; then
        echo "Usage: gacp \"pesan commit\""
        return 1
    fi
    git add . && git commit -m "$1" && git push
}

ports() {
    ss -tulnp 2>/dev/null || netstat -tulnp 2>/dev/null || echo "ss/netstat tidak tersedia"
}

y() {
    local tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
    yazi "$@" --cwd-file="$tmp"
    if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
        cd -- "$cwd"
    fi
    rm -f -- "$tmp"
}

copy() {
    if [ -z "$1" ]; then
        echo "Usage: copy <file>"
        return 1
    fi
    if [ ! -f "$1" ]; then
        echo "File tidak ditemukan: $1"
        return 1
    fi
    cat "$1" | termux-clipboard-set
    echo "Isi $1 udah di clipboard"
}

# fzf picker dari daftar direktori yang udah di-track zoxide,
# jadi lompat antar project (LunaWave, kasir-go, dll) tanpa cd manual
proj() {
    local dir
    dir=$(zoxide query -l 2>/dev/null | fzf --preview 'eza --tree --level=2 --icons {} 2>/dev/null') \
        && cd "$dir"
}
alias pj='proj'

# tmux session manager: attach ke session yang ada (pilih via fzf
# kalau lebih dari satu), atau bikin baru. Berguna biar proses gak
# mati pas Termux di-background-in Android.
tm() {
    if [ -n "$TMUX" ]; then
        echo "Udah di dalam tmux session."
        return 0
    fi
    local session
    session=$(tmux list-sessions -F '#S' 2>/dev/null | fzf --prompt="Attach session> ")
    if [ -n "$session" ]; then
        tmux attach -t "$session"
    else
        tmux new -s "${1:-main}"
    fi
}
