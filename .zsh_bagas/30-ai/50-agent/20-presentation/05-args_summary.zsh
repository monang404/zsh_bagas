# ============================================================
#  30-ai/20-presentation/05-args_summary.zsh — _ai_agent_args_summary — ringkasan argumen tool 1 baris buat tampilan compact
#  (split out of the old monolithic 30-ai/50-agent/20-presentation.zsh)
# ============================================================

# Task 1.3 (fase1_ui_ux_overhaul): ringkasan argumen tool buat baris
# compact "→ tool_name ringkasan_arg" -- bukan dump JSON args mentah
# ({"path":"..."} dsb). Per-tool karena tiap tool punya field args
# yang beda (path/pattern/command/url/...), tapi ini CUMA soal
# tampilan: gak menyentuh args_json asli yang dikirim ke
# _ai_tool_dispatch sama sekali.
_ai_agent_args_summary() {
    local tool="$1" args_json="$2"
    local val=""
    case "$tool" in
        read_file|write_file|edit_file|patch_file|count_lines|delete_file)
            val=$(echo "$args_json" | jq -r '.path // empty' 2>/dev/null)
            ;;
        move_file)
            local src dest
            src=$(echo "$args_json" | jq -r '.path // empty' 2>/dev/null)
            dest=$(echo "$args_json" | jq -r '.dest // empty' 2>/dev/null)
            [ -n "$src" ] && val="$src -> ${dest:-?}"
            ;;
        list_dir)
            val=$(echo "$args_json" | jq -r '.path // empty' 2>/dev/null)
            [ -z "$val" ] && val="."
            ;;
        grep_search)
            local pattern path
            pattern=$(echo "$args_json" | jq -r '.pattern // empty' 2>/dev/null)
            path=$(echo "$args_json" | jq -r '.path // empty' 2>/dev/null)
            val="$pattern"
            [ -n "$path" ] && val="$val in $path"
            ;;
        glob_search)
            val=$(echo "$args_json" | jq -r '.pattern // empty' 2>/dev/null)
            ;;
        run_command)
            val=$(echo "$args_json" | jq -r '.command // empty' 2>/dev/null)
            ;;
        run_test)
            local cmd tpath
            cmd=$(echo "$args_json" | jq -r '.cmd // empty' 2>/dev/null)
            tpath=$(echo "$args_json" | jq -r '.path // empty' 2>/dev/null)
            val="${cmd:-${tpath:-.}}"
            ;;
        git_diff)
            val=$(echo "$args_json" | jq -r '.path // empty' 2>/dev/null)
            ;;
        git_status|todo_read)
            val=""
            ;;
        web_fetch)
            val=$(echo "$args_json" | jq -r '.url // empty' 2>/dev/null)
            ;;
        todo_write)
            local n
            n=$(echo "$args_json" | jq -r '(.items // []) | length' 2>/dev/null)
            [ -n "$n" ] && [ "$n" != "null" ] && val="$n item"
            ;;
        *)
            val=$(echo "$args_json" | jq -c '.' 2>/dev/null)
            ;;
    esac
    if [ "${#val}" -gt 60 ]; then
        val="${val[1,60]}…"
    fi
    echo "$val"
}

