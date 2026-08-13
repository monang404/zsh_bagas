# ============================================================
#  00-core/compat.zsh — helper kompatibilitas lintas distro
#  Diload PALING AWAL (prefix 00-core) biar tersedia di semua
#  modul berikutnya, termasuk agent tools.
#
#  Masalah yang diselesaikan:
#  - `head` dari GNU coreutils tidak selalu terinstall di Termux
#    minimal / Debian minimal / Alpine. Semua modul ai pakai
#    `head -c N` untuk truncasi output. Kalau head gak ada,
#    _ai_permission_check dan semua tool langsung crash.
# ============================================================

# ─── _ai_head_c : portable "head -c N" ───────────────────────
# Usage: printf '%s' "$string" | _ai_head_c 3000
#        _ai_head_c 3000 < file
#        _ai_head_c 3000 file   (opsi: path sebagai arg ke-2)
#
# Urutan fallback:
#   1. head -c N          (GNU coreutils / macOS / busybox — paling cepat)
#   2. dd bs=1 count=N    (POSIX, ada di mana-mana, lambat tapi aman)
#   3. python3 -c         (sudah jadi dep wajib toolkit ini)
#   4. read loop zsh      (last resort pure-zsh, lambat untuk data besar)
_ai_head_c() {
    local n="${1:-3000}" f="${2:-}"
    if command -v head > /dev/null 2>&1; then
        if [ -n "$f" ]; then
            command head -c "$n" -- "$f" 2>/dev/null
        else
            command head -c "$n"
        fi
        return
    fi
    if command -v dd > /dev/null 2>&1; then
        if [ -n "$f" ]; then
            dd if="$f" bs=1 count="$n" 2>/dev/null
        else
            dd bs=1 count="$n" 2>/dev/null
        fi
        return
    fi
    if command -v python3 > /dev/null 2>&1; then
        if [ -n "$f" ]; then
            python3 -c "
import sys
with open(sys.argv[1],'rb') as fh:
    sys.stdout.buffer.write(fh.read(int(sys.argv[2])))
" "$f" "$n" 2>/dev/null
        else
            python3 -c "
import sys
sys.stdout.buffer.write(sys.stdin.buffer.read(int(sys.argv[1])))
" "$n" 2>/dev/null
        fi
        return
    fi
    # Last resort: pure-zsh read loop (lambat, tapi tidak crash)
    local chunk byte count=0
    while IFS= read -r -k 1 byte; do
        printf '%s' "$byte"
        count=$((count+1))
        [ $count -ge $n ] && break
    done
}

# ─── _ai_head_n : portable "head -n N" ───────────────────────
# Usage: cmd | _ai_head_n 50
_ai_head_n() {
    local n="${1:-50}"
    if command -v head > /dev/null 2>&1; then
        command head -n "$n"
        return
    fi
    # awk tersedia hampir di mana-mana (termasuk busybox)
    if command -v awk > /dev/null 2>&1; then
        awk "NR<=$n"
        return
    fi
    # python3 fallback
    command -v python3 > /dev/null 2>&1 && python3 -c "
import sys
for i,l in enumerate(sys.stdin):
    if i>=$n: break
    sys.stdout.write(l)
" "$n"
}

# Ekspor agar tersedia di subshell zsh (diperlukan karena run_command
# menjalankan `zsh -f -c "..."` tanpa source .zshrc)
# CATATAN: function export di zsh tidak seperti bash; kita definisikan
# ulang lewat ZSH_COMPAT_FUNCS yang di-source di zsh -f.
# Ini cukup untuk konteks shell interaktif.
