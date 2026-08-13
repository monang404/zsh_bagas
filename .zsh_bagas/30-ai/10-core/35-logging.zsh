# ============================================================
#  30-ai/10-core/35-logging.zsh — chat/usage logging
#  (split out of the old monolithic 30-ai/10-core.zsh)
# ============================================================

# v-fix: rotasi sederhana — file JSONL yang dibaca ulang SELURUHNYA tiap
# kali oleh `aih`/`aistats` (jq -s) makin lambat & makin berat kalau
# gak pernah dipangkas. Dipanggil abis nulis; kalau file udah lewat
# AI_LOG_MAX_LINES baris, potong ke N baris terakhir aja. Baris lama
# gak diarsip (log ini cuma buat riwayat cepat, bukan audit trail
# permanen) — kalau butuh histori penuh, backup manual filenya sendiri.
_ai_rotate_log() {
    local file="$1" max_lines="${2:-5000}"
    [ -f "$file" ] || return 0
    local n
    n=$(wc -l < "$file" 2>/dev/null) || return 0
    if [ "$n" -gt "$max_lines" ]; then
        tail -n "$max_lines" "$file" > "$file.tmp.$$" 2>/dev/null && command mv -f "$file.tmp.$$" "$file"
    fi
}

# log sekarang JSONL: satu baris = satu event, gampang di-query jq
_ai_log() {
    _ai_secure_runtime_dir "$AI_LOG_DIR"
    local kind="$1" prompt="$2" response="$3"
    # truncate prompt JUGA (bukan cuma response) — prompt panjang (mis.
    # isi file dari `aiask`) bisa bikin satu baris JSONL raksasa, yang
    # memperlambat jq -s dipakai aih/aistats baca seluruh file.
    jq -nc --arg t "$(date '+%Y-%m-%d %H:%M:%S')" --arg k "$kind" \
        --arg p "${prompt:0:1000}" --arg r "${response:0:1000}" \
        '{time:$t, kind:$k, prompt:$p, response:$r}' >> "$AI_HISTORY_LOG" 2>/dev/null
    _ai_rotate_log "$AI_HISTORY_LOG" "${AI_LOG_MAX_LINES:-5000}"
}

# log token usage per-call (dipisah dari history biar gampang di-agregasi)
_ai_log_usage() {
    _ai_secure_runtime_dir "$AI_LOG_DIR"
    local provider="$1" resp="$2"
    printf '%s' "$resp" | jq -c --arg t "$(date '+%Y-%m-%d %H:%M:%S')" --arg prov "$provider" \
        '{time:$t, provider:$prov, usage:(.usage // {})}' >> "$AI_USAGE_LOG" 2>/dev/null
    _ai_rotate_log "$AI_USAGE_LOG" "${AI_LOG_MAX_LINES:-5000}"
}
