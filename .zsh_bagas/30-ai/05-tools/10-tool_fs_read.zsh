# ============================================================
#  30-ai/05-tools/10-tool_fs_read.zsh — read_file / list_dir / count_lines
#  (split out of the old monolithic 30-ai/05-tools.zsh)
# ============================================================

_ai_tool_read_file() {
    local args_json="$1"
    local path offset limit
    path=$(_ai_tool_extract_path "$args_json")
    offset=$(_ai_tool_extract_field "$args_json" offset)
    limit=$(_ai_tool_extract_field "$args_json" limit)

    if [ -z "$path" ]; then
        echo "ERROR: read_file membutuhkan args.path (string non-empty). Diterima: $(printf '%s' "$args_json" | _ai_head_c 200)"
        return 1
    fi
    if [ ! -f "$path" ]; then
        echo "ERROR: file gak ketemu: $path"
        return 1
    fi
    if _ai_is_secret_file "$path"; then
        echo "ERROR: [$path] kelihatan kayak file secrets. Ditolak."
        return 1
    fi
    if _ai_is_binary_file "$path"; then
        echo "ERROR: [$path] kelihatan file biner. Ditolak."
        return 1
    fi

    # FIX BUG-5: jalankan langsung tanpa eval, hindari injection lewat path/offset
    local out
    if [ -n "$offset" ] && [ -n "$limit" ] && [[ "$offset" =~ ^[0-9]+$ ]] && [[ "$limit" =~ ^[0-9]+$ ]]; then
        local end=$((offset + limit - 1))
        out=$(command sed -n "${offset},${end}p" "$path" | command nl -ba -v"$offset" -w4 -s'  ')
    else
        out=$(command nl -ba -w4 -s'  ' "$path")
    fi
    printf '%s' "$out" | _ai_head_c "${AI_FILE_MAX_CHARS:-40000}"
}

_ai_tool_list_dir() {
    local args_json="$1"
    local path
    path=$(_ai_tool_extract_path "$args_json")
    [ -z "$path" ] && path="."
    if [ ! -d "$path" ]; then
        echo "ERROR: direktori gak ketemu ($path)"
        return 1
    fi
    local ls_cmd=""
    if whence -p eza >/dev/null 2>&1; then
        ls_cmd="$(whence -p eza)"
    elif whence -p ls >/dev/null 2>&1; then
        ls_cmd="$(whence -p ls)"
    elif [ -x "/bin/ls" ]; then
        ls_cmd="/bin/ls"
    elif [ -x "/usr/bin/ls" ]; then
        ls_cmd="/usr/bin/ls"
    else
        echo "ERROR: executable 'ls' atau 'eza' gak ketemu di PATH"
        return 1
    fi
    "$ls_cmd" -lah "$path" | _ai_head_n 50
}

# ─── Tool Baru: count_lines ───────────────────────────────────
# Beri agen info cepat tentang panjang file / frekuensi pattern
# TANPA harus membaca seluruh isi file (hemat token).
_ai_tool_count_lines() {
    local args_json="$1"
    local path pattern
    path=$(_ai_tool_extract_path "$args_json")
    pattern=$(_ai_tool_extract_field "$args_json" pattern)

    if [ -z "$path" ]; then
        echo "ERROR: count_lines membutuhkan args.path (string non-empty). Diterima: $(printf '%s' "$args_json" | _ai_head_c 200)"
        return 1
    fi
    if [ ! -f "$path" ]; then
        echo "ERROR: file gak ketemu: $path"
        return 1
    fi
    if _ai_is_secret_file "$path"; then
        echo "ERROR: [$path] kelihatan kayak file secrets. Ditolak."
        return 1
    fi

    local total
    total=$(command wc -l <"$path" 2>/dev/null | tr -d ' ')

    if [ -n "$pattern" ]; then
        local matches
        matches=$(command grep -c "$pattern" "$path" 2>/dev/null || echo 0)
        echo "File: $path | Total baris: $total | Kemunculan '$pattern': $matches"
    else
        echo "File: $path | Total baris: $total"
    fi
}
