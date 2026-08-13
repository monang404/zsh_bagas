# ============================================================
#  30-ai/60-ui/25-research.zsh — airesearch / aidev
#  (split out of the old monolithic 30-ai/60-ui.zsh)
# ============================================================

# ─── Standalone researcher wrapper (Task 7.3) ─────────────────────
#
# Thin wrapper saja: validasi goal -> runner researcher existing ->
# tampilkan hasil terstruktur. Tidak lewat aiagent(), tidak membuat
# runner/permission system baru.
airesearch() {
    local goal="$*"
    if [ -z "$goal" ]; then
        echo "Usage: ai research <goal>"
        return 1
    fi

    local result rc
    result=$(_ai_subagent_run researcher "$goal")
    rc=$?

    printf '%s\n' "$result"
    return "$rc"
}

aidev() {
    local proj="${1:-$(basename "$PWD")}"
    # v-fix (bug #39 audit): nama folder yang jadi tmux session name
    # dulu dipake mentah dari basename $PWD -- folder dengan karakter
    # yang tmux anggap spesial di nama session (titik dua, titik, spasi,
    # dst) bikin `tmux new-session -s` gagal/aneh. Sanitize dulu, mirip
    # pola _ai_project_slug.
    proj=$(echo "$proj" | tr -cs 'A-Za-z0-9_-' '_' | sed -e 's/^_//' -e 's/_$//')
    [ -z "$proj" ] && proj="workspace"
    if tmux has-session -t "$proj" 2>/dev/null; then
        tmux attach -t "$proj"
        return
    fi
    tmux new-session -d -s "$proj" -n main
    tmux send-keys -t "$proj:main" "v ." C-m
    tmux split-window -h -t "$proj:main"
    tmux send-keys -t "$proj:main.1" "clear" C-m
    tmux split-window -v -t "$proj:main.1"
    tmux send-keys -t "$proj:main.2" "echo 'Pane AI siap. Coba: ai session start $proj'" C-m
    tmux select-pane -t "$proj:main.0"
    tmux attach -t "$proj"
}
