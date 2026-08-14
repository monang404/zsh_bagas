# ============================================================
#  30-ai/60-ui/01-logger.zsh — centralized static execution logger
#
#  AI-FIRST UX: Menggantikan [AI][TAG] dengan Status Line minimalis
#  Progressive disclosure berbasis AI_VERBOSITY (0, 1, 2, 3).
#  Level 0: Sangat hening, hanya DONE/ERROR.
#  Level 3: Full debug log asli.
# ============================================================

_ai_log_status() {
    local state="$1"
    local detail="$2"
    local verbosity="${AI_VERBOSITY:-0}"
    
    # Level 3: Debug Log Asli
    if [ "$verbosity" -ge 3 ]; then
        printf '%s\n' "[AI][${state}] $detail" >&2
        return
    fi
    
    local icon text color print_newline=1
    case "$state" in
        WAIT)    icon="●" ; text="Thinking..." ; color="${AI_C_MUTED:-}" ;;
        REQUEST) icon="●" ; text="Sending..."  ; color="${AI_C_MUTED:-}" ;;
        DONE)    icon="✓" ; text="Done"        ; color="${AI_C_OK:-}" ;;
        ERROR)   icon="✗" ; text="Error"       ; color="${AI_C_ERR:-}" ;;
        START|MODEL|PROVIDER|STREAM|RETRY|FALLBACK|CANCELLED)
            # Level 0, 1, 2: Sembunyikan START/MODEL dsb agar terminal tetap bersih
            return
            ;;
        *)       icon="●" ; text="$state"      ; color="${AI_C_MUTED:-}" ;;
    esac
    
    # Tampilkan jika verbosity >= 1 (Level 1+) atau jika ini DONE/ERROR
    if [ "$verbosity" -ge 1 ] || [[ "$state" == "WAIT" || "$state" == "REQUEST" || "$state" == "DONE" || "$state" == "ERROR" ]]; then
        # Jika verbosity >= 1, tambahkan detail teks jika ada
        if [ "$verbosity" -ge 1 ] && [ -n "$detail" ]; then
            text="$detail"
        fi
        
        # Cetak minimalis, HANYA JIKA TIDAK DUPLIKAT (untuk hemat baris)
        # Kita cache status terakhir untuk menghindari spam `● Thinking...` berkali-kali
        if [ "${_AI_LAST_STATUS:-}" != "${state}:${text}" ]; then
            printf '%s%s%s %s\n' "${color}" "${icon}" "${AI_C_RESET:-}" "${text}" >&2
            _AI_LAST_STATUS="${state}:${text}"
        fi
    fi
}

_ai_log_start()     { _ai_log_status "START" "$1"; }
_ai_log_provider()  { _ai_log_status "PROVIDER" "$1"; }
_ai_log_model()     { _ai_log_status "MODEL" "$1"; }
_ai_log_request()   { _ai_log_status "REQUEST" "$1"; }
_ai_log_wait()      { _ai_log_status "WAIT" "$1"; }
_ai_log_stream()    { _ai_log_status "STREAM" "$1"; }
_ai_log_done()      { _ai_log_status "DONE" "$1"; }
_ai_log_error()     { _ai_log_status "ERROR" "$1"; }
_ai_log_retry()     { _ai_log_status "RETRY" "$1"; }
_ai_log_fallback()  { _ai_log_status "FALLBACK" "$1"; }
_ai_log_cancelled() { _ai_log_status "CANCELLED" "$1"; }
