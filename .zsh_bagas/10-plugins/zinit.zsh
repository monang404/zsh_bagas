# ============================================================
#  10-plugins/zinit.zsh — plugin manager + completion styling
# ============================================================

# ─── Zinit (plugin manager) ─────────────────────────────────
ZINIT_HOME="$HOME/.local/share/zinit/zinit.git"
# v-fix (bug #31 audit): dulu `git clone` polos tanpa pin versi/commit
# apa pun -- fresh install di device baru narik kode PALING BARU dari
# upstream apa adanya, jalan penuh di shell tanpa verifikasi apa pun.
# Itu risiko supply-chain: kalau upstream (atau akun maintainer-nya)
# pernah kena compromise, device baru otomatis ikut narik versi yang
# udah di-tempering tanpa ada yang sadar. Pin ke commit tertentu yang
# udah direview manual; upgrade dilakukan SADAR lewat `ai_zinit_upgrade`
# di bawah, bukan otomatis tiap fresh-install.
# commit di bawah di-pin per audit 2026-08 (HEAD `main` waktu itu) --
# ganti manual kalau memang mau upgrade, jangan biarin nilainya basi
# tanpa pernah direview ulang.
ZINIT_PINNED_COMMIT="571722af95f0b9cbf4382e78383a3d625a28e9c6"

# auto-install kalau zinit belum ada, biar config ini portable ke device baru
if [[ ! -f "$ZINIT_HOME/zinit.zsh" ]]; then
    print -P "%F{yellow}Zinit belum ke-install, nge-clone dulu (pinned ke $ZINIT_PINNED_COMMIT)...%f"
    command mkdir -p "$(dirname "$ZINIT_HOME")" || return 1
    command git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME" || {
        print -P "%F{red}Gagal clone Zinit. Plugin initialization dibatalkan.%f"
        return 1
    }
fi
if ! command git -C "$ZINIT_HOME" rev-parse --verify --quiet "$ZINIT_PINNED_COMMIT^{commit}" >/dev/null 2>&1; then
    print -P "%F{red}Zinit pinned commit tidak tersedia/valid. Plugin initialization dibatalkan.%f"
    return 1
fi
command git -C "$ZINIT_HOME" checkout --quiet --detach "$ZINIT_PINNED_COMMIT" || {
    print -P "%F{red}Gagal checkout Zinit pinned commit. Plugin initialization dibatalkan.%f"
    return 1
}
source "$ZINIT_HOME/zinit.zsh" || return 1

# ai_zinit_upgrade: cara SADAR buat upgrade zinit ke commit baru --
# review dulu changelog upstream-nya sebelum jalanin ini, jangan asal run.
ai_zinit_upgrade() {
    local target="${1:-main}"
    (
        cd "$ZINIT_HOME" || { echo "ZINIT_HOME ($ZINIT_HOME) gak ketemu."; exit 1; }
        git fetch --quiet origin "$target" || { echo "git fetch gagal."; exit 1; }
        git checkout --quiet "FETCH_HEAD"
        local newhash; newhash=$(git rev-parse HEAD)
        echo "Zinit sekarang di commit: $newhash"
        echo "Update ZINIT_PINNED_COMMIT di 10-plugins/zinit.zsh ke hash ini SETELAH kamu review perubahannya (git log/diff manual)."
    )
}
# ─── Plugin (turbo mode: async load, gak nge-block startup) ─
# compinit di-trigger sekali lewat ice atinit, dibarengin cache -C
# biar gak re-scan $fpath tiap buka shell.
zinit wait lucid for \
    atload"_zsh_autosuggest_start" \
        zsh-users/zsh-autosuggestions \
    blockf \
        zsh-users/zsh-completions \
    Aloxaf/fzf-tab \
    atload"bindkey '^[[A' history-substring-search-up; bindkey '^[[B' history-substring-search-down" \
        zsh-users/zsh-history-substring-search \
    atinit"ZINIT[COMPINIT_OPTS]=-C; zicompinit; zicdreplay" \
        zdharma-continuum/fast-syntax-highlighting

# ─── Completion styling ──────────────────────────────────────
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' menu select
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' special-dirs true
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "${ZDOTDIR:-$HOME}/.zcompcache"
zstyle ':fzf-tab:*' fzf-preview 'bat --color=always --line-range :50 $realpath 2>/dev/null || eza --tree --level=2 --icons $realpath 2>/dev/null'

# Warna untuk zsh-autosuggestions
export ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#5c6370'

# zcompile .zcompdump biar zsh baca dump-nya dalam bentuk yang udah di-compile
# (jalan di background, gak nge-block prompt)
{
    local zcd="${ZDOTDIR:-$HOME}/.zcompdump"
    [[ -s "$zcd" && ( ! -s "${zcd}.zwc" || "$zcd" -nt "${zcd}.zwc" ) ]] && zcompile "$zcd"
} &!
