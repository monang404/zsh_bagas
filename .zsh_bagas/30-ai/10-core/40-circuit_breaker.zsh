# ============================================================
#  30-ai/10-core/40-circuit_breaker.zsh — provider circuit breaker + diagnostics
#  (split out of the old monolithic 30-ai/10-core.zsh)
# ============================================================

# v-fix (bug #49 audit): tiap fungsi (aiplan, aispec, dst) punya retry
# sendiri-sendiri via _ai_chat_request, tapi kalau user manggil beberapa
# fungsi beruntun dan semuanya kena rate-limit di provider yang sama,
# tiap panggilan baru ngulang SELURUH siklus retry dari nol ke provider
# yang JELAS-JELAS baru aja gagal total. Breaker kecil ini nyimpen kapan
# terakhir kali sebuah provider gagal total (semua model-nya abis
# dicoba), dipakai buat skip provider itu SEMENTARA (AI_CIRCUIT_BREAKER_
# WINDOW detik) di panggilan berikutnya -- KECUALI provider itu satu-
# satunya sisa kandidat yang key-nya ke-set (mending coba daripada
# dipastikan gagal total tanpa nyoba apa-apa).
_ai_breaker_record_fail() {
    local provider="$1"
    mkdir -p "${AI_CIRCUIT_BREAKER_FILE:h}" 2>/dev/null
    { [ -f "$AI_CIRCUIT_BREAKER_FILE" ] && grep -v "^$provider " "$AI_CIRCUIT_BREAKER_FILE" 2>/dev/null; echo "$provider $(date +%s)"; } > "$AI_CIRCUIT_BREAKER_FILE.tmp.$$" 2>/dev/null \
        && command mv -f "$AI_CIRCUIT_BREAKER_FILE.tmp.$$" "$AI_CIRCUIT_BREAKER_FILE" 2>/dev/null
}

_ai_breaker_is_open() {
    local provider="$1"
    [ -f "$AI_CIRCUIT_BREAKER_FILE" ] || return 1
    local last
    last=$(grep "^$provider " "$AI_CIRCUIT_BREAKER_FILE" 2>/dev/null | tail -1 | awk '{print $2}')
    [ -z "$last" ] && return 1
    local now=$(date +%s)
    (( now - last < ${AI_CIRCUIT_BREAKER_WINDOW:-30} ))
}

# ─── Core: request AI dengan retry + fallback MULTI-MODEL x MULTI-PROVIDER ─
# v4: dua lapis fallback sekarang.
#   Lapis 1 (dalam 1 provider): coba tiap model di AI_MODELS[<provider>_<class>]
#   urut dari kiri, masing-masing dapet jatah AI_MAX_RETRIES x retry. Kalau
#   sebuah model gagal karena memang gak available (404) atau quota abis
#   (429) di percobaan PERTAMA, langsung skip ke model berikutnya tanpa
#   buang sisa retry-nya (429/404 bukan error transient, ngulang persis
#   sama pasti gagal lagi juga).
#   Lapis 2 (antar provider): kalau SEMUA model di satu provider abis
#   dicoba dan tetep gagal, baru pindah ke provider berikutnya di
#   AI_TASK_PROVIDER_ORDER (asal key-nya ke-set).
# Task class ("fast"/"smart", param ke-3) nentuin daftar model mana yang
# dipakai — ini bagian "pembagian tugas": task ringan (chat cepat, shell
# helper, commit message) lewat kelas "fast" (model kecil, latensi
# rendah), task berat (code gen, plan, review, agent) lewat kelas "smart"
# (model reasoning/lebih besar duluan). Default "smart" kalau gak dikasih.
# Dipakai internal buat semua call yang butuh reliability. Terima: (1)
# file JSON array of messages format OpenAI chat, (2) mode ("json" utk
# agent, kosong buat teks biasa), (3) task class ("fast"/"smart").
_ai_chat_diag() {
    # Keep interactive chat clean; set AI_VERBOSE=1 when low-level diagnostics are needed.
    [ "${AI_VERBOSE:-0}" = "1" ] || return 0
    printf '%s\\n' "$*" >&2
}

_ai_model_label() {
    local model="$1"
    case "${model:l}" in
        *llama*) print -r -- "llama" ;;
        *gpt-oss*) print -r -- "gpt-oss" ;;
        *gemini*) print -r -- "gemini" ;;
        *qwen*) print -r -- "qwen" ;;
        *deepseek*) print -r -- "deepseek" ;;
        *glm*) print -r -- "glm" ;;
        *) print -r -- "$model" ;;
    esac
}
