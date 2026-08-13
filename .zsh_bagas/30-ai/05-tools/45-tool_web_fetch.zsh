# ============================================================
#  30-ai/05-tools/45-tool_web_fetch.zsh — web_fetch
#  (split out of the old monolithic 30-ai/05-tools.zsh)
# ============================================================

# ─── Tool Baru: web_fetch ─────────────────────────────────────
# Ambil isi halaman web via curl, HTML di-strip jadi teks polos (biar
# gak buang token buat tag). Level "shell" (bukan readonly) karena ini
# akses jaringan keluar -- tetap minta konfirmasi tiap panggilan sama
# kayak run_command, PLUS guard SSRF sederhana berbasis nama host
# (nolak localhost/IP privat/link-local) biar agent gak dipancing
# nembak service internal device sendiri.
_ai_tool_web_fetch() {
    local args_json="$1" url check raw rc text
    url=$(_ai_tool_extract_field "$args_json" url link href)
    [ -n "$url" ] || { echo "ERROR: web_fetch membutuhkan args.url (string non-empty). Diterima: $(printf '%s' "$args_json" | _ai_head_c 200)"; return 1; }
    [[ "$url" == http://* || "$url" == https://* ]] || { echo "ERROR: cuma skema http/https yang diizinkan"; return 1; }
    command -v curl >/dev/null 2>&1 || { echo "ERROR: curl gak ketemu di PATH"; return 1; }

    check=$(URL="$url" python3 - <<'PY'
import os, socket, sys, ipaddress
from urllib.parse import urlsplit
u = urlsplit(os.environ["URL"])
if u.scheme not in ("http", "https") or not u.hostname or u.username or u.password:
    print("DENY: invalid URL authority")
    sys.exit(1)
try:
    infos = socket.getaddrinfo(u.hostname, u.port or (443 if u.scheme == "https" else 80), type=socket.SOCK_STREAM)
except Exception:
    print("DENY: DNS resolution failed")
    sys.exit(1)
public = []
for info in infos:
    ip = ipaddress.ip_address(info[4][0])
    if ip.is_private or ip.is_loopback or ip.is_link_local or ip.is_multicast or ip.is_reserved or ip.is_unspecified:
        print("DENY: target resolves to a non-public address")
        sys.exit(1)
    public.append(str(ip))
print("OK " + public[0])
PY
) || { echo "$check"; return 1; }

    local resolved_ip="${check#OK }" host port
    host=$(URL="$url" python3 -c 'from urllib.parse import urlsplit; import os; print(urlsplit(os.environ["URL"]).hostname)') || return 1
    port=$(URL="$url" python3 -c 'from urllib.parse import urlsplit; import os; u=urlsplit(os.environ["URL"]); print(u.port or (443 if u.scheme=="https" else 80))') || return 1
    raw=$(curl -sS --proto '=http,https' --proto-redir '=http,https' --resolve "$host:$port:$resolved_ip" --max-redirs 0 --max-time "${AI_WEBFETCH_TIMEOUT:-15}" -A "Mozilla/5.0 (agent-zsh)" "$url" 2>&1)
    rc=$?
    if [ $rc -ne 0 ]; then
        echo "ERROR: curl gagal (exit $rc): $raw"
        return 1
    fi

    local strip_script='
import sys, re, html
raw = sys.stdin.read()
raw = re.sub(r"(?is)<(script|style)[^>]*>.*?</\\1>", " ", raw)
raw = re.sub(r"(?s)<[^>]+>", " ", raw)
raw = html.unescape(raw)
raw = re.sub(r"[ \t]+", " ", raw)
raw = re.sub(r"\n\s*\n+", "\n\n", raw)
print(raw.strip())
'
    text=$(printf '%s' "$raw" | python3 -c "$strip_script" 2>/dev/null)
    [ -z "$text" ] && text="(kosong setelah strip HTML -- mungkin bukan halaman HTML biasa)"
    printf '%s' "$text" | _ai_head_c "${AI_WEBFETCH_MAX_CHARS:-8000}"
}
