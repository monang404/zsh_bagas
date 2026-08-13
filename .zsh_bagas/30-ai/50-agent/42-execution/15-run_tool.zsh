# ============================================================
#  30-ai/50-agent/42-execution/15-run_tool.zsh — dispatch tool call
#  yang dipilih AI, track file yang disentuh, invalidate index kalau
#  stale.
#  (split out of the old monolithic 30-ai/50-agent/42-execution.zsh)
#
#  Return code: 0 = lanjut normal, 1 = harus `break` loop (dari
#  caller, dibatalkan lewat SIGINT/SIGTERM).
# ============================================================

# FIX BUG-4: hapus allow_exec yang selalu bernilai 1 (dead code).
# Permission check sudah dilakukan di dalam _ai_tool_dispatch via
# _ai_permission_check. Tidak perlu wrapper if/else di sini lagi.
_ai_agent_exec_run_tool() {
    output=$(_ai_tool_dispatch "$tool" "$args" 2>&1)
    exit_status=$?
    if [ -f "$state_dir/cancelled" ]; then
        block_reason="Agent dibatalkan oleh SIGINT/SIGTERM setelah tool '$tool' (step $step)"
        _ai_agent_state_transition "$state_dir" BLOCKED 2>/dev/null || true
        return 1
    fi
    output=$(printf '%s' "$output" | _ai_head_c 3000)
    commands_run=$((commands_run+1))

    # FIX BUG-3: filepath dideklarasikan SEKALI, dipakai untuk
    # dua keperluan: py_compile tracking DAN session logging.
    #
    # v-fix (audit lanjutan): "move_file" args-nya {path: SUMBER, dest:
    # TUJUAN} -- setelah move sukses, file di SUMBER ("$path") udah gak
    # ada lagi (pindah ke "$dest"). Ambil ".path" doang di sini bikin
    # "[ -f "$filepath" ]" di bawah SELALU false buat move_file (source-
    # nya emang udah ilang), jadi file hasil move-nya diam-diam KELUAR
    # dari touched_files -- gak pernah diverifikasi syntax-nya
    # (_ai_verify_touched_files), dan juga gak nongol bener di log
    # "files_touched" (20-log_and_notify.zsh pakai variable yang sama).
    # Fallback ".dest // .path" generik: cuma move_file yang punya field
    # "dest", tool lain (read_file/write_file/edit_file/dst) gak punya
    # field itu jadi otomatis jatuh balik ke ".path" seperti biasa --
    # bukan special-case "if tool == move_file" di layer ini.
    filepath=$(echo "$args" | jq -r '.dest // .path // empty' 2>/dev/null)

    if [ "$exit_status" -eq 0 ]; then
        # Task 2.1: dulu cuma nge-track kalau *.py (satu-satunya yang
        # diverifikasi). Sekarang nge-track semua file yang ada biar
        # _ai_verify_touched_files() bisa dispatch by-extension --
        # utk .py hasilnya identik (tetap masuk & tetap dicek).
        [ -n "$filepath" ] && [ -f "$filepath" ] && touched_files[$filepath]=1
    fi

    # Task 3.4 (fase3_index_integration): begitu salah satu tool yang
    # bisa bikin index (46-index.zsh) jadi STALE berhasil (write_file/
    # edit_file/delete_file/move_file, exit_status == 0 -- SAMA PERSIS
    # kayak logic existing di atas, BUKAN asumsi/tebakan), hapus file
    # index PROJECT AKTIF SAAT INI ($AI_INDEX_DIR/$(_ai_index_slug).json
    # -- path & slug REUSE dari 46-index.zsh apa adanya, TIDAK
    # hardcode). delete_file/move_file SENGAJA diikutkan (bukan cuma
    # write_file/edit_file) karena keduanya SAMA-SAMA bisa bikin daftar
    # file & symbol di index gak nyambung lagi sama filesystem.
    #
    # SENGAJA CUMA `rm -f` file index-nya, TIDAK memanggil `aiindex()`
    # ulang di sini -- re-index tetap manual lewat 'ai index', biar
    # gak nembak scan filesystem otomatis tiap kali agent nulis file.
    # Next glob_search/grep_search (Task 3.2/3.3) otomatis fallback ke
    # fd/find/grep biasa karena index-nya udah gak ada (_ai_index_is_fresh
    # return 1 begitu file gak ketemu).
    #
    # Cuma index PROJECT INI yang kehapus (satu file, bukan seluruh
    # $AI_INDEX_DIR) -- index project lain (slug beda) sama sekali gak
    # disentuh. Kalau tool-nya gagal (exit_status != 0), TIDAK ADA
    # invalidation sama sekali -- index lama tetap dianggap valid,
    # gak ada perubahan behavior lama.
    if [ "$exit_status" -eq 0 ] && \
       [[ "$tool" == "write_file" || "$tool" == "edit_file" || \
          "$tool" == "delete_file" || "$tool" == "move_file" ]]; then
        rm -f "$AI_INDEX_DIR/$(_ai_index_slug).json" 2>/dev/null
    fi
    return 0
}
