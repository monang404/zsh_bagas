# ============================================================
#  30-ai/40-workflow/00-aicommit.zsh — aicommit — generate & commit pesan commit git conventional style
#  (split out of the old monolithic 30-ai/40-workflow.zsh)
# ============================================================

# ============================================================
#  30-ai/40-workflow.zsh — workflow non-kode
#  aiplan, aiprompt, aispec, aibuild, aireview, aisummarize, aicommit.
# ============================================================


aicommit() {
    _ai_need_any_key || return 1
    if ! command -v git >/dev/null || ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "Bukan git repo."
        return 1
    fi
    local diff
    diff=$(git diff --cached)
    [ -z "$diff" ] && { echo "Gak ada yang di-stage. 'git add' dulu."; return 1; }
    local diffstat guarded_diff msg
    diffstat=$(git diff --cached --stat)
    guarded_diff=$(_ai_guard_diff "$diff" "$diffstat")
    msg=$(_ai_quick "Buat SATU baris pesan commit git conventional style (feat:/fix:/chore:/refactor:/docs:), bahasa Inggris, tanpa tanda kutip, tanpa penjelasan tambahan." \
        "$guarded_diff" fast "${AI_TASK_PROVIDER_ORDER_FAST[*]}" | _ai_head_n 1)
    echo "Pesan commit: $msg"
    if command -v gum >/dev/null; then
        gum confirm "Commit dengan pesan ini?" && git commit -m "$msg"
    else
        local confirm
        # -t timeout biar gak hang tanpa batas kalau dijalankan non-
        # interaktif (lihat catatan yang sama di aipatch/35-files.zsh)
        if read -t 60 "confirm?Commit? (y/n) "; then
            [[ "$confirm" == "y" ]] && git commit -m "$msg"
        else
            echo "Timeout nunggu konfirmasi, commit dibatalkan."
        fi
    fi
}

