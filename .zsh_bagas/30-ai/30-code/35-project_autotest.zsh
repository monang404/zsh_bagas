# ============================================================
#  30-ai/30-code/35-project_autotest.zsh — _ai_project_autotest
#  (split out of the old monolithic 30-ai/30-code.zsh)
# ============================================================


# Generated projects are syntax-checked only. Runtime execution is deliberately
# disabled here because generated source is untrusted code.
_ai_project_autotest() {
    local project_dir="$1" task_desc="$2"
    local f err
    echo ""
    echo "Cek syntax semua file .py..."
    local failed=0
    for f in "$project_dir"/**/*.py(N); do
        [ -e "$f" ] || continue
        err=$(python3 -m py_compile "$f" 2>&1)
        if [ -n "$err" ]; then
            echo "  SYNTAX ERROR: $(basename "$f")"
            echo "$err" | tail -8
            failed=1
        fi
    done
    if [ "$failed" -eq 1 ]; then
        echo "ERROR: generated project memiliki syntax error. Tidak ada generated code yang dieksekusi otomatis."
        return 1
    fi
    echo "  OK — syntax Python valid."
    echo "  Runtime smoke-test otomatis dinonaktifkan: generated code dianggap untrusted dan tidak dieksekusi tanpa sandbox/approval."
    _ai_project_check_completeness "$project_dir" "$task_desc" "$project_dir/main.py"
    return 0
}
