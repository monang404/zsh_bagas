# ============================================================
#  30-ai/60-ui/15-diagnostics.zsh — dependency check / model test
#  (split out of the old monolithic 30-ai/60-ui.zsh)
# ============================================================

ai_check_deps() {
    # tgpt DICABUT dari list ini di v4 — semua call AI sekarang lewat
    # curl langsung (_ai_chat_request/_ai_quick), bukan tgpt lagi, biar
    # bisa dapet fallback multi-model x multi-provider (Groq+Gemini).
    # Kalau masih ke-install gapapa, cuma udah gak dipakai.
    local deps=(gum jq fzf fd bat curl tmux timeout)
    echo "Cek dependency AI environment:"
    for d in "${deps[@]}"; do
        if command -v "$d" >/dev/null; then
            echo "  OK $d"
        elif [ "$d" = "timeout" ]; then
            echo "  MISSING $d   -> pkg install coreutils (dipakai buat smoke-test aiproject)"
        else
            echo "  MISSING $d   -> pkg install $d"
        fi
    done
    # v-fix (bug #47 audit): dulu cuma cek KEBERADAAN tool, gak cek
    # versi minimum -- beberapa filter jq yang dipakai di sini (mis.
    # object construction shorthand, `//` default operator dipakai
    # luas) butuh jq >=1.6. Versi jq yang jauh lebih lama bisa gagal
    # aneh di filter tertentu tanpa pesan yang jelas ke mana akar
    # masalahnya.
    if command -v jq >/dev/null; then
        local jqver
        jqver=$(jq --version 2>/dev/null | sed -E 's/^jq-//')
        local jqmajor="${jqver%%.*}"
        local jqminor="${${jqver#*.}%%[^0-9]*}"
        if [ -n "$jqmajor" ] && { [ "$jqmajor" -lt 1 ] || { [ "$jqmajor" -eq 1 ] && [ "${jqminor:-0}" -lt 6 ]; }; }; then
            echo "  WARNING jq versi $jqver terdeteksi, script ini diasumsikan jq >=1.6 -> pkg upgrade jq"
        fi
    fi
    if command -v curl >/dev/null; then
        local curlver
        curlver=$(curl --version 2>/dev/null | head -1 | awk '{print $2}')
        [ -n "$curlver" ] && echo "  curl versi: $curlver"
    fi
    if command -v termux-notification >/dev/null; then
        echo "  OK termux-api"
        # v-fix (bug #64 audit): dulu cuma cek 1 command (termux-
        # notification) buat nyimpulkan "termux-api OK" -- padahal fitur
        # baru (wake-lock pas aiagent/aiproject, battery check) butuh
        # binary termux-api LAIN yang bisa aja gak semuanya ke-symlink
        # kalau app Termux:API-nya versi lama/belum di-update.
        command -v termux-wake-lock >/dev/null || echo "  WARNING termux-wake-lock gak ketemu -> aiagent/aiproject gak bisa cegah Android nge-throttle proses pas layar mati, update app Termux:API"
        command -v termux-battery-status >/dev/null || echo "  WARNING termux-battery-status gak ketemu -> cek baterai sebelum operasi berat gak jalan, update app Termux:API"
    else
        echo "  MISSING termux-api -> pkg install termux-api (+ install app Termux:API)"
    fi
    if [ -f "$HOME/.secrets.zsh" ]; then
        local perm=$(stat -c "%a" "$HOME/.secrets.zsh" 2>/dev/null)
        [ "$perm" != "600" ] && echo "  WARNING ~/.secrets.zsh permission longgar ($perm) -> chmod 600 ~/.secrets.zsh"
    fi
    if [ -f "$AI_SANITIZE_SCRIPT" ]; then
        echo "  OK auto-repair layer ($AI_SANITIZE_SCRIPT)"
    else
        echo "  MISSING $AI_SANITIZE_SCRIPT -> aicode/aiproject/aifix/aiscrap gak auto-benerin bug literal-\\n"
    fi
    if [ -d "$AI_SKILLS_DIR" ]; then
        echo "  OK skills dir ($AI_SKILLS_DIR, $(ls "$AI_SKILLS_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ') skill)"
    else
        echo "  MISSING skills dir ($AI_SKILLS_DIR) -> aiagent jalan tanpa panduan skill"
    fi
    echo ""
    echo "Cek provider yang aktif (key ke-set):"
    local provider keyvar apikey
    for provider in "${AI_TASK_PROVIDER_ORDER[@]}"; do
        keyvar="${AI_PROVIDERS[${provider}_key_var]}"
        apikey="${(P)keyvar}"
        if [ -n "$apikey" ]; then
            local fast="${AI_MODELS[${provider}_fast]:-${AI_PROVIDERS[${provider}_model]}}"
            local smart="${AI_MODELS[${provider}_smart]:-${AI_PROVIDERS[${provider}_model]}}"
            echo "  OK $provider"
            echo "       fast : $fast"
            echo "       smart: $smart"
        else
            echo "  SKIP $provider ($keyvar gak di-set, jadi gak dipakai buat fallback)"
        fi
    done
}

# v-fix (bug #46 audit): AI_MODELS di-comment "hasil audit manual per
# 2026-08" tapi gak ada mekanisme buat re-audit -- daftar model 429
# (quota abis)/404 (discontinue) gampang basi diam-diam seiring waktu.
# `ai testmodels` ngirim satu request kecil (max_tokens=5) ke SETIAP
# model yang ke-daftar di AI_MODELS dan laporin status HTTP-nya, biar
# bisa dijalanin manual kapan pun (atau dijadwalin lewat alarm/cron)
# alih-alih nunggu ketauan gagal pas lagi butuh beneran.
ai_testmodels() {
    _ai_need_any_key || return 1
    echo "Test ping tiap model di AI_MODELS (request kecil, max_tokens=5)..."
    echo ""
    local key
    for key in "${(k)AI_MODELS[@]}"; do
        local provider="${key%_*}"
        local keyvar="${AI_PROVIDERS[${provider}_key_var]}"
        local apikey="${(P)keyvar}"
        if [ -z "$apikey" ]; then
            echo "  SKIP  $key (key provider '$provider' gak di-set)"
            continue
        fi
        local endpoint="${AI_PROVIDERS[${provider}_endpoint]}"
        local models_str="${AI_MODELS[$key]}"
        local -a model_list
        model_list=(${=models_str})
        local model
        for model in "${model_list[@]}"; do
            local payload http_status
            payload=$(jq -n --arg model "$model" '{model:$model, messages:[{role:"user",content:"hi"}], max_tokens:5}')
            http_status=$(curl -s -S --max-time 15 -o /dev/null -w "%{http_code}" "$endpoint" \
                -H "Authorization: Bearer $apikey" \
                -H "Content-Type: application/json" \
                -d "$payload" 2>/dev/null)
            case "$http_status" in
                200) echo "  OK    $key/$model" ;;
                429) echo "  429   $key/$model  (quota/rate limit abis di akun ini)" ;;
                404) echo "  404   $key/$model  (model gak ada / udah discontinue -> pertimbangkan dicabut dari AI_MODELS)" ;;
                "")  echo "  ??    $key/$model  (curl gagal, cek koneksi)" ;;
                *)   echo "  $http_status   $key/$model" ;;
            esac
        done
    done
    echo ""
    echo "Model yang 404 persisten sebaiknya dicabut, yang 429 dicek lagi nanti -- update manual AI_MODELS di 00-config.zsh."
}
