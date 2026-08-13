# ============================================================
#  30-ai/30-code/05-code.zsh — aicode
#  (split out of the old monolithic 30-ai/30-code.zsh)
# ============================================================

_AI_CODE_SYSPROMPT="Kamu programmer expert. Tulis kode yang: 1) Semua string tertutup benar. 2) Semua kurung tertutup. 3) Tidak ada syntax error. 4) Selalu tangani edge case & error input/dependency. 5) Langsung bisa dijalankan. 6) Tanpa backtick atau markdown. 7) WAJIB pakai baris baru SUNGGUHAN (tekan enter beneran) buat pisah tiap statement/baris kode — JANGAN PERNAH menulis dua karakter literal backslash+n sebagai pengganti baris baru di luar string; backslash+n cuma boleh muncul kalau memang bagian dari isi string (mis. print(\"a\\nb\"))."


aicode() {
    _ai_need_any_key || return 1
    mkdir -p "$CODE_DIR"
    local output=""
    local prompt=""
    if [[ "$1" == "-o" ]]; then
        output="$CODE_DIR/$2"
        shift 2
        prompt=$(_ai_resolve_prompt "$@")
    else
        prompt=$(_ai_resolve_prompt "$@")
        local slug=$(echo "$prompt" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '_' | cut -c1-40)
        output="$CODE_DIR/${slug}_$(_ai_ts).py"
    fi

    # v-fix (bug #59 audit, P0): dulu `aicode -o <file_yg_udah_ada>`
    # nimpa file existing SENYAP TOTAL -- `> "$output"` mentah tanpa
    # backup atau diff, beda perlakuan sama aipatch yang selalu wajib
    # review. Kalau $output udah ada, generate ke draft dulu, tampilin
    # diff + minta confirm + backup, pakai pola persis sama kayak aipatch
    # (bukan default "generate file baru" lagi begitu targetnya udah ada).
    if [ -f "$output" ]; then
        echo "[$output] sudah ada -- generate draft dulu, direview lewat diff sebelum nimpa (kayak aipatch)."
        local tmpnew raw rc
        tmpnew=$(mktemp) || return 1
        raw=$(_ai_quick "$_AI_CODE_SYSPROMPT" "$prompt" smart "${AI_TASK_PROVIDER_ORDER_BIG[*]}")
        rc=$?
        if [ $rc -ne 0 ] || [ -z "$raw" ]; then
            echo "ERROR: generation gagal (provider exit $rc); file asli tidak disentuh."
            rm -f -- "$tmpnew"
            return ${rc:-1}
        fi
        printf '%s\n' "$raw" | grep -v '```' > "$tmpnew"
        _ai_sanitize_pycode "$tmpnew" || { rm -f -- "$tmpnew"; return 1; }

        if diff -q "$output" "$tmpnew" >/dev/null 2>&1; then
            echo "AI menghasilkan isi yang sama persis dengan $output, gak ada yang berubah."
            rm -f "$tmpnew"
            return 0
        fi

        echo ""
        echo "── Diff yang diusulkan: $output ──"
        diff -u "$output" "$tmpnew" | sed \
            -e "s/^-/$(printf '\033[31m')-/" \
            -e "s/^+/$(printf '\033[32m')+/" \
            -e "s/$/$(printf '\033[0m')/"
        echo "──────────────────────────────"

        local confirm=""
        if command -v gum >/dev/null; then
            gum confirm "Timpa $output dengan hasil di atas?" || { echo "Dibatalkan."; rm -f "$tmpnew"; return 1; }
        else
            if ! read -t 60 "confirm?Timpa $output? (y/n) "; then
                echo "Timeout nunggu konfirmasi, dianggap batal."
                rm -f "$tmpnew"
                return 1
            fi
            [[ "$confirm" != "y" ]] && { echo "Dibatalkan."; rm -f "$tmpnew"; return 1; }
        fi

        local backup="$output.bak.$(_ai_ts)"
        cp "$output" "$backup"
        if ! command mv -f "$tmpnew" "$output"; then
            echo "GAGAL menimpa (mv error). File asli gak berubah, cek $backup."
            rm -f "$backup"
            return 1
        fi
        echo "Diterapkan. Backup: $backup (undo cepat: aiundo \"$output\")"
        _ai_log "code" "$prompt" "overwritten $output (backup: $backup)"
        return 0
    fi

    local raw rc
    raw=$(_ai_quick "$_AI_CODE_SYSPROMPT" "$prompt" smart "${AI_TASK_PROVIDER_ORDER_BIG[*]}")
    rc=$?
    if [ $rc -ne 0 ] || [ -z "$raw" ]; then
        echo "ERROR: generation gagal (provider exit $rc); tidak membuat file kosong."
        return ${rc:-1}
    fi
    printf '%s\n' "$raw" | grep -v '```' > "$output" || { rm -f -- "$output"; return 1; }
    _ai_sanitize_pycode "$output" || { rm -f -- "$output"; return 1; }
    echo "Saved to $output"
    _ai_log "code" "$prompt" "saved to $output"
}
