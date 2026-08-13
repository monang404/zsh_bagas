# ============================================================
#  30-ai/50-agent/39-agent-state-machine.zsh
# ============================================================
# Canonical lifecycle. UI/result files must not invent terminal state.
typeset -gA AI_AGENT_STATE_TRANSITIONS
AI_AGENT_STATE_TRANSITIONS=(
  PLAN     "EXECUTE VERIFY BLOCKED"
  EXECUTE  "PLAN VERIFY BLOCKED"
  VERIFY   "PLAN EXECUTE COMPLETE BLOCKED"
  COMPLETE ""
  BLOCKED  ""
)

_ai_agent_state_init() {
    local state_dir="$1"
    mkdir -p -- "$state_dir" || return 1
    printf '%s\n' "PLAN" >| "$state_dir/lifecycle_state"
}

_ai_agent_state_get() {
    local state_dir="$1"
    [ -r "$state_dir/lifecycle_state" ] || return 1
    cat "$state_dir/lifecycle_state"
}

_ai_agent_state_transition() {
    local state_dir="$1" next="$2" current allowed
    current=$(_ai_agent_state_get "$state_dir") || return 1
    allowed="${AI_AGENT_STATE_TRANSITIONS[$current]}"
    if [[ " $allowed " != *" $next "* ]]; then
        echo "Invalid agent lifecycle transition: $current -> $next" >&2
        return 1
    fi
    printf '%s\n' "$next" >| "$state_dir/lifecycle_state"
}

_ai_agent_state_is_terminal() {
    local state
    state=$(_ai_agent_state_get "$1") || return 1
    [[ "$state" == COMPLETE || "$state" == BLOCKED ]]
}
