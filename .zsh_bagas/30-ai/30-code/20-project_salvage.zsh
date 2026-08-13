# ============================================================
#  30-ai/30-code/20-project_salvage.zsh — aiproject's empty-result / salvage path
#  (split out of the old monolithic 30-ai/30-code.zsh)
# ============================================================

# Reads $project_dir/$has_markers/$logfile/$gen_max_tries (caller
# locals, dynamic scope). Returns 1 if aiproject should stop with a
# hard failure (caller does `return $?`); returns 0 to keep going
# (either nothing needed salvaging, or the single-file salvage
# succeeded).
_ai_project_salvage_if_empty() {
    [ -n "$(ls -A "$project_dir" 2>/dev/null)" ] && return 0

    if [ "$has_markers" -eq 1 ]; then
        echo ""
        echo "GAGAL: gak ada satupun file ke-generate di $project_dir."
        echo "Kemungkinan besar semua provider/model gagal."
        echo "Cek log mentahnya buat tau kenapa:"
        echo "  cat \"$logfile\""
        echo ""
        tail -5 "$logfile"
        return 1
    fi

    # Udah dicoba $gen_max_tries kali dan tetap gak nulis '### FILE:'
    # sama sekali -- daripada folder kosong total, selametin isinya
    # jadi satu file main.py, biar setidaknya ada sesuatu yang bisa
    # dicek/dijalankan/di-autofix, ketimbang kerja generation-nya
    # kebuang percuma. TAPI ini kemungkinan besar app-nya GAK LENGKAP
    # (fitur yang harusnya kepisah ke file lain bisa aja ke-skip atau
    # nabrak/dobel definisi) -- smoke-test "jalan tanpa traceback" di
    # bawah TIDAK membuktikan app ini punya semua fitur yang diminta,
    # cuma membuktikan gak ada syntax/runtime-error di jalur yang
    # sempat ke-exercise. WAJIB dicek manual sebelum dipakai serius.
    echo ""
    echo "WARNING: AI gak nulis format '### FILE:' yang diminta walau udah dicoba $gen_max_tries kali (biasa kejadian di task kompleks/provider fallback)."
    echo "Nyelametin hasilnya jadi satu file: $project_dir/main.py (bukan multi-file kayak yang diminta)."
    echo "PENTING: file ini kemungkinan TIDAK LENGKAP dibanding spec aslinya -- 'jalan tanpa error' di bawah cuma cek syntax/crash, bukan cek fitur lengkap. Baca manual sebelum dipakai."
    command cp "$logfile" "$project_dir/main.py"
    _ai_sanitize_pycode "$project_dir/main.py"
    return 0
}
