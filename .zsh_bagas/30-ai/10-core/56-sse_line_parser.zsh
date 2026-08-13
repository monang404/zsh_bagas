# ============================================================
#  30-ai/10-core/56-sse_line_parser.zsh — one SSE line -> content/state
#  (used by 55-request_streaming.zsh)
# ============================================================

# Processes one line of a Server-Sent-Events response. Appends the raw
# line to $rawfile (so a non-SSE JSON body can still be re-parsed without
# a second API call), prints delta.content live to stdout, and tracks
# state (content=1/sse=1/done=1) in $statefile for the caller to inspect
# after the stream ends.
#
# FIX (audit Fase 7/8, HIGH-2): reasoning models (openai/gpt-oss-* on
# groq/cerebras) can stream ONLY reasoning deltas with delta.content
# never once filled (reasoning ate the whole max_tokens budget before it
# got to write a final answer). That text is captured into
# $reasoningfile as an internal-only fallback (never printed live here)
# so a healthy API call doesn't come back looking like an empty response.
# Reasoning must never become user-facing output, including under shell
# tracing/debug instrumentation, so it is appended directly rather than
# passed through a temporary shell variable.
#
# Mutates the caller's (dynamically-scoped) `model_label_printed`.
_ai_sse_process_line() {
    local line="$1" rawfile="$2" statefile="$3" reasoningfile="$4" model="$5"
    local data_line content
    printf '%s\n' "$line" >> "$rawfile"
    case "$line" in
        data:*)
            data_line="${line#data:}"
            [ "${data_line# }" != "$data_line" ] && data_line="${data_line# }"
            data_line="${data_line%$'\r'}"
            if [ "$data_line" = "[DONE]" ]; then
                printf '%s\n' 'done=1' >> "$statefile"
                return 0
            fi
            content=$(printf '%s' "$data_line" | jq -r '.choices[0].delta.content // empty' 2>/dev/null)
            if [ -n "$content" ]; then
                if [ "$model_label_printed" -eq 0 ]; then
                    printf "%s > " "$(_ai_model_label "$model")" >&2
                    model_label_printed=1
                fi
                printf '%s' "$content"
                printf '%s\n' 'content=1' >> "$statefile"
            else
                printf '%s' "$data_line" |
                    jq -r '.choices[0].delta.reasoning // .choices[0].delta.reasoning_content // empty' >> "$reasoningfile" 2>/dev/null
            fi
            printf '%s\n' 'sse=1' >> "$statefile"
            ;;
    esac
}
