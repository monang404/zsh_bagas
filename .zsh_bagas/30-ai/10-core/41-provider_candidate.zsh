# ============================================================
#  30-ai/10-core/41-provider_candidate.zsh — provider fallback lookahead
#  (shared by 50-request_blocking.zsh and 55-request_streaming.zsh)
# ============================================================

# cari tau apakah masih ada provider LAIN di sisa list yang key-nya
# ke-set -- kalau provider ini satu-satunya kandidat tersisa, breaker
# DIABAIKAN (mending coba daripada dipastikan gagal tanpa nyoba apa-apa
# sama sekali). Echoes 1/0 so callers can do:
#   if [ "$(_ai_provider_has_fallback "$provider" "${provider_order[*]}")" = 1 ] && ...
_ai_provider_has_fallback() {
    local provider="$1" order_str="$2"
    local -a provider_order
    provider_order=(${=order_str})
    local rest_provider rest_keyvar
    for rest_provider in "${provider_order[@]}"; do
        [ "$rest_provider" = "$provider" ] && continue
        rest_keyvar="${AI_PROVIDERS[${rest_provider}_key_var]}"
        if [ -n "${(P)rest_keyvar}" ]; then
            echo 1
            return 0
        fi
    done
    echo 0
}
