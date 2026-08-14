# ============================================================
#  30-ai/60-ui/01-logger.zsh — centralized static execution logger
#
#  Blueprint v2 §7: semua [AI][TAG] disembunyikan di default.
#  Hanya muncul kalau AI_VERBOSITY=3 (debug mode).
#  Gunakan: /config verbosity 3  untuk melihat semua log internal.
# ============================================================

# Helper internal: cetak ke stderr HANYA kalau AI_VERBOSITY >= 3
_ai_log_debug_line() {
    [ "${AI_VERBOSITY:-1}" -ge 3 ] && printf '%s\n' "$1" >&2 || true
}

_ai_log_start()     { _ai_log_debug_line "[AI][START] $1"; }
_ai_log_provider()  { _ai_log_debug_line "[AI][PROVIDER] $1"; }
_ai_log_model()     { _ai_log_debug_line "[AI][MODEL] $1"; }
_ai_log_request()   { _ai_log_debug_line "[AI][REQUEST] $1"; }
_ai_log_wait()      { _ai_log_debug_line "[AI][WAIT] $1"; }
_ai_log_stream()    { _ai_log_debug_line "[AI][STREAM] $1"; }
_ai_log_done()      { _ai_log_debug_line "[AI][DONE] $1"; }
_ai_log_error()     { _ai_log_debug_line "[AI][ERROR] $1"; }
_ai_log_retry()     { _ai_log_debug_line "[AI][RETRY] $1"; }
_ai_log_fallback()  { _ai_log_debug_line "[AI][FALLBACK] $1"; }
_ai_log_cancelled() { _ai_log_debug_line "[AI][CANCELLED] $1"; }
