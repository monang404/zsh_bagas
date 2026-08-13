# ============================================================
#  20-shell/prompt.zsh — prompt & navigasi: starship, zoxide,
#  direnv, fzf
# ============================================================

# ─── Starship ───────────────────────────────────────────────
command -v starship >/dev/null && eval "$(starship init zsh)"

# ─── Zoxide ─────────────────────────────────────────────────
command -v zoxide >/dev/null && eval "$(zoxide init zsh)"

# ─── direnv (auto-load .envrc per-folder project) ────────────
command -v direnv >/dev/null && eval "$(direnv hook zsh)"

# ─── FZF ────────────────────────────────────────────────────
export FZF_DEFAULT_OPTS='--height 40% --reverse --border'
export FZF_CTRL_T_OPTS="--preview 'bat --color=always --paging=never --line-range :50 {}'"
export FZF_ALT_C_OPTS="--preview 'eza --tree --level=2 --icons {}'"
export FZF_CTRL_R_OPTS="--preview 'echo {}' --preview-window=down:3:wrap"

if [ -f /data/data/com.termux/files/usr/share/fzf/key-bindings.zsh ]; then
    source /data/data/com.termux/files/usr/share/fzf/key-bindings.zsh
fi
if [ -f /data/data/com.termux/files/usr/share/fzf/completion.zsh ]; then
    source /data/data/com.termux/files/usr/share/fzf/completion.zsh
fi
