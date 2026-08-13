# ============================================================
#  30-ai/10-core/20-resource_guards.zsh — network/battery/budget pre-flight guards
#  (split out of the old monolithic 30-ai/10-core.zsh)
# ============================================================

# v-fix (bug #52 audit): gak ada cek baterai sama sekali sebelum
# operasi berat -- device bisa mati mendadak di tengah aiagent/
# aiproject kalau baterai udah kritis dan gak lagi charge. Silent-pass
# (return 0) kalau termux-api gak ada/gagal baca, biar gak nge-block
# device yang emang gak punya termux-api.
_ai_network_is_metered() {
    # Return 0 when no active Wi-Fi is detected (likely metered/cellular),
    # and 1 for Wi-Fi active or unknown. Silent-pass when Termux:API or
    # its JSON tooling is unavailable, matching _ai_battery_check.
    command -v termux-wifi-connectioninfo >/dev/null 2>&1 || return 1
    command -v jq >/dev/null 2>&1 || return 1

    local wifi_json ssid state
    wifi_json=$(timeout 5 termux-wifi-connectioninfo 2>/dev/null)
    [ -n "$wifi_json" ] || return 1

    ssid=$(printf '%s' "$wifi_json" | jq -r '.ssid // empty' 2>/dev/null)
    state=$(printf '%s' "$wifi_json" | jq -r '.supplicant_state // empty' 2>/dev/null)
    [ -n "$ssid" ] || return 0
    [ "$state" = "COMPLETED" ] || return 1
    return 1
}

_ai_data_saver_check() {
    # Task 9.2: warning aktif hanya saat detector mengembalikan 0
    # (likely metered). Return 1 dari detector berarti non-metered atau
    # unknown/unavailable dan harus fail-open tanpa warning.
    [ "${AI_DATA_SAVER_WARN:-1}" = "1" ] || return 0
    _ai_network_is_metered
    local metered=$?
    [ "$metered" -eq 0 ] || return 0

    echo "⚠ Jaringan kemungkinan memakai data seluler/metered. Operasi AI ini bisa memakai data cukup banyak."
    if command -v gum >/dev/null; then
        gum confirm "Tetap lanjut?" || return 1
    else
        local confirm
        if ! read -t 30 "confirm?Tetap lanjut? (y/n) "; then
            echo "Timeout, dianggap batal."
            return 1
        fi
        [[ "$confirm" == "y" || "$confirm" == "Y" ]] || return 1
    fi
    return 0
}

_ai_battery_check() {
    command -v termux-battery-status >/dev/null 2>&1 || return 0
    local status_json pct plugged
    status_json=$(timeout 5 termux-battery-status 2>/dev/null)
    [ -z "$status_json" ] && return 0
    pct=$(echo "$status_json" | jq -r '.percentage // empty' 2>/dev/null)
    plugged=$(echo "$status_json" | jq -r '.plugged // empty' 2>/dev/null)
    [[ "$pct" =~ ^[0-9]+$ ]] || return 0
    if [ "$pct" -lt "${AI_BATTERY_WARN_PCT:-15}" ] && [ "$plugged" != "PLUGGED_AC" ] && [ "$plugged" != "PLUGGED_USB" ] && [ "$plugged" != "PLUGGED_WIRELESS" ]; then
        echo "⚠ Baterai $pct% dan gak lagi charge -- operasi ini bisa makan waktu & baterai lumayan."
        if command -v gum >/dev/null; then
            gum confirm "Tetap lanjut?" || return 1
        else
            local confirm
            if ! read -t 30 "confirm?Tetap lanjut? (y/n) "; then
                echo "Timeout, dianggap batal."
                return 1
            fi
            [[ "$confirm" == "y" ]] || return 1
        fi
    fi
    return 0
}

# v-fix (bug #56 audit): gak ada governor sebelum operasi berat --
# aiproject/aibuild bisa langsung dipanggil beruntun sampai jatah TPM/
# RPM tier gratis abis tanpa peringatan apa pun. Cek total token yang
# udah kepakai HARI INI (dari usage log) dulu, minta konfirmasi kalau
# udah lewat ambang.
_ai_budget_check() {
    [ -f "$AI_USAGE_LOG" ] || return 0
    local today total
    today=$(date +%Y-%m-%d)
    total=$(jq -s --arg t "$today" \
        '[.[] | select(.time | startswith($t))] | map(.usage.total_tokens // 0) | add // 0' \
        "$AI_USAGE_LOG" 2>/dev/null)
    [[ "$total" =~ ^[0-9]+$ ]] || return 0
    if [ "$total" -gt "${AI_DAILY_TOKEN_WARN:-150000}" ]; then
        echo "⚠ Udah pakai ~$total token hari ini (ambang ${AI_DAILY_TOKEN_WARN:-150000}). Operasi project/build biasanya berat."
        if command -v gum >/dev/null; then
            gum confirm "Tetap lanjut?" || return 1
        else
            local confirm
            if ! read -t 30 "confirm?Tetap lanjut? (y/n) "; then
                echo "Timeout, dianggap batal."
                return 1
            fi
            [[ "$confirm" == "y" ]] || return 1
        fi
    fi
    return 0
}
