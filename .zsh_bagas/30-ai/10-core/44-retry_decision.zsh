# ============================================================
#  30-ai/10-core/44-retry_decision.zsh — what to do after a failed attempt
#  (shared by blocking + streaming request layers)
# ============================================================

# Decides what an attempt should do after a non-success HTTP response.
# Mutates the caller's `max_toks` / `tries` in place (zsh locals are
# dynamically scoped, so this reaches back into the caller's frame as
# long as the caller has already declared them `local`).
#
#   return 0  -> caller should retry the SAME model right away (`continue`)
#   return 1  -> caller should give up on this model (`break`)
#
# HTTP 413 = request (prompt + max_tokens) kelewat limit TPM akun. Ngirim
# ULANG payload yang PERSIS SAMA gak akan pernah berhasil (bukan masalah
# transient), jadi daripada buang retry buat request yang pasti gagal
# lagi, langsung kecilin max_tokens dan coba lagi tanpa nunggu delay.
#
# HTTP 429 (quota/rate limit abis) atau 404 (model gak ada/discontinue)
# BUKAN error transient -- ngulang request yang PERSIS SAMA ke model yang
# sama pasti gagal lagi juga, jadi langsung lompat ke model berikutnya
# (bikin fallback kerasa instan, bukan nunggu retry x delay dulu).
_ai_chat_retry_decision() {
    local http_status="$1" provider="$2" model="$3" resp="$4"

    if [ "$http_status" = "413" ]; then
        local new_max=$((max_toks / 2))
        if [ "$new_max" -ge 500 ]; then
            _ai_chat_diag "[info] $provider/$model: request kegedean buat limit TPM akun (413), nurunin max_tokens $max_toks -> $new_max, coba lagi..."
            max_toks=$new_max
            tries=$((tries + 1))
            return 0
        fi
        _ai_chat_diag "[warn] $provider/$model: masih kena limit TPM walau max_tokens udah diperkecil ke minimum, lanjut ke model berikutnya..."
        return 1
    fi

    if [ "$http_status" = "429" ] || [ "$http_status" = "404" ]; then
        _ai_chat_diag "[info] $provider/$model: HTTP $http_status (quota abis / model gak tersedia), lompat ke model berikutnya..."
        return 1
    fi

    # Cek apakah ada pesan error di dalam payload JSON meskipun HTTP status 200
    local json_error
    json_error=$(echo "$resp" | jq -r '.error.message // .error // empty' 2>/dev/null)
    if [ -n "$json_error" ] && [ "$json_error" != "null" ]; then
        _ai_chat_diag "[warn] $provider/$model: API membalas dengan error: $json_error"
        # Error dari API seperti 'Model does not exist' bukan transient error, langsung lompat model
        return 1
    fi

    # gagal — hitung finish_reason (buat ketauan kasus kehabisan token pas
    # reasoning vs error jaringan/API beneran) sebelum retry biasa.
    local finish_reason
    finish_reason=$(echo "$resp" | jq -r '.choices[0].finish_reason // "n/a"' 2>/dev/null)
    tries=$((tries + 1))
    sleep "$AI_RETRY_DELAY"
    return 0
}
