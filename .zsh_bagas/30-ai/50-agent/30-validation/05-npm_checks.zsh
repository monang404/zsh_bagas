# ============================================================
#  30-ai/30-validation/05-npm_checks.zsh — _ai_agent_maybe_run_npm_checks — npm test/lint opsional di akhir sesi (informational only)
#  (split out of the old monolithic 30-ai/50-agent/30-validation.zsh)
# ============================================================

# Task 2.4: npm test/lint OPSIONAL di akhir sesi -- BEDA dari
# _ai_verify_touched_files() di atas (yang WAJIB & blocking per file
# tiap kali agent mau declare done). Fungsi ini:
#   - cuma dipanggil SEKALI, di akhir sesi (setelah loop ReAct selesai
#     & done:true diterima), BUKAN tiap edit_file individual.
#   - HANYA jalan kalau SEMUA syarat berikut kepenuhi: (1) sesi ini
#     nyentuh minimal satu file .js/.ts, (2) toggle
#     AI_AGENT_AUTO_NPM_CHECK=1 nyala (DEFAULT OFF, lihat 00-config.zsh
#     -- npm test/lint bisa lambat/berat di Termux, jangan dipaksa
#     nyala tanpa user aktifin manual, ini "tawaran" bukan otomatis
#     paksa), (3) package.json ada di cwd (project emang JS/TS),
#     (4) project ini udah pernah di-scan _ai_project_context (file
#     summary-nya ada di $AI_PROJECT_DIR), (5) package.json punya
#     script "test" dan/atau "lint" yang bukan placeholder kosong.
#   - HASILNYA INFORMATIONAL DOANG -- ditambahin ke box ringkasan
#     akhir, TAPI TIDAK nge-block done:true walau npm test/lint-nya
#     gagal (beda dari node --check yang wajib & blocking).
#   - GAK PERNAH manggil npm install/npm update di sini.
# Args: daftar path file (hasil ${(k)touched_files[@]} dari caller).
# Output: teks hasil run (kosong kalau gak ada syarat yang kepenuhi/gak
# relevan). Exit 1 kalau gak jalan sama sekali (biar caller gampang
# nge-skip nambahin baris kosong ke box).
_ai_agent_maybe_run_npm_checks() {
    local -a touched=("$@")
    local has_js=0 t
    for t in "${touched[@]}"; do
        case "$t" in
            *.js|*.ts) has_js=1; break ;;
        esac
    done
    [ "$has_js" -eq 0 ] && return 1
    [ "${AI_AGENT_AUTO_NPM_CHECK:-0}" = "1" ] || return 1
    [ -f "package.json" ] || return 1
    command -v jq >/dev/null 2>&1 || return 1

    # syarat "project udah pernah di-scan _ai_project_context": cek
    # summary file-nya ADA (bukan manggil ulang aiscan/_ai_project_context
    # -- itu tanggung jawab pemanggil lain, di sini cuma verifikasi
    # syaratnya kepenuhi apa enggak, sesuai task spec "project udah
    # pernah di-scan").
    local ctx_file="$AI_PROJECT_DIR/$(_ai_project_slug).md"
    [ -f "$ctx_file" ] || return 1

    local test_cmd lint_cmd
    test_cmd=$(jq -r '.scripts.test // ""' package.json 2>/dev/null)
    lint_cmd=$(jq -r '.scripts.lint // ""' package.json 2>/dev/null)
    # v-fix pola sama kayak aiscan (45-project.zsh bug #24): placeholder
    # default `npm init` ("Error: no test specified") BUKAN test beneran.
    [[ "$test_cmd" == *"no test specified"* ]] && test_cmd=""
    [ -z "$test_cmd" ] && [ -z "$lint_cmd" ] && return 1

    local out=""
    if [ -n "$test_cmd" ]; then
        out="$out
  \$ npm test
$(npm test 2>&1 | head -c 2000)"
    fi
    if [ -n "$lint_cmd" ]; then
        out="$out
  \$ npm run lint
$(npm run lint 2>&1 | head -c 2000)"
    fi
    printf '%s' "$out"
}

