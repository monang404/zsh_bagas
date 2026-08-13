# ============================================================
#  30-ai/20-presentation/00-primary_model.zsh — _ai_agent_primary_model — provider/model pertama yang keliatan valid buat header
#  (split out of the old monolithic 30-ai/50-agent/20-presentation.zsh)
# ============================================================

# biar header gak nunjukin provider yang ujung-ujungnya bakal di-skip.
_ai_agent_primary_model() {
    local provider keyvar apikey model
    for provider in "${AI_TASK_PROVIDER_ORDER_AGENT[@]}"; do
        keyvar="${AI_PROVIDERS[${provider}_key_var]}"
        apikey="${(P)keyvar}"
        [ -z "$apikey" ] && continue
        model="${AI_PROVIDERS[${provider}_model]}"
        echo "${provider}/${model}"
        return 0
    done
    echo "(tidak ada provider terkonfigurasi)"
}

