# ============================================================
#  30-ai/30-validation/00-verify_touched_files.zsh — _ai_verify_touched_files — dispatcher verifikasi syntax by-extension (py/zsh/sh/json/yaml/js/ts)
#  (split out of the old monolithic 30-ai/50-agent/20-presentation.zsh (leading comment) + 50-agent/30-validation.zsh (body))
# ============================================================

# Task 2.1: dispatcher verifikasi self-check by extension. Loop semua
# file "touched" (berhasil ditulis/diedit, exit 0) sesi ini, branch
# berdasarkan ekstensi:
#   .py       -> py_compile, logic PERSIS SAMA kayak sebelum refactor ini
#                (cuma dipindah ke sini, gak ditulis ulang -- lihat
#                CHANGELOG buat detail asal blok kode ini).
#   .zsh/.sh  -> Task 2.2: zsh -n / bash -n (fallback sh -n), lihat
#                komentar di bawah.
#   .json     -> Task 2.3: jq empty <file>, lihat komentar di bawah.
#   .yaml/.yml -> Task 2.3: python3 + modul yaml (opsional), lihat
#                komentar di bawah.
#   .js       -> Task 2.4: node --check <file> (syntax check doang,
#                gak nge-run file-nya) KALAU binary node ada.
#   .ts       -> Task 2.4: tsc --noEmit --skipLibCheck <file>
#                best-effort KALAU tsc ada (global atau
#                ./node_modules/.bin/tsc project lokal) -- gak install
#                typescript baru cuma buat task ini.
#   gak dikenal -> di-skip, BUKAN dianggap gagal.
# Args: daftar path file (hasil ${(k)touched_files[@]} dari caller).
# Output: pesan error gabungan (kosong kalau semua lolos/di-skip),
# format & isi buat .py IDENTIK sama $bad_py versi lama biar pesan yang
# dikirim balik ke LLM gak berubah sama sekali. Buat ekstensi lain,
# format entry pesan ("$f: $err") dibikin SAMA polanya kayak .py, biar
# cara error nyampe ke LLM konsisten (lihat task spec: "pakai pola error
# handling yang sudah dipakai existing Python verification").
_ai_verify_touched_files() {
    local -a files=("$@")
    local f pyerr sherr jsonerr yamlerr yaml_available jserr tserr tsc_bin bad=""
    for f in "${files[@]}"; do
        [ -f "$f" ] || continue
        case "$f" in
            *.py)
                pyerr=$(python3 -m py_compile "$f" 2>&1)
                [ -n "$pyerr" ] && bad="$bad
$f: $pyerr"
                ;;
            *.zsh)
                # Task 2.2: zsh -n selalu ada (kita jalan di dalam zsh
                # sendiri), jadi gak perlu availability check kayak .sh.
                sherr=$(zsh -n "$f" 2>&1)
                [ -n "$sherr" ] && bad="$bad
$f: $sherr"
                ;;
            *.sh)
                # Task 2.2: bash -n kalau bash ada, fallback sh -n kalau
                # enggak, skip (dengan catatan di stdout, BUKAN masuk ke
                # $bad) kalau dua-duanya gak ketemu -- environment yang
                # gak punya checker relevan gak boleh nge-block agent.
                if command -v bash >/dev/null 2>&1; then
                    sherr=$(bash -n "$f" 2>&1)
                    [ -n "$sherr" ] && bad="$bad
$f: $sherr"
                elif command -v sh >/dev/null 2>&1; then
                    sherr=$(sh -n "$f" 2>&1)
                    [ -n "$sherr" ] && bad="$bad
$f: $sherr"
                else
                    echo "  [skip verifikasi $f: gak bisa diverifikasi, binary syntax-checker gak ketemu]" >&2
                fi
                ;;
            *.json)
                # Task 2.3: jq udah jadi dependency wajib project ini
                # (dipakai di 60-ui.zsh dkk), jadi gak perlu availability
                # check kayak bash/sh di .sh -- langsung dipakai.
                # "jq empty <file>" gak nge-print apa-apa ke stdout kalau
                # valid, cuma exit-code + pesan error ke stderr kalau
                # JSON-nya rusak.
                jsonerr=$(jq empty "$f" 2>&1)
                [ -n "$jsonerr" ] && bad="$bad
