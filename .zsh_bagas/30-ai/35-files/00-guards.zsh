# ============================================================
#  30-ai/35-files/00-guards.zsh — secret-file & binary-file detection (_ai_is_secret_file, _ai_is_binary_file)
#  (split out of the old monolithic 30-ai/35-files.zsh)
# ============================================================

# ============================================================
#  30-ai/35-files.zsh — baca & edit file existing dengan review
#  aicat, aipatch. Beda dari aicode (yang generate file BARU dari
#  nol): ini buat file yang SUDAH ADA — AI baca isi asli, usulin
#  perubahan, ditampilin sebagai diff, baru diterapkan kalau
#  dikonfirmasi. Gak ada file yang ketimpa tanpa user liat dulu
#  apa yang berubah.
# ============================================================

# file yang keliatan kayak secrets -- isinya gak dikirim ke AI
# kecuali user eksplisit maksa (jaga-jaga kekiriman .env/token ke API luar)
# v-fix: pattern lama gak nyakup file kunci SSH (id_rsa/id_ed25519 gak ada
# ekstensi ".key"), config manager package (.npmrc), credentials.json,
# .pgpass, cert bundle .pfx/.p12, dll -- semuanya bisa ke-`aipatch` dan
# isinya kekirim ke API eksternal tanpa sadar. Ditambah lapis KEDUA: cek
# awal ISI file (bukan cuma nama file) buat nangkep private key yang
# namanya gak ketebak dari pattern nama file manapun.
_ai_is_secret_file() {
    local f="${1:t}"
    case "${f:l}" in
        .env|.env.*|*secret*|*credential*|*.pem|*.key|*token*) return 0 ;;
        id_rsa|id_dsa|id_ecdsa|id_ed25519|*.ppk) return 0 ;;
        .npmrc|.pgpass|.netrc|.git-credentials) return 0 ;;
        credentials.json|client_secret*.json|*.pfx|*.p12|*.jks|*.keystore) return 0 ;;
    esac
    # lapis kedua: isi file, bukan cuma namanya -- private key biasanya
    # dimulai dengan header PEM yang khas biarpun nama filenya gak ketebak
    if [ -f "$1" ] && _ai_head_c 2000 "$1" 2>/dev/null | grep -qE 'BEGIN (RSA |EC |OPENSSH |DSA |ENCRYPTED )?PRIVATE KEY'; then
        return 0
    fi
    return 1
}

# v-fix (bug #44 audit): aicat/aipatch dulu gak ada penanganan sama
# sekali buat file biner -- `cat`/`sed -n` di file biner bisa nge-flood
# terminal dengan garbage (kadang sampe ubah setting terminal kalau
# ada control-char aneh), dan `aipatch` bakal ngirim byte biner mentah
# ke API AI (buang-buang token, hasilnya juga gak akan guna).
_ai_is_binary_file() {
    [ -f "$1" ] || return 1
    if command -v file >/dev/null 2>&1; then
        case "$(file --mime-encoding -b -- "$1" 2>/dev/null)" in
            binary) return 0 ;;
            *) return 1 ;;
        esac
    fi
    # fallback tanpa `file`: null byte di 8000 byte pertama = indikasi kuat biner.
    # Hindari grep/ugrep (pattern null dan flag -I sering false-positive).
    local _raw _stripped
    _raw=$(_ai_head_c 8000 "$1" 2>/dev/null | wc -c | tr -d " ")
    _stripped=$(_ai_head_c 8000 "$1" 2>/dev/null | tr -d "\0" | wc -c | tr -d " ")
    [ -n "$_raw" ] && [ "$_raw" -gt 0 ] && [ "$_raw" -ne "$_stripped" ] && return 0
    return 1
}

