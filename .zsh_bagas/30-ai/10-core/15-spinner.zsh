# ============================================================
#  30-ai/10-core/15-spinner.zsh — terminal spinner UI
#  (split out of the old monolithic 30-ai/10-core.zsh)
# ============================================================

: ${AI_SPINNER_ENABLE:=1}
_AI_SPINNER_FRAMES=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)

_ai_spinner_start() {
    setopt localoptions noxtrace
    local label="$1" statusfile pid
    # non-interaktif (stderr bukan tty, mis. dipipe/di-log/dijalanin dari
    # cron/termux-job-scheduler) atau dimatiin eksplisit lewat
    # AI_SPINNER_ENABLE=0 -> no-op. Handle kosong bikin _ai_spinner_update/
    # _stop otomatis no-op juga (dicek di awal masing-masing), jadi aman
    # dipanggil apa adanya tanpa caller perlu cek dulu.
    if [ "${AI_SPINNER_ENABLE:-1}" != "1" ] || [ ! -t 2 ]; then
        echo ""
        return 0
    fi
    statusfile=$(mktemp)
    printf '%s' "$label" > "$statusfile"
    (
        local i=0 start=$SECONDS frame cur elapsed
        while true; do
            frame="${_AI_SPINNER_FRAMES[$(( i % 10 + 1 ))]}"
            cur=$(<"$statusfile" 2>/dev/null)
            elapsed=$(( SECONDS - start ))
            printf '\r\033[K%s %s (%ss)' "$frame" "$cur" "$elapsed" >&2
            i=$((i + 1))
            sleep 0.15
            # jaga-jaga (mis. proses induk mati kena SIGKILL/OOM sebelum
            # sempat _ai_spinner_stop): jangan sampai spinner jadi proses
            # zombie yang jalan selamanya di background makan baterai --
            # 15 menit itu jauh di atas request AI paling lambat sekalipun.
            [ "$elapsed" -gt 900 ] && break
        done
    ) &
    pid=$!
    # Jangan disown: spinner harus ikut lifecycle command utama agar Ctrl-C\n    # tidak meninggalkan proses background yatim.\n    echo "${pid}:${statusfile}"
}

# ganti teks label tanpa restart spinner (mis. pindah provider/model,
# nambah nomor percobaan) -- dipanggil sesering perlu, murah (tulis file kecil)
_ai_spinner_update() {
    setopt localoptions noxtrace
    local handle="$1" label="$2"
    [ -z "$handle" ] && return 0
    local statusfile="${handle#*:}"
    [ -f "$statusfile" ] && printf '%s' "$label" > "$statusfile"
}

_ai_spinner_stop() {
    setopt localoptions noxtrace
    local handle="$1"
    [ -z "$handle" ] && return 0
    local pid="${handle%%:*}" statusfile="${handle#*:}"
    [ -n "$pid" ] && kill "$pid" 2>/dev/null
    [ -n "$pid" ] && wait "$pid" 2>/dev/null
    printf '\r\033[K' >&2
    [ -n "$statusfile" ] && rm -f "$statusfile"
}
