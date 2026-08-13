# ============================================================
#  30-ai/70-skills.zsh — skills-as-file, dimuat sesuai task
#  Skill = file Markdown pendek berisi "cara kerja yang benar"
#  untuk satu domain (debugging, testing, git, dst). Dicocokkan
#  ke task lewat keyword sederhana, TIDAK semua skill dimuat
#  sekaligus (hemat token). Dipakai aiagent buat nyuntik konteks
#  domain-spesifik ke sysprompt.
# ============================================================

: ${AI_SKILLS_DIR:="$ZSH_BAGAS/skills"}

typeset -gA AI_SKILL_KEYWORDS=(
    debugging  "error bug crash fix traceback exception gagal salah"
    testing    "test tes pytest jest unit coverage regression"
    git        "git commit branch merge rebase diff push pull"
    # v-fix (bug #62 audit): dulu gak ada skill khusus Termux di
    # skill-matching sama sekali (padahal AI_TERMUX_CONTEXT yang lebih
    # ringkas udah disuntik default ke SEMUA sysprompt aiagent di
    # 50-agent/40-runtime.zsh) -- skill ini nambahin detail lebih dalam pas task-nya
    # emang eksplisit nyinggung hal Termux-spesifik (storage, notifikasi,
    # wake-lock, baterai, dst), di luar yang udah ke-cover default.
    termux     "termux android hp storage wake-lock wakelock notifikasi notification baterai battery termux-api pkg tmux sdcard"

    # v-fix (bug #66 audit): 5 file skill di bawah ini UDAH ADA di
    # skills/*.md dari sebelumnya, tapi gak pernah kepasang di map ini --
    # jadi gak pernah ke-load oleh _ai_load_skills sama sekali (dead
    # file, ke-shadow diam-diam karena satu-satunya jalur load ya lewat
    # keyword match ini). Nemunya pas nambah tool baru & ngecek
    # coverage skill yang ada.
    code_editing   "edit ubah ganti modifikasi refactor tambah fungsi tambahkan parameter implementasi implementasikan patch old_str"
    error_recovery "gagal error retry recovery pulih ulangi coba lagi crash exception traceback"
    file_ops       "file baca tulis buat folder direktori path read_file write_file grep glob project besar"
    python         "python py pip venv virtualenv pytest django flask fastapi requirements.txt"
    web_dev        "web html css javascript js node npm react vite server frontend website http api"
    javascript     "javascript js typescript ts node npm async await promise callback react vue express fetch"
    shell_scripting "shell script bash zsh sh alias function .zshrc .bashrc export path shopt setopt"
)
# skill "general" selalu dimuat, gak butuh keyword match

_ai_skill_match() {
    local task="${1:l}" name kw w matched=()
    for name kw in "${(@kv)AI_SKILL_KEYWORDS}"; do
        for w in ${(s: :)kw}; do
            if [[ "$task" == *"$w"* ]]; then
                matched+=("$name")
                break
            fi
        done
    done
    echo "general ${matched[@]}"
}

_ai_load_skills() {
    local task="$1" names name file out=""
    names=$(_ai_skill_match "$task")
    for name in ${(z)names}; do
        file="$AI_SKILLS_DIR/$name.md"
        [ -f "$file" ] && out+="$(cat "$file")
"
    done
    echo "$out"
}

# Task 1.5 (fase1_ui_ux_overhaul): versi RINGKAS dari _ai_load_skills --
# cuma butuh NAMA skill yang beneran ke-load (file-nya ada), BUKAN isi
# markdown-nya, buat ditampilin compact ke user (lewat _ai_ui_line di
# 50-agent/40-runtime.zsh). Pakai _ai_skill_match yang sama persis (gak ada logic
# baru), cuma cek file exist tanpa `cat` isinya -- jadi isi skills/*.md
# gak pernah lewat fungsi ini sama sekali. Return 1 (gak nge-print apa2)
# kalau gak ada satupun skill yang file-nya ketemu.
_ai_skills_display_line() {
    local task="$1" names name file
    local -a loaded
    names=$(_ai_skill_match "$task")
    for name in ${(z)names}; do
        file="$AI_SKILLS_DIR/$name.md"
        [ -f "$file" ] && loaded+=("$name")
    done
    [ "${#loaded[@]}" -eq 0 ] && return 1

    local out="skills:" n
    for n in "${loaded[@]}"; do
        out="$out ✓ $n"
    done
    echo "$out"
    return 0
}
