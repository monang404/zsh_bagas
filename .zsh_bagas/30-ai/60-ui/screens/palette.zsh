# ============================================================
#  30-ai/60-ui/screens/palette.zsh — Full Command Palette
#  AI-FIRST UX: launcher modern via gum filter.
#  Semua slash commands tersedia di sini.
# ============================================================

ui_palette() {
    if ! command -v gum >/dev/null 2>&1; then
        printf '%sError: gum tidak terinstall (pkg install gum)%s\n' \
            "${AI_C_ERR:-}" "${AI_C_RESET:-}"
        return 1
    fi

    local -a options=(
        "chat          Tanya AI secara cepat"
        "code          Generate kode baru"
        "fix           Auto-fix file dari error"
        "scan          Scan project (bahasa, test cmd)"
        "index         Index codebase (functions/classes)"
        "agent         Jalankan AI Agent loop"
        "review        Code review diff"
        "commit        Generate commit message"
        "session       Mulai session baru"
        "details       Tampilkan detail log terakhir"
        "config verbosity 0   Output minimal"
        "config verbosity 1   Output normal (default)"
        "config verbosity 2   Output detail (tool+file)"
        "config verbosity 3   Debug semua log"
        "dev           Buka workspace tmux"
        "stats         Statistik token/usage"
        "help          Bantuan lengkap"
    )

    local selected
    selected=$(printf '%s\n' "${options[@]}" | \
        gum filter \
            --placeholder "Search command..." \
            --indicator ">" \
            --height 15 \
            --prompt "${AI_C_PRIMARY:-}> ${AI_C_RESET:-}")

    [ -z "$selected" ] && return 0

    # Ambil command (semua kata kecuali bagian deskripsi setelah spasi panjang)
    # Format: "cmd arg   Description" → cmd+arg adalah bagian sebelum 2+ spasi
    local cmd_part
    cmd_part=$(printf '%s' "$selected" | sed 's/  .*//' | xargs)

    if type ui_router >/dev/null 2>&1; then
        ui_router "$cmd_part"
    else
        # Fallback: kirim langsung ke ai dispatcher
        ai $cmd_part
    fi
}
