# ============================================================
#  30-ai/05-tools/20-tool_fs_write.zsh — write_file / edit_file / move_file
#  (split out of the old monolithic 30-ai/05-tools.zsh)
# ============================================================

_ai_tool_write_file() {
    local args_json="$1"
    local path content
    path=$(_ai_tool_extract_path "$args_json")
    content=$(_ai_tool_extract_field "$args_json" content)

    if [ -z "$path" ]; then
        echo "ERROR: write_file membutuhkan args.path (string non-empty). Diterima: $(printf '%s' "$args_json" | head -c 200)"
        return 1
    fi
    if [ -z "$content" ]; then
        echo "ERROR: write_file membutuhkan args.content (string non-empty)."
        return 1
    fi
    if [ -f "$path" ]; then
        echo "ERROR: file $path sudah ada. Gunakan edit_file untuk file existing."
        return 1
    fi
    if _ai_is_secret_file "$path"; then
        echo "ERROR: nama file $path menyerupai file rahasia."
        return 1
    fi

    local dir="${path:h}"
    mkdir -p -- "$dir" || { echo "ERROR: gagal membuat direktori $dir"; return 1; }
    printf '%s\n' "$content" > "$path" || { echo "ERROR: gagal menulis $path"; return 1; }
    echo "OK: file $path berhasil dibuat."
}

_ai_tool_edit_file() {
    local args_json="$1"
    local path old_str new_str
    path=$(_ai_tool_extract_path "$args_json")
    old_str=$(_ai_tool_extract_field "$args_json" old_str)
    new_str=$(_ai_tool_extract_field "$args_json" new_str)

    if [ -z "$path" ]; then
        echo "ERROR: edit_file membutuhkan args.path (string non-empty). Diterima: $(printf '%s' "$args_json" | head -c 200)"
        return 1
    fi
    if [ -z "$old_str" ]; then
        echo "ERROR: edit_file membutuhkan args.old_str (string non-empty)."
        return 1
    fi
    if [ ! -f "$path" ]; then
        echo "ERROR: file $path gak ketemu"
        return 1
    fi
    if _ai_is_secret_file "$path"; then
        echo "ERROR: [$path] kelihatan kayak file secrets. Ditolak."
        return 1
    fi

    local script='
import sys, os
path = sys.argv[1]
old = sys.argv[2]
new = sys.argv[3]
try:
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()
    count = content.count(old)
    if count == 0:
        print("ERROR: old_str gak ketemu di " + path)
        sys.exit(1)
    if count > 1:
        print("ERROR: old_str ketemu " + str(count) + " kali di " + path + ". Harus match persis 1 kali.")
        sys.exit(1)
    newcontent = content.replace(old, new)
    tmp = sys.argv[4]
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(newcontent)
    print("OK")
except Exception as e:
    print("ERROR:", str(e))
    sys.exit(1)
'
    local tmp res
    tmp=$(mktemp "${path:h}/.${path:t}.tmp.XXXXXX") || return 1
    res=$(python3 -c "$script" "$path" "$old_str" "$new_str" "$tmp" 2>&1)
    if [[ "$res" == OK* ]]; then
        local backup="$path.bak.$(_ai_ts)"
        command cp -f -- "$path" "$backup" || { rm -f -- "$tmp"; return 1; }
        command mv -f -- "$tmp" "$path" || { rm -f -- "$tmp"; return 1; }
        echo "OK: diff diterapkan ke $path (backup: $backup)"
    else
        rm -f -- "$tmp"
        echo "$res"
        return 1
    fi
}

# ─── Tool Baru: move_file ─────────────────────────────────────
# Rename/pindah file existing ke path baru. Beda dari edit_file (isi)
# dan write_file (bikin baru) -- ini murni operasi path, dengan guard
# yang sama (secret file, gak nimpa existing tanpa sadar).
_ai_tool_move_file() {
    local args_json="$1"
    local src dest
    src=$(_ai_tool_extract_path "$args_json")
    dest=$(_ai_tool_extract_field "$args_json" dest destination)

    if [ -z "$src" ]; then
        echo "ERROR: move_file membutuhkan args.path (sumber, string non-empty). Diterima: $(printf '%s' "$args_json" | head -c 200)"
        return 1
    fi
    if [ -z "$dest" ]; then
        echo "ERROR: move_file membutuhkan args.dest (tujuan, string non-empty)."
        return 1
    fi
    if [ ! -f "$src" ]; then
        echo "ERROR: file sumber $src gak ketemu"
        return 1
    fi
    if _ai_is_secret_file "$src" || _ai_is_secret_file "$dest"; then
        echo "ERROR: salah satu path ($src / $dest) kelihatan kayak file secrets. Ditolak."
        return 1
    fi
    if [ -f "$dest" ]; then
        echo "ERROR: file tujuan $dest sudah ada. Hapus/pindahkan dulu manual kalau memang mau ditimpa."
        return 1
    fi

    local destdir="${dest:h}"
    mkdir -p -- "$destdir" || { echo "ERROR: gagal membuat direktori tujuan $destdir"; return 1; }
    if command mv -- "$src" "$dest" 2>/dev/null; then
        echo "OK: $src dipindah ke $dest"
    else
        echo "ERROR: gagal memindahkan $src ke $dest"
        return 1
    fi
}
