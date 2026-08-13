#!/usr/bin/env python3
"""
ai_code_sanitize.py — auto-repair layer for LLM-generated Python code.

Target bug class: the model occasionally "leaks" JSON/text escaping into
its actual code output, emitting the two literal characters backslash + n
(and sometimes backslash + t) where a REAL newline/tab character should
be — but only in the parts of the source that are NOT string literals.
Example of the corrupted output (all one physical line):

    import os\ndef foo():\n    return os.getcwd()\n

Naively doing code.replace('\\n', '\n') is wrong: it also mangles every
LEGITIMATE '\n' escape sequence that lives inside an actual string literal
(e.g. print("a\nb")), silently changing program behavior instead of fixing
a syntax error. This module walks the source character-by-character with a
small string-aware state machine so it only touches backslash-n/backslash-t
pairs that are OUTSIDE any string literal (including inside the {expr}
part of an f-string, which is code, not string content).

Design goals / safety guarantees:
  - If the code already parses (ast.parse succeeds), it is returned
    completely untouched — never rewritten "just in case".
  - If repair is attempted but the result still doesn't parse, the
    ORIGINAL text is returned unchanged (never leave the file in a
    worse or silently-different state than before).
  - Content genuinely inside single/double/triple/raw/f-string literals
    is never modified, so legitimate `"a\nb"` or docstrings keep working.

CLI usage:
    python3 ai_code_sanitize.py <file.py>
        Reads the file, repairs it in memory, and overwrites the file
        ONLY if a repair was needed AND the repaired version parses.
        Prints a one-line notice to stderr when a repair was applied.
        Exits 0 always (never blocks the calling shell pipeline).

    python3 ai_code_sanitize.py -
        Reads code from stdin, writes the (possibly repaired) code to
        stdout. Use this to sanitize output that isn't saved to a file
        yet, e.g. `... | python3 ai_code_sanitize.py -`.

Library usage:
    from ai_code_sanitize import sanitize_literal_newlines
    fixed = sanitize_literal_newlines(code)
"""
import ast
import re
import sys

QUOTE_CHARS = ("'", '"')
STRING_PREFIXES = (
    "", "r", "R", "b", "B", "u", "U", "f", "F",
    "rb", "Rb", "rB", "RB", "br", "Br", "bR", "BR",
    "rf", "Rf", "rF", "RF", "fr", "Fr", "fR", "FR",
)


def _match_prefix_and_quote(code: str, i: int):
    """At position i (start of a token in code context), check if a
    string literal starts here. Returns (prefix, quote, is_triple) or
    None if this isn't the start of a string literal."""
    n = len(code)
    j = i
    while j < n and code[j].isalpha():
        j += 1
    prefix = code[i:j]
    if prefix not in STRING_PREFIXES:
        return None
    if j >= n or code[j] not in QUOTE_CHARS:
        return None
    q = code[j]
    is_triple = code[j:j + 3] == q * 3
    return (prefix, q * 3 if is_triple else q, is_triple)


