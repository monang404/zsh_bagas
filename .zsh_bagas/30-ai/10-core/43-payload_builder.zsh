# ============================================================
#  30-ai/10-core/43-payload_builder.zsh — chat completion JSON payload
#  (shared by blocking + streaming request layers)
# ============================================================

# Echoes the jq-built request body. is_reasoning=1 adds a provider-
# appropriate reasoning_effort field (Groq's gpt-oss models AND
# DeepSeek's v4 models both use this field name, but with different
# value/default per provider -- see _ai_reasoning_effort_for); stream=1
# adds "stream":true for the SSE path.
_ai_build_chat_payload() {
    local msgfile="$1" model="$2" max_toks="$3" temp="$4"
    local is_reasoning="$5" stream="$6" provider="${7:-groq}"
    if [ "$is_reasoning" -eq 1 ]; then
        local re
        re=$(_ai_reasoning_effort_for "$provider")
        if [ "$stream" -eq 1 ]; then
            jq -n --slurpfile msgs "$msgfile" --arg model "$model" \
                --argjson mt "$max_toks" --argjson temp "$temp" --arg re "$re" \
                '{model:$model, messages:$msgs[0], max_tokens:$mt, temperature:$temp, reasoning_effort:$re, stream:true}'
        else
            jq -n --slurpfile msgs "$msgfile" --arg model "$model" \
                --argjson mt "$max_toks" --argjson temp "$temp" --arg re "$re" \
                '{model:$model, messages:$msgs[0], max_tokens:$mt, temperature:$temp, reasoning_effort:$re}'
        fi
    else
        if [ "$stream" -eq 1 ]; then
            jq -n --slurpfile msgs "$msgfile" --arg model "$model" \
                --argjson mt "$max_toks" --argjson temp "$temp" \
                '{model:$model, messages:$msgs[0], max_tokens:$mt, temperature:$temp, stream:true}'
        else
            jq -n --slurpfile msgs "$msgfile" --arg model "$model" \
                --argjson mt "$max_toks" --argjson temp "$temp" \
                '{model:$model, messages:$msgs[0], max_tokens:$mt, temperature:$temp}'
        fi
    fi
}
