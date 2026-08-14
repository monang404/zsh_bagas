# ============================================================
#  30-ai/60-ui/components/header.zsh — Compact Sticky Header
#  AI-FIRST UX v2: SATU baris, tanpa garis atas/bawah.
#  Blueprint §1: "Tanpa garis atas bawah. Muncul sekali saat session dimulai."
#
#  Sumber data (runtime state, di-set oleh engine saat request berhasil):
#    AI_CURRENT_PROVIDER — provider yang berhasil (groq, gemini, deepseek, dst)
#    AI_CURRENT_MODEL    — model yang berhasil (llama-3.1-8b-instant, dst)
#    AI_CURRENT_SESSION  — nama session aktif
#    AI_TOKEN_USAGE      — jumlah token terakhir (opsional)
#
#  Format (Claude Code style):
#    Bagas AI • session • provider/model • ~/path [• dirty Nf] [• Ntok]
# ============================================================

ui_header() {
    # --- Baca runtime state ---
    local provider="${AI_CURRENT_PROVIDER:-}"
    local model="${AI_CURRENT_MODEL:-}"
    local session="${AI_CURRENT_SESSION:-main}"
    local pwd_str="${PWD/#$HOME/~}"
    local token_str="${AI_TOKEN_USAGE:-}"

    # Compose label model: "provider/model" atau hanya "model" atau kosong
    local model_label=""
    if [ -n "$provider" ] && [ -n "$model" ]; then
        model_label="$provider/$model"
    elif [ -n "$model" ]; then
        model_label="$model"
    elif [ -n "$provider" ]; then
        model_label="$provider"
    fi
    # Kalau belum ada request sukses: tampilkan "(no model)" agar jelas
    [ -z "$model_label" ] && model_label="${AI_C_MUTED:-}no model yet${AI_C_RESET:-}"

    # --- Git info ---
    local branch_info=""
    if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        local branch changed
        branch=$(git branch --show-current 2>/dev/null)
        changed=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
        if [ "$changed" -gt 0 ]; then
            branch_info="${branch:+$branch }${AI_C_WARN:-}dirty ${changed}f${AI_C_RESET:-}"
        else
            branch_info="${branch:-}"
        fi
    fi

    # --- Compose satu baris header (tanpa border) ---
    local parts="${AI_C_BOLD:-}Bagas AI${AI_C_RESET:-}"
    parts+=" ${AI_C_MUTED:-}•${AI_C_RESET:-} ${AI_C_PRIMARY:-}$session${AI_C_RESET:-}"
    parts+=" ${AI_C_MUTED:-}•${AI_C_RESET:-} $model_label"
    parts+=" ${AI_C_MUTED:-}•${AI_C_RESET:-} ${AI_C_MUTED:-}$pwd_str${AI_C_RESET:-}"
    [ -n "$branch_info" ] && parts+=" ${AI_C_MUTED:-}•${AI_C_RESET:-} $branch_info"
    [ -n "$token_str"   ] && parts+=" ${AI_C_MUTED:-}•${AI_C_RESET:-} ${AI_C_MUTED:-}${token_str}tok${AI_C_RESET:-}"

    # --- Cetak: 1 baris saja ---
    echo "$parts"
}
