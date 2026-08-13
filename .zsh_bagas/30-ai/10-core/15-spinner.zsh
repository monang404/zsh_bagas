# ============================================================
#  30-ai/10-core/15-spinner.zsh — terminal spinner UI
#  (split out of the old monolithic 30-ai/10-core.zsh)
# ============================================================

: ${AI_SPINNER_ENABLE:=1}
_AI_SPINNER_FRAMES=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)

_ai_spinner_start() {
    setopt localoptions noxtrace
    local label="$1" statusfile pid
    # v-fix (bug report "agent selalu stuk di write_file/dll"): dulu spinner
    # nulis ke &2 dan cek interaktif lewat `[ -t 2 ]`. Tapi caller (mis.
    # 05-get_plan.zsh) sering me-redirect SELURUH stderr pemanggilan ini ke
    # file sementara (`2>"$_gp_errfile"`, buat nangkep detail error
    # provider) -- akibatnya fd 2 di titik ini bukan tty lagi, `[ -t 2 ]`
    # selalu false, spinner jadi no-op TOTAL selama nunggu request LLM.
    # User cuma liat layar diam sampai puluhan detik/menit (45s x retry x
    # model/provider fallback), identik sama "hang", padahal step
    # SEBELUMNYA (tool yang terakhir ke-print) sudah selesai duluan.
    #
    # Fix: pakai /dev/tty langsung, independen dari fd 2 milik caller siapa
    # pun -- pola yang sama seperti _ai_perm_ask (06-permissions/20-perm_ask.zsh).
    # Precheck writability ke /dev/tty (bukan `-t 2`) biar tetap no-op yang
    # benar kalau memang gak ada terminal sama sekali (mis. dari cron).
    if [ "${AI_SPINNER_ENABLE:-1}" != "1" ] || ! { : >/dev/tty; } 2>/dev/null; then
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
            printf '\r\033[K%s %s (%ss)' "$frame" "$cur" "$elapsed" >/dev/tty 2>/dev/null
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
    # Jangan disown: spinner harus ikut lifecycle command utama agar Ctrl-C
    # tidak meninggalkan proses background yatim.
    echo "${pid}:${statusfile}"
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
    printf '\r\033[K' >/dev/tty 2>/dev/null
    [ -n "$statusfile" ] && rm -f "$statusfile"
}
