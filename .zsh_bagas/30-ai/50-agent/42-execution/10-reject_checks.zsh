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
    setopt localoptions noxtrace
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

        # Phase 6 (audit.md §11/§20, minimal option (a)): show a
        # "● Verify" block for the files verified this claim -- reusing
        # the SAME $bad_py string _ai_verify_touched_files already
        # returned above (not calling it a second time), cross-
        # referenced per-file against a static extension->checker-name
        # map (mirrors _ai_verify_touched_files's own case branches).
        # Per §29's explicit warning: a file whose extension has NO
        # checker at all (e.g. .md) must not render as a bare pass --
        # only extensions this dispatcher actually verifies are listed
        # here; unknown extensions are omitted from the block entirely
        # (not shown as ✓, not shown as ✗).
        local -a _verify_lines
        local vf vchecker _v_bullet _v_ok _v_bad
        if _ai_ui_supports_unicode; then
            _v_bullet="●"; _v_ok="✓"; _v_bad="✗"
        else
            _v_bullet="*"; _v_ok="+"; _v_bad="x"
        fi
        for vf in "${(k)touched_files[@]}"; do
            [ -f "$vf" ] || continue
            vchecker=""
            case "$vf" in
                *.py)  vchecker="python3 -m py_compile $vf" ;;
                *.zsh) vchecker="zsh -n $vf" ;;
                *.sh)  vchecker="bash -n $vf" ;;
                *.json) vchecker="jq empty $vf" ;;
                *.yaml|*.yml) vchecker="python3 -c 'import yaml' $vf" ;;
                *.js)  vchecker="node --check $vf" ;;
                *.ts)  vchecker="tsc --noEmit --skipLibCheck $vf" ;;
                *) continue ;;
            esac
            _verify_lines+=("\$ $vchecker")
            if [[ "$bad_py" == *"$vf: "* ]]; then
                local verr
                verr=$(printf '%s\n' "$bad_py" | grep "^${vf}: " | head -1)
                _verify_lines+=("${_v_bad} ${verr#${vf}: }")
            else
                _verify_lines+=("${_v_ok} passed")
            fi
        done
        if [ "${#_verify_lines[@]}" -gt 0 ]; then
            echo ""
            echo "  ${_v_bullet} Verify"
            echo ""
            local vl
            for vl in "${_verify_lines[@]}"; do
                echo "    $vl"
            done
        fi

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
