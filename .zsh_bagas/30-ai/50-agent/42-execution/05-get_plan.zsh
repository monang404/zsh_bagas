# ============================================================
#  30-ai/50-agent/42-execution/05-get_plan.zsh — minta rencana
#  langkah berikutnya dari AI dan parse balasannya.
#  (split out of the old monolithic 30-ai/50-agent/42-execution.zsh,
#  bagian awal body while-loop di _ai_agent_execute_loop)
#
#  Dipanggil dari _ai_agent_exec_step() di 20-step.zsh. Shared-state
#  var (state_dir, step, msgfile, checkpoint_file, reply, chat_status,
#  thought, tool, args, done_flag, pdir, block_reason) SENGAJA TIDAK
#  di-`local` ulang di sini -- dynamic scoping zsh bikin function ini
#  baca/tulis langsung ke local var punya _ai_agent_execute_loop
#  (pola yang sama seperti fix "exit_status/filepath" konsolidasi di
#  loop asli).
#
#  Return code: 0 = lanjut normal, 1 = harus `break` loop (dari
#  caller), 2 = harus `return 1` dari _ai_agent_execute_loop (state
#  transition gagal, fatal).
# ============================================================

_ai_agent_exec_get_plan() {
    # Same noxtrace guard as _ai_agent_execute_loop -- fungsi ini assign
    # shared-state vars (reply, thought, tool, etc.) yang bisa di-trace
    # oleh xtrace global kalau guard-nya hanya di parent loop.
    setopt localoptions noxtrace
    # Init already leaves lifecycle in PLAN. Re-entering PLAN from PLAN is
    # not a valid transition; treat "already PLAN" as success (no-op).
    # Only attempt the transition when we are coming from EXECUTE/VERIFY
    # (subsequent ReAct iterations).
    local _gp_cur
    _gp_cur=$(_ai_agent_state_get "$state_dir" 2>/dev/null) || _gp_cur=""
    if [ "$_gp_cur" != "PLAN" ]; then
        _ai_agent_state_transition "$state_dir" PLAN 2>/dev/null || return 2
    fi
    step=$((step+1))
    local _gp_errfile
    _gp_errfile=$(mktemp) 2>/dev/null
    if [ -n "$_gp_errfile" ]; then
        reply=$(_ai_agent_provider_request "$msgfile" "json" smart "${AI_TASK_PROVIDER_ORDER_AGENT[*]}" 2>"$_gp_errfile")
    else
        reply=$(_ai_agent_provider_request "$msgfile" "json" smart "${AI_TASK_PROVIDER_ORDER_AGENT[*]}")
    fi
    chat_status=$?
    if [ $chat_status -ne 0 ]; then
        # v-fix (bug #4 audit): _ai_chat_request nulis pesan diagnostik
        # ("semua provider & model gagal", raw error JSON, dll) ke
        # STDERR, sedangkan $reply cuma nangkep stdout (kosong saat
        # gagal total). Dulu block_reason gak pernah dapet detail asli
        # ini, jadi box BLOCKED akhir cuma bilang "status 1" generik.
        local _gp_detail=""
        [ -n "$_gp_errfile" ] && [ -s "$_gp_errfile" ] && _gp_detail=$(tail -3 "$_gp_errfile" | tr '\n' ' ' | sed 's/  */ /g')
        [ -n "$_gp_errfile" ] && rm -f "$_gp_errfile"
        [ -z "$_gp_detail" ] && _gp_detail="$reply"
        [ -z "$_gp_detail" ] && _gp_detail="tidak ada detail tambahan dari provider"
        echo ""
        echo "[step $step] Gagal minta respons dari AI, berhenti. Detail:"
        echo "$_gp_detail"
        # Pastikan checkpoint benar-benar disimpan sebelum mengklaim "tersimpan"
        # (sebelumnya pesan dicetak tanpa memanggil _ai_agent_checkpoint_save).
        if [ -n "$checkpoint_file" ]; then
            _ai_agent_checkpoint_save "$checkpoint_file" "$goal" "$step" "$msgfile" 2>/dev/null || true
            if [ -f "$checkpoint_file" ]; then
                echo "[checkpoint tersimpan: $(basename "$checkpoint_file" .json) -- lanjut lewat 'ai agent --resume $(basename "$checkpoint_file" .json)']"
            else
                echo "[checkpoint gagal disimpan -- resume mungkin tidak tersedia]"
            fi
        fi
        block_reason="LLM/provider request gagal (cek API key atau jalankan 'ai deps'). Detail: ${_gp_detail:0:200}"
        return 1
    fi
    [ -n "$_gp_errfile" ] && rm -f "$_gp_errfile" 2>/dev/null

    pdir=$(_ai_agent_parse "$reply")
    thought=$(<"$pdir/thought")
    tool=$(<"$pdir/tool")
    args=$(<"$pdir/args")
    done_flag=$(<"$pdir/done")
    local compat_msg=""
    [ -f "$pdir/compat" ] && compat_msg=$(<"$pdir/compat")
    rm -rf "$pdir"

    if [ "$AI_VERBOSE" = "1" ] && [ -n "$compat_msg" ]; then
        echo "  [AGENT][COMPAT] $compat_msg"
    fi

    if [ -z "$thought" ] && [ -z "$tool" ] && [ "$done_flag" != "true" ]; then
        echo "[error: agent balas format JSON gak valid, berhenti. Raw: $reply]"
        block_reason="AI balas format JSON gak valid (step $step)"
        return 1
    fi
    return 0
}
