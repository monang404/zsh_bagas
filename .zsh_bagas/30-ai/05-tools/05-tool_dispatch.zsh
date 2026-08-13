# ============================================================
#  30-ai/05-tools/05-tool_dispatch.zsh — manifest string + request validation + dispatcher
#  (split out of the old monolithic 30-ai/05-tools.zsh)
# ============================================================

_ai_tool_manifest() {
    local name cap level desc
    for name in ${(k)AI_TOOL_REGISTRY}; do
        [[ "$name" == "run_command" && "${AI_AGENT_EXPOSE_ARBITRARY_SHELL:-0}" != "1" ]] && continue
        desc="${AI_TOOL_REGISTRY[$name]%%|*}"
        level="${AI_TOOL_REGISTRY[$name]##*|}"
        cap="${AI_TOOL_CAPABILITY[$name]}"
        printf '%s | capability=%s | approval=%s | %s\n' "$name" "$cap" "$level" "$desc"
    done | sort
}

_ai_tool_validate_request() {
    local tool_name="$1" args_json="$2" schema
    schema="${AI_TOOL_SCHEMA[$tool_name]}"
    [ -n "$schema" ] || { echo "ERROR: tool '$tool_name' tidak punya schema contract" >&2; return 1; }
    command -v jq >/dev/null 2>&1 || { echo "ERROR: jq diperlukan untuk validasi tool contract" >&2; return 1; }
    # v-fix (BUG#2 audit): filter ini SAMA SEKALI gak baca "." dari stdin --
    # semua data masuk lewat --argjson. Tanpa "-n", jq tetap nunggu (atau,
    # kalau stdin udah ke-close/kosong kayak di dalam pipeline agent loop,
    # langsung exit 4 "no output produced") KARENA jq defaultnya baca 1
    # dokumen JSON dari stdin dulu sebelum jalanin filter -- gak peduli
    # filter itu butuh input atau enggak. Efeknya: validasi SELALU gagal
    # (exit != 0) buat SEMUA tool, apapun isi args-nya (termasuk yang udah
    # benar sesuai schema) -- persis gejala di bug report ("read_file"
    # gagal utk path relatif MAUPUN absolute, "list_dir" juga gagal).
    # "-n" bikin jq skip baca stdin sama sekali, filter jalan cuma modal
    # --argjson yang udah di-pass.
    if ! jq -en --argjson args "$args_json" "(\$args | type == \"object\") and (\$args | $schema)" >/dev/null 2>&1; then
        echo "ERROR: tool '$tool_name' menerima arguments yang tidak sesuai schema" >&2
        return 1
    fi
    return 0
}

_ai_tool_dispatch() {
    local tool_name="$1"
    local args_json="$2"

    if [[ -z "${AI_TOOL_REGISTRY[$tool_name]}" ]]; then
        echo "ERROR: tool '$tool_name' gak dikenal. Tool valid: ${(k)AI_TOOL_REGISTRY}"
        return 1
    fi

    # ── Normalize args before validation ─────────────────────────
    # Tolerate common model mistakes: bare string args, path at root,
    # alternative field names. This runs BEFORE schema validation so
    # the schema sees the corrected shape.
    if command -v _ai_tool_normalize_args >/dev/null 2>&1; then
        args_json=$(_ai_tool_normalize_args "$args_json" "$tool_name")
    fi

    if ! _ai_tool_validate_request "$tool_name" "$args_json"; then
        return 1
    fi

    # ── Permission check with specific error propagation ─────────
    # The permission check has two phases:
    #   1. Path validation (non-interactive, may echo errors to stderr)
    #   2. Interactive prompt (perm_ask, needs stdin/stdout to terminal)
    # We capture stderr to a temp file so validation errors propagate
    # to the model, but the interactive prompt still works normally.
    local _perm_errfile
    _perm_errfile=$(mktemp 2>/dev/null || echo "/tmp/.ai_perm_err.$$")
    if ! _ai_permission_check "$tool_name" "$args_json" 2>"$_perm_errfile"; then
        local _perm_errmsg
        _perm_errmsg=$(cat "$_perm_errfile" 2>/dev/null)
        rm -f "$_perm_errfile" 2>/dev/null
        if [ -n "$_perm_errmsg" ]; then
            echo "$_perm_errmsg"
        else
            echo "ERROR: ditolak permission model buat tool '$tool_name'"
        fi
        return 1
    fi
    rm -f "$_perm_errfile" 2>/dev/null

    case "$tool_name" in
        read_file)   _ai_tool_read_file "$args_json" ;;
        list_dir)    _ai_tool_list_dir "$args_json" ;;
        grep_search) _ai_tool_grep_search "$args_json" ;;
        glob_search) _ai_tool_glob_search "$args_json" ;;
        count_lines) _ai_tool_count_lines "$args_json" ;;
        write_file)  _ai_tool_write_file "$args_json" ;;
        edit_file)   _ai_tool_edit_file "$args_json" ;;
        patch_file)  _ai_tool_patch_file "$args_json" ;;
        run_command) _ai_tool_run_command "$args_json" ;;
        exec_process) _ai_tool_exec_process "$args_json" ;;
        run_test)    _ai_tool_run_test "$args_json" ;;
        move_file)   _ai_tool_move_file "$args_json" ;;
        delete_file) _ai_tool_delete_file "$args_json" ;;
        git_status)  _ai_tool_git_status "$args_json" ;;
        git_diff)    _ai_tool_git_diff "$args_json" ;;
        web_fetch)   _ai_tool_web_fetch "$args_json" ;;
        todo_write)  _ai_tool_todo_write "$args_json" ;;
        todo_read)   _ai_tool_todo_read "$args_json" ;;
    esac
}
