# ============================================================
#  30-ai/50-agent/40-runtime/10-load_checkpoint.zsh — --resume checkpoint loader
#  (split out of the old monolithic 30-ai/50-agent/40-runtime.zsh)
# ============================================================

# Loads a --resume checkpoint. Writes back into the caller's (aiagent)
# dynamically-scoped locals: goal, step_offset, msgfile, run_slug (left
# as a plain global assignment exactly like the original, which never
# `local`-declared it on this path either), _AI_AGENT_SESSION_SLUG.
# Returns 1 on any failure (caller does `_ai_agent_load_checkpoint ... || return 1`).
_ai_agent_load_checkpoint() {
    local resume_slug="$1"
    checkpoint_file="$AI_AGENT_CHECKPOINT_DIR/${resume_slug}.json"
    if [ ! -f "$checkpoint_file" ]; then
        echo "Checkpoint '$resume_slug' gak ketemu. 'ai agent --list-checkpoints' buat lihat yang ada."
        return 1
    fi
    if ! jq -e '(.schema_version // 1) == 2 and (.goal | type == "string") and (.messages | type == "array")' "$checkpoint_file" >/dev/null 2>&1; then
        echo "Checkpoint '$resume_slug' invalid atau schema tidak didukung."
        return 1
    fi
    goal=$(jq -r '.goal' "$checkpoint_file" 2>/dev/null)
    step_offset=$(jq -r '.step // 0' "$checkpoint_file" 2>/dev/null)
    [[ "$step_offset" =~ ^[0-9]+$ ]] || step_offset=0
    msgfile=$(mktemp)
    if ! jq '.messages' "$checkpoint_file" >| "$msgfile" 2>/dev/null; then
        rm -f -- "$msgfile"
        return 1
    fi
    # FIX BUG-8: set run_slug saat resume juga, biar logging JSONL pakai slug yang benar
    run_slug=$(_ai_agent_slug "$goal")
    _AI_AGENT_SESSION_SLUG="$run_slug"
    # FIX BUG-1: load project permissions saat resume juga
    _ai_perm_load_project
    _ai_data_saver_check || { rm -f "$msgfile"; return 1; }
    echo "Resume checkpoint '$resume_slug' (goal: $goal, udah $step_offset step sebelumnya)."
}
