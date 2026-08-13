# ============================================================
#  30-ai/20-chat/20-session_mgmt.zsh — _ai_session_prune + _ai_session — start/end/prune/list/resume dispatcher
#  (split out of the old monolithic 30-ai/20-chat.zsh)
# ============================================================

_ai_session_prune() {
    local days="${1:-30}"
    [ -d "$AI_SESSION_DIR/archive" ] || return 0
    local -a old_files
    old_files=("$AI_SESSION_DIR"/archive/*.json(N.mh+$((days*24))))
    if [ ${#old_files[@]} -eq 0 ]; then
        return 0
    fi
    local f
    for f in "${old_files[@]}"; do
        rm -f "$f"
    done
    echo "Prune sesi: ${#old_files[@]} archive lebih tua dari $days hari dihapus."
}

_ai_session() {
    if [ $# -eq 0 ]; then
        _ai_session_repl "${AI_CURRENT_SESSION:-main}"
        return $?
    fi
    local action="$1"; shift
    case "$action" in
        start)
            local name="${1:-main}"
            mkdir -p "$AI_SESSION_DIR"
            jq -n --arg p "$AI_PERSONA_LONG" '[{"role":"system","content":$p}]' > "$AI_SESSION_DIR/$name.json" || return 1
            _ai_session_repl "$name"
            ;;
        end)
            local name="${1:-$AI_CURRENT_SESSION}"
            [ -z "$name" ] && { echo "Gak ada sesi aktif."; return 1; }
            mkdir -p "$AI_SESSION_DIR/archive"
            command mv -f "$AI_SESSION_DIR/$name.json" "$AI_SESSION_DIR/archive/${name}_$(_ai_ts).json" 2>/dev/null
            unset AI_CURRENT_SESSION
            echo "Sesi '$name' diakhiri & diarsip."
            # v-fix (bug #33 audit): archive numpuk gak pernah dibersihkan
            # -- auto-prune archive lebih tua dari AI_SESSION_ARCHIVE_DAYS
            # hari tiap kali sesi diakhiri, plus subcommand manual `ai
            # session prune [hari]` buat yang mau jalanin sendiri kapan pun.
            _ai_session_prune "${AI_SESSION_ARCHIVE_DAYS:-30}" 2>/dev/null
            ;;
        prune)
            _ai_session_prune "${1:-${AI_SESSION_ARCHIVE_DAYS:-30}}"
            ;;
        list)
            local -a _ai_session_files
            _ai_session_files=("$AI_SESSION_DIR"/*.json(N))
            (( ${#_ai_session_files[@]} == 0 )) && return 0
            ls "${_ai_session_files[@]}" 2>/dev/null | xargs -n1 basename 2>/dev/null | sed 's/\.json$//'
            ;;
        resume)
            local name="$1"
            [ -f "$AI_SESSION_DIR/$name.json" ] || { echo "Sesi '$name' gak ketemu. 'ai session list' buat lihat yang ada."; return 1; }
            _ai_session_repl "$name"
            ;;
        "")
            _ai_session_repl "${AI_CURRENT_SESSION:-main}"
            ;;
        *)
            local name="${AI_CURRENT_SESSION:-main}"
            [ -f "$AI_SESSION_DIR/$name.json" ] || { mkdir -p "$AI_SESSION_DIR"; jq -n --arg p "$AI_PERSONA_LONG" '[{"role":"system","content":$p}]' > "$AI_SESSION_DIR/$name.json"; }
            _ai_session_ask "$name" "$action $*"
            ;;
    esac
}

