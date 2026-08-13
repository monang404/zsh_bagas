# ============================================================
#  30-ai/00-config/25-persona.zsh — UI ascii-fallback toggle + persona short/long
#  (split out of the old monolithic 30-ai/00-config.zsh)
# ============================================================

# Task 1.1 (fase1_ui_ux_overhaul): override manual buat matiin box-drawing
# unicode (╭╰│─→✓◌ dst) dan pakai ASCII biasa (+-|) sebagai gantinya.
# Dibiarkan ": ${VAR:=...}" (bukan "="), biar kalau user udah nge-export
# AI_UI_ASCII_FALLABCK sendiri sebelum .zshrc ke-source (mis. di
# .zshrc lokal / 90-local/local.zsh), nilai itu gak ketimpa balik ke
# default -- konsisten sama pola AI_CIRCUIT_BREAKER_FILE di atas.
# 0 = coba unicode (default), 1 = paksa ASCII fallback. Deteksi
# otomatis (locale non-UTF-8) tetap dilakukan runtime di 60-ui.zsh,
# ini cuma override manual buat kasus locale ngaku UTF-8 tapi font
# terminal-nya sebenarnya gak render box-drawing dengan benar.
: ${AI_UI_ASCII_FALLBACK:=0}

# v-fix (bug #41 & #50 audit): persona ini dikirim ULANG PENUH di SETIAP
# panggilan aic/aicl/aiask/aiclip/dst -- beda sama skills (70-skills.zsh)
# yang udah load-on-demand per keyword. Prompt-caching sisi-provider itu
# spesifik per API (belum diverifikasi konsisten dukung di endpoint
# OpenAI-compatible Groq/Gemini/Cerebras/DeepSeek yang dipakai di sini,
# jadi TIDAK diaktifkan tanpa verifikasi lebih lanjut per provider --
# ngasal nyalain field yang gak didukung bisa balikin 400 kayak
# reasoning_effort di bug #5). Sesuai fallback yang disaranin audit kalau
# caching gak bisa dipastikan aman: teks persona dipadatkan (makna sama,
# kata lebih sedikit) buat langsung motong biaya token per call, TANPA
# ubah instruksi/perilaku yang diminta.
AI_PERSONA_SHORT="Kamu asisten santai, jujur, cerdas. Bahasa Indonesia gaul, langsung ke inti, tanpa basa-basi/validasi/pujian, objektif apa adanya. Maks 3 kalimat."
AI_PERSONA_LONG="Kamu asisten santai, jujur, cerdas. Bahasa Indonesia gaul, langsung ke inti, tanpa basa-basi/validasi/pujian, objektif apa adanya. Jawaban lengkap, penomoran biasa, tanpa markdown."