def _fix_escapes_and_stray_newlines(code: str) -> str:
    """String-aware scanner covering two related sub-bugs:

    (a) a literal backslash-n / backslash-t pair sitting in pure code
        context (not inside any string) that should have been a real
        newline/tab — the original bug this module was written for.

    (b) an ACTUAL newline (or \\r) character landing INSIDE a
        non-triple-quoted string literal, e.g. `return "` really
        breaking to a new physical line before `".join(lines)`. A
        single/double-quoted string can never legally contain a raw
        newline, so encountering one there always means the escape
        sequence \\n was meant to be there instead of a real line
        break. We restore it as the two-character escape and keep the
        string open (it typically closes moments later on what is now
        the same repaired line).
    """
    out = []
    i = 0
    n = len(code)
    # Stack of open string contexts: each entry is
    # {"delim": "'" | '"' | "'''" | '"""', "raw": bool, "fstring": bool,
    #  "brace_depth": int}   (brace_depth > 0 means we're inside the
    #  {expr} portion of an f-string, i.e. back in *code* context)
    stack = []

    def top():
        return stack[-1] if stack else None

    while i < n:
        ctx = top()

        # ── Inside a string literal ────────────────────────────────
        if ctx is not None and ctx["brace_depth"] == 0:
            delim = ctx["delim"]
            dlen = len(delim)

            # f-string entering an {expr} (code context). `{{` is an
            # escaped literal brace, not the start of an expression.
            if ctx["fstring"] and code[i] == "{":
                if code[i:i + 2] == "{{":
                    out.append("{{")
                    i += 2
                    continue
                ctx["brace_depth"] = 1
                out.append("{")
                i += 1
                continue
            if ctx["fstring"] and code[i:i + 2] == "}}":
                out.append("}}")
                i += 2
                continue

            # closing delimiter
            if code[i:i + dlen] == delim:
                out.append(delim)
                i += dlen
                stack.pop()
                continue

            # backslash escape (real backslash char) — consume the
            # escaped pair untouched; this is exactly what protects
            # legitimate \n / \t / \" that already live in the string.
            if not ctx["raw"] and code[i] == "\\" and i + 1 < n:
                out.append(code[i:i + 2])
                i += 2
                continue

            # THE PATTERN-1 FIX: a raw newline (or \r / \r\n) inside a
            # non-triple-quoted string is never legal Python — restore
            # it as the \n escape it was meant to be, and stay inside
            # the string (don't treat it as a terminator).
            if dlen == 1 and code[i] in ("\n", "\r"):
                if code[i:i + 2] == "\r\n":
                    i += 2
                else:
                    i += 1
                out.append("\\n")
                continue

            out.append(code[i])
            i += 1
            continue

        # ── Inside the {expr} part of an f-string, OR plain code ───
        in_expr = ctx is not None and ctx["brace_depth"] > 0

        if in_expr:
            if code[i] == "{":
                ctx["brace_depth"] += 1
                out.append(code[i])
                i += 1
                continue
            if code[i] == "}":
                ctx["brace_depth"] -= 1
                out.append(code[i])
                i += 1
                if ctx["brace_depth"] == 0:
                    pass  # back to literal-text part of the f-string
                continue

        # a new string literal starting (either top-level code, or
        # inside an f-string's {expr})
        m = _match_prefix_and_quote(code, i)
        if m is not None:
            prefix, delim, _ = m
            fstring = "f" in prefix.lower()
            raw = "r" in prefix.lower()
            out.append(code[i:i + len(prefix) + len(delim)])
            i += len(prefix) + len(delim)
            stack.append({"delim": delim, "raw": raw, "fstring": fstring, "brace_depth": 0})
            continue

        # THE ACTUAL BUG FIX: a literal backslash-n / backslash-t pair
        # sitting in pure code context (not inside any string, not
        # inside a string's escape sequence) is not valid Python and
        # was almost certainly meant to be a real newline/tab.
        if code[i] == "\\" and i + 1 < n and code[i + 1] in ("n", "t"):
            out.append("\n" if code[i + 1] == "n" else "\t")
            i += 2
            continue

        out.append(code[i])
        i += 1

    return "".join(out)


CONTINUATION_KEYWORDS = {
    # words that can legitimately follow a run of extra spaces after a
    # closing paren/identifier as part of a SINGLE ongoing statement
    # (ternaries, boolean/comparison chains, comprehensions, imports).
    # If the token right after a space-run is one of these, it's not
    # the start of a new statement, so we leave the spacing alone.
    "and", "or", "not", "in", "is", "if", "else", "elif", "as",
    "import", "from", "for", "while", "with",
}

_IDENT_START_RE = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")


def _classify_topcode(code: str):
    """Best-effort per-character classification: topcode[i] is True
    only when position i is plain code (not inside any string literal)
    AND at paren/bracket/brace depth 0. This is a light-weight reuse of
    the same string-delimiter matching as the main scanner — it's only
    used to decide where it's SAFE to consider turning spacing back
    into a newline, so any imprecision here is harmless: the final
    ast.parse() check in sanitize_literal_newlines still guards against
    a bad repair ever being handed back.
    """
    n = len(code)
    topcode = [False] * n
    stack = []
    paren_depth = 0
    i = 0
    while i < n:
        if stack:
            delim = stack[-1]["delim"]
            dlen = len(delim)
            if code[i:i + dlen] == delim:
                i += dlen
                stack.pop()
                continue
            if not stack[-1]["raw"] and code[i] == "\\" and i + 1 < n:
                i += 2
                continue
            i += 1
            continue

        m = _match_prefix_and_quote(code, i)
        if m is not None:
            prefix, delim, _ = m
            raw = "r" in prefix.lower()
            stack.append({"delim": delim, "raw": raw})
            i += len(prefix) + len(delim)
            continue

        ch = code[i]
        if ch in "([{":
            paren_depth += 1
        elif ch in ")]}":
            paren_depth = max(0, paren_depth - 1)
        topcode[i] = (paren_depth == 0)
        i += 1
    return topcode


def _line_indent_before(code: str, pos: int) -> str:
    """Leading whitespace of the physical line that `pos` sits on, so a
    newly inserted newline continues at the same indentation as the
    statement it's splitting away from."""
    line_start = code.rfind("\n", 0, pos) + 1
    j = line_start
    while j < len(code) and code[j] in " \t":
        j += 1
    return code[line_start:j]


