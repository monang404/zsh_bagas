# walau isinya sebenarnya masih bisa dibaca. Output ke 3 file di tmpdir biar
# gak ada masalah delimiter kalau command-nya sendiri ada tab/newline.
_ai_agent_parse() {
    local reply="$1" tmpdir
    tmpdir=$(mktemp -d)
    echo "$reply" | AI_AGENT_PARSE_OUTDIR="$tmpdir" python3 -c "
import json, os, sys
raw = sys.stdin.read()
outdir = os.environ['AI_AGENT_PARSE_OUTDIR']
thought, tool, args, done = '', '', '{}', False
dec = json.JSONDecoder(strict=False)
idxs = [i for i, ch in enumerate(raw) if ch == '{']
for i in reversed(idxs):
    try:
        obj, _ = dec.raw_decode(raw, i)
    except Exception:
        continue
    if isinstance(obj, dict) and ('tool' in obj or 'command' in obj or 'thought' in obj or 'done' in obj):
        thought = str(obj.get('thought') or '')
        if 'command' in obj and 'tool' not in obj:
            # Legacy arbitrary-shell output is opt-in. In the default agent
            # contract, a model must request a structured tool such as
            # exec_process instead of smuggling a shell string through the
            # parser.
            if os.environ.get('AI_AGENT_EXPOSE_ARBITRARY_SHELL') == '1':
                tool = 'run_command'
                args = json.dumps({'command': str(obj.get('command'))})
            else:
                tool = ''
                args = json.dumps({})
                thought = (thought + ' Format legacy \"command\" ditolak. Gunakan: {\"tool\":\"run_command\",\"args\":{\"command\":\"...\"},\"done\":false}').strip()
        else:
            tool = str(obj.get('tool') or '')
            raw_args = obj.get('args')
            # ── Normalize args ──────────────────────────────────
            # If tool is set but args is missing or not a dict, try to
            # hoist well-known fields from the root object into args.
            if not isinstance(raw_args, dict):
                raw_args = {}
            # Hoist common fields from root into args if they are missing
            # in args but present at root level (model put them in wrong place).
            hoist_fields = ['path', 'file', 'filename', 'command', 'cmd',
                            'url', 'pattern', 'content', 'old_str', 'new_str',
                            'diff_content', 'dest', 'program', 'offset', 'limit',
                            'glob', 'items', 'runner', 'timeout']
            for field in hoist_fields:
                if field not in raw_args and field in obj and field not in ('tool', 'thought', 'done', 'args'):
                    raw_args[field] = obj[field]
            args = json.dumps(raw_args)
        done = bool(obj.get('done', False))
        break
with open(os.path.join(outdir, 'thought'), 'w', encoding='utf-8') as f:
    f.write(thought)
with open(os.path.join(outdir, 'tool'), 'w', encoding='utf-8') as f:
    f.write(tool)
with open(os.path.join(outdir, 'args'), 'w', encoding='utf-8') as f:
    f.write(args)
with open(os.path.join(outdir, 'done'), 'w', encoding='utf-8') as f:
    f.write('true' if done else 'false')
" 2>/dev/null
    echo "$tmpdir"
}

# v-fix (bug #55 audit): slug pendek dari goal, dipakai buat nama file
# checkpoint ($AI_AGENT_CHECKPOINT_DIR/<slug>.json) dan buat 'ai agent
# --resume <slug>'.
_ai_agent_slug() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '_' | sed -e 's/^_//' -e 's/_$//' | cut -c1-50
}

