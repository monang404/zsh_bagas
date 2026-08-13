# ============================================================
#  30-ai/30-code/00-scrap.zsh — aiscrap
#  (split out of the old monolithic 30-ai/30-code.zsh)
# ============================================================

# ============================================================
#  30-ai/30-code.zsh — generate & perbaiki kode
#  aicode, aifix, airun, aiproject (multi-file + autotest + completeness check), aiscrap.
# ============================================================


# ─── Fungsi AI dasar (tetap, tidak berubah dari v1/v2) ───────

aiscrap() {
    _ai_need_any_key || return 1
    local url="$1"; local task="$2"
    # v-fix (bug #43 audit): validasi scheme URL eksplisit dulu sebelum
    # dipakai requests.get -- sebelumnya string apapun diterima mentah,
    # termasuk skema non-http (file://, dsb) yang gak seharusnya nyentuh
    # jalur "fetch dari web" ini sama sekali.
    if [[ "$url" != http://* && "$url" != https://* ]]; then
        echo "URL harus diawali http:// atau https:// (dapet: ${url:0:40})"
        return 1
    fi
    # v-fix: URL dulu di-interpolate LANGSUNG ke dalam source Python
    # (python3 -c "...'$url'..."), jadi URL yang mengandung tanda kutip
    # bisa merusak sintaks / berpotensi command-injection kalau url-nya
    # datang dari input gak tepercaya. Sekarang dilewatin lewat env var
    # dan dibaca via os.environ di sisi Python, gak pernah nyentuh
    # source code sebagai string literal. requests.get juga dikasih
    # timeout eksplisit biar shell gak hang tanpa batas kalau situs
    # target lambat/gak respons.
    local structure
    structure=$(URL="$url" python3 -c "
import os
import requests
from bs4 import BeautifulSoup

url = os.environ['URL']
r = requests.get(url, headers={'User-Agent': 'Mozilla/5.0'}, timeout=15)
soup = BeautifulSoup(r.text, 'html.parser')
seen = set()
for a in soup.find_all('a', href=True):
    text = a.text.strip()
    cls = str(a.get('class'))
    if len(text) > 30 and cls not in seen:
        seen.add(cls)
        print('class:', cls, '|', text[:50])
" 2>/dev/null | head -10)
    local raw rc reply
    raw=$(_ai_quick "Kamu programmer Python expert. Struktur HTML target: $structure. Tulis kode langsung tanpa backtick. WAJIB pakai baris baru SUNGGUHAN buat pisah tiap statement — JANGAN PERNAH menulis dua karakter literal backslash+n sebagai pengganti baris baru di luar string." "Buat scraper $url: $task" smart "${AI_TASK_PROVIDER_ORDER_BIG[*]}")
    rc=$?
    [ $rc -eq 0 ] || { echo "ERROR: generation scraper gagal (provider exit $rc)"; return $rc; }
    reply=$(printf '%s\n' "$raw" | grep -v '```')
    if [ -f "$AI_SANITIZE_SCRIPT" ]; then
        printf '%s\n' "$reply" | python3 "$AI_SANITIZE_SCRIPT" -
    else
        printf '%s\n' "$reply"
    fi
}
