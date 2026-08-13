# CLI inspection helpers are intentionally side-effect limited to their output paths.

_ai_agent_list_checkpoints() {
    mkdir -p "$AI_AGENT_CHECKPOINT_DIR"
    local -a cps=("$AI_AGENT_CHECKPOINT_DIR"/*.json(N))
    if [ ${#cps[@]} -eq 0 ]; then
        echo "Gak ada checkpoint aiagent yang belum selesai."
        return 0
    fi
    local cf g s
    for cf in "${cps[@]}"; do
        g=$(jq -r '.goal' "$cf" 2>/dev/null)
        s=$(jq -r '.step' "$cf" 2>/dev/null)
        echo "$(basename "$cf" .json)  (step $s) -- $g"
    done
}

_ai_agent_list_logs() {
    mkdir -p "$AI_TOOL_RUNS_DIR"
    local -a logs=("$AI_TOOL_RUNS_DIR"/*.jsonl(N))
    if [ ${#logs[@]} -eq 0 ]; then
        echo "Gak ada log aiagent."
        return 0
    fi
    local lf steps
    for lf in "${logs[@]}"; do
        steps=$(wc -l < "$lf" | tr -d ' ')
        echo "$(basename "$lf" .jsonl)  ($steps step)"
    done
}

_ai_agent_show_log() {
    local slug="$2"
    # Task 1.3: flag opsional "--full" -- terminal saat eksekusi cuma
    # nampilin ringkasan ✓/✗, tapi output PENUH tiap step tetap ada
    # di jsonl (field "output", lihat _ai_agent_result_summary caller)
    # dan bisa dibuka lewat sini kalau user butuh detail lengkap.
    local show_full=0
    [[ "$3" == "--full" || "$2" == "--full" ]] && show_full=1
    [[ "$slug" == "--full" ]] && slug="$2"
    local logfile="$AI_TOOL_RUNS_DIR/${slug}.jsonl"
    if [ ! -f "$logfile" ]; then
        echo "Log '$slug' gak ketemu. 'ai agent --list-logs' buat lihat yang ada."
        return 1
    fi
    local steps=0 files=0
    local -A touched
    while read -r line; do
        local step=$(echo "$line" | jq -r '.step // 0' 2>/dev/null)
        local tool=$(echo "$line" | jq -r '.tool // empty' 2>/dev/null)
        local args_sum=$(echo "$line" | jq -r '.args_summary // empty' 2>/dev/null)
        local res=$(echo "$line" | jq -r '.result // empty' 2>/dev/null)
        local ft_list=$(echo "$line" | jq -r '.files_touched[] // empty' 2>/dev/null)
        
        echo "[$step] $tool $args_sum -> $res"
        if [ "$show_full" -eq 1 ]; then
            local out_full=$(echo "$line" | jq -r '.output // empty' 2>/dev/null)
            if [ -n "$out_full" ]; then
                echo "$out_full" | sed 's/^/    /'
            fi
        fi
        steps=$((steps+1))
        
        local ft
        for ft in ${(f)ft_list}; do
            [ -n "$ft" ] && touched[$ft]=1
        done
    done < "$logfile"
    files=${#touched[@]}
    local touched_files_str="${(k)touched[@]}"
    echo "$steps step, $files file kesentuh ($touched_files_str)."
    return 0

}

