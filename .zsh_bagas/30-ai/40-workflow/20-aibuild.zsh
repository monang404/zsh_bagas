# ============================================================
#  30-ai/40-workflow/20-aibuild.zsh — aibuild — aispec + aiproject berturut-turut
#  (split out of the old monolithic 30-ai/40-workflow.zsh)
# ============================================================

aibuild() {
    _ai_need_any_key || return 1
    if [ -z "$1" ]; then
        echo "Usage: ai build [-o nama_folder] <deskripsi aplikasi>"
        return 1
    fi
    # v-fix (bug #52 & #56 audit): aibuild = aispec + aiproject berturut-
    # turut, jadi paling berat dari semua subcommand -- cek baterai &
    # budget di awal ("[1/2]" spec) SEBELUM masuk tahap generate project
    # yang jauh lebih mahal, biar user gak nunggu spec kelar dulu baru
    # ketolak di step berikutnya.
    _ai_battery_check || return 1
    _ai_budget_check || return 1
    local project_name=""
    if [[ "$1" == "-o" ]]; then
        project_name="$2"
        shift 2
    fi
    local task=$(_ai_resolve_prompt "$@")
    [ -z "$task" ] && { echo "Deskripsi aplikasi kosong."; return 1; }
    if [ -z "$project_name" ]; then
        project_name=$(echo "$task" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '_' | cut -c1-40)
    fi
    _ai_data_saver_check || return 1

    mkdir -p "$AI_PROMPT_DIR"
    local slug=$(echo "$task" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '_' | cut -c1-40)
    local specfile="$AI_PROMPT_DIR/${slug}_spec_$(_ai_ts).txt"
    local msgfile=$(mktemp)
    jq -n --arg p "$AI_SPEC_SYSPROMPT" \
        --arg t "Deskripsi aplikasi: $task" \
        '[{role:"system",content:$p},{role:"user",content:$t}]' > "$msgfile"

    echo "[1/2] Merancang spec aplikasi..."
    local spec
    spec=$(_ai_chat_request "$msgfile" "" smart "${AI_TASK_PROVIDER_ORDER_BIG[*]}")
    local spec_rc=$?
    rm -f "$msgfile"

    # v-fix (bug ditemukan audit lanjutan): baterai/budget udah dicek DI
    # AWAL, sebelum masuk [1/2], persis biar user "gak nunggu spec kelar
    # dulu baru ketolak di step berikutnya" (lihat komentar atas). Tapi
    # kalau [1/2] SENDIRI yang gagal (semua provider/model abis dicoba --
    # _ai_chat_request return 1, stdout kosong karena pesan errornya
    # sengaja diarahkan ke stderr, bukan ikut ke $spec), sebelumnya kode
    # ini tetap nulis $spec (string kosong) ke $specfile dan LANGSUNG
    # lanjut ke [2/2] -- padahal [2/2] (aiproject) itu justru step yang
    # "jauh lebih mahal" (banyak call AI + smoke-test + auto-fix loop)
    # yang pre-check di awal itu coba dihindarin. Efeknya: satu proses
    # generate+test penuh dijalanin dari spec KOSONG, buang budget/waktu
    # persis untuk kasus yang harusnya udah ketolak dari [1/2].
    if [ "$spec_rc" -ne 0 ] || [ -z "$spec" ]; then
        echo "GAGAL: merancang spec aplikasi gagal (provider/model abis dicoba atau balasan kosong). [2/2] dibatalkan, tidak ada project yang di-generate."
        return 1
    fi

    # v-fix (audit lanjutan): zsh `echo` nge-interpret backslash-escape
    # (\n dsb) secara default -- $spec teks hasil AI, kalau ada literal
    # \n di isinya (gampang kejadian di teks yang dihasilkan LLM), `echo`
    # diam-diam ngubahnya jadi newline beneran di $specfile, padahal
    # $specfile ini nantinya DIBACA LAGI sebagai spec sama aiproject
    # (parsing [FILES]/dst) -- korupsi di sini nular ke step berikutnya.
    # printf '%s\n' nulis apa adanya, tanpa interpretasi escape.
    printf '%s\n' "$spec" > "$specfile"
    _ai_log "spec" "$task" "saved to $specfile"

    echo ""
    echo "[2/2] Generate & test project..."
    local AI_DATA_SAVER_WARN=0
    aiproject "$project_name" "$specfile"
}

