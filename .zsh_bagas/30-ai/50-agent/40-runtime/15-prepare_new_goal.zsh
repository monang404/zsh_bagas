# ============================================================
#  30-ai/50-agent/40-runtime/15-prepare_new_goal.zsh — new (non-resume) goal setup
#  (split out of the old monolithic 30-ai/50-agent/40-runtime.zsh; sysprompt
#  building and the subagent offer now live in 00-sysprompt.zsh / 05-subagent_offer.zsh)
# ============================================================

# Writes back into the caller's (aiagent) dynamically-scoped locals:
# goal, msgfile, run_slug, checkpoint_file, _AI_AGENT_SESSION_SLUG,
# skillsline. Returns 1 on the usage-error / data-saver-blocked paths
# (caller does `_ai_agent_prepare_new_goal "$@" || return 1`).
_ai_agent_prepare_new_goal() {
    if [ -z "$1" ]; then
        echo "Usage: ai agent [--yolo] [--no-review] <goal>"
        echo "       ai agent --resume <nama_checkpoint>"
        echo "       ai agent --list-checkpoints"
        echo "  --yolo = auto-approve capability yang masuk safe policy."
        echo "           Arbitrary shell / nested interpreter tetap meminta konfirmasi."
        # Task 4.4 (fase4_reviewer_integration): dokumentasiin behavior
        # review otomatis (Task 4.2) + flag --no-review (Task 4.3) di
        # usage text yang sudah ada -- baris --yolo di atas TIDAK
        # dihapus/diubah, cuma nambah baris baru.
        echo "  Setelah task selesai + verifikasi sukses DAN ada file yang"
        echo "  berubah, aiagent otomatis jalanin code review (aireview)"
        echo "  sekali di ringkasan akhir (bagian 'Review'). Informational"
        echo "  doang -- gak nunggu jawaban, gak auto-lanjut edit lagi."
        echo "  --no-review = skip review otomatis ini (hemat token/waktu)."
        return 1
    fi
    goal="$*"
    msgfile=$(mktemp)
    run_slug=$(_ai_agent_slug "$goal")
    checkpoint_file="$AI_AGENT_CHECKPOINT_DIR/${run_slug}.json"
    # FIX BUG-8 companion + BUG-7: set session slug setelah goal diketahui
    _AI_AGENT_SESSION_SLUG="$run_slug"
    # FIX BUG-1: load project permissions di sini (cwd saat agent dipanggil)
    _ai_perm_load_project
    _ai_data_saver_check || { rm -f "$msgfile"; return 1; }

    # v3.1: konteks project (auto-scan kalau belum pernah) + skill yang
    # relevan sama goal ini -- dua-duanya opsional/silent kalau modulnya
    # gak ke-load, biar agent tetap jalan walau file baru belum ditaruh.
    local projectctx="" skillctx=""
    command -v _ai_project_context >/dev/null 2>&1 && projectctx=$(_ai_project_context 2>/dev/null)
    command -v _ai_load_skills >/dev/null 2>&1 && skillctx=$(_ai_load_skills "$goal" 2>/dev/null)
    # Task 1.5: nama skill doang (bukan isi markdown) buat ditampilin
    # compact -- helper terpisah (_ai_skills_display_line, 70-skills.zsh)
    # yang cuma cek file exist, gak pernah `cat` isi skill.
    command -v _ai_skills_display_line >/dev/null 2>&1 && skillsline=$(_ai_skills_display_line "$goal" 2>/dev/null)
    local sysprompt
    sysprompt=$(_ai_agent_build_sysprompt "$goal" "$projectctx" "$skillctx")

    jq -n --arg p "$sysprompt" --arg g "Goal: $goal" \
        '[{role:"system",content:$p},{role:"user",content:$g}]' > "$msgfile"

    _ai_agent_offer_subagent "$goal"
}
