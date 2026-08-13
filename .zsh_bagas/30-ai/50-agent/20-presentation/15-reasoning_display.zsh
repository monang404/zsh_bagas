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
    items=("${clean[@]}")
    [ "${#items[@]}" -eq 0 ] && return 1

    local truncated=0
    if [ "${#items[@]}" -gt 3 ]; then
        items=("${items[1]}" "${items[2]}" "${items[3]}")
        truncated=1
    fi

    local i n=${#items[@]}
    for (( i = 1; i <= n; i++ )); do
        local line="${items[$i]}"
        if [ "${#line}" -gt 76 ]; then
            line="${line[1,76]}…"
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

