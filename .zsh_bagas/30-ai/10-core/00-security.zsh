# ============================================================
#  30-ai/10-core/00-security.zsh — security & API key checks
#  (split out of the old monolithic 30-ai/10-core.zsh)
# ============================================================

# Runtime state contains prompts, tool output, checkpoints and provider metadata.
# Keep newly-created runtime directories/files private by default.
_ai_secure_runtime_dir() {
    local d="$1"
    mkdir -p -- "$d" || return 1
    chmod 700 "$d" 2>/dev/null || true
}

# ============================================================
#  30-ai/10-core.zsh — request layer & utilitas inti
#  _ai_chat_request (fallback multi-model x multi-provider), log/notify/guard. Dipakai semua fungsi ai* lainnya.
# ============================================================

_ai_need_key() {
    if [ -z "${(P)1}" ]; then
        echo "$1 belum di-set. Cek ~/.secrets.zsh" >&2
        return 1
    fi
    return 0
}

# v4: guard baru — dulu tiap fungsi hard-require GROQ_API_KEY spesifik,
# padahal sekarang sistemnya multi-provider. Kalau suatu saat Groq
# dicabut tapi Gemini masih ke-set (atau sebaliknya), fungsi HARUSNYA
# tetap jalan lewat fallback, bukan langsung nolak di depan. Guard ini
# cuma mastiin minimal ADA SATU provider yang ke-set.
_ai_need_any_key() {
    local provider keyvar apikey
    for provider in "${AI_TASK_PROVIDER_ORDER[@]}"; do
        keyvar="${AI_PROVIDERS[${provider}_key_var]}"
        apikey="${(P)keyvar}"
        [ -n "$apikey" ] && return 0
    done
    echo "Gak ada API key provider yang ke-set (GROQ_API_KEY / GEMINI_API_KEY / dst). Cek ~/.secrets.zsh atau 'ai deps'." >&2
    return 1
}