def _reglue_missing_newlines(code: str) -> str:
    """Target bug class #2: the newline BETWEEN two statements gets
    dropped entirely and replaced by plain whitespace, gluing e.g.

        lines.append(x)               lines.append(y)

    onto a single physical line. Only a run of 2+ space/tab characters
    that sits at paren/bracket depth 0, outside any string, and that
    separates what looks like the end of one statement from the start
    of a new one gets turned into a real newline (at the same
    indentation as the line it's splitting). Ordinary double-spacing
    used for alignment inside an open call/collection (depth > 0), and
    `and`/`or`/`if`/etc. continuations of a single expression, are left
    untouched.
    """
    topcode = _classify_topcode(code)
    n = len(code)
    out = []
    i = 0
    while i < n:
        if topcode[i] and code[i] in " \t":
            j = i
            while j < n and topcode[j] and code[j] in " \t":
                j += 1
            run_len = j - i
            prev_ch = code[i - 1] if i > 0 else ""
            next_ch = code[j] if j < n else ""
            prev_ok = prev_ch in ")]}\"'" or prev_ch.isalnum() or prev_ch == "_"
            next_ok = next_ch.isalpha() or next_ch == "_"
            if run_len >= 2 and prev_ok and next_ok:
                word_match = _IDENT_START_RE.match(code, j)
                word = word_match.group(0) if word_match else ""
                if word not in CONTINUATION_KEYWORDS:
                    out.append("\n")
                    out.append(_line_indent_before(code, i))
                    i = j
                    continue
            out.append(code[i:j])
            i = j
            continue
        out.append(code[i])
        i += 1
    return "".join(out)


def sanitize_literal_newlines(code: str) -> str:
    # Never touch code that's already valid.
    try:
        ast.parse(code)
        return code
    except SyntaxError:
        pass

    # Stage 1: literal \n/\t-outside-strings, and raw-newline-inside-a
    # one-line-string. Try this alone first — it's the more surgical,
    # better-understood fix, so prefer it if it's already sufficient.
    stage1 = _fix_escapes_and_stray_newlines(code)
    try:
        ast.parse(stage1)
        return stage1
    except SyntaxError:
        pass

    # Stage 2: on top of stage 1, also try re-gluing statement
    # boundaries where the newline was dropped and replaced by spaces.
    stage2 = _reglue_missing_newlines(stage1)
    try:
        ast.parse(stage2)
        return stage2
    except SyntaxError:
        # Neither repair produced valid code — hand back the ORIGINAL,
        # untouched. Never return something worse/different than what
        # came in.
        return code


def normalize_markers(text: str, marker: str = "### FILE: ") -> str:
    """Narrow, targeted fix for aiproject's multi-file splitter, which is
    strictly line-based (awk, matching '/^### FILE: /'). If the
    literal-newline bug also swallowed the newlines around a
    '### FILE: ' delimiter, awk can't split the file boundaries at all
    (or worse, glues an entire file's body onto the marker line as a
    single record, which then gets misread as part of the filename).
    Two narrow substitutions, neither of which touch any other
    backslash-n in the document body:
      1. Ensure a real newline sits right BEFORE every marker.
      2. Ensure a real newline sits right AFTER "<marker><filename>" so
         the body starts on its own record. Filenames never contain a
         backslash or a real newline, so matching up to the first
         literal '\\n' right after the marker is unambiguous and safe.
    Per-file literal-newline bugs *inside* each file's body are still
    handled afterwards by sanitize_literal_newlines() on the split file.
    """
    text = text.replace("\\n" + marker, "\n" + marker)
    escaped_marker = re.escape(marker)
    text = re.sub(
        escaped_marker + r"([^\\\n]+)\\n",
        lambda m: marker + m.group(1) + "\n",
        text,
    )
    return text


def _main():
    if len(sys.argv) not in (2, 3):
        print("Usage: ai_code_sanitize.py <file.py>|- | --normalize-markers <file>", file=sys.stderr)
        return 0

    if sys.argv[1] == "--normalize-markers":
        if len(sys.argv) != 3:
            print("Usage: ai_code_sanitize.py --normalize-markers <file>", file=sys.stderr)
            return 0
        mpath = sys.argv[2]
        try:
            with open(mpath, "r", encoding="utf-8") as f:
                original = f.read()
        except OSError as e:
            print(f"[ai_code_sanitize] gak bisa baca {mpath}: {e}", file=sys.stderr)
            return 0
        fixed = normalize_markers(original)
        if fixed != original:
            with open(mpath, "w", encoding="utf-8") as f:
                f.write(fixed)
            print(f"[ai_code_sanitize] {mpath}: delimiter '### FILE:' yang ketiban bug literal-\\n dinormalisasi.", file=sys.stderr)
        return 0

    path = sys.argv[1]

    if path == "-":
        original = sys.stdin.read()
        sys.stdout.write(sanitize_literal_newlines(original))
        return 0

    try:
        with open(path, "r", encoding="utf-8") as f:
            original = f.read()
    except OSError as e:
        print(f"[ai_code_sanitize] gak bisa baca {path}: {e}", file=sys.stderr)
        return 0

    fixed = sanitize_literal_newlines(original)
    if fixed != original:
        with open(path, "w", encoding="utf-8") as f:
            f.write(fixed)
        print(f"[ai_code_sanitize] {path}: literal-newline bug terdeteksi & diperbaiki otomatis.", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(_main())
