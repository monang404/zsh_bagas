# ============================================================
#  30-ai/00-config/35-providers.zsh — AI_PROVIDERS endpoint/model/key-var map + legacy AI_PROVIDER_ORDER
#  (split out of the old monolithic 30-ai/00-config.zsh)
# ============================================================

# ─── Provider config (baru di v3) ─────────────────────────────
# Tiap provider = endpoint OpenAI-compatible + model + nama env var API key.
# Kalau env var key-nya kosong/gak di-set, provider itu otomatis di-skip
# (gak perlu comment-out apa pun buat nonaktifin provider yang gak dipakai).
typeset -gA AI_PROVIDERS=(
    groq_endpoint       "https://api.groq.com/openai/v1/chat/completions"
    groq_model          "$GROQ_MODEL"
    groq_key_var        "GROQ_API_KEY"

    gemini_endpoint     "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions"
    gemini_model        "${GEMINI_MODEL:-gemini-flash-latest}"
    gemini_key_var      "GEMINI_API_KEY"

    cerebras_endpoint   "https://api.cerebras.ai/v1/chat/completions"
    cerebras_model      "${CEREBRAS_MODEL:-gpt-oss-120b}"
    cerebras_key_var    "CEREBRAS_API_KEY"

    deepseek_endpoint   "https://api.deepseek.com/chat/completions"
    deepseek_model      "${DEEPSEEK_MODEL:-deepseek-v4-flash}"
    deepseek_key_var    "DEEPSEEK_API_KEY"

)
# urutan prioritas fallback lama (dipakai fungsi yang belum diarahin ke
# kelas fast/smart tertentu). Yang baru pakai AI_TASK_PROVIDER_ORDER +
# AI_MODELS di atas, yang dukung banyak model per provider.
# (openrouter dicabut juga dari sini -- sama alasannya kayak
# AI_TASK_PROVIDER_ORDER di atas, entry-nya belum ada di AI_PROVIDERS.)
AI_PROVIDER_ORDER=(groq gemini cerebras)

# guard biar function AI gak gagal senyap kalau API key lupa di-set

