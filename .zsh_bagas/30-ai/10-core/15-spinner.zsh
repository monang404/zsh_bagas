# ============================================================
#  30-ai/10-core/15-spinner.zsh — terminal spinner UI
#  (split out of the old monolithic 30-ai/10-core.zsh)
# ============================================================

: ${AI_SPINNER_ENABLE:=1}

_ai_spinner_start() {
    setopt localoptions noxtrace
    local label="$1"
    if [ "${AI_SPINNER_ENABLE:-1}" != "1" ] || ! { : >/dev/tty; } 2>/dev/null; then
        return 0
    fi
    _ai_log_wait "$label"
    # Return a dummy string so callers expecting a PID/file handle don't break
    echo "static_log:$$"
}

_ai_spinner_update() {
    setopt localoptions noxtrace
    local handle="$1" label="$2"
    [ -z "$handle" ] && return 0
    _ai_log_wait "$label"
}

_ai_spinner_stop() {
    setopt localoptions noxtrace
    local handle="$1"
    [ -z "$handle" ] && return 0
    # Nothing to clean up since there is no background process
}