$f: $jsonerr"
                ;;
            *.yaml|*.yml)
                # Task 2.3: YAML checker OPSIONAL -- modul python "yaml"
                # (PyYAML) belum tentu ke-install (BUKAN dependency wajib
                # project ini kayak jq/python3 sendiri). Cek dulu modul-
                # nya bisa di-import SEBELUM coba validasi; kalau enggak
                # bisa, skip dengan catatan jelas ke stderr (BUKAN masuk
                # $bad / dianggap gagal) -- jangan install paket baru
                # otomatis, dan jangan bikin agent stuck cuma gara-gara
                # dependency opsional ini gak ada.
                yaml_available=$(python3 -c 'import yaml' 2>/dev/null && echo 1)
                if [ "$yaml_available" = "1" ]; then
                    yamlerr=$(python3 -c 'import yaml,sys; yaml.safe_load(open(sys.argv[1]))' "$f" 2>&1)
                    [ -n "$yamlerr" ] && bad="$bad
$f: $yamlerr"
                else
                    echo "  [skip verifikasi $f: YAML gak bisa diverifikasi, modul python 'yaml' (PyYAML) gak ketemu]" >&2
                fi
                ;;
            *.js)
                # Task 2.4: "node --check <file>" -- SYNTAX CHECK DOANG
                # (parse doang, gak nge-run file-nya sama sekali, jadi
                # aman dipanggil otomatis meski file-nya punya side-
                # effect kalau di-run beneran). Kalau binary node gak
                # ada di environment ini -- SKIP dengan catatan jelas
                # ke stderr (BUKAN masuk $bad / dianggap gagal), pola
                # SAMA kayak .sh waktu bash/sh gak ketemu di Task 2.2.
                # Sengaja gak install node otomatis.
                if command -v node >/dev/null 2>&1; then
                    jserr=$(node --check "$f" 2>&1)
                    [ -n "$jserr" ] && bad="$bad
$f: $jserr"
                else
                    echo "  [skip verifikasi $f: JS gak bisa diverifikasi, binary 'node' gak ketemu]" >&2
                fi
                ;;
            *.ts)
                # Task 2.4: TypeScript best-effort. "node --check" gak
                # valid buat source .ts (ada type annotation dkk yang
                # bukan syntax JS biasa), jadi pakai 'tsc' KALAU udah
                # ada di environment -- coba global command dulu, kalau
                # enggak coba binary lokal project (./node_modules/.bin
                # /tsc, tandanya project ini emang udah punya typescript
                # ke-install sendiri). SENGAJA GAK install typescript
                # baru cuma buat verifikasi ini. "--noEmit --skipLibCheck"
                # + target SATU FILE (bukan project penuh/tsconfig)
                # biar bukan full build berat -- best-effort syntax/type
                # check ringan, bukan build lengkap.
                tsc_bin=""
                if command -v tsc >/dev/null 2>&1; then
                    tsc_bin="tsc"
                elif [ -x "./node_modules/.bin/tsc" ]; then
                    tsc_bin="./node_modules/.bin/tsc"
                fi
                if [ -n "$tsc_bin" ]; then
                    tserr=$("$tsc_bin" --noEmit --skipLibCheck "$f" 2>&1)
                    [ -n "$tserr" ] && bad="$bad
$f: $tserr"
                else
                    echo "  [skip verifikasi $f: TS gak bisa diverifikasi, 'tsc' gak ketemu (bukan global command, bukan juga ./node_modules/.bin/tsc) -- gak diinstall otomatis]" >&2
                fi
                ;;
            *)
                # File non-.py/.zsh/.sh/.json/.yaml/.yml/.js/.ts: gak
                # ada verifier buat tipe ini. Ekstensi gak dikenal
                # sengaja di-skip, BUKAN dianggap gagal verifikasi.
                ;;
        esac
    done
    printf '%s' "$bad"
}

