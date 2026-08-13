# ============================================================
#  30-ai/60-ui/45-completion.zsh — levenshtein + zsh tab-completion
#  (split out of the old monolithic 30-ai/60-ui.zsh)
# ============================================================

# v-fix (bug #29 audit): dipakai `ai()` buat nyaranin koreksi kalau
# subcommand yang diketik typo dan hampir nyasar jadi chat call biasa.
# Levenshtein distance sederhana, dua-baris-DP (bukan matriks penuh),
# cukup buat daftar subcommand yang pendek (~26 kata).
_ai_levenshtein() {
    local s1="$1" s2="$2"
    local len1=${#s1} len2=${#s2}
    local -a prev cur
    local i j cost del ins sub m
    for (( j=0; j<=len2; j++ )); do prev[j+1]=$j; done
    for (( i=1; i<=len1; i++ )); do
        cur[1]=$i
        for (( j=1; j<=len2; j++ )); do
            if [[ "${s1[i]}" == "${s2[j]}" ]]; then
                cost=0
            else
                cost=1
            fi
            del=$(( prev[j+1] + 1 ))
            ins=$(( cur[j] + 1 ))
            sub=$(( prev[j] + cost ))
            m=$del
            (( ins < m )) && m=$ins
            (( sub < m )) && m=$sub
            cur[j+1]=$m
        done
        prev=("${cur[@]}")
    done
    echo "${prev[len2+1]}"
}

# tab-completion: `ai <tab>` nunjukin semua subcommand
_ai_complete() {
    _describe 'ai subcommand' _AI_SUBCOMMANDS
}

(( $+functions[compdef] )) && compdef _ai_complete ai
