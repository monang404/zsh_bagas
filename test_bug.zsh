#!/bin/zsh
source ./.zsh_bagas/30-ai/50-agent/39-agent-state-machine.zsh
source ./.zsh_bagas/30-ai/50-agent/42-execution/00-loop_main.zsh

# Mock dependencies
_ai_agent_state_init() { mkdir -p "$1"; echo "PLAN" > "$1/lifecycle_state"; return 0; }
_ai_agent_state_transition() { echo "$2" > "$1/lifecycle_state"; return 0; }
_ai_agent_state_get() { cat "$1/lifecycle_state"; return 0; }

_ai_agent_exec_get_plan() {
    thought="test"
    tool=""
    done_flag="false"
    return 0
}

_ai_log_agent_plan() { :; }
_ai_agent_exec_check_done_rejections() { return 0; }

_ai_agent_execute_loop /tmp/test_state "" "" "" 0 "slug" "" 5
echo "Loop returned $?"
