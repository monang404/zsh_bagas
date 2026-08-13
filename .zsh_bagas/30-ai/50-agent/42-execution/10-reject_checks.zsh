# ============================================================
#  30-ai/50-agent/42-execution/10-reject_checks.zsh — tolak klaim
#  done:true yang belum terverifikasi (belum pernah jalanin tool,
#  atau file yang disentuh gagal syntax check).
#  (split out of the old monolithic 30-ai/50-agent/42-execution.zsh)
#
#  Return code: 0 = lanjut normal (bukan done, atau done & diterima),
#  1 = harus `continue` loop (dari caller, klaim ditolak), 2 = harus
#  `return 1` dari _ai_agent_execute_loop (state transition gagal).
# ============================================================

# v3.2: jangan terima klaim "selesai" kalau agent belum pernah
# beneran menjalankan satu command pun di sesi ini -- itu tandanya
# dia declare sukses tanpa verifikasi apa pun (hallucinated), bukan
# goal yang emang gak butuh aksi apa-apa. Dorong balik buat
# verifikasi dulu, jangan langsung percaya.
_ai_agent_exec_check_done_rejections() {
    if [ "$done_flag" = "true" ]; then
        _ai_agent_state_transition "$state_dir" VERIFY 2>/dev/null || return 2
    fi

    if [ "$done_flag" = "true" ] && [ "$commands_run" -eq 0 ]; then
        echo "  [ditolak: agent klaim selesai tapi belum pernah memanggil tool apa pun di sesi ini]"
        jq --arg a "$reply" --arg r "Kamu klaim goal ini sudah selesai, tapi belum memanggil satu tool pun di sesi ini. Klaim tanpa verifikasi TIDAK DITERIMA. Jalankan tool nyata yang membuktikan goal ini tercapai (baca file terkait, jalankan test, dsb) sebelum declare done:true lagi." \
            '. + [{"role":"assistant","content":$a},{"role":"user","content":$r}]' \
            "$msgfile" > "$msgfile.tmp.$$" && command mv -f "$msgfile.tmp.$$" "$msgfile"
        _ai_agent_checkpoint_save "$checkpoint_file" "$goal" "$step" "$msgfile"
        return 1
    fi

    # v-fix: kalau ada file .py yang disentuh sesi ini, jangan terima
    # done:true kalau salah satunya gagal py_compile -- mirip smoke-
    # test yang udah ada di aiproject, tapi versi ringan buat aiagent
    # yang sebelumnya SAMA SEKALI gak punya verifikasi begini.
    # Task 2.1: pengecekan py_compile-nya sendiri dipindah ke
    # _ai_verify_touched_files() (dispatcher by-extension), logic &
    # pesan error per-file buat .py IDENTIK, cuma lokasinya berubah.
    # Task 2.2: dispatcher sekarang juga bisa ngembaliin error dari
    # .zsh/.sh (bukan cuma .py lagi), jadi teks pembungkus di bawah
    # ini digeneralisasi dari "file .py ... py_compile" jadi "file
    # berikut gagal verifikasi syntax" -- MEKANISMENYA (reject,
    # jq wrap balik ke LLM, continue, checkpoint save, agent belum
    # boleh declare selesai) TETAP PERSIS SAMA, cuma kata-kata yang
    # nyebut "py_compile" secara eksplisit gak akurat lagi kalau
    # yang gagal ternyata file shell. Isi $bad_py per-file (baris
    # "$f: $err") sendiri gak disentuh -- itu yang dites regresi.
    if [ "$done_flag" = "true" ] && [ ${#touched_files[@]} -gt 0 ]; then
        local bad_py=""
        bad_py=$(_ai_verify_touched_files "${(k)touched_files[@]}")
        if [ -n "$bad_py" ]; then
            echo "  [ditolak: file berikut gagal verifikasi syntax sesi ini, agent belum boleh declare selesai]"
            jq --arg a "$reply" --arg r "Kamu klaim goal ini sudah selesai, tapi file berikut gagal verifikasi syntax setelah kamu edit:
$bad_py
Perbaiki dulu (mis. pakai 'ai patch <file> \"perbaiki syntax error\"') sebelum declare done:true lagi." \
                '. + [{"role":"assistant","content":$a},{"role":"user","content":$r}]' \
                "$msgfile" > "$msgfile.tmp.$$" && command mv -f "$msgfile.tmp.$$" "$msgfile"
            _ai_agent_checkpoint_save "$checkpoint_file" "$goal" "$step" "$msgfile"
            _ai_agent_state_transition "$state_dir" PLAN 2>/dev/null || true
            return 1
        fi
    fi
    return 0
}
