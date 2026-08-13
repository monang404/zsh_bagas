# ============================================================
#  30-ai/50-agent/40-runtime/05-subagent_offer.zsh — Task 6.3/6.4 subagent offer
#  (split out of the old monolithic 30-ai/50-agent/40-runtime.zsh)
# ============================================================

# Offers subagent mode for a matching NEW goal (never on --resume, same
# as the original). Injects the subagent's structured result summary
# into the caller's $msgfile (dynamically-scoped, same pattern as the
# 55-subagent.zsh step helpers) -- this function has no useful return
# value, it just mutates $msgfile in place when the user opts in.
_ai_agent_offer_subagent() {
    local goal="$1"
    # Task 6.3 (fase6_subagent_system): tawarin mode subagent kalau
    # goal cocok heuristik KASAR di atas -- SENGAJA cuma di jalur goal
    # BARU (blok else ini), TIDAK PERNAH kepanggil pas --resume (lihat
    # kontrak 55-subagent.zsh §8/Task 6.4: --resume di tengah sesi
    # yang pernah pakai subagent gak boleh nawarin ulang cuma gara-gara
    # goal LAMA kebetulan ngandung kata "audit"/"review" dst). Prompt
    # ini 0 API call sampai user eksplisit jawab 'y' -- default SELALU
    # 'N' (Enter/timeout/apa pun selain 'y' persis) dan --yolo TIDAK
    # mengubah default ini (--yolo cuma ngatur approval per-tool
    # SETELAH user pilih 'Y' di sini, bukan skip prompt-nya -- lihat
    # kontrak §2 & task 6.3 poin 13). Kalau user pilih 'N': TIDAK ADA
    # perubahan behavior apa pun, langsung lanjut ke main loop existing
    # di bawah persis kayak sebelum Task 6.3 ada. Kalau 'Y': panggil
    # runner Task 6.2 yang SUDAH ADA (_ai_subagent_run, TIDAK dibuat
    # ulang) dengan role 'researcher' (tahap investigasi) -- hasil
    # ringkasannya di-suntik ke $msgfile (Task 6.4, lihat di bawah).
    if _ai_subagent_should_offer "$goal"; then
        local _sub_confirm=""
        echo ""
        read -t 60 "_sub_confirm?Task ini kelihatannya butuh audit banyak file, mau pakai mode subagent (lebih lambat, lebih banyak API call, tapi lebih thorough)? [y/N] "
        if [[ "$_sub_confirm" == "y" || "$_sub_confirm" == "Y" ]]; then
            echo "Menjalankan subagent (role: researcher)..."
            local _sub_result _sub_status _sub_summary _sub_findings _sub_error _sub_files
            _sub_result=$(_ai_subagent_run researcher "$goal")
            _sub_status=$?
            _sub_summary=$(echo "$_sub_result" | sed -n 's/^summary=//p')
            _sub_findings=$(echo "$_sub_result" | sed -n 's/^findings=//p')
            _sub_error=$(echo "$_sub_result" | sed -n 's/^error=//p')
            _sub_files=$(echo "$_sub_result" | sed -n 's/^files_affected=//p')
            if [ "$_sub_status" -eq 0 ]; then
                echo "Subagent selesai: ${_sub_summary:-(tanpa ringkasan)}"
                [ -n "$_sub_findings" ] && echo "Temuan: $_sub_findings"
            else
                echo "Subagent gagal atau berhenti: ${_sub_summary:-(tanpa detail)}${_sub_error:+ ($_sub_error)}"
                echo "Melanjutkan dengan main agent biasa."
            fi

            # Task 6.4 (fase6_subagent_system): suntik RINGKASAN
            # terstruktur (BUKAN transcript/tool-output penuh -- lihat
            # kontrak 55-subagent.zsh §5) ke $msgfile SEBAGAI SATU
            # message tambahan, pola PERSIS SAMA kayak gimana hasil
            # tool biasa disuntik balik ke context di main loop (role
            # "user", lihat jq append di bawah loop) -- BUKAN struktur
            # history/context baru, REUSE $msgfile existing apa
            # adanya. Ditaruh di sini (SEBELUM main loop mulai),
            # bukan di akhir sesi, jadi LLM call PERTAMA main loop
            # sudah bisa liat hasil subagent (lihat kontrak §6 task
            # 6.4). Checkpoint pertama yang disimpan main loop
            # (_ai_agent_checkpoint_save, SUDAH ADA, TIDAK diubah)
            # otomatis ikut nyimpen message ini karena cuma nyalin
            # $msgfile apa adanya -- TIDAK PERLU field checkpoint
            # baru (kontrak §17: state existing cukup). Resume aman
            # dari duplikat karena blok trigger 6.3 ini CUMA jalan di
            # jalur goal BARU (else di atas, "$resume_slug" kosong),
            # TIDAK PERNAH kepanggil ulang pas --resume -- checkpoint
            # messages yang di-load pas resume udah include message
            # ini apa adanya, gak pernah nambah lagi.
            local _sub_status_word="success"
            [ "$_sub_status" -ne 0 ] && _sub_status_word="failed"
            local _sub_block="[SUBAGENT RESULT]
role: researcher
status: ${_sub_status_word}"
            if [ "$_sub_status_word" = "failed" ]; then
                _sub_block+="

error:
${_sub_error:-(tidak ada detail)}"
            else
                _sub_block+="

summary:
${_sub_summary:-(tanpa ringkasan)}"
                [ -n "$_sub_findings" ] && _sub_block+="

findings:
${_sub_findings}"
                if [ -n "$_sub_files" ]; then
                    _sub_block+="

files:
$(echo "$_sub_files" | tr ',' '\n' | sed 's/^/- /')"
                fi
            fi
            # guard panjang sederhana (pola sama kayak head -c 3000 di
            # _ai_subagent_run) -- summary/findings udah 1-baris (lihat
            # _ai_subagent_oneline di 55-subagent.zsh), jadi ini cuma
            # jaring pengaman, BUKAN token counting framework baru.
            _sub_block=$(printf '%s' "$_sub_block" | head -c 2000)
            jq --arg r "$_sub_block" \
                '. + [{"role":"user","content":$r}]' \
                "$msgfile" > "$msgfile.tmp.$$" && command mv -f "$msgfile.tmp.$$" "$msgfile"
        fi
    fi
}
