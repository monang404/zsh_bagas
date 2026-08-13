# ============================================================
#  30-ai/60-ui/01-logger.zsh — centralized static execution logger
#  (replaces dynamic spinners/boxes with plain-text observable trace)
# ============================================================

_ai_log_start() { echo "[AI][START] $1" >&2; }
_ai_log_provider() { echo "[AI][PROVIDER] $1" >&2; }
_ai_log_model() { echo "[AI][MODEL] $1" >&2; }
_ai_log_request() { echo "[AI][REQUEST] $1" >&2; }
_ai_log_wait() { echo "[AI][WAIT] $1" >&2; }
_ai_log_stream() { echo "[AI][STREAM] $1" >&2; }
_ai_log_done() { echo "[AI][DONE] $1" >&2; }
_ai_log_error() { echo "[AI][ERROR] $1" >&2; }
_ai_log_retry() { echo "[AI][RETRY] $1" >&2; }
_ai_log_fallback() { echo "[AI][FALLBACK] $1" >&2; }
_ai_log_cancelled() { echo "[AI][CANCELLED] $1" >&2; }

_ai_log_agent_start() { echo "" >&2; echo "[AGENT][START] $1" >&2; }
_ai_log_agent_plan() { echo "[AGENT][PLAN] $1" >&2; }
_ai_log_agent_step() { echo "" >&2; echo "[AGENT][STEP $1] $2" >&2; }
_ai_log_agent_tool() { echo "[AGENT][TOOL] $1" >&2; }
_ai_log_agent_ok() { echo "[AGENT][OK] $1" >&2; }
_ai_log_agent_error() { echo "[AGENT][ERROR] $1" >&2; }
_ai_log_agent_verify() { echo "" >&2; echo "[AGENT][VERIFY] $1" >&2; }
_ai_log_agent_done() { echo "" >&2; echo "[AGENT][DONE] $1" >&2; }
