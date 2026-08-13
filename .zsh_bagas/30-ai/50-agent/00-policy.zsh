# ============================================================
#  30-ai/50-agent/ — AI agent (ReAct loop + guardrail)
#  aiagent, plus helper deteksi command berbahaya & parsing aksi.
#
#  v3.1 (improvement): sekarang nyuntik project summary (aiscan)
#  + skill relevan (70-skills.zsh) ke sysprompt, dan berhenti
#  otomatis kalau command PERSIS SAMA gagal 3x berturut-turut
#  (dulu cuma dibatasi oleh MAX_STEPS total, bisa buang step
#  ngulang command yang jelas-jelas gak bakal berubah hasilnya).
# ============================================================


# ─── Fungsi baru (v3): AI Agent — ReAct loop dengan guardrail ─
# Beda sama semua fungsi di atas: ini bukan satu kali tanya-jawab,
# tapi loop "mikir -> propose command -> (konfirmasi) -> eksekusi ->
# lihat hasil -> mikir lagi" sampai goal-nya AI sendiri bilang selesai.
# Ini yang paling "mengerikan" di v3 ini — dipakai hati-hati.

# ─── Fungsi baru (v3): AI Agent — ReAct loop dengan guardrail ─
# Beda sama semua fungsi di atas: ini bukan satu kali tanya-jawab,
# tapi loop "mikir -> propose command -> (konfirmasi) -> eksekusi ->
# lihat hasil -> mikir lagi" sampai goal-nya AI sendiri bilang selesai.
# Ini yang paling "mengerikan" di v3 ini — dipakai hati-hati.
#
# AI_AGENT_MAX_STEPS / AI_AGENT_MAX_SAME_FAIL dipindah ke
# 30-ai/00-config.zsh (semua konstanta AI hidup di satu tempat,
# sesuai yang didokumentasikan sendiri di README) — 00-config.zsh
# ke-source lebih dulu (nomor lebih kecil), jadi keduanya udah
# ke-set sebelum baris manapun di file ini jalan.

# pola command yang OTOMATIS diblokir, gak peduli --yolo atau enggak.
# v-fix: daftar di bawah ini nangkep kasus yang gak bisa ditebak dari
# NAMA command doang (redirect ke device, fork bomb, pipe ke shell,
# dst). Kelas command yang SIFATNYA destruktif dari kombinasi nama+flag
# (rm rekursif+force, git push --force) sekarang dicek TERPISAH lewat
# tokenisasi command di _ai_agent_is_dangerous (deny-by-default, lihat
# di bawah) — bukan regex-per-pola, karena regex gampang dibobol lewat
# variasi kecil (mis. `rm -rf $VAR` lolos dari pola lama yang cuma
# nyari karakter '/' literal di argumennya).
AI_AGENT_DANGEROUS_PATTERNS=(
    # fork bomb -- spasi opsional di banyak titik, bukan cuma 1 format
    ':[[:space:]]*\([[:space:]]*\)[[:space:]]*\{[[:space:]]*:[[:space:]]*\|[[:space:]]*:[[:space:]]*&[[:space:]]*\}[[:space:]]*;[[:space:]]*:'
    'mkfs\.'
    '(^|[;&|]) *dd .*of=/dev/'
    '> */dev/sd[a-z]'
    'chmod +-R +000'
    '(^|[;&|]) *(curl|wget) .*\| *(sh|bash|zsh)([ ;|&]|$)'
    '(^|[;&|]) *(shutdown|reboot|poweroff)([ ;|&]|$)'
    '(^|[;&|]) *find .*-delete'
    '> */etc/'
    '> */boot/'
    '> *~?/?\.secrets\.zsh'
    '> *~?/?\.zshrc'
    '(^|[;&|]) *(pip3?|npm|pkg|apt|apt-get) +(uninstall|remove|purge)[^;&|]*(-y|--yes)'
)

