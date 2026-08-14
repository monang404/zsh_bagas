# ============================================================
# 30-ai/60-ui/components/cards.zsh — Summary and Stats Cards
# Commit 6b (implementasi_plan.md): rewrite pakai _ai_ui_box dan
# design tokens standar (AI_C_*) agar konsisten dengan komponen
# lain. Tidak ada gaya box ketiga — satu sumber, satu tampilan.
# ============================================================

# ui_card_summary(title, content) — card ringkasan via _ai_ui_box
# Tugas: tampilkan blok info ringkas (misal ringkasan code/project).
ui_card_summary() {
    local title="${1:-Summary}"
    local content="${2:-}"
    local -a lines
    # Pecah content per baris → array untuk _ai_ui_box
    while IFS= read -r line || [[ -n "$line" ]]; do
        lines+=("$line")
    done <<< "$content"
    _ai_ui_box "$title" "${lines[@]}"
}

# ui_card_stats(files_changed, runtime, tools_used)
# Tugas: satu baris stats compact — tidak pakai box, hanya inline.
# Format: ✓ N files changed  ·  Xs  ·  N tools
ui_card_stats() {
    local files="${1:-0}"
    local runtime="${2:-}"
    local tools="${3:-}"
    local sep="·"
    _ai_ui_supports_unicode 2>/dev/null || sep="-"
    local line="Files changed: $files"
    [ -n "$runtime" ] && line+="  ${sep}  $runtime"
    [ -n "$tools"   ] && line+="  ${sep}  Tools: $tools"
    if _ai_ui_supports_unicode 2>/dev/null; then
        printf '%s✓%s %s\n' "${AI_C_OK:-}" "${AI_C_RESET:-}" "$line"
    else
        printf '+ %s\n' "$line"
    fi
}
