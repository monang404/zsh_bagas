# ============================================================
#  30-ai/05-tools/35-tool_run_test.zsh — run_test (typed test-suite runner)
#  (split out of the old monolithic 30-ai/05-tools.zsh)
# ============================================================

# ─── Tool Baru: run_test ─────────────────────────────────────
# Auto-detect test runner dari project scan / file penanda,
# lalu jalankan test suite dengan output terstruktur.
# Args opsional: cmd (override auto-detect), path (direktori spesifik)
_ai_tool_run_test() {
    local args_json="$1"
    local cmd path timeout_s runner
    cmd=$(_ai_tool_extract_field "$args_json" cmd)
    runner=$(_ai_tool_extract_field "$args_json" runner)
    path=$(_ai_tool_extract_path "$args_json")
    timeout_s=$(_ai_tool_extract_field "$args_json" timeout)
    [ -z "$timeout_s" ] && timeout_s=60
    [ -n "$path" ] || path="."

    # Resolve a test request to a typed executable + argv.  The old
    # implementation passed a model-controlled string to `zsh -c`, which
    # turned process.test into arbitrary shell execution.  `cmd` remains
    # accepted for compatibility, but it is tokenized only; it is NEVER
    # interpreted by a shell.
    local -a test_args
    if [ -n "$cmd" ]; then
        if [[ "$cmd" == *';'* || "$cmd" == *'|'* || "$cmd" == *'&'* || "$cmd" == *'<'* || "$cmd" == *'>'* || "$cmd" == *'`'* || "$cmd" == *'$('* || "$cmd" == *$'\n'* ]]; then
            echo "ERROR: test command mengandung shell metacharacter; gunakan runner + args terstruktur."
            return 1
        fi
        local -a tokens
        tokens=(${(z)cmd})
        [ ${#tokens[@]} -gt 0 ] || { echo "ERROR: test command kosong"; return 1; }
        runner="${tokens[1]}"
        test_args=("${tokens[@]:1}")
    else
        [ -n "$runner" ] || {
            # Auto-detect hanya menghasilkan argv tetap; tidak menerima script
            # dari package.json sebagai shell string.
            if [ -f "$path/package.json" ] && command -v npm >/dev/null 2>&1; then
                local has_test_script
                has_test_script=$(jq -r '(.scripts.test // "") | select(length > 0 and . != "echo \"Error: no test specified\" && exit 1")' "$path/package.json" 2>/dev/null || true)
                if [ -n "$has_test_script" ]; then
                    runner="npm"
                    test_args=(test)
                fi
            fi
            if [ -z "$runner" ] && [ -f "$path/Cargo.toml" ] && command -v cargo >/dev/null 2>&1; then
                runner="cargo"; test_args=(test)
            fi
            if [ -z "$runner" ] && [ -f "$path/go.mod" ] && command -v go >/dev/null 2>&1; then
                runner="go"; test_args=(test ./...)
            fi
            if [ -z "$runner" ] && command -v pytest >/dev/null 2>&1; then
                local has_tests
                has_tests=$(find "$path" -maxdepth 3 \( -name 'test_*.py' -o -name '*_test.py' \) -print -quit 2>/dev/null)
                if [ -n "$has_tests" ]; then
                    runner="pytest"; test_args=(-v --tb=short)
                fi
            fi
            [ -n "$runner" ] || {
                echo "Gak bisa auto-detect test runner. Gunakan runner + args terstruktur atau cmd kompatibel tanpa shell syntax."
                return 1
            }
        }
        test_args=("${(@f)$(jq -r '.args[]?' <<<"$args_json")}")
    fi

    # Only real test runners are allowed. Interpreters that can directly
    # evaluate source (`python -c`, `node -e`, etc.) are deliberately excluded.
    case "${runner:t}" in
        npm|pnpm|yarn|bun)
            [[ "${test_args[1]:-}" == "test" ]] || {
                echo "ERROR: $runner hanya boleh menjalankan subcommand 'test'."
                return 1
            }
            ;;
        cargo)
            [[ "${test_args[1]:-}" == "test" ]] || {
                echo "ERROR: cargo hanya boleh menjalankan subcommand 'test'."
                return 1
            }
            ;;
        go)
            [[ "${test_args[1]:-}" == "test" ]] || {
                echo "ERROR: go hanya boleh menjalankan subcommand 'test'."
                return 1
            }
            ;;
        pytest)
            ;;
        python|python3)
            [[ "${test_args[1]:-}" == "-m" && "${test_args[2]:-}" == "pytest" ]] || {
                echo "ERROR: python runner hanya boleh menjalankan '-m pytest'."
                return 1
            }
            ;;
        *)
            echo "ERROR: test runner '${runner:t}' tidak diizinkan."
            return 1
            ;;
    esac

    local real_cwd resolved
    _ai_validate_project_path "$path" "run_test" || return 1
    real_cwd=$(_ai_canonical_path "$path") || {
        echo "ERROR: direktori test tidak bisa dikanonicalisasi"
        return 1
    }
    [ -d "$real_cwd" ] || { echo "ERROR: path test bukan direktori: $path"; return 1; }
    resolved=$(command -v -- "${runner:t}" 2>/dev/null) || {
        echo "ERROR: test runner '${runner:t}' tidak ditemukan"
        return 1
    }
    if _ai_path_within_project "$resolved"; then
        echo "ERROR: executable '${runner:t}' resolves inside project; PATH hijacking protection"
        return 1
    fi

    echo "Menjalankan test: ${runner:t} ${(q-)test_args[*]}"
    local out rc
    if command -v timeout >/dev/null 2>&1; then
        out=$(cd -- "$real_cwd" && timeout -- "$timeout_s" "$resolved" "${test_args[@]}" 2>&1)
        rc=$?
    else
        out=$(cd -- "$real_cwd" && "$resolved" "${test_args[@]}" 2>&1)
        rc=$?
    fi
    out=$(printf '%s' "$out" | _ai_head_c 3000)
    printf '%s\n' "$out"
    if [ "$rc" -eq 0 ]; then
        echo ""
        echo "OK: test selesai tanpa error (exit 0)"
        return 0
    fi
    echo ""
    echo "GAGAL: test exit dengan kode $rc"
    return 1
}
