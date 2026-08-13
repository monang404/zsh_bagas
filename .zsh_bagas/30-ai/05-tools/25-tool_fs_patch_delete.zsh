# ============================================================
#  30-ai/05-tools/25-tool_fs_patch_delete.zsh — patch_file / delete_file
#  (split out of the old monolithic 30-ai/05-tools.zsh)
# ============================================================

# ─── Tool Baru: patch_file ────────────────────────────────────
# Apply unified diff string ke file. Berguna untuk edit kompleks
# multi-blok yang sulit diekspresikan via satu old_str unik.
# LLM memberikan diff_content dalam format:
#   --- a/file.py
#   +++ b/file.py
#   @@ -N,M +N,M @@
#   -baris lama
#   +baris baru
_ai_tool_patch_file() {
    local args_json="$1"
    local path diff_content
    path=$(_ai_tool_extract_path "$args_json")
    diff_content=$(_ai_tool_extract_field "$args_json" diff_content)

    if [ -z "$path" ]; then
        echo "ERROR: patch_file membutuhkan args.path (string non-empty). Diterima: $(printf '%s' "$args_json" | _ai_head_c 200)"
        return 1
    fi
    if [ -z "$diff_content" ]; then
        echo "ERROR: patch_file membutuhkan args.diff_content (string non-empty)."
        return 1
    fi
    if (( ${#diff_content} > ${AI_PATCH_MAX_CHARS:-200000} )); then
        echo "ERROR: diff terlalu besar (maks ${AI_PATCH_MAX_CHARS:-200000} karakter)"
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
    if ! command -v patch >/dev/null 2>&1; then
        echo "ERROR: command 'patch' gak ketemu. Install via: pkg install patch"
        return 1
    fi

    # Buat backup dan tmpfile untuk diff
    local backup="$path.bak.$(_ai_ts)"
    local difffile
    difffile=$(mktemp --suffix=.patch)
    printf '%s\n' "$diff_content" > "$difffile"

    cp "$path" "$backup"
    local out
    out=$(patch -p0 "$path" < "$difffile" 2>&1)
    local rc=$?
    rm -f "$difffile"

    if [ $rc -eq 0 ]; then
        echo "OK: patch berhasil diterapkan ke $path (backup: $backup)"
    else
        # Restore backup jika patch gagal
        # command cp: WAJIB bypass alias `cp='cp -i'` — $path pasti sudah
        # ada (ini restore), alias -i bikin cp minta konfirmasi ke stdin
        # dan bisa hang/gagal senyap di jalur non-interaktif.
        command cp -f "$backup" "$path"
        rm -f "$backup"
        echo "ERROR: patch gagal diterapkan (backup di-restore ke semula):"
        echo "$out"
        return 1
    fi
}

# ─── Tool Baru: delete_file ───────────────────────────────────
# Beda level dari write_file/edit_file (bukan "write" tapi "shell") --
# penghapusan itu operasi yang paling gampang nyesel, jadi SELALU minta
# konfirmasi tiap panggilan (gak di-dedup ask_once_per_file kayak
# write/edit). Backup dulu ke .bak.<timestamp> sebelum benar-benar
# dihapus, biar masih bisa di-`ai undo` kalau ternyata salah target.
_ai_tool_delete_file() {
    local args_json="$1"
    local path
    path=$(_ai_tool_extract_path "$args_json")

    if [ -z "$path" ]; then
        echo "ERROR: delete_file membutuhkan args.path (string non-empty). Diterima: $(printf '%s' "$args_json" | _ai_head_c 200)"
        return 1
    fi
    if [ ! -f "$path" ]; then
        echo "ERROR: file $path gak ketemu (atau bukan file biasa)"
        return 1
    fi
    if _ai_is_secret_file "$path"; then
        echo "ERROR: [$path] kelihatan kayak file secrets. Ditolak."
        return 1
    fi

    local backup="$path.bak.$(_ai_ts)"
    command cp -f -- "$path" "$backup" || { echo "ERROR: gagal membuat backup $backup"; return 1; }
    command rm -f -- "$path" || { echo "ERROR: gagal menghapus $path"; return 1; }
    echo "OK: $path dihapus (backup: $backup, restore lewat 'ai undo $path')"
}
