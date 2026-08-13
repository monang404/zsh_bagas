# ============================================================
#  30-ai/10-core/05-wakelock.zsh — termux wakelock helpers
#  (split out of the old monolithic 30-ai/10-core.zsh)
# ============================================================

# v-fix (bug #54 audit): aiagent/aiproject bisa jalan berapa menit
# (banyak call AI berturut-turut) tanpa sekalipun pasang wake-lock --
# begitu layar mati, Android bisa doze/throttle proses Termux di
# tengah operasi. Acquire di awal operasi berat, release begitu selesai
# (dipanggil lewat blok `always {}` biar tetap ke-release walau loop
# berhenti gara-gara error/return awal). Silent no-op kalau termux-api
# gak ke-install, biar tetep jalan di device tanpa termux-api.
_ai_wakelock_acquire() {
    command -v termux-wake-lock >/dev/null 2>&1 && termux-wake-lock
}

_ai_wakelock_release() {
    command -v termux-wake-unlock >/dev/null 2>&1 && termux-wake-unlock
}
