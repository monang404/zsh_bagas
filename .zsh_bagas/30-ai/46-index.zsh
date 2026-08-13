# ============================================================
#  30-ai/46-index.zsh — Codebase Indexing sederhana
# ============================================================

: ${AI_INDEX_DIR:="$AI_GENERATE_DIR/index"}

_ai_index_slug() {
    _ai_project_slug
}

aiindex() {
    _ai_secure_runtime_dir "$AI_INDEX_DIR" 2>/dev/null || mkdir -p -- "$AI_INDEX_DIR" || return 1
    local outfile="$AI_INDEX_DIR/$(_ai_index_slug).json"
    local tmpjson
    tmpjson=$(mktemp) || return 1
    echo "Indexing codebase..."

    # One Python pass replaces the previous per-file jq rewrite (O(n²)) and
    # multiple subprocesses per source file. Paths are serialized once and
    # written atomically.
    PROJECT_ROOT="$PWD" OUTFILE="$tmpjson" python3 - <<'PY'
import json, os, pathlib, re, sys
root = pathlib.Path(os.environ["PROJECT_ROOT"]).resolve()
exts = {".py", ".js", ".ts", ".go", ".rs", ".zsh", ".sh"}
files = []
for p in root.rglob("*"):
    if not p.is_file() or p.suffix not in exts:
        continue
    try:
        rel = p.relative_to(root)
    except ValueError:
        continue
    if ".git" in rel.parts or "generate" in rel.parts:
        continue
    files.append((rel.as_posix(), p))
files.sort()
result = {"files": {}}
for rel, p in files:
    try:
        text = p.read_text(encoding="utf-8", errors="replace")
        lines = text.count("\n") + (1 if text and not text.endswith("\n") else 0)
    except OSError:
        continue
    symbols = []
    for i, line in enumerate(text.splitlines(), 1):
        m = re.match(r"^(?:def|class|function)\s+([A-Za-z_][A-Za-z0-9_]*)", line)
        if m:
            typ = line.split(None, 1)[0]
            symbols.append({"type": typ, "name": m.group(1), "line": i})
    result["files"][rel] = {"lines": lines, "symbols": symbols, "size": p.stat().st_size, "mtime_ns": p.stat().st_mtime_ns}
result["scanned_at"] = str(int(__import__("time").time()))
pathlib.Path(os.environ["OUTFILE"]).write_text(json.dumps(result, ensure_ascii=False), encoding="utf-8")
print(len(result["files"]))
PY
    local rc=$?
    if [ $rc -ne 0 ]; then
        rm -f -- "$tmpjson"
        echo "ERROR: index build gagal."
        return $rc
    fi
    command mv -f -- "$tmpjson" "$outfile" || { rm -f -- "$tmpjson"; return 1; }
    echo "Index selesai: $outfile"
}

_ai_index_get() {
    local f="$AI_INDEX_DIR/$(_ai_index_slug).json"
    if [ ! -f "$f" ] || ! _ai_index_is_fresh; then
        aiindex >/dev/null || return 1
    fi
    [ -f "$f" ] && cat "$f"
}

# Task 3.1 (fase3_index_integration): helper CEK DOANG apakah index
# fresh atau stale -- BEDA dari _ai_index_get() di atas, yang otomatis
# manggil aiindex() sendiri kalau index gak ada/stale. Fungsi ini TIDAK
# PERNAH re-index, TIDAK PERNAH manggil aiindex -- keputusan mau
# fallback ke fd/find atau trigger re-index itu tanggung jawab
# pemanggil (lihat task 3.2), bukan helper ini.
#
# Freshness-nya REUSE pola stale-check yang SAMA PERSIS kayak
# _ai_project_context() di 45-project.zsh (juga dipakai _ai_index_get()
# di atas) -- SENGAJA gak bikin mekanisme timestamp baru. Yang dicek
# cuma mtime file MANIFEST project (package.json/requirements.txt/
# pyproject.toml/Cargo.toml/go.mod) di cwd dibanding mtime index,
# BUKAN scanning mtime SELURUH file/direktori repository -- asumsinya
# sama kayak _ai_project_context: perubahan struktur/dependency project
# ditandai lewat manifest-nya, bukan tiap file kode individual yang
# disentuh.
#
# Return 0 -> index ADA dan FRESH (file index ada, gak ada manifest
#             yang mtime-nya lebih baru dari index).
# Return 1 -> index BELUM PERNAH DIBUAT SAMA SEKALI, ATAU STALE (ada
#             minimal satu manifest yang mtime-nya lebih baru).
_ai_index_is_fresh() {
    local f="$AI_INDEX_DIR/$(_ai_index_slug).json"
    [ -f "$f" ] || return 1
    INDEX_FILE="$f" PROJECT_ROOT="$PWD" python3 - <<'PY' >/dev/null 2>&1
import os, pathlib, sys
root = pathlib.Path(os.environ["PROJECT_ROOT"]).resolve()
idx = pathlib.Path(os.environ["INDEX_FILE"]).stat().st_mtime_ns
exts = {".py", ".js", ".ts", ".go", ".rs", ".zsh", ".sh"}
newest = 0
for p in root.rglob("*"):
    if p.is_file() and p.suffix in exts and ".git" not in p.parts and "generate" not in p.parts:
        try: newest = max(newest, p.stat().st_mtime_ns)
        except OSError: pass
sys.exit(0 if newest <= idx else 1)
PY
}
