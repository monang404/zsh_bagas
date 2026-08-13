# ============================================================
#  30-ai/00-config/15-limits.zsh — retry/timeout/session/diff/patch/file size guards + web_fetch guard note
#  (split out of the old monolithic 30-ai/00-config.zsh)
# ============================================================

AI_MAX_RETRIES="${AI_MAX_RETRIES:-1}"
# Hard network timeout for interactive AI requests. Keep independent of max_tokens.
AI_CURL_TIMEOUT="${AI_CURL_TIMEOUT:-45}"
AI_RETRY_DELAY=2
AI_SESSION_MAX_MSGS=30   # trim history sesi biar context gak membengkak
AI_LOG_MAX_LINES=5000    # rotasi otomatis history.jsonl/usage.jsonl (lihat _ai_rotate_log)
AI_DIFF_MAX_CHARS=15000  # guard panjang diff buat aicommit/aireview (lihat _ai_guard_diff)
AI_PATCH_MAX_CHARS=200000  # batas keras diff_content untuk tool patch_file

# v-fix (bug #51 audit): aipatch dulu gak ada guard panjang file sama
# sekali (beda dengan diff yang udah dijaga AI_DIFF_MAX_CHARS) -- file
# gede ngirim isi PENUH ke API tiap kali, boros token & gampang kena
# timeout/413. Di atas limit ini, aipatch nolak jalan kecuali dipaksa
# lewat --force.
AI_FILE_MAX_CHARS=40000

# Rate limit safety config
# AI_PROJECT_MAX_TOKS: max_tokens untuk aiproject/aibuild. Sengaja jauh lebih
# kecil dari 9000 lama karena Groq free tier punya TPM limit ~6000 token/menit
# -- request dengan max_tokens=9000 hampir pasti kena HTTP 413 "Request too
# large" bukan karena balance habis, tapi karena satu request aja udah melebihi
# jatah TPM per menit. 3500 aman bahkan di tier gratis paling ketat.
# Naikkan ke 5000-6000 kalau kamu punya akun Groq paid/Dev tier.
AI_PROJECT_MAX_TOKS=3500


# v-fix (bug #55 audit): dulu gak ada checkpoint sama sekali buat
# aiagent -- kalau proses Termux mati di tengah loop (OOM killer, app
# di-swipe, baterai abis), seluruh konteks percakapan hilang & harus
# ulang dari nol. Progress disimpan di sini tiap step, bisa dilanjut
# lewat 'ai agent --resume <nama>'.
: ${AI_AGENT_CHECKPOINT_DIR:="$AI_GENERATE_DIR/sessions/agent_checkpoints"}

AI_GREP_MAX_RESULTS=100
: ${AI_TOOL_RUNS_DIR:="$AI_SESSION_DIR/agent_runs"}
: ${AI_INDEX_DIR:="$AI_GENERATE_DIR/index"}

# v-fix (bug #65 audit — perluasan tool registry): konstanta buat tool
# baru (delete_file/move_file/git_status/git_diff/web_fetch/todo_*).
# Semua ngikutin pola guard yang sama kayak AI_FILE_MAX_CHARS/
# AI_GREP_MAX_RESULTS -- batas eksplisit, bukan nebak-nebak.
: ${AI_TODO_DIR:="$AI_SESSION_DIR/todos"}
AI_GITDIFF_MAX_CHARS=6000       # guard output git_diff, biar gak flood context diff raksasa
AI_WEBFETCH_MAX_CHARS=8000      # guard hasil web_fetch (sudah di-strip HTML) sebelum masuk context
AI_WEBFETCH_TIMEOUT=15          # detik -- jaringan Termux gampang putus-nyambung (lihat skills/termux.md)
# web_fetch performs URL parsing + DNS/IP validation at runtime.
# String-based host blocklists are intentionally not used as the security boundary.

