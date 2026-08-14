# ============================================================
#  30-ai/20-chat/00-quick_chat.zsh — aic/aicl/aish — chat cepat/panjang & shell-helper (streaming via _ai_quick)
#  (split out of the old monolithic 30-ai/20-chat.zsh)
# ============================================================

# ============================================================
#  30-ai/20-chat.zsh — chat cepat/panjang & sesi multi-turn
#  aic, aicl, aish, aiask, aiclip, session (_ai_session*).
# ============================================================


# NOTE v4 + Task 8.2: aic/aish sekarang lewat _ai_quick dalam mode
# streaming. _ai_quick tetap jadi pembungkus request bersama, tetapi mode
# stream memanggil _ai_chat_request_stream secara langsung dan memakai tee
# untuk menangkap full response setelah token tetap mengalir ke terminal.
# aicl/aiask dan caller lain tetap memakai jalur blocking.
# v-fix (real bug): aic/aicl dulu streaming raw ke terminal pakai
# AI_PERSONA_SHORT/LONG (persona agent, kontrak JSON {thought,...}) --
# hasilnya reasoning model ("**Thought**...") nempel jadi satu blok sama
# jawaban tanpa pemisah apapun pas di-stream mentah. Sekarang pindah ke
# blocking (_ai_quick stream=0 -- tetap ada spinner dari jalur blocking
# di 10-core/50-request_blocking.zsh, jadi feedback nunggu gak hilang),
# pakai persona chat khusus yang minta model pisahin lewat marker
# '@@JAWABAN@@', lalu _ai_chat_render motong: reasoning polos di luar,
# jawaban bersih di dalam box. _ai_quick jalur blocking gak nge-log
# sendiri (beda dari jalur stream-nya) makanya _ai_log dipanggil manual
# di sini biar histori 'chat'/'chat-long' gak regresi kehilangan entry.
aic() {
    # Keep this call tree free of inherited xtrace, same as aicl/aish.
    setopt localoptions noxtrace
    _ai_need_any_key || return 1
    local reply rc
    reply=$(_ai_quick "$AI_PERSONA_CHAT_SHORT" "$*" fast "${AI_TASK_PROVIDER_ORDER_FAST[*]}" "" 0)
    rc=$?
    [ -n "$reply" ] && _ai_chat_render "$reply"
    _ai_log "chat" "$*" "$reply"
    return $rc
}

aicl() {
    # Keep the entire public long-chat call tree free of inherited xtrace.
    # localoptions restores the caller's original shell option on return.
    setopt localoptions noxtrace
    _ai_need_any_key || return 1
    
    local usermsg="$*"
    [ -z "$usermsg" ] && return 1

    local steps_str="Outline
Draft
Refinement
Review
Final"
    local -a stages=("Outline" "Draft" "Refinement" "Review" "Final")
    local current_context="Permintaan Asli: $usermsg"
    local combined_results=""
    local stage_result=""
    local i=1
    local rc=0

    # Pastikan ui_timeline tersedia
    type ui_timeline >/dev/null 2>&1 || source "$ZSH_BAGAS/30-ai/60-ui/components/timeline.zsh"

    echo "" >&2

    for stage in "${stages[@]}"; do
        # 1. Update timeline
        ui_timeline "$steps_str" "$i" >&2
        
        # 2. Setup prompt per tahap
        local stage_prompt=""
        case "$stage" in
            "Outline")
                stage_prompt="Buat outline ringkas (3-5 poin utama) untuk menjawab permintaan user berikut. Jangan tulis konten lengkapnya, cukup poin-poin strukturnya saja.\n\n$current_context"
                ;;
            "Draft")
                stage_prompt="Berdasarkan outline berikut, buatlah draft awal konten yang detail dan menyeluruh. Fokus pada kelengkapan informasi.\n\nOutline:\n$current_context"
                ;;
            "Refinement")
                stage_prompt="Perbaiki dan perluas draft berikut agar bahasanya lebih natural, mengalir, dan informasinya padat/akurat.\n\nDraft:\n$current_context"
                ;;
            "Review")
                stage_prompt="Review hasil perbaikan berikut. Apakah sudah menjawab permintaan asli user ('$usermsg')? Jika ada yang kurang, perbaiki. Jika sudah pas, pertajam hasilnya.\n\nKonten:\n$current_context"
                ;;
            "Final")
                stage_prompt="Ini adalah tahap final. Format dan rangkum hasil akhir berikut dengan rapi agar siap dibaca user (gunakan heading/poin yang sesuai, bersihkan teks internal AI, pastikan profesional).\n\nKonten:\n$current_context"
                ;;
        esac

        # 3. Request (menggunakan class smart, stream=0)
        stage_result=$(AI_CURL_TIMEOUT=60 _ai_quick "$AI_PERSONA_CHAT_LONG" "$stage_prompt" smart "${AI_TASK_PROVIDER_ORDER[*]}" "" 0)
        rc=$?

        if [ "$rc" -ne 0 ]; then
            echo "" >&2
            echo "❌ Tahap '$stage' gagal." >&2
            _ai_log "chat-long" "$usermsg" "[GAGAL DI TAHAP $stage]\n\n$combined_results"
            return "$rc"
        fi

        # Sukses
        current_context="$stage_result"
        combined_results+="\n=== TAHAP: $stage ===\n$stage_result\n"
        (( i++ ))
    done

    echo "" >&2

    # 4. Render hasil final
    [ -n "$current_context" ] && _ai_chat_render "$current_context"

    # 5. Log hasil utuh ke histori
    _ai_log "chat-long" "$usermsg" "HASIL FINAL:\n$current_context\n\nPROSES INTERNAL:$combined_results"
    return 0
}

aish() {
    setopt localoptions noxtrace
    _ai_need_any_key || return 1
    _ai_quick "Kamu expert Linux dan Termux. Berikan perintah shell yang tepat, aman, dan langsung bisa dijalankan di Termux Android." "$*" fast "${AI_TASK_PROVIDER_ORDER_FAST[*]}" "" 1 "shell"
}

