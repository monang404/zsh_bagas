# ============================================================
#  30-ai/55-subagent/40-debug.zsh — Task 7.2: explicit `ai debug` mode
#  (split out of the old monolithic 30-ai/55-subagent.zsh; per-step logic
#  and report printing now live in 30-debug_step.zsh / 35-debug_report.zsh)
# ============================================================

# `aidebug <description>` -- bounded diagnosis runner.
# Tidak pernah memanggil aifix/aiagent dan tidak memiliki jalur auto-fix.
aidebug() {
    _ai_need_any_key || return 1

    local problem="$*"
    if [ -z "$problem" ]; then
        echo "Usage: ai debug <description>"
        return 1
    fi

    # Project-local permission overrides tetap dipakai oleh _ai_tool_dispatch.
    _ai_perm_load_project

    # SECURITY FIX (audit Fase 7/8, CRITICAL-1): AI_AGENT_YOLO_MODE adalah
    # env var GLOBAL yang di-export oleh aiagent() (50-agent/) dan TIDAK
    # PERNAH direset setelah aiagent selesai -- kalau `aiagent --yolo` pernah
    # dijalankan di sesi shell yang sama, AI_AGENT_YOLO_MODE=1 tetap nempel
    # dan bikin _ai_perm_ask_shell (06-permissions.zsh) lolos tanpa
    # konfirmasi APAPUN, termasuk buat run_command yang dipanggil dari sini.
    # Itu membobol jaminan "ai debug TIDAK PERNAH mengubah file" (acceptance
    # criteria Task 7.2) walau _ai_debug_tool_allowed sendiri sudah benar.
    # `.aiagent/permissions.zsh` project-local yang baru di-load di atas juga
    # bisa berisi AI_PERM_SHELL_MODE=yolo. Paksa ulang dua-duanya ke aman di
    # sini -- `local` di zsh shadow global secara dinamis untuk seluruh
    # pemanggilan nested (_ai_tool_dispatch -> _ai_tool_run_command ->
    # _ai_perm_ask_shell) selama fungsi ini berjalan, lalu otomatis balik ke
    # nilai luar begitu aidebug() return, jadi tidak mempengaruhi aiagent()
    # atau command lain.
    local AI_AGENT_YOLO_MODE=0
    local AI_PERM_SHELL_MODE=ask_always

    local sysprompt="You are a debugging agent.

Goal:
${problem}

Your job is to diagnose the problem.

You may inspect files and run tests or commands needed to reproduce
and understand the issue.

Do NOT modify files.
Do NOT propose executing file mutations through tools.

Return a concise diagnosis and recommended next steps.

Do not claim a fix was applied.

You must respond only as JSON:
{\"thought\":\"...\",\"tool\":\"...\",\"args\":{...},\"done\":true|false}"

    local msgfile
    msgfile=$(mktemp) || {
        echo "Debug incomplete:"
        echo "Unable to create temporary session file."
        return 1
    }
    jq -n --arg p "$sysprompt" --arg g "Problem: ${problem}" \
        '[{role:"system",content:$p},{role:"user",content:$g}]' > "$msgfile" || {
        rm -f "$msgfile"
        echo "Debug incomplete:"
        echo "Unable to initialize debug session."
        return 1
    }

    local max_steps="${AI_DEBUG_MAX_STEPS:-${AI_AGENT_MAX_STEPS:-8}}"
    local step=0 reply chat_status thought tool args done_flag
    local output exit_status final_thought="" diagnosis_status="failed" error=""
    local -a reproduction=()
    local -A affected_files

    while [ "$step" -lt "$max_steps" ]; do
        step=$((step + 1))
        _ai_debug_step
        [ $? -eq 1 ] && break
    done

    if [ "$step" -ge "$max_steps" ] && [ "$diagnosis_status" != "success" ]; then
        error="debug step limit reached (step ${step})"
    fi

    rm -f "$msgfile"

    _ai_debug_print_report

    [ "$diagnosis_status" = "success" ] && return 0
    return 1
}
