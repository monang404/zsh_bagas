# ============================================================
#  30-ai/00-config/00-models.zsh — model list per provider (AI_MODELS) + GROQ_MODEL/GROQ_REASONING_EFFORT
#  (split out of the old monolithic 30-ai/00-config.zsh)
# ============================================================

# ─── Config dasar ─────────────────────────────────────────────
GROQ_MODEL="openai/gpt-oss-120b"
# openai/gpt-oss-* itu model REASONING: dia "mikir" dulu (chain-of-thought)
# sebelum nulis jawaban akhir, dan itu makan jatah token tersendiri dari
# max_tokens yang sama kayak jawaban akhirnya. Kalau effort-nya "medium"/
# "high" + prompt-nya panjang/kompleks (kayak ai plan / ai prompt), reasoning-
# nya bisa makan HABIS max_tokens sebelum sempat nulis jawaban -> content
# jadi kosong, keliatan kayak "gak ada respons" walau API-nya sehat. "low"
# bikin dia gak kebanyakan mikir jadi jatah buat jawaban beneran lebih
# kebagian — TANPA perlu naikin max_tokens (banyak akun Groq, apalagi tier
# gratis, punya limit TPM/menit yang ketat; max_tokens gede malah gampang
# nabrak limit itu duluan sebelum request-nya sempat diproses, ini keliatan
# sebagai HTTP 413 "Request too large"). Ganti ke "medium"/"high" di sini
# kalau suatu saat butuh reasoning lebih dalam buat task lain.
GROQ_REASONING_EFFORT="low"

# ─── v4: pembagian tugas + fallback multi-model per provider ─
# Tiap task punya "kelas": FAST (butuh cepat, gak butuh mikir dalam —
# chat singkat, shell helper, commit message, clipboard) atau SMART
# (butuh kualitas/reasoning lebih — code gen, plan, prompt, review,
# summarize, agent). Tiap kelas punya DAFTAR model per provider, dicoba
# urut dari kiri ke kanan; kalau satu model gagal/kena limit, otomatis
# lanjut ke model berikutnya SEBELUM pindah provider. Ini beda dari v3
# yang cuma punya 1 model per provider.
#
# Daftar model di bawah hasil audit manual (lihat riwayat test_model
# loop) per 2026-08: model yang konsisten 429 (quota abis di tier
# gratis: gemini-2.5-pro, gemini-2.0-*, gemini-pro-latest, gemini-3-pro-
# preview, gemini-3.1-pro-preview), 404 (gemini-2.5-flash-lite, udah
# discontinue), atau formatnya rusak buat parser kita (groq/compound
# balikin objek "stub" non-standar, model gemma-* nulis reasoning-nya
# di dalam field "content" pakai tag <thought>...</thought> yang bikin
# jawaban akhir ketutupan) SENGAJA gak dimasukin. Kalau nanti dites
# ulang dan statusnya berubah, tinggal tambahin ke list di bawah.
typeset -gA AI_MODELS=(
    groq_fast    "llama-3.1-8b-instant llama-3.3-70b-versatile"
    groq_smart   "openai/gpt-oss-120b openai/gpt-oss-20b llama-3.3-70b-versatile llama-3.1-8b-instant"
    gemini_fast  "gemini-flash-latest gemini-3.5-flash-lite gemini-flash-lite-latest gemini-3-flash-preview"
    gemini_smart "gemini-3.5-flash gemini-flash-latest gemini-3-flash-preview gemini-3.1-flash-lite-preview"
    cerebras_fast  "gpt-oss-120b gemma-4-31b zai-glm-4.7"
    cerebras_smart "gpt-oss-120b zai-glm-4.7 gemma-4-31b"
    deepseek_fast  "deepseek-v4-flash"
    deepseek_smart "deepseek-v4-flash deepseek-v4-pro"
)
