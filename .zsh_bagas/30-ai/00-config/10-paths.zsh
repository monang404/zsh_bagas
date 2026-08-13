# ============================================================
#  30-ai/00-config/10-paths.zsh — runtime output paths ($AI_GENERATE_DIR dan turunannya)
#  (split out of the old monolithic 30-ai/00-config.zsh)
# ============================================================

# Semua OUTPUT/data runtime (bukan config) ngumpul di satu tempat:
# $ZSH_BAGAS/generate/. Folder ini di-gitignore (lihat .gitignore),
# jadi biarpun ~/.zsh_bagas di-git-init buat versioning config, isi
# generate/ (project hasil aicode, log, sesi, plan, prompt) gak ikut
# ke-commit -- cuma path-nya doang yang nyatu, historinya tetap kepisah.
AI_GENERATE_DIR="$ZSH_BAGAS/generate"
CODE_DIR="$AI_GENERATE_DIR/aicode"
AI_SANITIZE_SCRIPT="$ZSH_BAGAS/30-ai/scripts/ai_code_sanitize.py"
AI_EXTRACT_SCRIPT="$ZSH_BAGAS/30-ai/scripts/ai_extract.py"
AI_LOG_DIR="$AI_GENERATE_DIR/logs"
AI_SESSION_DIR="$AI_GENERATE_DIR/sessions"
AI_HISTORY_LOG="$AI_LOG_DIR/history.jsonl"
AI_USAGE_LOG="$AI_LOG_DIR/usage.jsonl"
AI_PLAN_DIR="$AI_GENERATE_DIR/plans"
AI_PROMPT_DIR="$AI_GENERATE_DIR/prompts"
AI_CACHE_DIR="$AI_GENERATE_DIR/cache"
AI_CACHE_TTL_SECONDS=3600

