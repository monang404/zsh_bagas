# ============================================================
#  30-ai/00-config/05-provider_order.zsh — task-class provider order (FAST/SMART/BIG/AGENT) + default alias
#  (split out of the old monolithic 30-ai/00-config.zsh)
# ============================================================

# ─── Provider order per kelas tugas ───────────────────────────────────
# FAST (ringan): chat biasa, shell helper, commit msg, summarize —
# Groq & Gemini paling cepet untuk single-turn pendek, deepseek/cerebras
# jadi fallback kalau groq/gemini lagi throttle.
AI_TASK_PROVIDER_ORDER_FAST=(groq gemini cerebras deepseek)

# SMART (sedang): aiplan, aireview, aiask, aifix, ai session —
# Cerebras paling cocok: limit-nya jauh lebih lega dari Groq, model
# gpt-oss-120b-nya juga kompetitif. DeepSeek jadi primary karena
# kualitasnya top untuk reasoning.
AI_TASK_PROVIDER_ORDER_SMART=(deepseek cerebras gemini groq)

# BIG (berat): aiproject, aibuild, aiscrap — butuh completion panjang.
# DeepSeek paling oke untuk coding besar; Cerebras jadi fallback cepet.
AI_TASK_PROVIDER_ORDER_BIG=(deepseek cerebras gemini groq)

# AGENT (aiagent ReAct loop): DeepSeek & Cerebras untuk JSON-mode tool
# call yang cepat dan akurat. Groq sebagai fallback.
AI_TASK_PROVIDER_ORDER_AGENT=(deepseek cerebras groq gemini)

# Alias default (backward compat): fast/smart dipakai oleh kode lama
# yang belum spesifik pilih order sendiri.
AI_TASK_PROVIDER_ORDER=("${AI_TASK_PROVIDER_ORDER_SMART[@]}")
