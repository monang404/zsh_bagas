# ============================================================
#  30-ai/55-subagent/25-debug_allowlist.zsh — Task 7.2: `ai debug` tool guard
#  (split out of the old monolithic 30-ai/55-subagent.zsh)
# ============================================================

# Debug adalah diagnosis-only mode. Guard tool dilakukan SEBELUM
# _ai_tool_dispatch supaya prompt injection yang memilih mutation tool
# tidak pernah mencapai dispatcher. run_test/run_command tetap lewat
# permission model existing setelah lolos guard lokal.
_ai_debug_tool_allowed() {
    local tool="$1"
    case "$tool" in
        read_file|list_dir|grep_search|glob_search|count_lines|git_status|git_diff|todo_read|run_test|run_command)
            return 0 ;;
        edit_file|write_file|patch_file|delete_file|move_file)
            echo "PERMISSION DENIED: tool '$tool' tidak diizinkan dalam ai debug."
            return 1 ;;
        *)
            echo "PERMISSION DENIED: tool '$tool' tidak diizinkan dalam ai debug."
            return 1 ;;
    esac
}
