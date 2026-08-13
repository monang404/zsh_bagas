# ============================================================
#  30-ai/30-code/40-project_completeness.zsh — _ai_project_check_completeness
#  (split out of the old monolithic 30-ai/30-code.zsh)
# ============================================================


# v5.2: smoke-test cuma buktiin "gak crash di jalur yang sempat dicoba" —
# itu BUKAN bukti app-nya lengkap. Kasus nyata: aiproject gagal nulis
# '### FILE:', salvage jadi satu main.py yang cuma separuh jadi (mis.
# helper JSON + satu class doang, gak ada logic utama/menu), lalu aifix
# nge-patch satu ModuleNotFoundError sampai smoke-test "lolos" — padahal
# hampir semua fitur yang diminta gak pernah ke-tulis. Dua sinyal murah
# buat nangkep pola ini TANPA perlu ngerti isi programnya:
#   1) Kalau prompt aslinya spec terstruktur (ada '[FILES]' dari `ai spec`),
#      tiap nama file yang disebut di situ HARUS ada di project_dir. Kalau
#      ada yang hilang, besar kemungkinan itu isyarat generation kepotong.
#   2) File entry (main.py / fallback single-file) yang gak punya blok
#      `if __name__ == "__main__"` kemungkinan cuma kumpulan
#      helper/class tanpa program yang beneran jalan -- bukan bukti pasti
#      (skrip pendek kadang sengaja gak pakai guard ini), tapi cukup buat
#      warning, bukan silent-pass.
_ai_project_check_completeness() {
    local project_dir="$1" task_desc="$2" entry="$3"
    local -a missing_files
    if [[ "$task_desc" == *"[FILES]"* ]]; then
        local expected
        for expected in $(echo "$task_desc" | grep -oE '^-[[:space:]]*[A-Za-z0-9_./]+\.py' | sed -E 's/^-[[:space:]]*//'); do
            [ -f "$project_dir/$expected" ] || missing_files+=("$expected")
        done
        if [ ${#missing_files[@]} -gt 0 ]; then
            echo ""
            echo "WARNING: spec minta file ini tapi gak ketemu di $project_dir: ${missing_files[*]}"
            echo "  Kemungkinan besar generation kepotong sebelum sempat nulis semua file. Cek raw log, atau ulang 'ai project' buat project_dir yang sama."
        fi
    fi
    if [ -f "$entry" ] && ! grep -q '__main__' "$entry"; then
        echo ""
        echo "WARNING: $(basename "$entry") gak ada blok 'if __name__ == \"__main__\":' — kemungkinan cuma kumpulan fungsi/class tanpa program yang beneran bisa dijalankan user. Smoke-test 'jalan tanpa error' DI ATAS gak membuktikan sebaliknya (import doang juga bisa 'jalan tanpa error'). Cek isi filenya manual."
    fi
}
