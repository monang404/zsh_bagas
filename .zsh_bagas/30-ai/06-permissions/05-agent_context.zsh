# ============================================================
#  30-ai/06-permissions/05-agent_context.zsh — agent runtime context begin/end + capability check
#  (split out of the old monolithic 30-ai/06-permissions.zsh)
# ============================================================

# Explicit runtime context for the agent/tool boundary.  These values are
# process-local shell state; they are never exported to child processes.
_ai_agent_context_begin() {
    local session_id="$1" project_root="$2" yolo="${3:-0}"
    typeset -g AI_AGENT_SESSION_ID="$session_id"
    typeset -g AI_AGENT_PROJECT_ROOT="$project_root"
    typeset -g AI_AGENT_YOLO_MODE="$yolo"
    typeset -gA AI_AGENT_CAPABILITIES=(
        filesystem.read 1
        git.read 1
        session.todo 1
        process.test 1
        process.execute 0
        network.public 0
        filesystem.write 0
        filesystem.delete 0
        shell.arbitrary 0
    )
}

_ai_agent_context_end() {
    unset AI_AGENT_SESSION_ID AI_AGENT_PROJECT_ROOT AI_AGENT_CAPABILITIES
}

_ai_agent_capability_allowed() {
    local capability="$1"
    [[ -n "${AI_AGENT_CAPABILITIES[$capability]:-}" && "${AI_AGENT_CAPABILITIES[$capability]}" == "1" ]]
}

