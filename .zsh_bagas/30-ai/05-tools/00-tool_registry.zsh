# ============================================================
#  30-ai/05-tools/00-tool_registry.zsh — tool registry: names, capabilities, jq request schemas
#  (split out of the old monolithic 30-ai/05-tools.zsh)
# ============================================================

# Tool metadata is deliberately separate from implementation.  The model only
# gets capabilities it can request; the executor still validates the concrete
# JSON shape before any side effect is allowed.
typeset -gA AI_TOOL_REGISTRY=(
    read_file    "baca isi file (opsional offset/limit baris)|readonly"
    list_dir     "list isi direktori|readonly"
    grep_search  "cari pattern regex di project (wrapper rg/grep -rn)|readonly"
    glob_search  "cari file by nama pattern (wrapper fd)|readonly"
    count_lines  "hitung jumlah baris file / hitung kemunculan pattern di file|readonly"
    write_file   "buat file BARU (tolak kalau udah ada)|write"
    edit_file    "ganti blok teks unik di file existing (search-replace)|write"
    patch_file   "apply unified diff (patch -p0) ke file existing|write"
    run_command  "jalanin command shell (legacy compatibility; hidden from model by default)|shell"
    exec_process "jalankan executable terstruktur tanpa shell interpreter|process"
    run_test     "jalankan test suite project (typed runner; tanpa shell command string)|process"
    move_file    "pindah/rename file existing ke path baru|write"
    delete_file  "hapus file existing (backup dulu ke .bak sebelum dihapus)|shell"
    git_status   "lihat status git singkat (branch + file berubah), readonly|readonly"
    git_diff     "lihat diff git (opsional path spesifik), readonly|readonly"
    web_fetch    "ambil isi halaman web via curl, HTML di-strip jadi teks|shell"
    todo_write   "simpan/update checklist rencana kerja sesi ini (bukan file project)|readonly"
    todo_read    "baca checklist rencana kerja sesi ini saat ini|readonly"
)

typeset -gA AI_TOOL_CAPABILITY=(
    read_file    "filesystem.read"
    list_dir     "filesystem.read"
    grep_search  "filesystem.read"
    glob_search  "filesystem.read"
    count_lines  "filesystem.read"
    write_file   "filesystem.write"
    edit_file    "filesystem.write"
    patch_file   "filesystem.write"
    run_command  "shell.arbitrary"
    exec_process "process.execute"
    run_test     "process.test"
    move_file    "filesystem.write"
    delete_file  "filesystem.delete"
    git_status   "git.read"
    git_diff     "git.read"
    web_fetch    "network.public"
    todo_write   "session.todo"
    todo_read    "session.todo"
)

# jq predicates are contracts, not sanitizers.  They reject malformed tool
# requests before path resolution, permission prompts, or side effects.
typeset -gA AI_TOOL_SCHEMA=(
    read_file    '(.path | type == "string" and length > 0) and ((.offset // 0) | type == "number") and ((.limit // 0) | type == "number")'
    list_dir     '((.path // ".") | type == "string")'
    grep_search  '(.pattern | type == "string" and length > 0) and ((.path // ".") | type == "string") and ((.glob // "") | type == "string")'
    glob_search  '(.pattern | type == "string" and length > 0)'
    count_lines  '(.path | type == "string" and length > 0) and ((.pattern // "") | type == "string")'
    write_file   '(.path | type == "string" and length > 0) and (.content | type == "string")'
    edit_file    '(.path | type == "string" and length > 0) and (.old_str | type == "string") and (.new_str | type == "string")'
    patch_file   '(.path | type == "string" and length > 0) and (.diff_content | type == "string")'
    run_command  '(.command | type == "string" and length > 0)'
    exec_process  '(.program | type == "string" and length > 0) and ((.args // []) | type == "array" and all(.[]; type == "string" and (contains("\n") | not))) and ((.cwd // ".") | type == "string") and ((.timeout // 30) | type == "number" and . >= 1 and . <= 300)'
    run_test     '((.cmd // "") | type == "string") and ((.runner // "") | type == "string") and ((.args // []) | type == "array" and all(.[]; type == "string" and (contains("\n") | not))) and ((.path // ".") | type == "string") and ((.timeout // 60) | type == "number" and . >= 1 and . <= 300)'
    move_file    '(.path | type == "string" and length > 0) and (.dest | type == "string" and length > 0)'
    delete_file  '(.path | type == "string" and length > 0)'
    git_status   'true'
    git_diff     '((.path // "") | type == "string")'
    web_fetch    '(.url | type == "string" and length > 0)'
    todo_write   '.items | type == "array" and length > 0 and all(.[]; type == "object" and (.text | type == "string") and (.status | IN("pending","doing","done")))'
    todo_read    'true'
)
