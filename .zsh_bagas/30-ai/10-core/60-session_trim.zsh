# ============================================================
#  30-ai/10-core/60-session_trim.zsh — session history trimming
#  (split out of the old monolithic 30-ai/10-core.zsh)
# ============================================================

# trim session/context file biar gak membengkak (system message tetap dipertahankan)
_ai_trim_session() {
    local file="$1"
    local len
    len=$(jq 'length' "$file" 2>/dev/null) || return
    if [ "$len" -gt "$AI_SESSION_MAX_MSGS" ]; then
        jq --argjson max "$AI_SESSION_MAX_MSGS" \
            '[.[0]] + (.[1:] | .[-($max-1):])' "$file" > "$file.tmp.$$" && command mv -f "$file.tmp.$$" "$file"
    fi
}
