# ============================================================
#  30-ai/55-subagent/05-tool_allowlist.zsh — per-role tool allowlist + oneline helper
#  (split out of the old monolithic 30-ai/55-subagent.zsh)
# ============================================================

# Helper lokal: tool mana yang boleh dipanggil subagent untuk role
# tertentu. Dicek SEBELUM _ai_tool_dispatch (bukan sesudah) supaya
# researcher gak sempat mengeksekusi tool write/shell sama sekali.
#   researcher -> HANYA 5 tool readonly yang dipilih manual di
#                 bawah (bukan filter otomatis dari registry --
#                 walau kelima tool ini kebetulan juga ditandai
#                 "readonly" di AI_TOOL_REGISTRY, filter list eksplisit
#                 ini yang jadi sumber kebenaran, bukan tag registry).
#   coder      -> tool APA PUN yang ada di AI_TOOL_REGISTRY existing
#                 (gak ada daftar tool kedua yang dibuat manual).
_ai_subagent_tool_allowed() {
    local role="$1" tool="$2"
    case "$role" in
        researcher)
            case "$tool" in
                read_file|list_dir|grep_search|glob_search|count_lines)
                    return 0 ;;
                *)
                    return 1 ;;
            esac
            ;;
        coder)
            [[ -n "${AI_TOOL_REGISTRY[$tool]}" ]]
            ;;
        *)
            return 1
            ;;
    esac
}

# Ringkas string multi-baris jadi satu baris (newline -> spasi) buat
# ditaruh di output key=value yang aman diparse shell. Reuse pola
# yang sama kayak "${review_text//$'\n'/ }" di aiagent() (50-agent/).
_ai_subagent_oneline() {
    local s="$1"
    s="${s//$'\n'/ }"
    echo "$s"
}
