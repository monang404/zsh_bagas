# ============================================================
#  30-ai/10-core/10-cache.zsh — response cache (key/file/read/write)
#  (split out of the old monolithic 30-ai/10-core.zsh)
# ============================================================

# ─── Prompt cache foundation (Task 10.1) ─────────────────────
# Cache key sengaja hanya bergantung pada input yang menentukan respons:
# provider/model target class, prompt penuh, dan persona/system prompt. Tidak ada
# timestamp/PID/random value, sehingga key stabil antar-run dan aman dipakai
# sebagai nama file cache.
_ai_cache_key() {
    local provider="$1" model="$2" task_class="$3" prompt="$4" persona="$5"
    local digest
    if command -v sha256sum >/dev/null 2>&1; then
        digest=$(printf '%s\0%s\0%s\0%s\0%s' "$provider" "$model" "$task_class" "$prompt" "$persona" | sha256sum 2>/dev/null | awk '{print $1}')
    elif command -v shasum >/dev/null 2>&1; then
        digest=$(printf '%s\0%s\0%s\0%s\0%s' "$provider" "$model" "$task_class" "$prompt" "$persona" | shasum -a 256 2>/dev/null | awk '{print $1}')
    else
        return 1
    fi
    [ -n "$digest" ] || return 1
    printf '%s\n' "$digest"
}

_ai_cache_file() {
    local prompt_hash="$1"
    [ -n "$prompt_hash" ] || return 1
    printf '%s/%s.json\n' "${AI_CACHE_DIR:-$AI_GENERATE_DIR/cache}" "$prompt_hash"
}

# Cache read adalah fail-open: file hilang, JSON rusak, timestamp invalid,
# dependency gagal, atau cache expired semuanya diperlakukan sebagai miss.
_ai_cache_read() {
    local prompt_hash="$1" file ts now age ttl reply
    file=$(_ai_cache_file "$prompt_hash") || return 1
    [ -f "$file" ] || return 1
    command -v jq >/dev/null 2>&1 || return 1

    ts=$(jq -r '.ts // empty' "$file" 2>/dev/null) || return 1
    [[ "$ts" == <-> ]] || return 1
    now=$(date +%s 2>/dev/null) || return 1
    age=$(( now - ts ))
    ttl="${AI_CACHE_TTL_SECONDS:-3600}"
    [[ "$ttl" == <-> ]] || ttl=3600
    (( age >= 0 && age <= ttl )) || return 1

    reply=$(jq -er --arg h "$prompt_hash" \
        'select(.prompt_hash == $h and (.reply | type) == "string" and (.provider | type) == "string" and (.model | type) == "string") | .reply' \
        "$file" 2>/dev/null) || return 1
    printf '%s\n' "$reply"
}

# Cache write juga fail-open. Tulis ke file sementara lalu rename atomik supaya
# cache reader tidak melihat JSON setengah jadi bila proses terputus saat write.
_ai_cache_write() {
    local prompt_hash="$1" reply="$2" provider="$3" model="$4"
    local dir file tmp ts
    [ -n "$prompt_hash" ] || return 1
    command -v jq >/dev/null 2>&1 || return 1
    dir="${AI_CACHE_DIR:-$AI_GENERATE_DIR/cache}"
    mkdir -p "$dir" 2>/dev/null || return 1
    file="$dir/$prompt_hash.json"
    tmp="$file.tmp.$$"
    ts=$(date +%s 2>/dev/null) || return 1
    jq -n --arg h "$prompt_hash" --arg r "$reply" --arg t "$ts" \
        --arg p "$provider" --arg m "$model" \
        '{prompt_hash:$h, reply:$r, ts:$t, provider:$p, model:$m}' > "$tmp" 2>/dev/null || {
        rm -f "$tmp" 2>/dev/null
        return 1
    }
    command mv -f "$tmp" "$file" 2>/dev/null || {
        rm -f "$tmp" 2>/dev/null
        return 1
    }
    return 0
}
