import json, re, sys

# ── Safety net: strip leaked internal shell-trace lines ───────────────
# Root cause (not 100% pinned yet — see ai-hub.zsh _ai_chat_request):
# occasionally the text that reaches here has one or more lines that are
# an exact match for _ai_chat_request's OWN local shell variables
# (temp, respfile, http_status, curl_exit, ...) sitting at the very top,
# ahead of the model's real answer, e.g.:
#
#   temp=0.6
#   respfile=/data/data/com.termux/files/usr/tmp/tmp.PIhfxSs6ep
#   http_status=200
#   curl_exit=28
#   ### FILE: utils.py
#   ...
#
# curl_exit=28 (CURLE_OPERATION_TIMEDOUT, --max-time 45) shows up in real
# examples of this, so the working theory is a timed-out/truncated curl
# response occasionally lets a fragment of the calling shell's own trace
# state bleed into what ends up in "content" before it gets here. Whatever
# the exact mechanism, this leak is cosmetically identical every time: a
# contiguous run of "known_internal_var=value" lines glued to the front
# of an otherwise-good answer. Rather than trying to reconstruct the
# original text (the leaked lines carry no recoverable information), we
# just drop that leading run. Deliberately a NAME WHITELIST, not a
# generic "key=value" regex — a generic regex would also eat legitimate
# first lines of generated code like `count = 0` or `DEBUG=True`, which
# would silently corrupt real output instead of fixing anything.
_LEAKED_TRACE_VARS = {
    "temp", "respfile", "http_status", "curl_exit", "resp", "reply",
    "payload", "provider", "endpoint", "model", "keyvar", "apikey",
    "modelkey", "models_str", "tries", "max_toks", "max_toks_override",
    "finish_reason", "msgfile", "order_str", "task_class",
    "is_reasoning_model",
}
# shell var-assignment shape: identifier=value, no spaces around "=" — a
# real trace line, not e.g. a sentence containing an "=" sign.
_VAR_LINE_RE = re.compile(r'^([a-zA-Z_][a-zA-Z0-9_]*)=\S.*$')


def strip_leaked_trace(text: str) -> str:
    lines = text.splitlines(keepends=True)
    i = 0
    while i < len(lines):
        m = _VAR_LINE_RE.match(lines[i].rstrip("\n"))
        if m and m.group(1) in _LEAKED_TRACE_VARS:
            i += 1
            continue
        break
    return "".join(lines[i:]) if i else text


def extract(raw: str) -> str:
    try:
        d = json.loads(raw, strict=False)
    except Exception:
        return ""

    # BUG LAMA: `d.get("choices", [{}])[0]` cuma pasang default kalau key
    # "choices" gak ada sama sekali. Kalau API balikin "choices": [] (array
    # kosong -- ini valid JSON, kejadian nyata kalau request kena content
    # filter atau semacamnya), maka default GAK kepake karena key-nya ADA,
    # dan [][0] langsung IndexError. Exception itu ketangkep sama
    # `except Exception: pass` di bawah, jadi print() gak pernah kepanggil
    # dan skrip keliatan diam total, padahal isi respons API sebenarnya
    # bisa dibaca (mis. ada dijawab tapi bukan berupa pilihan choice).
    choices = d.get("choices") or []
    if not choices:
        return ""

    message = choices[0].get("message") or {}
    content = (message.get("content") or "").strip()
    if content:
        return strip_leaked_trace(content).strip()

    # Reasoning fields are provider/model-internal and must never be exposed
    # as the user-facing answer. If a reasoning model exhausts its token
    # budget before producing final content, return empty so the caller can
    # classify the response as incomplete and apply its normal retry/fallback
    # policy.
    return ""


if __name__ == "__main__":
    raw = sys.stdin.read()
    print(extract(raw))
