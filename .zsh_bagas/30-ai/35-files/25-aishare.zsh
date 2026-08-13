# ============================================================
#  30-ai/35-files/25-aishare.zsh — aishare — kirim file lewat Android share sheet (termux-share)
#  (split out of the old monolithic 30-ai/35-files.zsh)
# ============================================================

# v-fix (bug #63 audit): dulu gak ada cara gampang buat kirim hasil
# kerja (aicode/aiproject output) ke app Android lain -- user harus
# `cd` manual ke $CODE_DIR trus buka file manager sendiri. termux-share
# munculin share sheet Android biasa (WhatsApp, Gmail, GitHub, dst).
aishare() {
    local file="$1"
    if [ -z "$file" ]; then
        echo "Usage: aishare <file>"
        return 1
    fi
    if [ ! -f "$file" ]; then
        echo "File gak ketemu: $file"
        return 1
    fi
    if ! command -v termux-share >/dev/null 2>&1; then
        echo "Butuh termux-api: pkg install termux-api"
        return 1
    fi
    termux-share -a send "$file"
}
