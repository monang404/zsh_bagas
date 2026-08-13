# ============================================================
#  30-ai/30-code/50-run.zsh — airun
#  (split out of the old monolithic 30-ai/30-code.zsh)
# ============================================================


airun() {
    if [ -z "$1" ]; then
        echo "Usage: airun <file.py>"
        return 1
    fi
    local file="$1"
    local tries=0
    while [ $tries -lt 2 ]; do
        # v-fix: dulu program dijalanin DUA KALI kalau berhasil (sekali
        # buat cek error lewat `2>&1 >/dev/null`, sekali lagi buat nampilin
        # output) — program dengan efek samping (tulis DB, kirim request
        # API, dst) jalan dua kali. Sekarang cuma SEKALI eksekusi: stdout+
        # stderr ditangkap bareng, dan deteksi error pakai EXIT CODE python3
        # (bukan "stderr kosong atau nggak" — warning non-fatal ke stderr
        # gak lagi salah dianggap kegagalan).
        local output exit_code
        output=$(python3 "$file" 2>&1)
        exit_code=$?
        if [ "$exit_code" -eq 0 ]; then
            echo "Berjalan tanpa error"
            [ -n "$output" ] && echo "$output"
            _ai_notify "airun selesai" "$file jalan tanpa error"
            return 0
        fi
        echo "Error terdeteksi, mencoba perbaikan otomatis ($((tries+1))/2)..."
        aifix "$file" "$output" || return 1
        command cp "$file" "${file}.bak.$(_ai_ts)"
        command mv -f "${file}.fixed" "$file"
        tries=$((tries+1))
    done
    echo "Masih error setelah 2x percobaan, cek manual: $file (backup ada di ${file}.bak.*)"
    _ai_notify "airun gagal" "$file masih error setelah 2x auto-fix"
    python3 "$file"
}
