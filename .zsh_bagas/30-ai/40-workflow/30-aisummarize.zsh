# ============================================================
#  30-ai/40-workflow/30-aisummarize.zsh — aisummarize — ringkas file/url, chunked kalau panjang
#  (split out of the old monolithic 30-ai/40-workflow.zsh)
# ============================================================

aisummarize() {
    _ai_need_any_key || return 1
    if [ -z "$1" ]; then
        echo "Usage: ai summarize <file|url>"
        return 1
    fi
    local src="$1" content
    if [[ "$src" == http://* || "$src" == https://* ]]; then
        content=$(curl -s --max-time 20 -A "Mozilla/5.0" "$src")
        # v-fix: dulu HTML mentah (tag/script/style ikutan) langsung dikirim
        # ke AI -- boros token, kontradiksi sama tujuan "hemat token".
        # Strip ke plain text pakai BeautifulSoup (pola yang sama dipakai
        # aiscrap), lewat STDIN (bukan interpolasi string) biar aman dari
        # isu yang sama kayak bug injeksi URL di aiscrap. Kalau bs4 gak
        # ada, tetap jalan pakai HTML mentah (fallback, bukan hard-fail).
        if command -v python3 >/dev/null 2>&1 && python3 -c "import bs4" 2>/dev/null; then
            content=$(printf '%s' "$content" | python3 -c "
import sys
from bs4 import BeautifulSoup

html = sys.stdin.read()
soup = BeautifulSoup(html, 'html.parser')
for tag in soup(['script', 'style']):
    tag.decompose()
text = soup.get_text(separator='\n')
lines = [l.strip() for l in text.splitlines() if l.strip()]
print('\n'.join(lines))
" 2>/dev/null)
        fi
    else
        content=$(cat "$src" 2>/dev/null)
    fi
    [ -z "$content" ] && { echo "Gak ada konten buat diringkes (cek file/url)."; return 1; }

    local reply
    if [ ${#content} -gt 12000 ]; then
        echo "Konten panjang (${#content} char), diringkes bertahap per chunk..."
        # v-fix: dulu chunking pakai `fold -w 12000` (potong per KARAKTER
        # mentah, gak peduli tengah kalimat) tanpa overlap sama sekali --
        # tiap chunk kehilangan continuity konteks dari chunk sebelumnya.
        # Sekarang split berbasis PARAGRAF (baris kosong sebagai pemisah)
        # dan tiap chunk baru disisipin overlap ekor chunk sebelumnya biar
        # ringkasannya tetap nyambung.
        local -a paragraphs parts
        # v-fix (bug ditemukan audit lanjutan): sebelumnya "${(f)$(awk
        # 'BEGIN{RS="";ORS="\n\n"}...')}" -- niatnya split per PARAGRAF
        # (blank line jadi pemisah), tapi "(f)" di zsh motong di SETIAP
        # newline tunggal, termasuk newline DI DALAM satu paragraf yang
        # emang beberapa baris. Hasilnya paragraf multi-baris ke-pecah
        # jadi elemen array per-BARIS, bukan per-PARAGRAF -- persis
        # masalah yang katanya mau difix (chunk kepotong di tengah unit
        # teks yang harusnya nyambung), cuma sekarang unitnya "baris"
        # bukan "kalimat mentah" kayak versi fold -w lama. Fix: pisahkan
        # paragraf pakai sentinel byte langka (\x01, gak mungkin muncul
        # di teks biasa) lewat awk ORS, baru split pakai "(ps:...:)"
        # (exact-string split, BUKAN newline-split) biar newline INTERNAL
        # tiap paragraf tetap utuh dalam satu elemen array.
        local _para_raw
        _para_raw=$(echo "$content" | awk 'BEGIN{RS="";ORS="\x01"}{print}')
        paragraphs=("${(@ps:\x01:)_para_raw}")
        local cur="" overlap_chars=300
        local para
        for para in "${paragraphs[@]}"; do
            [ -z "$para" ] && continue
            if [ -n "$cur" ] && [ $(( ${#cur} + ${#para} )) -gt 12000 ]; then
                parts+=("$cur")
                # overlap: ekor chunk sebelumnya ditempel di depan chunk baru
                cur="${cur: -$overlap_chars}

$para"
            else
                if [ -z "$cur" ]; then
                    cur="$para"
                else
                    cur="$cur

$para"
                fi
            fi
        done
        [ -n "$cur" ] && parts+=("$cur")

        local combined=""
        local i=1
        for p in "${parts[@]}"; do
            echo "  chunk $i/${#parts[@]}..."
            local msgfile=$(mktemp)
            jq -n --arg p2 "Ringkes teks ini jadi poin-poin penting, bahasa Indonesia, singkat, tanpa markdown." \
                --arg c "$p" '[{role:"system",content:$p2},{role:"user",content:$c}]' > "$msgfile"
            local s; s=$(_ai_chat_request "$msgfile" "" fast "${AI_TASK_PROVIDER_ORDER_FAST[*]}")
            rm -f "$msgfile"
            combined="$combined
$s"
            i=$((i+1))
        done
        local msgfile2=$(mktemp)
        jq -n --arg p3 "$AI_PERSONA_LONG Gabungkan poin-poin ringkasan berikut jadi satu ringkasan koheren dan gak redundan." \
            --arg c "$combined" '[{role:"system",content:$p3},{role:"user",content:$c}]' > "$msgfile2"
        reply=$(_ai_chat_request "$msgfile2" "" smart "${AI_TASK_PROVIDER_ORDER_SMART[*]}")
        rm -f "$msgfile2"
    else
        local msgfile=$(mktemp)
        jq -n --arg p "$AI_PERSONA_LONG Ringkes konten berikut jadi poin-poin penting." \
            --arg c "$content" '[{role:"system",content:$p},{role:"user",content:$c}]' > "$msgfile"
        reply=$(_ai_chat_request "$msgfile" "" smart "${AI_TASK_PROVIDER_ORDER_SMART[*]}")
        rm -f "$msgfile"
    fi
    echo "$reply"
    _ai_log "summarize" "$src" "$reply"
}
