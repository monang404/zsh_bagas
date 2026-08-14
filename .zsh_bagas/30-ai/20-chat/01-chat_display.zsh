# ============================================================
#  30-ai/20-chat/01-chat_display.zsh — reasoning di luar, jawaban
#  bersih di dalam box. Dipakai aic/aicl (freeform chat, BUKAN
#  kontrak JSON agent {thought,tool,args,done} yang punya jalur
#  tampil sendiri di 50-agent/20-presentation/15-reasoning_display.zsh).
# ============================================================

# _ai_chat_split_reply(raw) -- pisahin raw jadi thought vs jawaban.
# Kontrak baru (lihat AI_PERSONA_CHAT_* di 00-config/25-persona.zsh):
# model taruh reasoning SEBELUM marker literal '@@JAWABAN@@', jawaban
# bersih SESUDAHNYA. Kalau model gak nurut (sering di model kecil/
# gratis), fallback ke pola lama yang udah ketemu di produksi --
# jawaban dulu, baru heading "**Thought**" nempel abis itu (urutan
# kebalik dari marker baru). Kalau dua-duanya gak ketemu, semua raw
# diperlakukan sebagai jawaban apa adanya -- jawaban user TIDAK PERNAH
# ke-drop cuma karena parsing gagal.
# Hasil: $_AI_CHAT_THOUGHT / $_AI_CHAT_ANSWER (dynamic-scoped ke caller,
# caller declare local-nya sendiri -- pola sama kayak 42-execution/*.zsh).
_ai_chat_split_reply() {
    setopt localoptions noxtrace
    local raw="$1"
    local marker='@@JAWABAN@@'
    local thought="" answer="$raw"

    if [[ "$raw" == *"$marker"* ]]; then
        thought="${raw%%$marker*}"
        answer="${raw#*$marker}"
    elif [[ "$raw" == *'**Thought**'* ]]; then
        answer="${raw%%\*\*Thought\*\**}"
        thought="${raw#*\*\*Thought\*\*}"
    fi

    thought="${thought## }"; thought="${thought%% }"
    answer="${answer## }"; answer="${answer%% }"
    [ -z "$answer" ] && answer="$raw"

    _AI_CHAT_THOUGHT="$thought"
    _AI_CHAT_ANSWER="$answer"
}

# _ai_chat_render(raw) -- reasoning (kalau ada) dicetak POLOS di luar
# lewat ◌ (mesin ringkas yang sama kayak agent mode, biar konsisten:
# max 3 poin, wrap 76 char), jawaban bersih dicetak DI DALAM box.
_ai_chat_render() {
    setopt localoptions noxtrace
    local raw="$1"
    [ -z "$raw" ] && return 1

    local _AI_CHAT_THOUGHT _AI_CHAT_ANSWER
    _ai_chat_split_reply "$raw"

    if [ -n "$_AI_CHAT_THOUGHT" ]; then
        local disp
        if disp=$(_ai_agent_reasoning_display "$_AI_CHAT_THOUGHT"); then
            _ai_ui_line "◌" "$disp"
            echo ""
        fi
    fi

    local -a alines
    alines=(${(f)_AI_CHAT_ANSWER})
    _ai_ui_box "" "${alines[@]}"
}
