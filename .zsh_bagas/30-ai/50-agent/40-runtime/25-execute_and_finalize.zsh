# ============================================================
#  30-ai/50-agent/40-runtime/25-execute_and_finalize.zsh — pre-loop setup + execute + finalize
#  (split out of the old monolithic 30-ai/50-agent/40-runtime.zsh)
# ============================================================

# Everything from the battery/wakelock pre-flight through the final
# `_ai_agent_finalize` call and cleanup. Reads $goal/$msgfile/
# $checkpoint_file/$step_offset/$run_slug/$yolo/$no_review (caller
# locals, dynamic scope). $_ai_prev_yolo_set/$_ai_prev_yolo_value are
# purely internal to this block in the original too, so they're now
# `local` to this helper instead of being declared way up in aiagent().
# Returns the same status aiagent() itself should return.
_ai_agent_run_execution() {
    local _ai_prev_yolo_set=0 _ai_prev_yolo_value=""

# v-fix (bug #52 & #54 audit): cek baterai dulu (loop ini bisa makan
# waktu berapa menit), lalu pasang wake-lock buat SELURUH sisa fungsi
# -- `always{}` mastiin wake-lock ke-release walau loop berhenti
# gara-gara error/return awal, bukan cuma di jalur sukses biasa.
if ! _ai_battery_check; then
    rm -f "$msgfile"
    return 1
fi
_ai_wakelock_acquire

if (( ${+AI_AGENT_YOLO_MODE} )); then
    _ai_prev_yolo_set=1
    _ai_prev_yolo_value="$AI_AGENT_YOLO_MODE"
fi
# Establish one explicit runtime context shared by the tool/policy layer.
# It is shell-local state, never exported to subprocesses.
local agent_project_root
agent_project_root=$(_ai_project_root) || {
    _ai_wakelock_release
    rm -f -- "$msgfile"
    return 1
}
_ai_agent_context_begin "$run_slug" "$agent_project_root" "$yolo"

local step=$step_offset reply thought tool args done_flag output pdir chat_status
local last_failed_tool="" last_failed_args="" same_fail_count=0 commands_run=0
local max_step=$(( AI_AGENT_MAX_STEPS + step_offset ))
# Task 12.2: timestamp update notifikasi progress terakhir -- dipakai
# buat rate-limit (AI_NOTIFY_MIN_INTERVAL_SEC) biar step yang cepat
# banget berturut-turut gak spam update notifikasi. 0 = belum pernah
# kirim, jadi step pertama SELALU langsung kirim.
local -i last_notify_ts=0
# Task 1.6: alasan singkat buat box BLOCKED di akhir -- diisi TEPAT
# di titik yang sama dengan echo "[berhenti: ...]" yang udah ada di
# tiap jalur keluar loop (bukan logic baru, cuma nyimpen teks yang
# emang udah dicetak biar bisa dipakai lagi di box akhir).
local block_reason=""
# FIX BUG-2: run_slug & runs_logfile dideklarasikan di luar loop.
# run_slug sudah di-set di branch resume/new di atas; fallback ke
# slug dari goal kalau karena alasan tertentu belum ter-set.
[ -z "${run_slug:-}" ] && local run_slug=$(_ai_agent_slug "$goal")
local runs_logfile="$AI_TOOL_RUNS_DIR/${run_slug}.jsonl"
mkdir -p "$AI_TOOL_RUNS_DIR"

# Explicit execution state boundary. The execution engine and finalizer
# communicate through this directory rather than hidden dynamic locals.
local state_dir
state_dir=$(mktemp -d "${TMPDIR:-/tmp}/bagas-agent.XXXXXX") || {
    _ai_wakelock_release
    rm -f -- "$msgfile"
    _ai_agent_context_end
    return 1
}
chmod 700 "$state_dir" 2>/dev/null || true

# Cancellation is cooperative: SIGINT/SIGTERM marks the private run state;
# the executor observes it between model/tool operations and finalizes
# through the normal BLOCKED + cleanup path.
trap 'printf "%s\n" "1" >| "$state_dir/cancelled" 2>/dev/null' INT TERM
rm -f -- "$state_dir/cancelled"

local exec_status=0
{
    _ai_agent_execute_loop "$state_dir" "$msgfile" "$checkpoint_file" "$goal" \
        "$step_offset" "$run_slug" "$runs_logfile" "$max_step"
    exec_status=$?
} always {
    _ai_wakelock_release
}
if [ "$exec_status" -ne 0 ]; then
    # v-fix (bug #4 audit): jangan timpa block_reason yang udah diisi
    # sama loop (mis. detail kegagalan LLM/provider) dengan pesan
    # generik "status N" -- cuma pakai fallback generik kalau memang
    # gak ada detail apa pun yang tersedia dari path chat/request.
    local _finalize_reason=""
    [ -s "$state_dir/block_reason" ] && _finalize_reason=$(<"$state_dir/block_reason")
    if [ -n "$_finalize_reason" ]; then
        echo "[agent execution berhenti: $_finalize_reason]"
    else
        _finalize_reason="LLM/provider request gagal (cek API key atau jalankan 'ai deps'). Detail: internal status $exec_status"
        echo "[agent execution gagal internal: status $exec_status]"
    fi
    printf '%s\n' "$_finalize_reason" >| "$state_dir/block_reason"
    printf '%s\n' "0" >| "$state_dir/step"
    printf '%s\n' "false" >| "$state_dir/done"
    : >| "$state_dir/thought"
    : >| "$state_dir/touched_files"
    : >| "$state_dir/changed_files"
    printf '%s\n' "BLOCKED" >| "$state_dir/lifecycle_state"
fi

_ai_agent_finalize "$state_dir" "$checkpoint_file" "$goal" "$msgfile" \
    "$no_review" "$yolo" "$run_slug"
local finalize_status=$?
local final_step="0"
[ -f "$state_dir/step" ] && final_step=$(<"$state_dir/step")
rm -rf -- "$state_dir"
rm -f -- "$msgfile"
_ai_notify "AI Agent selesai" "$goal"
_ai_log "agent" "$goal" "selesai dalam $final_step step (yolo=$yolo)" 2>/dev/null || true
_ai_agent_context_end
if [ "$_ai_prev_yolo_set" -eq 1 ]; then
    typeset -g AI_AGENT_YOLO_MODE="$_ai_prev_yolo_value"
else
    unset AI_AGENT_YOLO_MODE
fi
return "$finalize_status"
}
