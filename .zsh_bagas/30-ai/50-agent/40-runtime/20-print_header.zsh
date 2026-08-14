# ============================================================
#  30-ai/50-agent/40-runtime/20-print_header.zsh — aiagent's header box + skills line
#  (split out of the old monolithic 30-ai/50-agent/40-runtime.zsh)
# ============================================================

# Reads $goal/$resume_slug/$yolo/$skillsline (caller locals, dynamic
# scope). Pure output, printed exactly once per run (never inside the
# step loop).
_ai_agent_print_header() {
# Task 1.2 + Phase 1 (audit.md §20/§23): header box PERSIS SEKALI di
# sini -- titik ini dilewatin cuma sekali per run (baik goal baru
# maupun --resume), BUKAN di dalam loop `while` di bawah, jadi gak
# bakal keprint ulang tiap step. Goal line dibedain kalau --resume
# ("Resuming: <goal>") biar user sadar ini lanjutan sesi lama, bukan
# run baru dari nol -- pakai _ai_ui_box (Task 1.1/System B primitive)
# buat titel/goal, lalu metadata block (Model/Project/Mode/Skills)
# sebagai baris rata kiri compact di bawahnya (semua nilai SUDAH ada,
# fase ini cuma ganti cara nge-print-nya).
    local hdr_project hdr_model hdr_mode hdr_goal_label
    hdr_project=$(_ai_agent_project_name)
    hdr_model=$(_ai_agent_primary_model)
    if [ "$yolo" -eq 1 ]; then
        hdr_mode="yolo (auto-run, tanpa konfirmasi)"
    else
        hdr_mode="autonomous (konfirmasi tiap command)"
    fi
    if [ $step_offset -eq 0 ]; then
        hdr_goal_label="$goal"
    else
        hdr_goal_label="Resuming: $goal"
    fi

    # "Hero" header: box judul pakai aksen ungu/magenta (lihat
    # _ai_ui_box_accent -- title "AI Agent" otomatis kebagian warna
    # itu), lalu metadata di bawahnya pakai label warna redup
    # (AI_C_MUTED) supaya nilainya yang justru menonjol -- mata
    # langsung lompat ke goal & nilai penting, bukan ke label yang
    # berulang tiap run.
    #
    # Catatan: goal TIDAK diwarnain di dalam body box -- _ai_ui_box
    # ngitung padding dari panjang teks yang dikirim, dan kode warna
    # ANSI ke-hitung sebagai karakter kalau ditempel di situ (bisa
    # bikin box miring). Border/title box sendiri sudah otomatis
    # berwarna lewat _ai_ui_box_accent, jadi ini tetap gak polos-polos
    # amat.
    _ai_ui_box "AI Agent" "$hdr_goal_label"
    echo ""
    echo "  ${AI_C_MUTED}Model${AI_C_RESET}     $hdr_model"
    echo "  ${AI_C_MUTED}Project${AI_C_RESET}   $hdr_project"
    echo "  ${AI_C_MUTED}Mode${AI_C_RESET}      $hdr_mode"
    if [ -n "$skillsline" ]; then
        echo "  ${AI_C_MUTED}Skills${AI_C_RESET}    $skillsline"
    fi
}
