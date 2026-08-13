# ============================================================
#  30-ai/06-permissions/10-path_guard.zsh — project root resolution + canonical path containment
#  (split out of the old monolithic 30-ai/06-permissions.zsh)
# ============================================================

_ai_project_root() {
    local root
    # Prefer the repository root when invoked from inside a Git worktree;
    # otherwise fall back to the physical current directory.  This makes the
    # security boundary match the documented meaning of "project root" while
    # preserving support for non-Git projects.
    if command -v git >/dev/null 2>&1; then
        root=$(git rev-parse --show-toplevel 2>/dev/null) && {
            root=$(cd -P -- "$root" 2>/dev/null && pwd -P) || return 1
            printf '%s\n' "$root"
            return 0
        }
    fi
    root=$(cd -P -- "${PWD:-.}" 2>/dev/null && pwd -P) || return 1
    printf '%s\n' "$root"
}

# Canonicalize a path even when the final component does not exist.
# This is the security primitive for all project-scoped filesystem tools.
_ai_canonical_path() {
    local target="$1" base name canon
    [ -n "$target" ] || return 1
    if command -v realpath >/dev/null 2>&1; then
        if canon=$(realpath "$target" 2>/dev/null); then
            printf '%s\n' "$canon"
            return 0
        fi
    fi
    if canon=$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' -- "$target" 2>/dev/null); then
        printf '%s\n' "$canon"
        return 0
    fi
    return 1
}

_ai_path_within_project() {
    local target="$1" root canonical
    root=$(_ai_project_root) || return 1
    canonical=$(_ai_canonical_path "$target") || return 1
    [[ "$canonical" == "$root" || "$canonical" == "$root"/* ]]
}

_ai_validate_project_path() {
    local target="$1" operation="${2:-filesystem}"
    [ -n "$target" ] || { echo "ERROR: path kosong untuk $operation" >&2; return 1; }
    if [[ "${AI_PERM_ALLOW_OUTSIDE_PROJECT:-0}" == "1" ]]; then
        return 0
    fi
    if ! _ai_path_within_project "$target"; then
        echo "ERROR: $operation ditolak: path berada di luar project root: $target" >&2
        return 1
    fi
    return 0
}

