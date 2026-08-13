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
    if [ -n "$resume_slug" ]; then
        _ai_ui_box "BAGAS AI AGENT" \
            "Resuming: $goal" \
            "Project: $hdr_project" \
            "Model: $hdr_model" \
            "Mode: $hdr_mode"
    else
        _ai_ui_box "BAGAS AI AGENT" \
            "Goal: $goal" \
            "Project: $hdr_project" \
            "Model: $hdr_model" \
            "Mode: $hdr_mode"
    fi

# Task 1.5: baris compact "skills: ✓ nama1 ✓ nama2 ..." -- CUMA nama
# skill yang ke-load (dari $skillsline, 70-skills.zsh), gak pernah
# isi markdown-nya. Kosong kalau gak ada skill yang match/ketemu
# (mis. pas --resume, atau goal-nya gak nyerempet keyword manapun)
# -- sengaja gak nge-print baris kosong buat kasus itu.
    if [ -n "$skillsline" ]; then
        _ai_ui_line "•" "$skillsline"
    fi
}
