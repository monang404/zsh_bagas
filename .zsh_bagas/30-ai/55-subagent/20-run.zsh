# ============================================================
#  30-ai/55-subagent/20-run.zsh — Task 6.2: _ai_subagent_run(role, sub_goal)
#  (split out of the old monolithic 30-ai/55-subagent.zsh; sysprompt
#  building and per-step logic now live in 10-sysprompt.zsh / 15-run_step.zsh)
# ============================================================

# Runner MINIMAL, bukan copy dari aiagent() (50-agent/) -- reuse arsitektur
# existing sebanyak mungkin (_ai_chat_request, _ai_agent_parse,
# _ai_tool_dispatch, _ai_agent_slug, _ai_trim_session — semua TIDAK diubah).
#
# Return: TIDAK exit dari shell/session, TIDAK bikin caller (aiagent) mati
# tanpa hasil -- selalu `return 0` (status=success) atau `return 1`
# (status=failed) dari FUNCTION INI SAJA, dengan ringkasan terstruktur
# (key=value, satu key per baris) di stdout. Caller ambil lewat command
# substitution: result=$(_ai_subagent_run researcher "cari semua endpoint auth")
_ai_subagent_run() {
    local role="$1" sub_goal="$2"

    case "$role" in
        researcher|coder) ;;
        *)
            echo "status=failed"
            echo "role=${role}"
            echo "summary=Role subagent tidak dikenal."
            echo "findings="
            echo "changes="
            echo "files_affected="
            echo "error=role harus 'researcher' atau 'coder', dapat: '${role}'"
            return 1
            ;;
    esac

    if [ -z "$sub_goal" ]; then
        echo "status=failed"
        echo "role=${role}"
        echo "summary=sub_goal kosong."
        echo "findings="
        echo "changes="
        echo "files_affected="
        echo "error=sub_goal wajib diisi"
        return 1
    fi

    local sysprompt msgfile slug runs_logfile
    sysprompt=$(_ai_subagent_build_sysprompt "$role" "$sub_goal")
    msgfile=$(mktemp)
    jq -n --arg p "$sysprompt" --arg g "Goal: ${sub_goal}" \
        '[{role:"system",content:$p},{role:"user",content:$g}]' > "$msgfile"

    slug=$(_ai_agent_slug "$sub_goal")
    mkdir -p "$AI_TOOL_RUNS_DIR"
    runs_logfile="$AI_TOOL_RUNS_DIR/${slug}-subagent-${role}.jsonl"

    # ── loop bounded: max_steps SAMA atau LEBIH KECIL dari
    #    AI_AGENT_MAX_STEPS (00-config.zsh), override opsional lewat
    #    AI_SUBAGENT_MAX_STEPS -- TIDAK PERNAH unlimited/`while true` ──
    local max_steps="${AI_SUBAGENT_MAX_STEPS:-$AI_AGENT_MAX_STEPS}"
    local step=0 reply chat_status thought tool args done_flag
    local output exit_status filepath
    local sub_status="failed" summary="" error="" final_thought=""
    local last_failed_tool="" last_failed_args="" same_fail_count=0
    local max_same_fail="${AI_AGENT_MAX_SAME_FAIL:-3}"
    local -A files_affected

    while [ "$step" -lt "$max_steps" ]; do
        step=$((step + 1))
        _ai_subagent_step
        [ $? -eq 1 ] && break
    done

    if [ "$step" -ge "$max_steps" ] && [ "$sub_status" != "success" ]; then
        sub_status="failed"
        summary="Subagent berhenti, sudah ${max_steps} langkah tanpa declare selesai."
        error="subagent step limit reached (step ${step})"
    fi

    rm -f "$msgfile"

    # ── return: ringkasan terstruktur SAJA (bukan transcript/history
    #    penuh) -- key=value, aman diparse shell, TANPA parser JSON baru ──
    local files_csv=""
    if [ "${#files_affected[@]}" -gt 0 ]; then
        files_csv="${(j:,:)${(k)files_affected}}"
    fi

    echo "status=${sub_status}"
    echo "role=${role}"
    echo "summary=$(_ai_subagent_oneline "$summary")"
    if [ "$role" = "researcher" ]; then
        echo "findings=$(_ai_subagent_oneline "${final_thought:-$summary}")"
        echo "changes="
    else
        echo "findings="
        echo "changes=$(_ai_subagent_oneline "${final_thought:-$summary}")"
    fi
    echo "files_affected=${files_csv}"
    echo "error=$(_ai_subagent_oneline "$error")"

    [ "$sub_status" = "success" ] && return 0
    return 1
}
