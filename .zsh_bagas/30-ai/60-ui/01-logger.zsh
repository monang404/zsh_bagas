# ============================================================
#  30-ai/60-ui/01-logger.zsh — centralized static execution logger
#  (replaces dynamic spinners/boxes with plain-text observable trace)
#
#  UI Overhaul (audit.md, §21 file-by-file plan): the _ai_log_agent_*
#  family (raw "[AGENT][TAG] text" lines) has been retired. Every
#  aiagent call site that used it now renders through the box/tree-
#  style System B primitives instead (60-ui/05-ui_box.zsh,
#  50-agent/20-presentation/20-tool_step_render.zsh) -- see
#  00-loop_main.zsh, 20-log_and_notify.zsh, 40-runtime/20-print_header.zsh,
#  and 44-finalize.zsh. Per the audit's explicit instruction, the two
#  presentation systems are not left live simultaneously; the plain,
#  non-agent _ai_log_* family below (shared with aiask/session chat,
#  out of this audit's scope) is unaffected and untouched.
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
