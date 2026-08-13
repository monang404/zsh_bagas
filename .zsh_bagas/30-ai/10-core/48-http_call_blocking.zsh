# ============================================================
#  30-ai/10-core/48-http_call_blocking.zsh — single blocking curl attempt
#  (used by 50-request_blocking.zsh)
# ============================================================

# Body respons ditulis LANGSUNG ke file oleh curl (-o), status code
# ditangkap terpisah lewat -w. Ini sengaja dipisah biar gak ada gabung-
# gabung string yang gampang salah potong. Interactive requests use a
# fixed network timeout — never derive it from max_tokens, a large
# completion budget must never turn a CLI chat request into a multi-
# minute wait.
#
# Writes to the caller's (dynamically-scoped) `resp`, `http_status`,
# `curl_exit`, `_ai_active_curl_pid` locals. Returns 130 if the request
# was cancelled via the caller's TRAPINT/TRAPTERM (caller must check for
# that and `return 130` itself — a `return` here only exits this helper).
_ai_http_call_blocking() {
    local endpoint="$1" apikey="$2" payload="$3" curl_timeout="$4"
    local respfile http_status_file
    respfile=$(mktemp)
    http_status_file=$(mktemp)
    curl -s -S --max-time "$curl_timeout" -o "$respfile" -w "%{http_code}" "$endpoint" \
        -H "Authorization: Bearer $apikey" \
        -H "Content-Type: application/json" \
        -d "$payload" >| "$http_status_file" 2>/dev/null &
    _ai_active_curl_pid=$!
    wait "$_ai_active_curl_pid"
    curl_exit=$?
    _ai_active_curl_pid=""
    if [ "$_ai_cancelled" -eq 1 ]; then
        rm -f "$http_status_file" "$respfile"
        return 130
    fi
    http_status=$(<"$http_status_file" 2>/dev/null)
    rm -f "$http_status_file"
    resp=$(cat "$respfile" 2>/dev/null)
    rm -f "$respfile"
    return 0
}
