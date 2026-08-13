# ============================================================
#  30-ai/05-tools/15-tool_search.zsh — grep_search / glob_search
#  (split out of the old monolithic 30-ai/05-tools.zsh)
# ============================================================

_ai_tool_grep_search() {
    local args_json="$1"
    local pattern path glob
    pattern=$(_ai_tool_extract_field "$args_json" pattern)
    path=$(_ai_tool_extract_path "$args_json")
    glob=$(_ai_tool_extract_field "$args_json" glob)

    if [ -z "$pattern" ]; then
        echo "ERROR: grep_search membutuhkan args.pattern (string non-empty). Diterima: $(printf '%s' "$args_json" | _ai_head_c 200)"
        return 1
    fi
    [ -z "$path" ] && path="."

    # Task 3.3 (fase3_index_integration): TAMBAHAN opsional -- kalau
    # pattern adalah identifier sederhana (cuma huruf/angka/underscore,
    # TANPA karakter regex/operator apa pun: . * + ? ^ $ [ ] ( ) { } |
    # \), DAN index project fresh (_ai_index_is_fresh dari Task 3.1,
    # DI-REUSE apa adanya, GAK bikin stale-check kedua), cari nama
    # symbol yang PERSIS SAMA di generate/index/<slug>.json
    # (.files[].symbols[].name) dan tampilkan hasilnya (file+line)
    # LEBIH DULU, SEBAGAI TAMBAHAN di atas hasil grep -- BUKAN
    # pengganti. Grep/rg beneran di bawah TETAP jalan seperti biasa,
    # apa pun hasil bagian ini.
    #
    # SKIP diam-diam (langsung ke grep behavior lama TANPA PERUBAHAN
    # SAMA SEKALI) kalau salah satu ini kejadian:
    #  - pattern BUKAN identifier sederhana (ada karakter regex/
    #    operator -- termasuk pattern kayak foo.*, foo|bar, ^foo$,
    #    foo\(bar)
    #  - index gak ada / stale (_ai_index_is_fresh return 1)
    #  - binary jq gak ada
    #  - baca/parse index gagal (jq error) atau gak ada symbol yang
    #    namanya persis sama
    if [[ "$pattern" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] && command -v jq >/dev/null 2>&1 && _ai_index_is_fresh; then
        local idxfile="$AI_INDEX_DIR/$(_ai_index_slug).json"
        local sym_hits
        sym_hits=$(jq -r --arg name "$pattern" '
            (.files // {}) | to_entries[] as $e |
            (($e.value.symbols // [])[] | select(.name == $name) |
                "\($e.key):\(.line): \(.type) \(.name)")
        ' "$idxfile" 2>/dev/null)
        if [ -n "$sym_hits" ]; then
            echo "[index symbol]"
            printf '%s\n' "$sym_hits"
            echo
        fi
    fi

    # FIX BUG-6 (minor): gunakan argumen literal, bukan eval+string interpolation
    # untuk mencegah command injection dari pattern LLM yang mengandung ;/$()
    if command -v rg >/dev/null 2>&1; then
        if [ -n "$glob" ]; then
            command rg -n -g "$glob" -e "$pattern" "$path" 2>/dev/null | command _ai_head_n "${AI_GREP_MAX_RESULTS:-100}"
        else
            command rg -n -e "$pattern" "$path" 2>/dev/null | command _ai_head_n "${AI_GREP_MAX_RESULTS:-100}"
        fi
    else
        if [ -n "$glob" ]; then
            command find "$path" -name "$glob" -type f -exec grep -Hn -e "$pattern" {} + 2>/dev/null | command _ai_head_n "${AI_GREP_MAX_RESULTS:-100}"
        else
            command grep -rn -e "$pattern" "$path" 2>/dev/null | command _ai_head_n "${AI_GREP_MAX_RESULTS:-100}"
        fi
    fi
}

_ai_tool_glob_search() {
    local args_json="$1"
    local pattern
    pattern=$(_ai_tool_extract_field "$args_json" pattern)
    if [ -z "$pattern" ]; then
        echo "ERROR: glob_search membutuhkan args.pattern (string non-empty). Diterima: $(printf '%s' "$args_json" | _ai_head_c 200)"
        return 1
    fi

    # Task 3.2 (fase3_index_integration): kalau pattern nyari salah
    # satu ekstensi yang KEBETULAN di-index (py/js/ts/go/rs/zsh/sh --
    # daftar ekstensi PERSIS sama kayak yang di-scan aiindex,
    # 46-index.zsh) DAN index-nya fresh (_ai_index_is_fresh dari Task
    # 3.1 -- REUSE apa adanya, GAK bikin stale-check kedua), baca
    # daftar file dari index DULU (gak scan filesystem sama sekali)
    # buat filter -- lebih murah daripada nembak fd/find kalau data-nya
    # udah ada & fresh.
    #
    # FALLBACK ke behavior lama (fd/find) WAJIB kalau salah satu dari
    # ini kejadian -- glob_search TIDAK BOLEH gagal/return kosong cuma
    # gara-gara index bermasalah:
    #  - pattern-nya BUKAN salah satu ekstensi yang di-index (mis.
    #    *.json, *.md, *.yaml, atau pattern non-ekstensi biasa)
    #  - index gak ada / stale (_ai_index_is_fresh return 1)
    #  - binary jq gak ada
    #  - baca/parse index gagal (jq error) atau index-nya gak punya
    #    daftar file sama sekali
    local idx_ext=""
    case "$pattern" in
        *.py)  idx_ext=py  ;;
        *.js)  idx_ext=js  ;;
        *.ts)  idx_ext=ts  ;;
        *.go)  idx_ext=go  ;;
        *.rs)  idx_ext=rs  ;;
        *.zsh) idx_ext=zsh ;;
        *.sh)  idx_ext=sh  ;;
    esac

    if [ -n "$idx_ext" ] && command -v jq >/dev/null 2>&1 && _ai_index_is_fresh; then
        local idxfile="$AI_INDEX_DIR/$(_ai_index_slug).json"
        local -a idx_files
        idx_files=(${(f)"$(jq -r '.files | keys[]?' "$idxfile" 2>/dev/null)"})
        if [ ${#idx_files[@]} -gt 0 ]; then
            # Glob match SEDERHANA (pattern shell biasa lewat [[ ]],
            # BUKAN regex penuh) terhadap tiap path di index.
            local -a matched
            local p
            for p in "${idx_files[@]}"; do
                [[ "$p" == ${~pattern} ]] && matched+=("$p")
            done
            # Daftar file dari index KE-BACA (walau hasil filter-nya
            # bisa kosong kalau emang gak ada yang match) -- ini hasil
            # VALID dari index, jadi return dari sini, JANGAN lanjut
            # ke fd/find (itu bakal scan filesystem, yang justru mau
            # dihindari kalau index-nya fresh).
            if [ ${#matched[@]} -gt 0 ]; then
                printf '%s\n' "${matched[@]}" | _ai_head_n 100
            fi
            return 0
        fi
        # idx_files kosong -> index-nya gak punya daftar file (kosong)
        # atau parse-nya gagal -- jatuh ke fallback di bawah biar aman,
        # BUKAN return kosong yang bisa disalahartikan "gak ketemu".
    fi

    if command -v fd >/dev/null 2>&1; then
        command fd "$pattern" | command _ai_head_n 100
    else
        command find . -name "*${pattern}*" 2>/dev/null | command _ai_head_n 100
    fi
}
