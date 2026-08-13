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
aic() {
    # Keep this call tree free of inherited xtrace, same as aicl/aish.
    setopt localoptions noxtrace
    _ai_need_any_key || return 1
    _ai_quick "$AI_PERSONA_SHORT" "$*" fast "${AI_TASK_PROVIDER_ORDER_FAST[*]}" "" 1 "chat"
}

aicl() {
    # Keep the entire public long-chat call tree free of inherited xtrace.
    # localoptions restores the caller's original shell option on return.
    setopt localoptions noxtrace
    _ai_need_any_key || return 1
    AI_CURL_TIMEOUT=15 AI_SPINNER_ENABLE=0 _ai_quick "$AI_PERSONA_LONG" "$*" fast "${AI_TASK_PROVIDER_ORDER_FAST[*]}" "" 1 "chat-long"
}

aish() {
    setopt localoptions noxtrace
    _ai_need_any_key || return 1
    _ai_quick "Kamu expert Linux dan Termux. Berikan perintah shell yang tepat, aman, dan langsung bisa dijalankan di Termux Android." "$*" fast "${AI_TASK_PROVIDER_ORDER_FAST[*]}" "" 1 "shell"
}

