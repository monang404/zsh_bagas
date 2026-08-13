# ============================================================
#  30-ai/20-chat/05-aiask.zsh — aiask — tanya soal konteks file/pipe, dengan cache per (provider,model,prompt)
#  (split out of the old monolithic 30-ai/20-chat.zsh)
# ============================================================

# ─── Fungsi (v1) ────────────────────────────────────────────

aiask() {
    setopt localoptions noxtrace
    _ai_need_any_key || return 1

    local no_cache=0
    local -a args
    local arg
    for arg in "$@"; do
        if [ "$arg" = "--no-cache" ]; then
            no_cache=1
        else
            args+=("$arg")
        fi
    done

    local content query
    if [ -p /dev/stdin ]; then
        content=$(cat)
        query="${args[*]}"
    else
        [ ${#args[@]} -gt 0 ] || { echo "Gak ada konten (file kosong/gak ketemu, atau lupa pipe)."; return 1; }
        if [ -f "${args[0]}" ]; then
            content=$(cat "${args[0]}" 2>/dev/null)
            query="${args[@]:1}"
        else
            content=$(cat "${args[0]}" 2>/dev/null)
            query="${args[*]:1}"
        fi
    fi
    [ -z "$content" ] && { echo "Gak ada konten (file kosong/gak ketemu, atau lupa pipe)."; return 1; }

    local persona="$AI_PERSONA_LONG Kamu akan dikasih konteks (isi file/output command), jawab pertanyaan berdasarkan konteks itu."
    local prompt="Konteks:\n$content\n\nPertanyaan: $query"
    local task_class="fast"
    local order_str="${AI_TASK_PROVIDER_ORDER_FAST[*]}"
    local cache_hash cache_reply cache_file cache_ts cache_age
    local provider model models_str modelkey keyvar apikey

    if [ "$no_cache" -eq 0 ]; then
        for provider in ${=order_str}; do
            keyvar="${AI_PROVIDERS[${provider}_key_var]}"
            apikey="${(P)keyvar}"
            [ -n "$apikey" ] || continue
            modelkey="${provider}_${task_class}"
            models_str="${AI_MODELS[$modelkey]:-${AI_PROVIDERS[${provider}_model]}}"
            for model in ${=models_str}; do
                cache_hash=$(_ai_cache_key "$provider" "$model" "$task_class" "$prompt" "$persona") || continue
                cache_reply=$(_ai_cache_read "$cache_hash") || continue
                cache_file=$(_ai_cache_file "$cache_hash") || continue
                cache_ts=$(jq -r '.ts // empty' "$cache_file" 2>/dev/null)
                [[ "$cache_ts" == <-> ]] || continue
                cache_age=$(( $(date +%s) - cache_ts ))
                (( cache_age >= 0 )) || continue
                echo "$cache_reply"
                echo "(dari cache, ${cache_age}s lalu)"
                _ai_log "ask" "$query" "$cache_reply"
                return 0
            done
        done
    fi

    local msgfile meta_file reply rc provider_used model_used
    msgfile=$(mktemp) || return 1
    meta_file=$(mktemp) || { rm -f "$msgfile"; return 1; }
    jq -n --arg p "$persona" --arg u "$prompt" \
        '[{role:"system",content:$p},{role:"user",content:$u}]' > "$msgfile" || {
        rm -f "$msgfile" "$meta_file"
        return 1
    }

    reply=$(_ai_chat_request "$msgfile" "" "$task_class" "$order_str" "" "$meta_file")
    rc=$?
    rm -f "$msgfile"
    if [ "$rc" -ne 0 ]; then
        rm -f "$meta_file"
        echo "$reply"
        return "$rc"
    fi

    provider_used=$(cut -f1 "$meta_file" 2>/dev/null)
    model_used=$(cut -f2 "$meta_file" 2>/dev/null)
    rm -f "$meta_file"

    if [ -n "$provider_used" ] && [ -n "$model_used" ]; then
        cache_hash=$(_ai_cache_key "$provider_used" "$model_used" "$task_class" "$prompt" "$persona") || cache_hash=""
        [ -n "$cache_hash" ] && _ai_cache_write "$cache_hash" "$reply" "$provider_used" "$model_used" >/dev/null 2>&1 || true
    fi

    echo "$reply"
    _ai_log "ask" "$query" "$reply"
}

