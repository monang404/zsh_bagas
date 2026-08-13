# ============================================================
#  30-ai/20-chat/10-session_ask.zsh — _ai_session_sanitize_file + _ai_session_ask — satu giliran sesi multi-turn (streaming)
#  (split out of the old monolithic 30-ai/20-chat.zsh)
# ============================================================

_ai_session_sanitize_file() {
    setopt localoptions noxtrace
    local file="$1"
    [ -f "$file" ] || return 0
    local tmp="${file}.sanitize.$$"
    # Presentation labels belong to the terminal only. Strip labels that may
    # exist in older sessions created by pre-fix versions. Repeated labels are
    # collapsed in one pass so an already-contaminated session is repaired.
    if jq 'map(if .role == "assistant" and (.content | type) == "string" then .content |= sub("^((llama|gpt-oss|gemini|qwen|deepseek|glm)[[:space:]]*>[[:space:]]*)+"; "") else . end)' "$file" > "$tmp"; then
        command mv -f "$tmp" "$file"
    else
        rm -f "$tmp"
        return 1
    fi
}

_ai_session_ask() {
    setopt localoptions noxtrace
    _ai_need_any_key || return 1
    local name="$1"; shift
    local msg="$*"
    [ -n "$msg" ] || return 0
    mkdir -p "$AI_SESSION_DIR"
    local file="$AI_SESSION_DIR/$name.json"
    if [ ! -f "$file" ]; then
        jq -n --arg p "$AI_PERSONA_LONG" '[{"role":"system","content":$p}]' > "$file" || { echo "ERROR: gagal membuat session $file" >&2; return 1; }
    fi

    _ai_session_sanitize_file "$file" || { echo "ERROR: session JSON rusak/tidak bisa disanitasi." >&2; return 1; }

    # Build the request context in a temporary file first. The session is only
    # committed after a successful model response, so a cancelled/failed turn
    # cannot leave an orphan user message behind.
    local request_file capture tmp_session reply rc tee_status
    request_file=$(mktemp) || return 1
    capture=$(mktemp) || { rm -f "$request_file"; return 1; }
    tmp_session=$(mktemp) || { rm -f "$request_file" "$capture"; return 1; }
    if ! jq --arg m "$msg" '. + [{"role":"user","content":$m}]' "$file" > "$request_file"; then
        rm -f "$request_file" "$capture"
        echo "ERROR: gagal membuat context request." >&2
        return 1
    fi

    AI_CURL_TIMEOUT=15 _ai_chat_request_stream "$request_file" "" fast "${AI_TASK_PROVIDER_ORDER_FAST[*]}" "" |
        tee "$capture"
    local -a stream_status=("${pipestatus[@]}")
    rc=${stream_status[1]}
    tee_status=${stream_status[2]}

    reply=$(cat "$capture" 2>/dev/null)
    rm -f "$capture" "$request_file"

    if [ "$rc" -ne 0 ] || [ "$tee_status" -ne 0 ]; then
        printf '\n' >&2
        rm -f "$tmp_session"
        [ -n "$reply" ] && _ai_log "session:$name" "$msg" "$reply"
        return "${rc:-${tee_status:-1}}"
    fi

    # Commit the exact raw assistant content. The model label is emitted on
    # stderr by the streaming layer and therefore never enters this file.
    if ! jq --arg u "$msg" --arg a "$reply" '. + [{"role":"user","content":$u},{"role":"assistant","content":$a}]' "$file" > "$tmp_session"; then
        rm -f "$tmp_session"
        echo "ERROR: gagal menyusun session assistant message" >&2
        return 1
    fi
    if ! command mv -f "$tmp_session" "$file"; then
        rm -f "$tmp_session"
        echo "ERROR: gagal menyimpan session assistant message" >&2
        return 1
    fi

    _ai_trim_session "$file" || return 1
    printf '\n'
    _ai_log "session:$name" "$msg" "$reply"
}