# Task 6.3 (fase6_subagent_system): heuristik KASAR & MURAH buat nentuin
# apakah goal ini "kandidat" ditawarin mode subagent -- kontrak lengkap
# ada di 55-subagent.zsh §1 (Task 6.1). Cuma string match sederhana dari
# GOAL doang (bukan seluruh command line -- jadi flag kayak --log/--resume/
# --yolo TIDAK PERNAH bikin ini match, lihat kontrak §1 & task 6.3 poin
# 14), 0 API call, BUKAN NLP/LLM classifier. Fungsi ini CUMA jawab
# ya/tidak buat DITAWARIN (bukan otomatis dipakai) -- TIDAK milih role,
# TIDAK manggil _ai_subagent_run, TIDAK manggil LLM sama sekali.
# Convention: dipakai lewat `if _ai_subagent_should_offer "$goal"; then`
# (pola shell biasa) -- return 0 = tawarin, return 1 = jangan tawarin.
_ai_subagent_should_offer() {
    local goal_lc
    goal_lc=$(echo "$1" | tr '[:upper:]' '[:lower:]')
    case "$goal_lc" in
        *audit*|*'refactor seluruh'*|*'semua file'*|*'seluruh backend'*|*'review seluruh'*|*'review semua'*)
            return 0 ;;
        *)
            return 1 ;;
    esac
}

# v-fix (bug #55 audit): dipanggil tiap kali $msgfile berubah di dalam
# loop -- nyimpen snapshot goal+step+messages ke disk, biar kalau proses
# Termux mati di tengah jalan (OOM killer/app di-swipe/baterai abis),
# progress bisa dilanjut lewat 'ai agent --resume <slug>' alih-alih
# ngulang dari nol.
_ai_agent_checkpoint_save() {
    local checkpoint_file="$1" goal="$2" step="$3" msgfile="$4"
    [ -z "$checkpoint_file" ] && return 0
    mkdir -p -- "${checkpoint_file:h}" 2>/dev/null || return 1
    chmod 700 -- "${checkpoint_file:h}" 2>/dev/null || true

    local lock="${checkpoint_file}.lock" owner="" now stale=0
    # mkdir is atomic on local filesystems: it serializes concurrent writers.
    if ! mkdir -- "$lock" 2>/dev/null; then
        owner=$(cat "$lock/pid" 2>/dev/null)
        if [[ "$owner" =~ '^[0-9]+$' ]] && kill -0 "$owner" 2>/dev/null; then
            echo "checkpoint busy: $checkpoint_file" >&2
            return 1
        fi
        rm -rf -- "$lock" 2>/dev/null || return 1
        mkdir -- "$lock" 2>/dev/null || return 1
    fi
    printf '%s\n' "$$" >| "$lock/pid"

    local revision=0 tmp="${checkpoint_file}.tmp.$$" session_id="${checkpoint_file:t:r}"
    if [ -f "$checkpoint_file" ]; then
        revision=$(jq -r '.revision // 0' "$checkpoint_file" 2>/dev/null)
        [[ "$revision" =~ ^[0-9]+$ ]] || revision=0
    fi
    revision=$((revision + 1))

    if ! jq -n --arg g "$goal" --argjson s "$step" --argjson r "$revision" --arg ts "$(_ai_ts)" --arg sid "$session_id" \
        --slurpfile m "$msgfile" \
        '{schema_version:2,revision:$r,session_id:$sid,updated_at:$ts,goal:$g,step:$s,messages:$m[0]}' \
        >| "$tmp" 2>/dev/null; then
        rm -f -- "$tmp"
        rm -rf -- "$lock"
        return 1
    fi
    chmod 600 -- "$tmp" 2>/dev/null || true
    if ! command mv -f -- "$tmp" "$checkpoint_file" 2>/dev/null; then
        rm -f -- "$tmp"
        rm -rf -- "$lock"
        return 1
    fi
    rm -rf -- "$lock"
    return 0
}

# Task 1.2 (fase1_ui_ux_overhaul): nama project buat header box —
# pakai basename dari physical cwd (`pwd -P`), sumber yang SAMA dengan
# yang dipakai _ai_project_slug (45-project.zsh) buat identitas project,
# cuma versi manusiawi (bukan slug+hash) biar enak dibaca di header.
_ai_agent_project_name() {
    local phys
    phys=$(pwd -P)
    basename "$phys"
}

# Task 1.2: model/provider yang bakal DICOBA PERTAMA buat sesi agent ini
# (urutan AI_TASK_PROVIDER_ORDER_AGENT), cuma buat ditampilin di header
# -- bukan logic baru. Skip provider yang API key-nya belum di-set,
# sama persis kayak yang beneran dilakuin _ai_chat_request (10-core.zsh),
