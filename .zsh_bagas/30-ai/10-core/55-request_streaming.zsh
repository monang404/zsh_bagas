# ============================================================
#  30-ai/10-core/55-request_streaming.zsh — streaming (SSE) chat request
#  (split out of the old monolithic 30-ai/10-core.zsh; payload/token/retry/
#  SSE-parsing logic now lives in the shared helpers next to this file)
# ============================================================

# Task 8.1: blocking request layer tetap dipertahankan; helper ini
# hanya menyediakan jalur SSE terpisah untuk caller yang butuh
# token-by-token. Signature sengaja kompatibel dengan _ai_chat_request.
_ai_chat_request_stream() {
    # AI request internals must never inherit global zsh xtrace.
    setopt localoptions noxtrace
    local msgfile="$1" mode="$2" task_class="${3:-smart}"
    local order_str="${4:-${AI_TASK_PROVIDER_ORDER[*]}}"
    local max_toks_override="${5:-}"
    local -a provider_order
    provider_order=(${=order_str})
    local provider endpoint model keyvar apikey modelkey models_str
    local tries payload resp http_status curl_exit
    local model_label_printed=0

    for provider in "${provider_order[@]}"; do
        keyvar="${AI_PROVIDERS[${provider}_key_var]}"
        apikey="${(P)keyvar}"
        [ -z "$apikey" ] && continue

        if [ "$(_ai_provider_has_fallback "$provider" "$order_str")" = 1 ] && _ai_breaker_is_open "$provider"; then
            _ai_chat_diag "[info] $provider baru aja gagal total <${AI_CIRCUIT_BREAKER_WINDOW:-30} detik lalu (circuit breaker), skip dulu ke provider berikutnya..."
            continue
        fi

        endpoint="${AI_PROVIDERS[${provider}_endpoint]}"
        modelkey="${provider}_${task_class}"
        models_str="${AI_MODELS[$modelkey]:-${AI_PROVIDERS[${provider}_model]}}"
        local -a model_list
        model_list=(${=models_str})

        local model_idx=0
        for model in "${model_list[@]}"; do
            tries=0
            model_label_printed=0
            model_idx=$((model_idx + 1))

            if [ ${#model_list[@]} -gt 1 ] && _ai_breaker_is_open "${provider}/${model}"; then
                _ai_chat_diag "[info] $provider/$model baru aja gagal total <${AI_CIRCUIT_BREAKER_WINDOW:-30} detik lalu, skip ke model berikutnya..."
                continue
            fi

            local max_toks
            max_toks=$(_ai_resolve_max_toks "$model_idx" "$max_toks_override")
            local is_reasoning_model=0
            _ai_is_reasoning_model "$provider" "$model" && is_reasoning_model=1

            while [ $tries -lt $AI_MAX_RETRIES ]; do
                local temp
                temp=$(_ai_chat_temp_for_mode "$mode")
                payload=$(_ai_build_chat_payload "$msgfile" "$model" "$max_toks" "$temp" "$is_reasoning_model" 1 "$provider")

                local curl_timeout="${AI_CURL_TIMEOUT:-45}"
                [[ "$curl_timeout" == <-> ]] || curl_timeout=45
                [ "$curl_timeout" -lt 5 ] && curl_timeout=5
                local headerfile statefile rawfile reasoningfile
                headerfile=$(mktemp)
                statefile=$(mktemp)
                rawfile=$(mktemp)
                reasoningfile=$(mktemp)
                printf '%s\n' 'content=0' 'sse=0' 'done=0' > "$statefile"

                # curl -N sengaja dibiarkan mengalir ke parser; header disimpan
                # terpisah hanya untuk membaca HTTP status setelah stream selesai.
                # Semua baris juga disimpan supaya kalau provider ternyata
                # mengembalikan JSON blocking (bukan SSE), response yang SAMA
                # bisa diparse tanpa request API kedua.
                curl -N -s -S --max-time "$curl_timeout" -D "$headerfile" "$endpoint" \
                    -H "Authorization: Bearer $apikey" \
                    -H "Content-Type: application/json" \
                    -d "$payload" 2>/dev/null |
                while IFS= read -r line || [ -n "$line" ]; do
                    _ai_sse_process_line "$line" "$rawfile" "$statefile" "$reasoningfile" "$model"
                done
                curl_exit=${pipestatus[1]}

                http_status=$(awk '$1 ~ /^HTTP\// {code=$2} END {print code}' "$headerfile" 2>/dev/null)
                local stream_content=0 stream_sse=0
                grep -q '^content=1$' "$statefile" && stream_content=1
                grep -q '^sse=1$' "$statefile" && stream_sse=1
                resp=$(cat "$rawfile" 2>/dev/null)
                local stream_reasoning
                stream_reasoning=$(cat "$reasoningfile" 2>/dev/null)

                if [ "$curl_exit" -eq 0 ] && [ "$http_status" = "200" ] && [ "$stream_content" -eq 0 ]; then
                    # FIX (Fase 7/8, HIGH-2): "content delta kosong" dua arti:
                    # (1) sse=1 + reasoning ada -> valid SSE tanpa final content;
                    # reasoning tetap INTERNAL, jangan pernah fallback ke stdout.
                    # (2) selain itu -> non-SSE, provider kirim JSON blocking
                    # biasa walau diminta stream:true; $resp = body itu persis,
                    # aman diparse ulang tanpa request kedua.
                    if [ "$stream_sse" -eq 1 ] && [ -n "$stream_reasoning" ]; then
                        _ai_log "warning" "$provider/$model returned reasoning without final content; suppressing internal reasoning"
                        rm -f "$headerfile" "$statefile" "$rawfile" "$reasoningfile"
                        break
                    fi

                    # A provider may honor the request but ignore `stream:true` and
                    # return one normal JSON response. That is a successful non-SSE
                    # response, not a provider failure. Reuse this exact response
                    # instead of issuing a second API request.
                    reply=$(printf '%s' "$resp" | python3 "$AI_EXTRACT_SCRIPT" 2>/dev/null)
                    if [ -n "$reply" ]; then
                        printf "%s > " "$(_ai_model_label "$model")" >&2
                        printf '%s\n' "$reply"
                        _ai_log_usage "$provider" "$resp"
                        rm -f "$headerfile" "$statefile" "$rawfile" "$reasoningfile"
                        return 0
                    fi
                fi

                rm -f "$headerfile" "$statefile" "$rawfile" "$reasoningfile"

                if [ "$curl_exit" -eq 28 ]; then
                    _ai_chat_diag "[warn] $provider/$model: request timeout setelah ${curl_timeout}s; lanjut ke model berikutnya..."
                fi

                if [ "$curl_exit" -eq 0 ] && [ "$http_status" = "200" ] && [ "$stream_content" -eq 1 ]; then
                    # FIX (audit Fase 7/8, HIGH-1): parity with the blocking path
                    # -- always log usage on a successful streamed reply, so
                    # `aistats` doesn't lose the streaming half of chat traffic.
                    _ai_log_usage "$provider" "$resp"
                    return 0
                fi

                _ai_chat_retry_decision "$http_status" "$provider" "$model" "$resp"
                [ $? -eq 1 ] && break
            done

            _ai_chat_diag "[info] $provider/$model gagal, coba model berikutnya (kalau ada)..."
            _ai_breaker_record_fail "${provider}/${model}"
        done

        echo "[warn: semua model provider '$provider' gagal, coba provider berikutnya...]" >&2
        _ai_breaker_record_fail "$provider"
    done

    echo "[error: semua provider & model gagal (cek 'ai deps' buat lihat provider mana yang aktif). Raw response terakhir:]" >&2
    echo "$resp" | _ai_head_c 300 >&2
    echo "" >&2
    return 1
}
