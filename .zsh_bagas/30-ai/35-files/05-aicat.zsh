# ============================================================
#  30-ai/35-files/05-aicat.zsh — aicat — baca file dengan nomor baris
#  (split out of the old monolithic 30-ai/35-files.zsh)
# ============================================================

# baca file dengan nomor baris, opsional range -- biar bisa liat
# potongan file gede tanpa dorong seluruh isinya ke context/terminal
aicat() {
    local file="$1" start="$2" end="$3"
    if [ -z "$file" ] || [ ! -f "$file" ]; then
        echo "Usage: aicat <file> [start_line] [end_line]"
        return 1
    fi
    if _ai_is_binary_file "$file"; then
        echo "[$file] kelihatan file biner (bukan teks), gak ditampilin. Pakai 'file $file' buat cek tipe aslinya."
        return 1
    fi
    if [ -n "$start" ] && [ -n "$end" ]; then
        sed -n "${start},${end}p" "$file" | nl -ba -v"$start" -w4 -s'  '
    else
        nl -ba -w4 -s'  ' "$file"
    fi
}

