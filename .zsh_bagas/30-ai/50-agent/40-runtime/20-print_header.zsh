# ============================================================
#  30-ai/50-agent/40-runtime/20-print_header.zsh — aiagent's header box + skills line
#  (split out of the old monolithic 30-ai/50-agent/40-runtime.zsh)
# ============================================================

# Reads $goal/$resume_slug/$yolo/$skillsline (caller locals, dynamic
# scope). Pure output, printed exactly once per run (never inside the
# step loop).
_ai_agent_print_header() {
# Task 1.2: header box PERSIS SEKALI di sini -- titik ini dilewatin
# cuma sekali per run (baik goal baru maupun --resume), BUKAN di
# dalam loop `while` di bawah, jadi gak bakal keprint ulang tiap
# step. Teks dibedain kalau --resume ("Resuming: <goal>") biar user
# sadar ini lanjutan sesi lama, bukan run baru dari nol.
    local hdr_project hdr_model hdr_mode
    hdr_project=$(_ai_agent_project_name)
    hdr_model=$(_ai_agent_primary_model)
    if [ "$yolo" -eq 1 ]; then
        hdr_mode="yolo (auto-run, tanpa konfirmasi)"
    else
        hdr_mode="autonomous (konfirmasi tiap command)"
    fi
    if [ $step_offset -eq 0 ]; then
        _ai_log_agent_start "Task received"
    else
        _ai_log_agent_start "Resuming task"
    fi
    echo "[AGENT][GOAL] $goal" >&2
    echo "[AGENT][PROJECT] $hdr_project" >&2
    echo "[AGENT][MODEL] $hdr_model" >&2
    echo "[AGENT][MODE] $hdr_mode" >&2
    if [ -n "$skillsline" ]; then
        echo "[AGENT][SKILLS] $skillsline" >&2
    fi
}