# v-fix P0 (bug #1 audit): blocklist lama 100% regex-per-pola, jadi
# gampang dibobol lewat variasi kecil yang gak ketangkep pola aslinya —
# `rm -rf $VAR` (path lewat variabel, bukan literal) lolos dari pola
# `rm +-rf? +(/|~|...)`, padahal sama bahayanya cuma nyamar. Sekarang
# ada dua lapis:
#   1) AI_AGENT_DANGEROUS_PATTERNS di atas — buat pola yang cuma bisa
#      dikenali dari BENTUK string command-nya (redirect device, fork
#      bomb, pipe-to-shell, dst).
#   2) Deny-by-default di bawah ini — buat KELAS command yang destruktif
#      dari kombinasi NAMA + FLAG-nya, dicek dari TOKEN command (bukan
#      whole-string regex), jadi gak peduli argumen targetnya literal
#      atau lewat variabel: kombinasi `rm` + flag recursive + flag
#      force SELALU diblokir, titik, gak coba nebak "aman gak sih
#      argumennya" (nebak itu yang bikin lolos di versi lama).
_ai_agent_is_dangerous() {
    local cmd="$1" pat
    for pat in "${AI_AGENT_DANGEROUS_PATTERNS[@]}"; do
        [[ "$cmd" =~ $pat ]] && return 0
    done

    # tokenisasi command (zsh word-split ala shell, `${(z)cmd}`) biar
    # deteksi flag gak kecoh sama argumen yang isinya kebetulan
    # mengandung huruf 'r'/'f' (mis. nama file "refactor.py")
    local -a tokens
    tokens=(${(z)cmd})
    local tok has_recursive=0 has_force=0 in_rm_scope=0
    for tok in "${tokens[@]}"; do
        case "$tok" in
            ';'|'&&'|'||'|'|')
                in_rm_scope=0; has_recursive=0; has_force=0
                continue
                ;;
        esac
        if [[ "$tok" == "rm" || "$tok" == */rm ]]; then
            in_rm_scope=1; has_recursive=0; has_force=0
            continue
        fi
        if [ "$in_rm_scope" -eq 1 ]; then
            case "$tok" in
                --recursive) has_recursive=1 ;;
                --force|--no-preserve-root) has_force=1 ;;
                --*) : ;;
                -*)
                    [[ "$tok" == *[rR]* ]] && has_recursive=1
                    [[ "$tok" == *f* ]] && has_force=1
                    ;;
            esac
            if [ "$has_recursive" -eq 1 ] && [ "$has_force" -eq 1 ]; then
                return 0
            fi
        fi
    done

    # git push dengan force flag apapun -- nulis ulang history remote,
    # gak ada "undo" yang gampang begitu kepush. Dicek dari TOKEN (bukan
    # substring `*-f*` polos, itu false-positive kena nama branch yang
    # kebetulan ngandung "-f" kayak "main-final"), dan WAJIB ada token
    # "push" di scope git yang sama -- biar `git checkout -f` (buang
    # perubahan lokal, beda command, beda tingkat bahaya) gak ikut kena.
    local -a push_tokens
    push_tokens=(${(z)cmd})
    local ptok in_git_scope=0 has_push=0 has_force=0
    for ptok in "${push_tokens[@]}"; do
        case "$ptok" in
            ';'|'&&'|'||'|'|')
                in_git_scope=0; has_push=0; has_force=0
                continue
                ;;
        esac
        if [[ "$ptok" == "git" ]]; then
            in_git_scope=1; has_push=0; has_force=0
            continue
        fi
        if [ "$in_git_scope" -eq 1 ]; then
            case "$ptok" in
                push) has_push=1 ;;
                --force|--force-with-lease|--force-with-lease=*) has_force=1 ;;
                -f) has_force=1 ;;
                -*)
                    [[ "$ptok" != --* && "$ptok" == *f* ]] && has_force=1
                    ;;
            esac
            if [ "$has_push" -eq 1 ] && [ "$has_force" -eq 1 ]; then
                return 0
            fi
        fi
    done

    return 1
}

# Parse balasan JSON dari agent. Pakai python json.loads(strict=False) karena
# model kadang masukin newline/control-char literal di dalam string (mis. di
# command yang ada heredoc-nya) — itu bikin jq (parser JSON ketat) gagal
