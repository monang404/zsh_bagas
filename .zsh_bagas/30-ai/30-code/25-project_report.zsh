# ============================================================
#  30-ai/30-code/25-project_report.zsh — aiproject's final report + import check
#  (split out of the old monolithic 30-ai/30-code.zsh)
# ============================================================

# Reads $project_dir/$logfile/$prompt/$project_name (caller locals,
# dynamic scope). Pure tail-end reporting + calls the existing
# _ai_project_autotest.
_ai_project_finish_report() {
    echo ""
    echo "Project dibuat di: $project_dir"
    ls -la "$project_dir"
    echo ""
    echo "Raw log tersimpan di: $logfile (buat debug kalau ada file hilang/error)"

    echo ""
    echo "Cek konsistensi import..."
    local f
    for f in "$project_dir"/**/*.py(N); do
        [ -e "$f" ] || continue
        grep -oP "^from \K[a-zA-Z_]+(?= import)" "$f" 2>/dev/null | while read -r mod; do
            if [ ! -f "$project_dir/$mod.py" ]; then
                echo "  WARNING: $(basename "$f") import '$mod' tapi $mod.py tidak ditemukan"
            fi
        done
    done
    _ai_project_autotest "$project_dir" "$prompt"

    _ai_notify "aiproject selesai" "Project '$project_name' udah jadi"
    _ai_log "project" "$project_name: $prompt" "saved to $project_dir"
}
