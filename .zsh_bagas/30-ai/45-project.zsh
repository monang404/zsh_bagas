# ============================================================
#  30-ai/45-project.zsh — project discovery ringan
#  aiscan bikin ringkasan project (bahasa, package manager, test
#  command, struktur) sekali per folder, disimpan di
#  generate/project/. Dipakai aiagent biar gak nembak command
#  random di project yang belum "dikenal".
# ============================================================

: ${AI_PROJECT_DIR:="$AI_GENERATE_DIR/project"}

# nama file summary unik per path project (biar tiap folder beda file)
# v-fix (bug #26 audit): dulu cuma `pwd | tr -cs ...`, jadi dua folder
# beda yang PATH-nya sama-sama disquash jadi string sama abis di-tr
# (mis. karena karakter aneh yang sama-sama jadi '_', atau symlink ke
# folder lain) bisa collide dan saling timpa summary-nya. Sekarang pakai
# `pwd -P` (physical path, symlink di-resolve dulu) + suffix hash pendek
# dari full path biar praktis gak pernah collide.
_ai_project_slug() {
    local phys base_slug hash
    phys=$(pwd -P)
    base_slug=$(echo "$phys" | tr -cs 'A-Za-z0-9' '_' | sed -e 's/^_//' -e 's/_$//' | cut -c1-80)
    hash=$(echo -n "$phys" | cksum | cut -d' ' -f1)
    echo "${base_slug}_${hash}"
}

# scan project di direktori sekarang, tulis .md ringkas.
# Deteksi heuristik sederhana lewat file penanda -- sengaja gak
# nge-parse isi package.json/pyproject dalam-dalam, cukup buat
# ngasih agent konteks awal.
aiscan() {
    mkdir -p "$AI_PROJECT_DIR"
    local outfile="$AI_PROJECT_DIR/$(_ai_project_slug).md"
    local lang="unknown" pkg="-" tests="-" gitrepo="no" entry="-"

    if [ -f "package.json" ]; then
        lang="javascript/node"; pkg="npm"
        # v-fix (bug #24 audit): `grep -q '"test"'` ke-trigger juga sama
        # placeholder default yang di-generate `npm init` ("test": "echo
        # \"Error: no test specified\" && exit 1") -- itu BUKAN test
        # beneran, tapi tetap kedeteksi "ada". Sekarang cek isi command-nya
        # lewat jq, bukan cuma keberadaan key "test".
        if command -v jq >/dev/null; then
            local test_cmd
            test_cmd=$(jq -r '.scripts.test // ""' package.json 2>/dev/null)
            if [ -n "$test_cmd" ] && [[ "$test_cmd" != *"no test specified"* ]]; then
                tests="npm test"
            fi
        else
            grep -qE '"test"[[:space:]]*:' package.json 2>/dev/null && ! grep -q "no test specified" package.json 2>/dev/null && tests="npm test"
        fi
        command -v jq >/dev/null && entry=$(jq -r '.main // "-"' package.json 2>/dev/null)
    elif [ -f "pyproject.toml" ] || [ -f "requirements.txt" ] || [ -f "setup.py" ]; then
        lang="python"
        # v-fix (bug #25 audit): dulu selalu nebak pkg="pip" begitu ada
        # pyproject.toml, walau project-nya sebenarnya dikelola poetry/pdm
        # (yang punya cara install/run/test sendiri, beda command dari pip
        # polos). Cek penanda yang lebih spesifik dulu sebelum fallback ke pip.
        if [ -f "poetry.lock" ] || { [ -f "pyproject.toml" ] && grep -q '\[tool\.poetry\]' pyproject.toml 2>/dev/null; }; then
            pkg="poetry"
        elif [ -f "pdm.lock" ] || { [ -f "pyproject.toml" ] && grep -q '\[tool\.pdm\]' pyproject.toml 2>/dev/null; }; then
            pkg="pdm"
        else
            pkg="pip"
        fi
        command -v pytest >/dev/null && tests="pytest"
    elif ls -- *.py(N) >/dev/null 2>&1; then
        # fallback: gak ada manifest (requirements.txt/pyproject.toml) tapi
        # ada file .py -- lebih baik nebak "python tanpa manifest" daripada
        # "unknown" total, biar aiagent tetep dapet konteks yang guna.
        lang="python (tanpa manifest)"; pkg="-"
        command -v pytest >/dev/null && ls -- test_*.py(N) *_test.py(N) >/dev/null 2>&1 && tests="pytest"
    elif [ -f "Cargo.toml" ]; then
        lang="rust"; pkg="cargo"; tests="cargo test"
    elif [ -f "go.mod" ]; then
        lang="go"; pkg="go mod"; tests="go test ./..."
    fi
    [ -d ".git" ] && gitrepo="yes"

    {
        echo "# Project: $(pwd)"
        echo "_scanned: $(date '+%Y-%m-%d %H:%M:%S')_"
        echo ""
        echo "- Language: $lang"
        echo "- Package manager: $pkg"
        echo "- Test command: $tests"
        echo "- Git repo: $gitrepo"
        echo "- Entry point: $entry"
        echo ""
        echo "## Struktur (2 level, tanpa .git/node_modules/__pycache__)"
        find . -maxdepth 2 \
            -not -path '*/.git*' \
            -not -path '*/node_modules*' \
            -not -path '*/__pycache__*' \
            -not -path '*/.venv*' \
            2>/dev/null | sort
        if [ -f "README.md" ]; then
            echo ""
            echo "## Cuplikan README (30 baris pertama)"
            _ai_head_n 30 README.md
        fi
    } > "$outfile"

    echo "Project summary: $outfile"
    cat "$outfile"
}

# dipanggil modul lain (mis. aiagent) buat nyuntik context project
# ke sysprompt. Auto-scan kalau belum pernah di-scan di folder ini.
#
# v-fix (bug #61 audit): dulu sekali ke-scan, summary dipakai SELAMANYA
# walau struktur project udah berubah total (manifest baru, bahasa
# ganti) -- gak ada TTL atau cek staleness apa pun. Sekarang re-scan
# otomatis kalau salah satu file penanda (package.json/requirements.txt/
# pyproject.toml/Cargo.toml/go.mod) di cwd lebih baru dari summary lama.
_ai_project_context() {
    local f="$AI_PROJECT_DIR/$(_ai_project_slug).md"
    local stale=0
    if [ -f "$f" ]; then
        local marker
        for marker in package.json requirements.txt pyproject.toml Cargo.toml go.mod; do
            if [ -f "$marker" ] && [ "$marker" -nt "$f" ]; then
                stale=1
                break
            fi
        done
    fi
    if [ ! -f "$f" ] || [ "$stale" -eq 1 ]; then
        aiscan >/dev/null
    fi
    [ -f "$f" ] && cat "$f"
}
