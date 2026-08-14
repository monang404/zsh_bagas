# ============================================================
#  30-ai/60-ui/router.zsh — Slash Command Router
#  AI-FIRST UX: menangani semua "/command" dari workspace prompt.
#  Slash commands: /chat /code /fix /scan /agent /details
#                  /config verbosity N  /help  /session [name]
# ============================================================

_AI_ROUTER_ZSH_BAGAS="${ZSH_BAGAS:-$HOME/.zsh_bagas}"

ui_router() {
    local raw="${1:-}"
    shift 2>/dev/null || true

    # Pisahkan command utama dari argumennya
    local cmd="${raw%% *}"
    local args=""
    [[ "$raw" == *" "* ]] && args="${raw#* }"

    # Strip leading "/" jika ada
    cmd="${cmd#/}"

    case "$cmd" in

        # ── Chat / mode shortcuts ─────────────────────────────
        chat)
            if [ -n "$args" ]; then
                aic "$args"
            else
                local m
                m=$(gum input --placeholder "Tanya apa?" 2>/dev/null) || { printf 'Batal.\n'; return; }
                aic "$m"
            fi
            ;;

        code)
            if [ -n "$args" ]; then
                aicode "$args"
            else
                local m
                m=$(gum input --placeholder "Generate kode apa?" 2>/dev/null) || { printf 'Batal.\n'; return; }
                aicode "$m"
            fi
            ;;

        fix)
            if [ -n "$args" ]; then
                aifix "" "$args"
            else
                local f e
                f=$(fd --type f 2>/dev/null | gum filter --placeholder "Pilih file" 2>/dev/null)
                [ -z "$f" ] && { printf 'Batal.\n'; return; }
                e=$(gum write --placeholder "Paste pesan error" 2>/dev/null)
                aifix "$f" "$e"
            fi
            ;;

        scan)    aiscan ;;
        agent)   aiagent "$args" ;;
        index)   aiindex "$args" ;;
        commit)  aicommit ;;
        review)  aireview ;;
        stats)   aistats ;;
        dev)     aidev ;;

        # ── Session ──────────────────────────────────────────
        session)
            if [ -n "$args" ]; then
                _ai_session start "$args"
            else
                local sname
                sname=$(gum input --placeholder "Nama sesi (kosong = main)" 2>/dev/null) || sname="main"
                _ai_session start "${sname:-main}"
            fi
            ;;

        # ── Progressive Disclosure ────────────────────────────
        details)
            source "$_AI_ROUTER_ZSH_BAGAS/30-ai/60-ui/components/disclosure.zsh" 2>/dev/null || true
            if type _ai_detail_show >/dev/null 2>&1; then
                _ai_detail_show
            else
                printf 'Detail log tidak tersedia.\n'
            fi
            ;;

        # ── Verbosity config ──────────────────────────────────
        config)
            # /config verbosity N
            local sub="${args%% *}"
            local val="${args#* }"
            case "$sub" in
                verbosity)
                    source "$_AI_ROUTER_ZSH_BAGAS/30-ai/60-ui/components/verbosity.zsh" 2>/dev/null || true
                    if type ai_verbosity_set >/dev/null 2>&1; then
                        ai_verbosity_set "${val:-1}"
                    else
                        export AI_VERBOSITY="${val:-1}"
                        printf 'AI_VERBOSITY=%s\n' "$AI_VERBOSITY"
                    fi
                    ;;
                *)
                    printf '%sUnknown config key: %s%s\n' "${AI_C_WARN:-}" "$sub" "${AI_C_RESET:-}"
                    ;;
            esac
            ;;

        # ── Command Palette ───────────────────────────────────
        ""|\?)
            source "$_AI_ROUTER_ZSH_BAGAS/30-ai/60-ui/components/palette.zsh" 2>/dev/null || true
            if type ui_palette >/dev/null 2>&1; then
                ui_palette
            fi
            ;;

        help|h)
            _ai_help 2>/dev/null || printf 'Gunakan: ai h\n'
            ;;

        # ── Unknown ───────────────────────────────────────────
        *)
            printf '%sUnknown slash command: /%s%s\n' \
                "${AI_C_WARN:-}" "$cmd" "${AI_C_RESET:-}"
            printf '%sCoba /%shelp%s atau tekan / untuk Command Palette\n' \
                "${AI_C_MUTED:-}" "${AI_C_RESET:-}" "${AI_C_RESET:-}"
            ;;
    esac
}
