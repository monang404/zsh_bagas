# ============================================================
#  30-ai/20-presentation/15-reasoning_display.zsh — _ai_agent_reasoning_display — ringkas field 'thought' jadi maks 3 baris
#  (split out of the old monolithic 30-ai/50-agent/20-presentation.zsh)
# ============================================================

# Task 1.4 (fase1_ui_ux_overhaul): ringkas field 'thought' (reasoning
# singkat dari reply JSON LLM -- kontrak {thought,tool,args,done} yang
# udah ada, BUKAN reasoning engine baru) jadi MAKSIMAL 3 baris buat
# ditampilin lewat _ai_ui_line icon ◌. Murni presentasi -- gak ngubah
# gimana LLM di-prompt (sysprompt "penalaran singkat" di atas TETAP
# sama), cuma motong tampilannya kalau ternyata kepanjangan.
# Return 1 (gak nge-print apa-apa) kalau thought kosong, biar caller
# gak nampilin baris reasoning kosong yang ganggu.
_ai_agent_reasoning_display() {
    # Never leak internal assignments if caller has global xtrace enabled
    # (same defensive pattern used elsewhere in 30-ai, e.g. 10-core/15-spinner.zsh).
    setopt localoptions noxtrace

    local raw="$1"
    raw="${raw## }"
    raw="${raw%% }"
    [ -z "$raw" ] && return 1

    local -a items
    if [[ "$raw" == *$'\n'* ]]; then
        # thought udah multi-baris (LLM nulis list bernomor dsb) --
        # pecah apa adanya per baris.
        items=(${(f)raw})
    else
        # thought 1 paragraf -- pecah per kalimat (". "/"! "/"? ") jadi
        # pseudo-langkah, biar reasoning panjang tetap kekompres jadi
        # beberapa poin, bukan 1 baris raksasa yang di-cut paksa.
        #
        # v-fix (BUG#1 audit): DUA bug ketemu di sini sekaligus:
        #  1) "?" di pattern LHS ("? ") itu bukan literal question-mark
        #     kalau gak di-escape -- di zsh glob, "?" adalah wildcard
        #     "1 char apa aja". Jadi "${tmp//? /...}" match SETIAP
        #     [char][spasi], bukan cuma "?[spasi]" beneran -- itu penyebab
        #     korupsi "Membac?...main.p?...dul?..." di bug report (tiap
        #     kata kepotong 1 huruf terakhir + spasi ketimpa). Fix: escape
        #     jadi "\? " biar "?" diperlakukan literal.
        #  2) "$'\n'" di sisi REPLACEMENT gak pernah ke-expand jadi newline
        #     beneran selama dia nested di dalam string yang udah double-
        #     quoted (assignment "${tmp//pat/repl}" itu sendiri dalam
        #     quotes) -- zsh cuma parse ANSI-C quoting $'...' di posisi
        #     awal word, BUKAN di tengah string yang udah di-quote. Hasilnya
        #     malah nyisipin 6 karakter literal `$`,`'`,`\`,`n`,`'` ke
        #     output (bukan newline), makanya reasoning gak pernah kepecah
        #     per kalimat sama sekali -- cuma numpuk sampah "$'\n'" di
        #     tengah kalimat lalu ke-truncate di 76 char. Fix: simpan
        #     newline asli ke variable ($nl=$'\n') DULU, baru dipakai di
        #     replacement -- referensi $nl di dalam quotes itu ekspansi
        #     parameter biasa (udah berisi byte newline asli), bukan
        #     parsing ANSI-C quote lagi, jadi aman.
        local nl=$'\n'
        local tmp="$raw"
        tmp="${tmp//. /.$nl}"
        tmp="${tmp//! /!$nl}"
        tmp="${tmp//\? /?$nl}"
        items=(${(f)tmp})
    fi

    local -a clean
    local it
    for it in "${items[@]}"; do
        it="${it## }"
        it="${it%% }"
        [ -n "$it" ] && clean+=("$it")
    done

    # v-fix (real bug, found while investigating the "2...." truncation
    # report): when the model writes a numbered list with the marker and
    # its content on separate lines ("1.\n  Analisis: ...\n2.\n  ..."),
    # each becomes its own array item after the split above. If a bare
    # marker like "2." lands as the LAST item kept by the 3-item
    # truncation below, line 87's "..." gets appended straight to it,
    # producing the garbled "2...." fragment from the bug report -- not
    # data corruption, just truncation landing on an empty header. Fix:
    # merge a bare "N." marker with the line right after it into one
    # logical item BEFORE truncation, so truncation always keeps
    # (marker + content) together or drops the pair entirely.
    local -a merged
    local -i ci=1 cn=${#clean[@]}
    while (( ci <= cn )); do
        local cur="${clean[$ci]}"
        if [[ "$cur" =~ ^[0-9]+\.$ ]] && (( ci < cn )); then
            merged+=("$cur ${clean[$((ci + 1))]}")
            (( ci += 2 ))
        else
            merged+=("$cur")
            (( ci += 1 ))
        fi
    done
    items=("${merged[@]}")
    [ "${#items[@]}" -eq 0 ] && return 1

    local truncated=0
    if [ "${#items[@]}" -gt 3 ]; then
        items=("${items[1]}" "${items[2]}" "${items[3]}")
        truncated=1
    fi

    # v-fix (UI polish): potongan 76-char dulu asal cut di tengah kata
    # ("...kebutuha…" dari kata "kebutuhan") -- kesannya berantakan.
    # Sekarang cari spasi terakhir SEBELUM batas 76 char, potong di
    # situ; kalau gak ada spasi sama sekali dalam 76 char pertama
    # (satu kata super panjang, jarang tapi mungkin), baru fallback ke
    # hard-cut seperti sebelumnya biar box tetap gak jebol lebarnya.
    local i n=${#items[@]}
    for (( i = 1; i <= n; i++ )); do
        local line="${items[$i]}"
        if [ "${#line}" -gt 76 ]; then
            local head="${line[1,76]}"
            local cut="${head%% *}"
            if [ "${#head}" -gt "${#cut}" ]; then
                line="${head% *}…"
            else
                line="${head}…"
            fi
        fi
        items[$i]="$line"
    done
    [ "$truncated" -eq 1 ] && items[$n]="${items[$n]}..."

    local out="${items[1]}"
    for (( i = 2; i <= n; i++ )); do
        out="$out
  ${items[$i]}"
    done
    echo "$out"
    return 0
}

