# ============================================================
#  20-shell/aliases.zsh — semua alias non-AI
# ============================================================

# ─── Aliases: Navigation ────────────────────────────────────
#alias ls='eza --icons'
#alias ll='eza -lah --git'
alias la='eza -a'
alias ..='cd ..'
alias ...='cd ../..'
alias c='clear'
alias v='nvim'

# ─── Aliases: Modern Tools ──────────────────────────────────
#alias cat='bat'
alias rg='rg --smart-case'
alias ff='fd'

# ─── Aliases: Git ───────────────────────────────────────────
alias gs='git status'
alias ga='git add .'
alias gc='git commit -m'
alias gp='git push'
alias gl='git log --oneline --graph --decorate'

# ─── Aliases: Termux ────────────────────────────────────────
alias update='pkg update && pkg upgrade -y'
alias up='pkg update && pkg upgrade -y'
alias sshkey='\cat ~/.ssh/id_ed25519.pub'
#alias p='python'
alias pc='~/pc'

# ─── Aliases: Safety ────────────────────────────────────────
#alias rm='rm -i'
#alias cp='cp -i'
#alias mv='mv -i'
