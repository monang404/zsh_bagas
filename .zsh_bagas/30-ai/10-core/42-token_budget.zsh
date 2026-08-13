# ============================================================
#  30-ai/10-core/42-token_budget.zsh — max_tokens/temperature/reasoning
#  model selection (shared by blocking + streaming request layers)
# ============================================================

# NOTE: default max_tokens 4000 buat task ringan (chat/fix/shell) —
# beberapa akun Groq (terutama tier gratis/on-demand) punya limit TPM
# (token per menit) yang ketat, kadang cuma 8000. Kalau max_tokens dipepet
# ke situ, prompt + max_tokens gampang kelewat limit dan API balikin
# HTTP 413 "Request too large". v5: task yang emang butuh output gede
# (generate project multi-file) bisa OVERRIDE ini lewat param ke-5
# _ai_chat_request/_ai_quick — kalau providernya masih kena 413 walau
# udah dinaikin, retry decision di bawah bakal otomatis nurunin lagi per
# provider, jadi override ini aman dicoba. Override cuma dipakai penuh
# buat model PERTAMA di tiap kelas (biasanya model "besar" yang emang
# butuh budget token gede, mis. aiproject override 9000). Model fallback
# berikutnya di list yang sama balik ke default 4000 kecuali override-nya
# sendiri lebih kecil dari itu — jangan paksa model fallback yang kecil
# ikut coba budget token segede model utamanya, itu cuma buang waktu
# (lebih gampang kena 413) sebelum akhirnya diturunin.
_ai_resolve_max_toks() {
    local model_idx="$1" max_toks_override="$2"
    if [ "$model_idx" -eq 1 ] || [ -z "$max_toks_override" ]; then
        echo "${max_toks_override:-4000}"
    else
        echo $(( max_toks_override < 4000 ? max_toks_override : 4000 ))
    fi
}

# temperature lebih rendah buat mode "json" biar keluaran lebih konsisten,
# TANPA response_format — beberapa model/provider (termasuk
# openai/gpt-oss-120b di Groq) suka nolak field itu dengan 400 error, yang
# bikin retry gagal terus padahal API sehat. Keandalan parsing-nya udah
# ditangani di _ai_agent_parse.
_ai_chat_temp_for_mode() {
    [ "$1" = "json" ] && echo 0.4 || echo 0.6
}

# reasoning_effort itu field spesifik Groq -- Cerebras juga punya model
# bernama sama persis "gpt-oss-120b" (lihat cerebras_fast/smart di
# AI_MODELS), jadi cek nama model doang gak cukup, harus ikut cek
# provider-nya biar field ini gak ke-kirim ke endpoint yang gak ngerti
# dan balikin 400.
#
# v-fix (deepseek v4 empty-completion bug): per dokumentasi resmi
# (api-docs.deepseek.com/guides/thinking_mode), deepseek-v4-flash DAN
# deepseek-v4-pro punya thinking mode ENABLED BY DEFAULT dengan default
# effort "high" -- ini beda dari model lama (deepseek-chat/deepseek-
# reasoner) yang gak auto-mikir kalau dipanggil lewat alias non-thinking.
# Kalau reasoning_effort gak dikirim eksplisit, model mikir panjang dulu
# (chain-of-thought masuk reasoning_content) SEBELUM nulis content, dan
# effort "high" gampang ngabisin max_tokens 4000 punya kita duluan
# sebelum sempat nulis jawaban akhir -> content kosong, keliatan kayak
# "provider gagal" padahal HTTP 200 sehat. Makanya deepseek-v4* juga
# harus dianggap "reasoning model" di sini biar dapet reasoning_effort
# eksplisit (default "low", lihat DEEPSEEK_REASONING_EFFORT) alih-alih
# diam-diam jalan di effort "high" bawaan API.
_ai_is_reasoning_model() {
    local provider="$1" model="$2"
    [[ "$provider" == groq* && "$model" == *gpt-oss* ]] && return 0
    [[ "$provider" == deepseek* && "$model" == deepseek-v4-* ]] && return 0
    return 1
}

# Effort value yang dikirim beda per provider (Groq: low/medium/high,
# DeepSeek: low/high/max -- lihat tabel mapping di dokumentasi resmi).
# "low" dipilih sebagai default DeepSeek supaya sisa budget max_tokens
# yang kecil (4000 default, lihat _ai_resolve_max_toks) lebih kebagian
# buat jawaban beneran, bukan abis buat mikir. Naikkan ke "high"/"max" di
# 90-local kalau task-nya emang butuh reasoning dalam dan max_tokens-nya
# udah dinaikin juga.
: ${DEEPSEEK_REASONING_EFFORT:="low"}

_ai_reasoning_effort_for() {
    local provider="$1"
    [[ "$provider" == deepseek* ]] && echo "$DEEPSEEK_REASONING_EFFORT" || echo "$GROQ_REASONING_EFFORT"
}
