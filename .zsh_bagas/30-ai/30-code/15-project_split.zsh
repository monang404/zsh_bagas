# ============================================================
#  30-ai/30-code/15-project_split.zsh — aiproject's '### FILE:' marker splitter
#  (split out of the old monolithic 30-ai/30-code.zsh)
# ============================================================

# Parse AI file markers with structured path validation. Never feed
# AI-generated filenames are parsed as structured data, never as shell code.
#
# Reads $project_dir/$logfile/$has_markers (caller locals, dynamic
# scope). Returns non-zero if parsing the generated files failed.
_ai_project_split_files() {
    if [ "$has_markers" -eq 1 ]; then
        PROJECT_DIR="$project_dir" LOGFILE="$logfile" python3 - <<'PY'
import os, pathlib, sys
root = pathlib.Path(os.environ["PROJECT_DIR"]).resolve()
current = None
chunks = {}
with open(os.environ["LOGFILE"], "r", encoding="utf-8", errors="replace") as fh:
    for line in fh:
        if line.startswith("### FILE: "):
            raw = line[len("### FILE: "):].strip()
            candidate = pathlib.PurePosixPath(raw)
            if candidate.is_absolute() or any(part in ("", ".", "..") for part in candidate.parts):
                current = None
                print(f"WARNING: rejected unsafe AI filename: {raw}", file=sys.stderr)
                continue
            target = (root / pathlib.Path(*candidate.parts)).resolve()
            if target != root and root not in target.parents:
                current = None
                print(f"WARNING: rejected escaping AI filename: {raw}", file=sys.stderr)
                continue
            current = target
            chunks.setdefault(target, [])
            continue
        if current is not None:
            chunks[current].append(line)
for target, lines in chunks.items():
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text("".join(lines), encoding="utf-8")
PY
        local rc=$?
        [ $rc -eq 0 ] || { echo "ERROR: parsing generated files gagal."; return $rc; }
    fi

    # auto-repair layer: tiap file .py yang baru di-split dicek & dibenerin
    # (kalau ada bug literal-\n) SEBELUM project dianggap "jadi".
    local f
    for f in "$project_dir"/**/*.py(N); do
        [ -e "$f" ] || continue
        _ai_sanitize_pycode "$f"
    done
    return 0
}
