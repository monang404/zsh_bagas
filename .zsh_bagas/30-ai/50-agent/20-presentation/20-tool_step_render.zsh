# ============================================================
#  30-ai/50-agent/20-presentation/20-tool_step_render.zsh
#  _ai_agent_render_step_start / _ai_agent_render_step_result —
#  tree-style step/tool/result rendering, replacing the raw
#  [AGENT][STEP N]/[AGENT][TOOL]/[AGENT][OK|ERROR] tag lines.
#
#  UI Overhaul (audit.md Phase 2): composes existing data
#  ($args_disp via _ai_agent_args_summary, $result_disp via
#  _ai_agent_result_summary) into a tree block:
#
#    ├─ N  tool  args_disp
#    │     ✓ result_disp        (exit_status == 0)
#    │     ✗ result_disp        (exit_status != 0)
#
#  Tree glyphs follow the same unicode/ascii-fallback convention
#  already used by _ai_ui_line for icons -- no bare unicode
#  without a fallback (per audit §16/§20 Phase 2).
#
#  "Is this the last step" (├─ vs └─) is not tracked by the loop
#  (step count isn't known in advance -- the loop is bounded by
#  max_step but usually ends earlier via done:true), so this
#  renderer always uses the "├─" connector for step lines and a
#  plain "│" continuation for the result line, documented here per
#  audit §20 Phase 2's explicit note that this simplification is
#  acceptable and should be documented in a comment.
# ============================================================

_ai_agent_render_step_start() {
    setopt localoptions noxtrace
    local step="$1" tool="$2" args_disp="$3"
    # Commit 3 (implementasi_plan.md): gate tree render ke verbosity≥1.
    # Di level 0 (default Minimal) tulis ke detail log saja — tidak ke layar.
    local tree_line
    local branch
    if _ai_ui_supports_unicode; then
        branch="├─"
    else
        branch="|-"
    fi
    if [ -n "$args_disp" ]; then
        tree_line="  ${branch} ${step}  ${tool}  ${args_disp}"
    else
        tree_line="  ${branch} ${step}  ${tool}"
    fi
    if [ "${AI_VERBOSITY:-0}" -ge 1 ]; then
        if [ -n "$args_disp" ]; then
            echo "  ${AI_C_MUTED}${branch}${AI_C_RESET} ${step}  ${AI_C_BOLD}${tool}${AI_C_RESET}  ${AI_C_DIM}${args_disp}${AI_C_RESET}"
        else
            echo "  ${AI_C_MUTED}${branch}${AI_C_RESET} ${step}  ${AI_C_BOLD}${tool}${AI_C_RESET}"
        fi
    fi
    # Selalu push ke detail log untuk /details
    _ai_detail_push "[tool-start] step=${step} tool=${tool} args=${args_disp}"
}

_ai_agent_render_step_result() {
    setopt localoptions noxtrace
    local ok="$1" result_disp="$2"
    local cont icon color
    if _ai_ui_supports_unicode; then
        cont="│"
    else
        cont="|"
    fi
    if [ "$ok" -eq 0 ]; then
        icon="✓"; color="$AI_C_OK"
        _ai_ui_supports_unicode || icon="+"
    else
        icon="✗"; color="$AI_C_ERR"
        _ai_ui_supports_unicode || icon="x"
    fi
    # Commit 3: hanya tampilkan ke layar di verbosity≥1
    if [ "${AI_VERBOSITY:-0}" -ge 1 ]; then
        echo "  ${AI_C_MUTED}${cont}${AI_C_RESET}     ${color}${icon}${AI_C_RESET} ${result_disp}"
    fi
    # Selalu push ke detail log
    local status_tag; [ "$ok" -eq 0 ] && status_tag="ok" || status_tag="fail"
    _ai_detail_push "[tool-result] ${status_tag}: ${result_disp}"
}

# _ai_agent_render_retry(current, max) — "↻ retrying... (N/MAX)" line,
# printed under the same tree continuation as the step's result line
# (Phase 5). Kept in this file since it shares the tree-glyph fallback
# logic above rather than duplicating it in track_and_continue.zsh.
_ai_agent_render_retry() {
    setopt localoptions noxtrace
    local current="$1" max="$2"
    local cont icon
    if _ai_ui_supports_unicode; then
        cont="│"; icon="↻"
    else
        cont="|"; icon="~"
    fi
    # Gate retry line ke verbosity≥1, push ke detail log di level 0
    if [ "${AI_VERBOSITY:-0}" -ge 1 ]; then
        echo "  ${AI_C_MUTED}${cont}${AI_C_RESET}     ${AI_C_WARN}${icon}${AI_C_RESET} retrying... (${current}/${max})"
    fi
    _ai_detail_push "[tool-retry] attempt ${current}/${max}"
}
