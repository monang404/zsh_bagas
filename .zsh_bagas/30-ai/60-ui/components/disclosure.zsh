# ============================================================
#  30-ai/60-ui/components/disclosure.zsh — Progressive Disclosure
#  AI-FIRST UX: detail log tersembunyi secara default.
#  User ketik /details untuk lihat semua log aksi terakhir.
# ============================================================

typeset -g AI_LAST_DETAIL_LOG=""

# _ai_detail_push(line) — append satu baris ke detail log
_ai_detail_push() {
    AI_LAST_DETAIL_LOG+="$1"$'\n'
}

# _ai_detail_clear() — reset log (panggil di awal setiap task baru)
_ai_detail_clear() {
    AI_LAST_DETAIL_LOG=""
}

# _ai_detail_show() — print semua log dengan formatting
_ai_detail_show() {
    if [ -z "${AI_LAST_DETAIL_LOG:-}" ]; then
        printf '%s(Tidak ada detail log untuk ditampilkan)%s\n' \
            "${AI_C_MUTED:-}" "${AI_C_RESET:-}"
        return
    fi

    local width inner hz
    width=$(_ai_ui_width 2>/dev/null || echo 40)
    inner=$(( width - 2 ))
    if _ai_ui_supports_unicode 2>/dev/null; then hz="─"; else hz="-"; fi

    local fill="" i
    for (( i = 0; i < inner; i++ )); do fill+="$hz"; done

    printf '%s%s%s\n' "${AI_C_MUTED:-}" "$fill" "${AI_C_RESET:-}"
    printf ' %sDetail Log%s\n' "${AI_C_BOLD:-}" "${AI_C_RESET:-}"
    printf '%s%s%s\n' "${AI_C_MUTED:-}" "$fill" "${AI_C_RESET:-}"

    while IFS= read -r logline; do
        [ -z "$logline" ] && continue
        # Color-code berdasarkan prefix
        case "$logline" in
            \[done\]*)    printf '%s✓%s %s\n' "${AI_C_OK:-}"   "${AI_C_RESET:-}" "${logline#\[done\] }" ;;
            \[error\]*)   printf '%s✗%s %s\n' "${AI_C_ERR:-}"  "${AI_C_RESET:-}" "${logline#\[error\] }" ;;
            \[thinking\]*) printf '%s◌%s %s\n' "${AI_C_INFO:-}" "${AI_C_RESET:-}" "${logline#\[thinking\] }" ;;
            \[acting\]*)  printf '%s→%s %s\n' "${AI_C_PRIMARY:-}" "${AI_C_RESET:-}" "${logline#\[acting\] }" ;;
            \[tool\]*)    printf '%s  Tool: %s%s\n' "${AI_C_MUTED:-}" "${logline#\[tool\] }" "${AI_C_RESET:-}" ;;
            \[approval\]*) printf '%s⚠%s %s\n' "${AI_C_WARN:-}" "${AI_C_RESET:-}" "${logline#\[approval\] }" ;;
            \[debug\]*)   printf '%s[DBG] %s%s\n' "${AI_C_MUTED:-}" "${logline#\[debug\] }" "${AI_C_RESET:-}" ;;
            *)             printf '  %s\n' "$logline" ;;
        esac
    done <<< "$AI_LAST_DETAIL_LOG"

    printf '%s%s%s\n' "${AI_C_MUTED:-}" "$fill" "${AI_C_RESET:-}"
}
