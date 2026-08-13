# ============================================================
#  30-ai/30-code/10-project_generate.zsh — aiproject's generate-with-retry step
#  (split out of the old monolithic 30-ai/30-code.zsh)
# ============================================================

# v5.2: dulu SEKALI generate, langsung "salvage jadi satu file" begitu
# marker '### FILE:' gak ketemu sama sekali -- padahal ini paling sering
# kejadian karena model (apalagi model fallback yang kurang nurut
# instruksi format) nulis kode beneran tapi ngabaiin format yang
# diminta, BUKAN karena kontennya emang gagal total. Salvage jadi 1
# file nyelametin isinya biar gak kebuang, TAPI kalau app-nya emang
# dirancang multi-file (mis. main.py yang `from utils import ...`),
# hasil salvage-nya SETENGAH JADI: aifix cuma nge-patch symptom-nya
# (ModuleNotFoundError) dengan buang importnya, bukan bikin app-nya
# lengkap -- hasil akhirnya "jalan tanpa traceback" tapi fitur yang
# diminta ada yang ilang diam-diam. Sekarang retry generate dulu
# (dengan reminder format yang lebih tegas) SEBELUM nyerah ke salvage,
# jadi salvage cuma jadi jalan terakhir beneran, bukan default kalau
# provider pertama kebetulan kurang patuh.
#
# Reads $prompt/$logfile (caller locals, dynamic scope) and writes back
# $has_markers/$generation_ok. Reuses the caller's $gen_max_tries (set
# by the caller before calling this) rather than declaring its own, so
# a later salvage message can still reference how many tries happened.
_ai_project_generate() {
    local gen_sysprompt="Kamu programmer expert. Buat project multi-file sesuai request. WAJIB format tiap file dengan penanda persis: ### FILE: nama_file.ext lalu isi kode di baris berikutnya, tanpa markdown/backtick. Pisahkan tiap file dengan penanda itu. WAJIB tulis SEMUA file yang direferensikan lewat import di project ini, jangan skip satupun. WAJIB pakai baris baru SUNGGUHAN buat pisah tiap statement/baris kode di semua file — JANGAN PERNAH menulis dua karakter literal backslash+n sebagai pengganti baris baru di luar string; backslash+n cuma boleh muncul kalau memang bagian dari isi string. KALAU request yang dikasih SUDAH berupa spec terstruktur (ada header [APLIKASI]/[FILES]/[ALUR]/dst, biasanya hasil dari 'ai spec'), WAJIB ikuti persis: nama file di [FILES] harus jadi nama file beneran (jangan diganti/disingkat/digabung), tanggung jawab tiap file harus sesuai deskripsinya, dan import antar file harus konsisten sama yang disebut di situ. Kalau ada [CONTOH_INPUT], pastikan urutan & jumlah input() di main.py sesuai urutan itu. Kalau project-nya butuh banyak file/kode panjang, WAJIB prioritaskan nulis SEMUA file secara lengkap dulu (jangan berhenti di tengah salah satu file) — mending tiap file agak ringkas/simpel daripada ada file yang kepotong atau sama sekali gak sempat ditulis."

    local gen_tries=0
    has_markers=0
    generation_ok=0
    echo "Generating project..."
    while [ $gen_tries -lt $gen_max_tries ]; do
        gen_tries=$((gen_tries + 1))
        local this_prompt="$prompt"
        if [ $gen_tries -gt 1 ]; then
            echo "[info] percobaan sebelumnya gak nulis format '### FILE:', ulang dengan reminder lebih tegas ($gen_tries/$gen_max_tries)..." >&2
            this_prompt="$prompt

INGAT: jawaban HARUS dimulai dari baris '### FILE: <nama_file>' -- jangan tulis penjelasan/narasi apapun sebelum penanda itu, dan jangan ada satupun file yang ditulis tanpa penanda itu di depannya."
        fi
        _ai_quick "$gen_sysprompt" "$this_prompt" smart "${AI_TASK_PROVIDER_ORDER_BIG[*]}" "${AI_PROJECT_MAX_TOKS:-3500}" > "$logfile"
        local gen_rc=$?
        if [ $gen_rc -ne 0 ]; then
            echo "[error] provider generation gagal (exit $gen_rc), tidak akan menyimpan error response sebagai source code." >&2
            continue
        fi
        generation_ok=1

        if [ -f "$AI_SANITIZE_SCRIPT" ]; then
            python3 "$AI_SANITIZE_SCRIPT" --normalize-markers "$logfile" 2>&1 | grep -v '^$' >&2
        fi

        if grep -q '^### FILE: ' "$logfile"; then
            has_markers=1
            break
        fi
    done
}
