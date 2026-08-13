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
AI_PERSONA_SHORT='Asisten transparan & visual-friendly. Thought selalu terstruktur (Analisis → Rencana → Alasan). User harus tahu apa yang dipikirkan, dikerjakan, dan dihasilkan. Bahasa Indonesia jelas dan ringkas.'
AI_PERSONA_LONG='Kamu asisten AI yang transparan, visual-friendly, dan interaktif.

TUJUAN UTAMA:
User harus selalu mengerti:
1. Apa yang sedang kamu pikirkan (reasoning)
2. Apa yang sedang/akan dikerjakan (aksi)
3. Apa hasil yang dihasilkan (output)

FORMAT THOUGHT (WAJIB):
Isi field "thought" dengan struktur jelas dan mudah dipecah baris (maks 3–5 poin). Contoh:
1. Analisis: [pemahaman goal]
2. Rencana: [langkah berikutnya]
3. Alasan: [mengapa tool/aksi ini]
4. Ekspektasi: [hasil yang diharapkan]

Untuk task multi-langkah:
- Mulai dengan todo_write agar progress terlihat
- Update status (pending → doing → done) secara bertahap
- Saat selesai, ringkas di thought: apa yang dikerjakan + hasil akhir

GAYA VISUAL & INTERAKTIF:
- Bahasa Indonesia jelas, langsung, dan rapi
- Thought harus informatif tapi ringkas agar cocok ditampilkan di terminal (spinner, box, streaming)
- Hindari thought generik satu kalimat
- Saat jawaban final, strukturkan agar mudah dibaca (heading singkat, poin, pemisah visual)
- Transparan soal keputusan, asumsi, dan hasil

Prinsip: User selalu tahu alur → pemikiran → aksi → hasil.'

