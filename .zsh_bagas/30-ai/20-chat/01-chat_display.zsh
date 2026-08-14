# ============================================================
#  30-ai/20-chat/01-chat_display.zsh — reasoning di luar, jawaban
#  plain tanpa box (Blueprint v2 §2: "Response tanpa box.").
#  Metadata (⏱ elapsed · provider/model) menjadi satu baris di bawah.
#
#  Dipakai aic/aicl (freeform chat, BUKAN kontrak JSON agent {thought,tool,args,done}
#  yang punya jalur tampil sendiri di 50-agent/).
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

# _ai_chat_render(raw) — reasoning (kalau ada) dicetak POLOS di luar
# lewat ◌ (mesin ringkas yang sama kayak agent mode), jawaban bersih
# dicetak PLAIN tanpa box (Blueprint v2: compact mode).
# Metadata: ⏱ elapsed·s · provider/model dicetak di bawah jawaban.
_ai_chat_render() {
    setopt localoptions noxtrace
    local raw="$1"
    [ -z "$raw" ] && return 1

    local _AI_CHAT_THOUGHT _AI_CHAT_ANSWER
    _ai_chat_split_reply "$raw"

    # Reasoning: cetak sebaris tipis kalau ada
    if [ -n "$_AI_CHAT_THOUGHT" ]; then
        local disp
        if disp=$(_ai_agent_reasoning_display "$_AI_CHAT_THOUGHT" 2>/dev/null); then
            _ai_ui_line "◌" "$disp"
            echo ""
        fi
    fi

    # Jawaban: cetak plain, satu baris per baris
    local line
    while IFS= read -r line; do
        printf '%s\n' "$line"
    done <<< "$_AI_CHAT_ANSWER"

    # Metadata: ⏱ elapsed·s · provider/model (satu baris di bawah)
    local meta=""
    local elapsed="${AI_LAST_ELAPSED:-}"
    local provider="${AI_CURRENT_PROVIDER:-}"
    local model="${AI_CURRENT_MODEL:-}"
    if [ -n "$elapsed" ]; then
        meta="⏱ ${elapsed}s"
    fi
    if [ -n "$provider" ] && [ -n "$model" ]; then
        [ -n "$meta" ] && meta+=" ${AI_C_MUTED:-}·${AI_C_RESET:-} "
        meta+="${provider}/${model}"
    elif [ -n "$model" ]; then
        [ -n "$meta" ] && meta+=" ${AI_C_MUTED:-}·${AI_C_RESET:-} "
        meta+="$model"
    fi
    if [ -n "$meta" ]; then
        echo ""
        printf '%s%s%s\n' "${AI_C_MUTED:-}" "$meta" "${AI_C_RESET:-}"
    fi
}
