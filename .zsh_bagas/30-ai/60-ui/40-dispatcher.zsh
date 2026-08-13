# ============================================================
#  30-ai/60-ui/40-dispatcher.zsh — main `ai` command dispatcher
#  (split out of the old monolithic 30-ai/60-ui.zsh)
# ============================================================

_AI_SUBCOMMANDS=(chat long code edit view scan fix run build project scrap ask shell commit review debug research plan prompt spec summarize clip session agent stats log menu deps dev testmodels undo bakclean share index update h)

ai() {
    setopt localoptions noxtrace
    if [ $# -eq 0 ]; then
        _ai_menu
        return
    fi
    local sub="$1"
    case "$sub" in
        --help|-h|help)
            _ai_help
            return
            ;;
    esac
    if [[ " ${_AI_SUBCOMMANDS[*]} " == *" $sub "* ]]; then
        shift
        case "$sub" in
            chat)      aic "$@" ;;
            long)      aicl "$@" ;;
            code)      aicode "$@" ;;
            edit)      aipatch "$@" ;;
            view)      aicat "$@" ;;
            scan)      aiscan ;;
            index)     aiindex "$@" ;;
            fix)       aifix "$@" ;;
            run)       airun "$@" ;;
            build)     aibuild "$@" ;;
            project)   aiproject "$@" ;;
            scrap)     aiscrap "$@" ;;
            ask)       aiask "$@" ;;
            shell)     aish "$@" ;;
            commit)    aicommit ;;
            review)    aireview ;;
            debug)     aidebug "$@" ;;
            research)  airesearch "$@" ;;
            plan)      aiplan "$@" ;;
            prompt)    aiprompt "$@" ;;
            spec)      aispec "$@" ;;
            summarize) aisummarize "$@" ;;
            clip)      aiclip "$@" ;;
            session)   _ai_session "$@" ;;
            agent)     aiagent "$@" ;;
            stats)     aistats ;;
            log)       aih ;;
            menu)      _ai_menu ;;
            deps)      ai_check_deps ;;
            dev)       aidev "$@" ;;
            testmodels) ai_testmodels ;;
            undo)      aiundo "$@" ;;
            bakclean)  aibakclean "$@" ;;
            share)     aishare "$@" ;;
            update)    _ai_update_confirm_pull ;;
            h)         _ai_help ;;
            # v-fix (bug #28 audit): safety net -- kalau _AI_SUBCOMMANDS
            # dan case ini drift (nambah subcommand baru di satu tempat,
            # lupa di tempat lain), dulu command "kedetek valid" tapi gak
            # ngapa-ngapain sama sekali (silent no-op). Sekarang minimal
            # ada pesan error yang jelas, bukan diam total.
            *) echo "Subcommand '$sub' terdaftar di _AI_SUBCOMMANDS tapi belum ada case-nya di ai() -- ini bug internal, bukan salah kamu. Lapor ini." ;;
        esac
    else
        # v-fix (bug #29 audit): dulu subcommand yang typo (mis. "ai
        # comit") langsung nyasar jadi chat call biasa ke LLM TANPA
        # peringatan -- boros token, dan user gak sadar itu jadi API
        # call beneran (bisa aja gak sengaja ngirim data sensitif).
        # Sekarang dicek dulu apakah kata pertama "mirip" (Levenshtein
        # <=2) salah satu subcommand valid, tawarkan koreksi dulu.
        local closest="" closest_dist=999 sc dist
        for sc in "${_AI_SUBCOMMANDS[@]}"; do
            dist=$(_ai_levenshtein "$sub" "$sc")
            if [ "$dist" -lt "$closest_dist" ]; then
                closest_dist=$dist
                closest="$sc"
            fi
        done
        if [ -n "$closest" ] && [ "$closest_dist" -le 2 ] && [ "$closest_dist" -gt 0 ]; then
            local yn
            if read -t 20 "yn?'$sub' bukan subcommand yang dikenal. Maksudnya 'ai $closest'? (y/n, timeout/enter kosong = lanjut sebagai chat biasa) "; then
                if [[ "$yn" == "y" ]]; then
                    ai "$closest" "${@:2}"
                    return $?
                fi
            fi
        fi

        _ai_need_any_key || return 1
        echo ""
        echo "-- AI --"
        _ai_quick "$AI_PERSONA_SHORT" "$*" fast "${AI_TASK_PROVIDER_ORDER_FAST[*]}" "" 1 "chat"
        echo ""
        echo "--"
        echo ""
    fi
}
