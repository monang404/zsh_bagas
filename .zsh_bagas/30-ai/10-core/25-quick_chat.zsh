# ============================================================
#  30-ai/10-core/25-quick_chat.zsh — _ai_quick wrapper + prompt/code helpers
#  (split out of the old monolithic 30-ai/10-core.zsh)
# ============================================================

# helper single-shot: bungkus preprompt+pesan jadi msgfile, lewat
# _ai_chat_request (dapet fallback multi-model x multi-provider gratis),
# lalu cetak balasannya. Dipakai gantiin call `tgpt` langsung di fungsi-
# fungsi pendek (chat cepat, shell helper, commit msg, dll) biar mereka
# semua ikut kebagian keandalan yang sama kayak plan/review/agent.
_ai_quick() {
    setopt localoptions noxtrace
    local preprompt="$1" usermsg="$2" task_class="${3:-fast}" order="${4:-}" max_toks_override="${5:-}"
    local stream="${6:-0}" log_kind="${7:-}"
    local msgfile reply rc tee_status stream_status
    msgfile=$(mktemp) || return 1
    jq -n --arg p "$preprompt" --arg u "$usermsg" \
        '[{role:"system",content:$p},{role:"user",content:$u}]' > "$msgfile" || {
        rm -f "$msgfile"
        return 1
    }

    if [ "$stream" -eq 1 ]; then
        local capture
        capture=$(mktemp) || {
            rm -f "$msgfile"
            return 1
        }

        # tee hanya menduplikasi byte yang sedang mengalir: stdout tetap
        # live ke terminal, sementara full response dikumpulkan untuk log
        # setelah request selesai. Jangan ubah ini menjadi command
        # substitution karena itu akan menahan seluruh stream sampai EOF.
        _ai_chat_request_stream "$msgfile" "" "$task_class" "$order" "$max_toks_override" |
            tee "$capture"
        stream_status=("${pipestatus[@]}")
        rc=${stream_status[1]}
        tee_status=${stream_status[2]}

        reply=$(cat "$capture" 2>/dev/null)
        rm -f "$capture" "$msgfile"

        if [ "$rc" -eq 0 ] && [ "$tee_status" -eq 0 ]; then
            printf '\n'
            [ -n "$log_kind" ] && _ai_log "$log_kind" "$usermsg" "$reply"
            return 0
        fi

        [ -n "$log_kind" ] && [ -n "$reply" ] && _ai_log "$log_kind" "$usermsg" "$reply"
        [ "${rc:-0}" -ne 0 ] && return "$rc"
        return "${tee_status:-1}"
    fi

    reply=$(_ai_chat_request "$msgfile" "" "$task_class" "$order" "$max_toks_override")
    # v-fix (bug #16 audit, forward exit code): dulu baris terakhir
    # fungsi ini `echo "$reply"` -- exit status $? yang keluar dari
    # _ai_quick jadinya SELALU 0 (exit code `echo`), bukan exit code
    # asli _ai_chat_request. Semua caller yang ngecek `$?` abis manggil
    # _ai_quick (aifix, dst) gak pernah bisa tau beneran gagal atau
    # nggak. $? di-capture SEBELUM `rm -f` (yang juga ngeset $? sendiri)
    # dan di-`return` eksplisit di akhir biar tetap valid abis `echo`.
    rc=$?
    rm -f "$msgfile"
    echo "$reply"
    return $rc
}

# v4.1: baca prompt dari file .txt/.md kalau argumennya emang path ke file
# yang ada — biar bisa `aicode prompt.txt` alih-alih ngetik promptnya
# manual di terminal (berguna buat prompt panjang/multi-baris). Kalau
# argumennya lebih dari satu kata ATAU bukan file yang ada, diperlakukan
# kayak biasa (semua argumen digabung jadi teks prompt literal).
_ai_resolve_prompt() {
    if [ $# -eq 1 ] && [ -f "$1" ] && [[ "${1:l}" == *.txt || "${1:l}" == *.md ]]; then
        cat "$1"
    else
        echo "$*"
    fi
}

# v4.2: auto-repair layer — jalan SEBELUM kode ditulis final ke file
# (dipanggil dari aicode/aiproject/aifix). Nempelin $AI_SANITIZE_SCRIPT
# ke file .py yang dikasih dan otomatis benerin bug "literal \n" (model
# nulis backslash+n dua karakter di LUAR string literal padahal maksudnya
# baris baru sungguhan — bikin SyntaxError). Aman-by-design: kalau file
# udah valid gak diapa-apain, kalau perbaikannya gagal bikin valid, file
# dibalikin persis kayak semula (gak ada resiko file makin rusak, dan gak
# nutupin error jenis lain — itu tetap kelewat apa adanya ke aifix/airun).
# Silent kalau python3/script gak ada, biar gak bikin fungsi lain ikut gagal.
_ai_sanitize_pycode() {
    local file="$1"
    [ -f "$file" ] || return 0
    # strip a trailing ".fixed" (dari aifix) sebelum ngecek ekstensi, biar
    # "foo.py.fixed" tetep kena deteksi walau bukan "*.py" persis
    local check="${file%.fixed}"
    [[ "$check" == *.py ]] || return 0
    command -v python3 >/dev/null || return 0
    [ -f "$AI_SANITIZE_SCRIPT" ] || return 0
    python3 "$AI_SANITIZE_SCRIPT" "$file" 2>&1 | grep -v '^$' >&2
    return 0
}

# v-fix: timestamp UNIK buat nama file (plan/prompt/code/backup/dst).
# Dulu banyak tempat pakai `date +%H%M%S` doang (kadang malah tanpa
# tanggal sekalipun) buat bikin nama file unik -- dua run/backup dalam
# detik yang sama collide dan saling timpa. Tambahin tanggal penuh +
# suffix random pendek ($RANDOM, built-in zsh) biar praktis gak pernah
# tabrakan walau dipanggil beruntun cepat.
_ai_ts() {
    printf '%s_%04x' "$(date +%Y%m%d_%H%M%S)" "$RANDOM"
}
