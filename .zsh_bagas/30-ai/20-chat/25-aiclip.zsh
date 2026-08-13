# ============================================================
#  30-ai/20-chat/25-aiclip.zsh — _ai_clip_is_sensitive + aiclip — tanya AI soal isi clipboard, dengan filter data sensitif
#  (split out of the old monolithic 30-ai/20-chat.zsh)
# ============================================================

# v-fix (bug #60 audit, P0): aiclip dulu ngirim isi clipboard MENTAH ke
# API eksternal tanpa filter apa pun -- beda dengan file (_ai_is_secret_
# file udah ngecek pattern nama/isi), clipboard di Android sering isinya
# OTP/password ke-copy dari SMS/password manager. Heuristik ringan:
# baris pendek isinya cuma digit (khas OTP), pola kartu 13-19 digit,
# blok private-key PEM, atau keyword password/secret/token/otp diikuti
# value pendek. Bukan deteksi sempurna (namanya juga heuristik), tapi
# jauh lebih baik daripada gak ada filter sama sekali.
_ai_clip_is_sensitive() {
    local content="$1"
    if echo "$content" | grep -qE 'BEGIN (RSA |EC |OPENSSH |DSA |ENCRYPTED )?PRIVATE KEY'; then
        return 0
    fi
    if echo "$content" | grep -qE '([0-9][ -]?){13,19}'; then
        return 0
    fi
    if echo "$content" | grep -qiE '(password|passwd|secret|api[_-]?key|token|otp|kode verifikasi|verification code)[[:space:]:=]+[A-Za-z0-9!@#$%^&*_-]{4,}'; then
        return 0
    fi
    local trimmed
    trimmed=$(echo "$content" | tr -d '[:space:]')
    if [[ "$trimmed" =~ ^[0-9]{4,8}$ ]]; then
        return 0
    fi
    return 1
}

aiclip() {
    _ai_need_any_key || return 1
    local force=0
    if [[ "$1" == "--force" ]]; then
        force=1
        shift
    fi
    command -v termux-clipboard-get >/dev/null || { echo "Butuh termux-api: pkg install termux-api"; return 1; }
    local content; content=$(termux-clipboard-get)
    [ -z "$content" ] && { echo "Clipboard kosong."; return 1; }
    if [ "$force" -ne 1 ] && _ai_clip_is_sensitive "$content"; then
        echo "Isi clipboard kelihatan kayak data sensitif (OTP/password/token/nomor kartu/private key)."
        echo "Isinya GAK dikirim ke AI. Kalau memang yakin ini aman: aiclip --force ..."
        return 1
    fi
    local query="${*:-ringkes/jelaskan isi clipboard ini}"
    local reply
    reply=$(_ai_quick "$AI_PERSONA_LONG Konteks dari clipboard user, jawab sesuai permintaan." \
        "Clipboard:
$content

Permintaan: $query" smart)
    echo "$reply"
    if command -v termux-clipboard-set >/dev/null; then
        echo "$reply" | termux-clipboard-set
        echo ""
        echo "(hasil udah di-copy balik ke clipboard)"
    fi
    _ai_log "clip" "$query" "$reply"
}
