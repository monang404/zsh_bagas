# ============================================================
#  30-ai/00-config/20-runtime_guards.zsh — battery, data-saver, daily token, notify-interval, circuit-breaker, agent-step, npm-check guards
#  (split out of the old monolithic 30-ai/00-config.zsh)
# ============================================================

# v-fix (bug #52 audit): ambang baterai (%) buat _ai_battery_check --
# di bawah ini DAN gak lagi charge, aiagent/aiproject (yang bisa makan
# waktu berapa menit karena banyak call AI berturut-turut) minta
# konfirmasi dulu sebelum lanjut, biar Termux gak mati mendadak di
# tengah jalan gara-gara baterai abis.
AI_BATTERY_WARN_PCT=15

# Task 9.2: warning sebelum operasi AI berat saat jaringan kemungkinan
# metered/cellular. 1 = aktif, 0 = nonaktif; fail-open tetap ditangani
# oleh _ai_network_is_metered() di 10-core.zsh.
AI_DATA_SAVER_WARN=1

# v-fix (bug #56 audit): gak ada governor sama sekali sebelum operasi
# berat (aiproject/aibuild) -- user bisa gak sadar udah abisin jatah
# TPM/RPM tier gratis. Di atas ambang token harian ini, minta
# konfirmasi dulu sebelum lanjut generate project baru.
AI_DAILY_TOKEN_WARN=150000

# Task 12.1/12.2: jarak minimum (detik) antar update notifikasi progress
# _ai_notify_progress di loop aiagent -- cegah spam kalau step-nya cepat
# banget berturut-turut. Notifikasi tetap pakai --id tetap (aiagent_progress)
# jadi walau di-skip gara-gara rate-limit, notifikasi terakhir yang berhasil
# terkirim tetap keliatan (bukan hilang), cuma gak ke-update SETIAP step.
AI_NOTIFY_MIN_INTERVAL_SEC=3

# v-fix (bug #49 audit): circuit breaker jangka pendek per-provider --
# lihat _ai_breaker_is_open/_ai_breaker_record_fail di 10-core.zsh buat
# detail kenapa ini perlu (retry-budget lintas panggilan, bukan cuma
# lintas percobaan dalam satu panggilan).
: ${AI_CIRCUIT_BREAKER_FILE:="$AI_LOG_DIR/circuit_breaker.txt"}
AI_CIRCUIT_BREAKER_WINDOW=30   # detik

# v-fix (bug #36 audit): dua konstanta ini dulu didefinisikan di
# 30-ai/50-agent/, padahal README bilang "semua konstanta di satu
# tempat" (file ini). Dipindah ke sini biar konsisten sama prinsip
# yang didokumentasikan sendiri -- 00-config.zsh ke-source lebih dulu
# dari 50-agent/40-runtime.zsh (nomor lebih kecil), jadi urutan loading tetap aman.
AI_AGENT_MAX_STEPS=15
AI_AGENT_MAX_SAME_FAIL=3

# Task 2.4 (fase2_multi_language_verification): toggle buat npm
# test/lint OPSIONAL di akhir sesi aiagent (lihat
# _ai_agent_maybe_run_npm_checks() di 50-agent/). DEFAULT OFF (0)
# SENGAJA -- npm test/lint bisa lambat/berat di Termux (baterai/data),
# jadi ini "tawaran" yang user aktifin sendiri kalau mau, BUKAN
# otomatis nyala buat semua orang. Walau di-set 1, tetap cuma jalan
# kalau SEMUA syarat lain kepenuhi (project JS/TS + package.json +
# script test/lint ada + project udah pernah di-scan) DAN cuma
# INFORMATIONAL (gak nge-block done:true walau gagal) -- beda dari
# node --check (WAJIB, blocking) yang jalan otomatis independen dari
# toggle ini. Set 1 di 90-local/local.zsh kalau mau nyalain.
: ${AI_AGENT_AUTO_NPM_CHECK:=0}

