# ============================================================
#  30-ai/06-permissions/00-config.zsh — defaults (AI_PERM_*) + _ai_perm_load_project
#  (split out of the old monolithic 30-ai/06-permissions.zsh)
# ============================================================

# ============================================================
#  30-ai/06-permissions.zsh — Granular permissions untuk aiagent
#
#  CATATAN: _ai_perm_load_project() HARUS dipanggil di dalam
#  aiagent() bukan di top-level file ini, karena path project
#  baru diketahui saat agent dijalankan (bukan saat shell start).
# ============================================================

: ${AI_PERM_WRITE_MODE:="ask_once_per_file"}
: ${AI_PERM_SHELL_MODE:="ask_always"}
: ${AI_PERM_PROCESS_MODE:="ask_always"}
: ${AI_PERM_ALLOW_OUTSIDE_PROJECT:=0}

# FIX BUG-1: dipanggil dari dalam aiagent(), bukan saat module di-load.
# Dengan begini, .aiagent/permissions.zsh di cwd project yang benar
# yang ter-source, bukan cwd saat shell pertama kali dijalankan.
_ai_perm_load_project() {
    # Project-local shell config is executable code and therefore untrusted.
    # It is never sourced implicitly merely because an agent entered a repo.
    # Opt in explicitly with AI_ALLOW_PROJECT_CONFIG=1.
    if [[ "${AI_ALLOW_PROJECT_CONFIG:-0}" == "1" && -f ".aiagent/permissions.zsh" ]]; then
        source "./.aiagent/permissions.zsh"
    fi
}


