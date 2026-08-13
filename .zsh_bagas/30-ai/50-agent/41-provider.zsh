# ============================================================
#  30-ai/50-agent/41-provider.zsh — agent provider boundary
# ============================================================
# The agent runtime depends on this adapter, not on provider HTTP details.
# Keep provider selection/auth/retry implementation in 10-core.zsh.

_ai_agent_provider_request() {
    local msgfile="$1" mode="${2:-json}" task_class="${3:-smart}" order="${4:-${AI_TASK_PROVIDER_ORDER_AGENT[*]}}"
    [ -n "$msgfile" ] || { echo "agent provider: missing message file" >&2; return 2; }
    [ -f "$msgfile" ] || { echo "agent provider: message file not found" >&2; return 2; }

    # Contract: stdout is model response; non-zero means no usable response.
    # Provider-specific failures remain owned by _ai_chat_request.
    _ai_chat_request "$msgfile" "$mode" "$task_class" "$order"
}

_ai_agent_provider_health() {
    local provider keyvar
    for provider in ${=AI_TASK_PROVIDER_ORDER_AGENT}; do
        keyvar="${AI_PROVIDERS[${provider}_key_var]}"
        [ -n "${(P)keyvar}" ] && return 0
    done
    echo "Tidak ada provider AI agent yang terkonfigurasi." >&2
    return 1
}
