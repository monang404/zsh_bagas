# ============================================================
#  30-ai/60-ui/components/verbosity.zsh — Verbosity System
#  AI-FIRST UX: output yang tampil dikontrol oleh AI_VERBOSITY.
#
#  Level:
#    0 — Minimal  : hanya hasil akhir (Done/Error)  ← DEFAULT
#    1 — Normal   : + Searching, Acting
#    2 — Detailed : + nama tool, file yang dibuka
#    3 — Debug    : semua log internal
#
#  Cara set: /config verbosity 0  (lewat router)
#            export AI_VERBOSITY=2 (manual)
# ============================================================

# Default level 0 (Minimal) jika belum ada
: "${AI_VERBOSITY:=0}"

# _ai_verbose(min_level, message) — cetak message jika AI_VERBOSITY >= min_level
# Gunakan ini di semua modul sebagai pengganti `echo` langsung.
_ai_verbose() {
    local level="${1:-0}"
    shift
    if [ "${AI_VERBOSITY:-0}" -ge "$level" ]; then
        printf '%s\n' "$*"
    fi
}

# _ai_verbose_c(min_level, color_var, message) — dengan warna
_ai_verbose_c() {
    local level="$1" color="$2"
    shift 2
    if [ "${AI_VERBOSITY:-0}" -ge "$level" ]; then
        printf '%s%s%s\n' "$color" "$*" "${AI_C_RESET:-}"
    fi
}

# ai_verbosity_set(N) — ubah level verbosity dan simpan di env
ai_verbosity_set() {
    local n="${1:-0}"
    case "$n" in
        0|1|2|3) export AI_VERBOSITY="$n" ;;
        *)
            printf '%sVerbosity harus 0-3 (dapat: %s)%s\n' \
                "${AI_C_WARN:-}" "$n" "${AI_C_RESET:-}"
            return 1
            ;;
    esac
    local label
    case "$n" in
        0) label="Minimal (hanya hasil)" ;;
        1) label="Normal" ;;
        2) label="Detailed (tool+file)" ;;
        3) label="Debug (semua log)" ;;
    esac
    printf '%s✓%s Verbosity → %s  %s(%s)%s\n' \
        "${AI_C_OK:-}" "${AI_C_RESET:-}" \
        "$n" "${AI_C_MUTED:-}" "$label" "${AI_C_RESET:-}"
}
