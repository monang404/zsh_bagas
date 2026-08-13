# ============================================================
#  30-ai/30-code/30-project.zsh — aiproject (multi-file project generator)
#  (split out of the old monolithic 30-ai/30-code.zsh; generate/split/
#  salvage/report steps now live in the 10/15/20/25-project_*.zsh helpers)
# ============================================================

aiproject() {
    _ai_need_any_key || return 1
    if [ -z "$1" ]; then
        echo "Usage: aiproject <nama_folder> <deskripsi_project|file.txt|file.md>"
        echo "Tips: 'ai spec \"deskripsi aplikasi\"' dulu buat rincian per-file, baru 'ai project <folder> <path_spec.txt>'"
        return 1
    fi
    # v-fix (bug #52 & #56 audit): aiproject itu operasi paling berat
    # (banyak call AI + smoke-test + auto-fix loop, bisa makan waktu
    # beberapa menit) -- cek baterai & budget token harian dulu SEBELUM
    # mulai, bukan setelah kepotong di tengah jalan.
    _ai_battery_check || return 1
    _ai_budget_check || return 1
    mkdir -p "$CODE_DIR" "$AI_LOG_DIR"
    local project_name="$1"
    shift
    if [[ -z "$project_name" || "$project_name" == *[!A-Za-z0-9._-]* || "$project_name" == *..* ]]; then
        echo "ERROR: nama project tidak aman. Gunakan satu nama direktori sederhana tanpa path traversal."
        return 1
    fi
    local prompt=$(_ai_resolve_prompt "$@")
    _ai_data_saver_check || return 1
    local project_dir="$CODE_DIR/$project_name"
    mkdir -p "$project_dir"
    local logfile="$AI_LOG_DIR/${project_name}_$(_ai_ts).txt"
    local has_markers=0 generation_ok=0 gen_max_tries=2

    # v-fix (bug #54 audit): wake-lock buat seluruh sisa fungsi ini
    # (generate + autotest bisa makan waktu beberapa menit) -- `always{}`
    # zsh mastiin release TETAP kepanggil walau ada `return` di tengah
    # jalan (mis. gagal generate) atau error gak terduga, gak cuma di
    # jalur sukses.
    _ai_wakelock_acquire
    {

    _ai_project_generate

    _ai_project_split_files
    local split_rc=$?
    [ $split_rc -eq 0 ] || return $split_rc

    if [ "$generation_ok" -eq 0 ]; then
        echo "GAGAL: semua percobaan provider untuk aiproject gagal. Tidak ada source code yang dibuat."
        return 1
    fi

    _ai_project_salvage_if_empty
    [ $? -eq 0 ] || return 1

    _ai_project_finish_report
    } always {
        _ai_wakelock_release
    }
}
