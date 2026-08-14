# ============================================================
#  30-ai/20-chat/00-quick_chat.zsh — aic/aicl/aish — chat cepat/panjang & shell-helper (streaming via _ai_quick)
#  (split out of the old monolithic 30-ai/20-chat.zsh)
# ============================================================

# ============================================================
#  30-ai/20-chat.zsh — chat cepat/panjang & sesi multi-turn
#  aic, aicl, aish, aiask, aiclip, session (_ai_session*).
# ============================================================


# NOTE v4 + Task 8.2: aic/aish sekarang lewat _ai_quick dalam mode
# streaming. _ai_quick tetap jadi pembungkus request bersama, tetapi mode
# stream memanggil _ai_chat_request_stream secara langsung dan memakai tee
# untuk menangkap full response setelah token tetap mengalir ke terminal.
# aicl/aiask dan caller lain tetap memakai jalur blocking.
# v-fix (real bug): aic/aicl dulu streaming raw ke terminal pakai
# AI_PERSONA_SHORT/LONG (persona agent, kontrak JSON {thought,...}) --
# hasilnya reasoning model ("**Thought**...") nempel jadi satu blok sama
# jawaban tanpa pemisah apapun pas di-stream mentah. Sekarang pindah ke
# blocking (_ai_quick stream=0 -- tetap ada spinner dari jalur blocking
# di 10-core/50-request_blocking.zsh, jadi feedback nunggu gak hilang),
# pakai persona chat khusus yang minta model pisahin lewat marker
# '@@JAWABAN@@', lalu _ai_chat_render motong: reasoning polos di luar,
# jawaban bersih di dalam box. _ai_quick jalur blocking gak nge-log
# sendiri (beda dari jalur stream-nya) makanya _ai_log dipanggil manual
# di sini biar histori 'chat'/'chat-long' gak regresi kehilangan entry.
aic() {
    # Keep this call tree free of inherited xtrace, same as aicl/aish.
    setopt localoptions noxtrace
    _ai_need_any_key || return 1
    local reply rc
    reply=$(_ai_quick "$AI_PERSONA_CHAT_SHORT" "$*" fast "${AI_TASK_PROVIDER_ORDER_FAST[*]}" "" 0)
    rc=$?
    [ -n "$reply" ] && _ai_chat_render "$reply"
    _ai_log "chat" "$*" "$reply"
    return $rc
}

aicl() {
    # Keep the entire public long-chat call tree free of inherited xtrace.
    # localoptions restores the caller's original shell option on return.
    setopt localoptions noxtrace
    _ai_need_any_key || return 1
    local reply rc
    reply=$(AI_CURL_TIMEOUT=15 _ai_quick "$AI_PERSONA_CHAT_LONG" "$*" fast "${AI_TASK_PROVIDER_ORDER_FAST[*]}" "" 0)
    rc=$?
    [ -n "$reply" ] && _ai_chat_render "$reply"
    _ai_log "chat-long" "$*" "$reply"
    return $rc
}

aish() {
    setopt localoptions noxtrace
    _ai_need_any_key || return 1
    _ai_quick "Kamu expert Linux dan Termux. Berikan perintah shell yang tepat, aman, dan langsung bisa dijalankan di Termux Android." "$*" fast "${AI_TASK_PROVIDER_ORDER_FAST[*]}" "" 1 "shell"
}

