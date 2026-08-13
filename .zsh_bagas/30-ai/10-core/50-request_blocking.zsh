# ============================================================
#  30-ai/10-core/50-request_blocking.zsh — blocking chat request (provider/model fallback loop)
#  (split out of the old monolithic 30-ai/10-core.zsh; payload/token/retry
#  logic now lives in the shared 4x-*.zsh helpers next to this file)
# ============================================================

_ai_chat_request() {
    # Never leak internal assignments when caller has global xtrace enabled.
    setopt localoptions noxtrace
    local msgfile="$1" mode="$2" task_class="${3:-smart}"
    local order_str="${4:-${AI_TASK_PROVIDER_ORDER[*]}}"
    local max_toks_override="${5:-}"
    local result_meta_file="${6:-}"
    local -a provider_order
    provider_order=(${=order_str})
    local provider endpoint model keyvar apikey modelkey models_str
    local tries resp reply payload

    # spinner mulai SEKALI di awal, dipertahankan lintas provider/model/
    # percobaan (di-update labelnya, gak di-restart) sampai salah satu
    # return point di bawah -- biar user liat 1 animasi mengalir yang
    # berubah context-nya, bukan spinner kedip-restart tiap ganti model.
    local _spin=""
    _spin=$(_ai_spinner_start "Menyiapkan AI provider...")

    # Ctrl-C harus membatalkan request aktif dan membersihkan spinner.
    # _ai_chat_request sering dipanggil lewat command substitution (r=$(...)),
    # sehingga jangan mengandalkan SIGINT otomatis diteruskan ke curl.
    local _ai_active_curl_pid=""
    local -i _ai_cancelled=0
    TRAPINT() {
        if [ -n "$_ai_active_curl_pid" ]; then
            kill -INT "$_ai_active_curl_pid" 2>/dev/null
            kill -TERM "$_ai_active_curl_pid" 2>/dev/null
        fi
        _ai_cancelled=1
        _ai_spinner_stop "$_spin"
        return 130
    }
    TRAPTERM() {
        if [ -n "$_ai_active_curl_pid" ]; then
            kill -TERM "$_ai_active_curl_pid" 2>/dev/null
        fi
        _ai_cancelled=1
        _ai_spinner_stop "$_spin"
        return 143
    }

    for provider in "${provider_order[@]}"; do
        keyvar="${AI_PROVIDERS[${provider}_key_var]}"
        apikey="${(P)keyvar}"
        [ -z "$apikey" ] && continue   # provider gak dikonfigurasi, skip diam-diam

        _ai_chat_diag "[trace] cek provider $provider..."

        if [ "$(_ai_provider_has_fallback "$provider" "$order_str")" = 1 ] && _ai_breaker_is_open "$provider"; then
            _ai_chat_diag "[info] $provider baru aja gagal total <${AI_CIRCUIT_BREAKER_WINDOW:-30} detik lalu (circuit breaker), skip dulu ke provider berikutnya..."
            continue
        fi

        endpoint="${AI_PROVIDERS[${provider}_endpoint]}"

        # provider dengan daftar model di AI_MODELS (groq/gemini) pakai
        # fallback multi-model; provider lain (cerebras/openrouter) belum
        # dipetakan ke kelas fast/smart, jadi tetap 1 model kayak v3.
        modelkey="${provider}_${task_class}"
        models_str="${AI_MODELS[$modelkey]:-${AI_PROVIDERS[${provider}_model]}}"
        local -a model_list
        model_list=(${=models_str})

        local model_idx=0
        for model in "${model_list[@]}"; do
        tries=0
        model_idx=$((model_idx + 1))

        # v-fix (bug #57 audit): breaker key "$provider/$model" dicek
        # SEBELUM nyoba, tapi cuma di-skip kalau masih ada model LAIN
        # tersisa buat provider ini (mending coba daripada dipastikan
        # gagal tanpa nyoba sama sekali kalau ini satu-satunya opsi).
        if [ ${#model_list[@]} -gt 1 ] && _ai_breaker_is_open "${provider}/${model}"; then
            _ai_chat_diag "[info] $provider/$model baru aja gagal total <${AI_CIRCUIT_BREAKER_WINDOW:-30} detik lalu, skip ke model berikutnya..."
            continue
        fi

        local max_toks
        max_toks=$(_ai_resolve_max_toks "$model_idx" "$max_toks_override")
        local is_reasoning_model=0
        _ai_is_reasoning_model "$provider" "$model" && is_reasoning_model=1

        while [ $tries -lt $AI_MAX_RETRIES ]; do
            _ai_spinner_update "$_spin" "Menghubungi $provider/$model (percobaan $((tries+1)))..."
            _ai_chat_diag "[trace] bangun payload buat $provider/$model (percobaan $((tries+1)))..."
            local temp
            temp=$(_ai_chat_temp_for_mode "$mode")
            payload=$(_ai_build_chat_payload "$msgfile" "$model" "$max_toks" "$temp" "$is_reasoning_model" 0)

            local curl_timeout="${AI_CURL_TIMEOUT:-45}"
            [[ "$curl_timeout" == <-> ]] || curl_timeout=45
            [ "$curl_timeout" -lt 5 ] && curl_timeout=5

            local http_status curl_exit
            local _diag_t0=$SECONDS
            _ai_chat_diag "[trace] curl -> $endpoint (max-time ${curl_timeout}s) dikirim..."
            _ai_http_call_blocking "$endpoint" "$apikey" "$payload" "$curl_timeout"
            if [ $? -eq 130 ]; then
                trap - INT TERM
                _ai_spinner_stop "$_spin"
                return 130
            fi
            _ai_chat_diag "[trace] curl selesai ($((SECONDS - _diag_t0))s) exit=$curl_exit http_status=${http_status:-?}"

            if [ "$curl_exit" -eq 28 ]; then
                _ai_chat_diag "[warn] $provider/$model: request timeout setelah ${curl_timeout}s; lanjut ke model berikutnya..."
            fi

            reply=$(echo "$resp" | python3 "$AI_EXTRACT_SCRIPT" 2>/dev/null)
            if [ -n "$reply" ]; then
                _ai_spinner_stop "$_spin"
                if [ -n "$result_meta_file" ]; then
                    printf '%s\t%s\n' "$provider" "$model" > "$result_meta_file" 2>/dev/null || true
                fi
                echo "$reply"
                _ai_log_usage "$provider" "$resp"
                trap - INT TERM
                return 0
            fi

            # gagal — tampilin curl exit code/HTTP status ke stderr via diag,
            # cuplikan body cuma di titik "semua provider gagal" di bawah,
            # biar gak ngotorin stdout yang dipakai sebagai reply.
            _ai_chat_retry_decision "$http_status" "$provider" "$model" "$resp"
            [ $? -eq 1 ] && break
        done

        _ai_chat_diag "[info] $provider/$model gagal, coba model berikutnya (kalau ada)..."
        _ai_breaker_record_fail "${provider}/${model}"
        done   # end model_list loop

        # v-fix: warn SETIAP provider yang gagal ke stderr (bukan cuma
        # provider terakhir) -- sebelumnya provider lain cuma lewat
        # _ai_chat_diag yang tersembunyi kecuali AI_VERBOSE=1, jadi user
        # gak tau provider mana saja yang dicoba dan kenapa semua gagal.
        echo "[warn: semua model provider '$provider' gagal, coba provider berikutnya...]" >&2
        _ai_breaker_record_fail "$provider"
    done

    echo "[error: semua provider & model gagal (cek 'ai deps' buat lihat provider mana yang aktif). Raw response terakhir:]" >&2
    # v-fix: tampilkan raw response dengan benar -- jq diam-diam gagal kalau
    # input bukan JSON (mis. HTML 402/503 page, string plain "rate limited"),
    # hasilnya baris kosong dan user gak tau penyebab aslinya. Coba jq dulu
    # (ambil .error kalau ada), kalau gagal fallback ke raw string mentah.
    local _raw_err
    _raw_err=$(echo "$resp" | jq -r '.error.message // .error // .message // empty' 2>/dev/null)
    if [ -z "$_raw_err" ]; then
        _raw_err=$(printf '%s' "$resp" | _ai_head_c 300)
    fi
    [ -n "$_raw_err" ] && echo "$_raw_err" >&2 || echo "(response kosong)" >&2
    echo "" >&2
    trap - INT TERM
    _ai_spinner_stop "$_spin"
    return 1
}
