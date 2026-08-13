# ============================================================
#  30-ai/20-chat/15-session_repl.zsh — _ai_session_repl — REPL interaktif multi-turn
#  (split out of the old monolithic 30-ai/20-chat.zsh)
# ============================================================

# True interactive multi-turn terminal chat. The JSON session is the source of
# truth, so every turn automatically carries the previous conversation context.
# No spinner is used: streamed tokens are the progress indicator.
# Ctrl+C during a request cancels that request and returns to this prompt.
# Ctrl+D, /exit, or /quit leaves the REPL.
_ai_session_repl() {
    # REPL UI should remain clean even when caller has xtrace enabled.
    setopt localoptions noxtrace
    local name="${1:-main}" msg rc
    mkdir -p "$AI_SESSION_DIR" || return 1
    local file="$AI_SESSION_DIR/$name.json"
    if [ ! -f "$file" ]; then
        jq -n --arg p "$AI_PERSONA_LONG" '[{"role":"system","content":$p}]' > "$file" || {
            echo "ERROR: gagal membuat session $file" >&2
            return 1
        }
    fi
    export AI_CURRENT_SESSION="$name"

    printf '\nAI session: %s\n' "$name"
    echo "Ketik pesan untuk melanjutkan percakapan."
    echo "/help untuk perintah, /exit untuk keluar."

    while true; do
        printf '\nYou> '
        IFS= read -r msg
        rc=$?
        if [ "$rc" -ne 0 ]; then
            printf '\n'
            # Ctrl+C at the input prompt redraws the prompt; Ctrl+D exits.
            [ "$rc" -eq 130 ] && continue
            break
        fi

        [ -n "$msg" ] || continue

        case "$msg" in
            /exit|/quit|/q)
                printf 'Keluar dari session "%s".\n' "$name"
                return 0
                ;;
            /help|/h)
                cat <<'EOF'
Perintah session:
  /help      tampilkan bantuan
  /history   tampilkan riwayat percakapan
  /clear     hapus context dan mulai dari system prompt
  /name      tampilkan nama session aktif
  /exit      keluar dari session
  /quit      keluar dari session
EOF
                continue
                ;;
            /name)
                printf '%s\n' "$name"
                continue
                ;;
            /history)
                jq -r '.[] | select(.role != "system") | "[" + .role + "] " + .content' "$file" 2>/dev/null ||
                    echo "ERROR: session JSON rusak." >&2
                continue
                ;;
            /clear)
                jq -n --arg p "$AI_PERSONA_LONG" '[{"role":"system","content":$p}]' > "$file.tmp.$$" &&
                    command mv -f "$file.tmp.$$" "$file" ||
                    { rm -f "$file.tmp.$$"; echo "ERROR: gagal menghapus context." >&2; continue; }
                echo "Context session dihapus."
                continue
                ;;
            /*)
                echo "Perintah tidak dikenal. Gunakan /help." >&2
                continue
                ;;
        esac

        _ai_session_ask "$name" "$msg"
        rc=$?
        if [ "$rc" -eq 130 ]; then
            echo "[request dibatalkan]" >&2
        elif [ "$rc" -ne 0 ]; then
            echo "[request gagal, session tetap aktif]" >&2
        fi
    done

    return 0
}

