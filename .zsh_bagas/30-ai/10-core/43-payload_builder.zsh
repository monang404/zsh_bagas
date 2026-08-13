# ============================================================
#  30-ai/10-core/43-payload_builder.zsh — chat completion JSON payload
#  (shared by blocking + streaming request layers)
# ============================================================

# Echoes the jq-built request body. is_reasoning=1 adds Groq's
# reasoning_effort field; stream=1 adds "stream":true for the SSE path.
_ai_build_chat_payload() {
    local msgfile="$1" model="$2" max_toks="$3" temp="$4"
    local is_reasoning="$5" stream="$6"
    if [ "$is_reasoning" -eq 1 ]; then
        if [ "$stream" -eq 1 ]; then
            jq -n --slurpfile msgs "$msgfile" --arg model "$model" \
                --argjson mt "$max_toks" --argjson temp "$temp" --arg re "$GROQ_REASONING_EFFORT" \
                '{model:$model, messages:$msgs[0], max_tokens:$mt, temperature:$temp, reasoning_effort:$re, stream:true}'
        else
            jq -n --slurpfile msgs "$msgfile" --arg model "$model" \
                --argjson mt "$max_toks" --argjson temp "$temp" --arg re "$GROQ_REASONING_EFFORT" \
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
