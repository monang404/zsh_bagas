# ============================================================
#  30-ai/35-files/10-aipatch.zsh — aipatch — edit file existing lewat AI dengan review wajib
#  (split out of the old monolithic 30-ai/35-files.zsh)
# ============================================================

# aipatch <file> <instruksi> — edit file existing lewat AI dengan
# review wajib sebelum apply.
# Alur: baca file asli -> AI balikin isi file LENGKAP hasil edit ->
# diff-kan sama aslinya -> tampilin -> confirm -> backup -> apply.
# AI sengaja diminta balikin FULL FILE (bukan unified diff) karena
# model kecil (fast/free tier) sering bikin diff format yang gak
# nyambung ke `patch`; full-file + `diff -u` di sisi kita jauh lebih
# reliable buat model kelas ini.
aipatch() {
    _ai_need_any_key || return 1
    # v-fix (bug #51 audit): --force-secret di-generalize jadi --force
    # (--force-secret tetap diterima sebagai alias, biar script/alias
    # lama yang udah kepakai gak break) -- sekarang dipakai bareng buat
    # bypass DUA guard: file secrets DAN file kegedean, daripada nambah
    # nama flag baru buat tiap guard baru yang ditambahin ke depannya.
    local force=0
    if [[ "$1" == "--force" || "$1" == "--force-secret" ]]; then
        force=1
        shift
    fi
    if [ $# -lt 2 ]; then
        echo "Usage: aipatch [--force] <file> <instruksi perubahan>"
        return 1
    fi
    local file="$1"; shift
    local instruction="$*"

    if [ -z "$file" ] || [ -z "$instruction" ]; then
        echo "Usage: aipatch [--force] <file> <instruksi perubahan>"
        return 1
    fi
    if [ ! -f "$file" ]; then
        echo "File gak ketemu: $file"
        return 1
    fi
    if _ai_is_binary_file "$file"; then
        echo "[$file] kelihatan file biner (bukan teks) -- aipatch cuma buat file teks/kode. Ditolak."
        return 1
    fi
    if [ "$force" -ne 1 ] && _ai_is_secret_file "$file"; then
        echo "[$file] kelihatan kayak file secrets (.env/credential/key/token)."
        echo "Isinya gak dikirim ke AI. Kalau memang yakin: aipatch --force \"$file\" ..."
        return 1
    fi

    local content
    content=$(cat "$file")

    # v-fix (bug #51 audit): dulu gak ada guard panjang file sama
    # sekali -- beda dengan diff (AI_DIFF_MAX_CHARS) yang udah dijaga,
    # isi file PENUH selalu dikirim mentah ke API berapa pun panjangnya.
    # File gede boros token & gampang kena 413/timeout, hasilnya malah
    # beresiko kepotong/korup pas ditulis balik.
    if [ "$force" -ne 1 ] && [ ${#content} -gt "${AI_FILE_MAX_CHARS:-40000}" ]; then
        echo "[$file] kegedean buat aipatch (${#content} char, limit ${AI_FILE_MAX_CHARS:-40000})."
        echo "aipatch minta AI balikin ISI FILE LENGKAP -- file sebesar ini gampang kepotong/timeout, hasil edit-nya beresiko korup."
        echo "Pecah instruksi ke bagian yang lebih kecil (mis. edit function tertentu aja), atau paksa tetap coba: aipatch --force \"$file\" ..."
        return 1
    fi
    local sysprompt="Kamu programmer expert. Kamu dikasih ISI FILE LENGKAP dan instruksi perubahan. Balas HANYA isi file LENGKAP hasil perubahan -- bukan diff, bukan potongan, bukan penjelasan, bukan markdown/backtick. Output harus langsung siap ditimpa ke disk apa adanya. Bagian yang gak diminta berubah harus tetap PERSIS sama seperti aslinya."
    local usermsg="Nama file: $file
Instruksi: $instruction

Isi file saat ini:
$content"

    echo "Minta AI menyusun perubahan untuk $file ..."
    local newcontent
    newcontent=$(_ai_quick "$sysprompt" "$usermsg" smart)
    if [ -z "$newcontent" ]; then
        echo "Gagal dapat balasan dari AI."
        return 1
    fi

    local tmpnew
    tmpnew=$(mktemp)
    # printf, bukan echo -- echo bisa salah interpretasi baris yang
    # diawali '-' sebagai flag di sebagian implementasi, dan trailing-
    # newline handling-nya gak konsisten antar shell/echo build.
    printf '%s\n' "$newcontent" | grep -vE '^```' > "$tmpnew"
    if [[ "$file" == *.py ]] && [ -f "$AI_SANITIZE_SCRIPT" ]; then
        python3 "$AI_SANITIZE_SCRIPT" "$tmpnew" >/dev/null 2>&1
    fi

    if diff -q "$file" "$tmpnew" >/dev/null 2>&1; then
        echo "AI gak mengusulkan perubahan apa pun."
        rm -f "$tmpnew"
        return 0
    fi

    echo ""
    echo "── Diff yang diusulkan: $file ──"
    diff -u "$file" "$tmpnew" | sed \
        -e "s/^-/$(printf '\033[31m')-/" \
        -e "s/^+/$(printf '\033[32m')+/" \
        -e "s/$/$(printf '\033[0m')/"
    echo "──────────────────────────────"

    local confirm=""
    if command -v gum >/dev/null; then
        gum confirm "Terapkan perubahan ini ke $file?" || { echo "Dibatalkan."; rm -f "$tmpnew"; return 1; }
    else
        # -t timeout: kalau dijalankan non-interaktif (cron/script/lewat
        # aiagent tanpa TTY), `read` polos bisa hang tanpa batas nunggu
        # input yang gak akan pernah datang. Default aman = batal.
        if ! read -t 60 "confirm?Terapkan perubahan ke $file? (y/n) "; then
            echo "Timeout nunggu konfirmasi, dianggap batal."
            rm -f "$tmpnew"
            return 1
        fi
        [[ "$confirm" != "y" ]] && { echo "Dibatalkan."; rm -f "$tmpnew"; return 1; }
    fi

    local backup="$file.bak.$(_ai_ts)"
    cp "$file" "$backup"
    # command mv -f: WAJIB bypass alias `mv` (kalau ada alias mv='mv -i'
    # di aliases.zsh, mv polos bakal minta konfirmasi KEDUA yang gak
    # kejawab di sini dan bikin apply gagal SENYAP tanpa exit code jelek).
    if ! command mv -f "$tmpnew" "$file"; then
        echo "GAGAL menerapkan perubahan (mv error). File asli gak berubah, cek $backup."
        rm -f "$backup"
        return 1
    fi
    if ! diff -q "$file" "$backup" >/dev/null 2>&1; then
        echo "Diterapkan. Backup: $backup"
        _ai_log "patch" "$file: $instruction" "applied (backup: $backup)"
    else
        echo "GAGAL: isi file gak berubah setelah mv. Cek manual."
        _ai_log "patch" "$file: $instruction" "apply verification failed"
        return 1
    fi
}

