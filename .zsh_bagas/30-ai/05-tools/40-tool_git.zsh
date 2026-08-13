# ============================================================
#  30-ai/05-tools/40-tool_git.zsh — git_status / git_diff
#  (split out of the old monolithic 30-ai/05-tools.zsh)
# ============================================================

# ─── Tool Baru: git_status / git_diff ─────────────────────────
# Wrapper readonly buat dua hal yang paling sering ditanya agent
# lewat run_command (yang selalu minta konfirmasi) -- dijadiin tool
# tersendiri biar auto-approve (level readonly), gak ganggu user
# minta konfirmasi cuma buat "liat status doang".
_ai_tool_git_status() {
    if ! command -v git >/dev/null 2>&1; then
        echo "ERROR: git gak ketemu di PATH"
        return 1
    fi
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "ERROR: direktori saat ini bukan git repo"
        return 1
    fi
    echo "Branch: $(git branch --show-current 2>/dev/null)"
    git status --short -b 2>&1 | head -n 100
}

_ai_tool_git_diff() {
    local args_json="$1"
    local path
    path=$(_ai_tool_extract_path "$args_json")

    if ! command -v git >/dev/null 2>&1; then
        echo "ERROR: git gak ketemu di PATH"
        return 1
    fi
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "ERROR: direktori saat ini bukan git repo"
        return 1
    fi
    local out
    if [ -n "$path" ]; then
        out=$(git diff -- "$path" 2>&1)
    else
        out=$(git diff 2>&1)
    fi
    if [ -z "$out" ]; then
        echo "OK: gak ada perubahan (git diff kosong)"
        return 0
    fi
    printf '%s' "$out" | head -c "${AI_GITDIFF_MAX_CHARS:-6000}"
}
