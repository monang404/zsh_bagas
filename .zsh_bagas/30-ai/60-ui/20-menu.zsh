# ============================================================
#  30-ai/60-ui/20-menu.zsh — interactive _ai_menu
#  (split out of the old monolithic 30-ai/60-ui.zsh)
# ============================================================

# menu interaktif (butuh gum: pkg install gum)
_ai_menu() {
    if ! command -v gum >/dev/null; then
        echo "Install 'gum' dulu buat menu interaktif: pkg install gum"
        echo "Sementara ini pakai command langsung, misal: ai chat \"halo\""
        return 1
    fi
    local choice
    choice=$(gum choose \
        "Chat cepat" \
        "Chat panjang" \
        "Sesi nyambung (multi-turn)" \
        "AI Agent (ReAct loop)" \
        "Generate kode (file baru)" \
        "Edit file (AI + diff review)" \
        "Lihat isi file (nomor baris)" \
        "Scan project (deteksi bahasa/test cmd)" \
        "Index codebase (scan functions/classes)" \
        "Fix kode" \
        "Jalanin & auto-fix script" \
        "Buat aplikasi otomatis (satu perintah)" \
        "Buat spec aplikasi (buat main.py dulu)" \
        "Buat project multi-file" \
        "Scraper generator" \
        "Tanya soal file" \
        "Auto commit message" \
        "Code review (diff)" \
        "Buat rencana/plan" \
        "Generate structured prompt" \
        "Ringkes file/url" \
        "Tanya dari clipboard" \
        "Shell command helper" \
        "Cari riwayat AI" \
        "Statistik token/usage" \
        "Buka workspace tmux" \
        "Cek dependency & provider")
    case "$choice" in
        "Chat cepat") ai chat "$(gum input --placeholder 'Tanya apa?')" ;;
        "Chat panjang") ai long "$(gum input --placeholder 'Tanya apa?')" ;;
        "Sesi nyambung (multi-turn)")
            local sname
            sname=$(gum input --placeholder 'Nama sesi (kosongin = main)')
            ai session start "${sname:-main}"
            while true; do
                local m
                # v-fix (bug #27 audit): "gum input" cuma single-line,
                # gak konsisten sama input instruksi lain yang multi-line
                # (gum write) -- pesan chat panjang/multi-baris kepotong.
                m=$(gum write --placeholder "[$AI_CURRENT_SESSION] ketik pesan, Ctrl+D/Esc buat kirim, kosongin buat keluar")
                [ -z "$m" ] && break
                ai session "$m"
            done
            ai session end
            ;;
        "AI Agent (ReAct loop)")
            local g yolo_choice yflag=""
            g=$(gum input --placeholder 'Goal buat agent?')
            yolo_choice=$(gum choose "Konfirmasi tiap command" "--yolo (auto-run, hati-hati)")
            [[ "$yolo_choice" == --yolo* ]] && yflag="--yolo"
            ai agent $yflag "$g"
            ;;
        "Generate kode (file baru)") ai code "$(gum input --placeholder 'Mau kode apa?')" ;;
        "Edit file (AI + diff review)")
            local f instr
            f=$(fd --type f 2>/dev/null | gum filter --placeholder 'Pilih file yang mau diedit')
            [ -z "$f" ] && { echo "Batal."; return; }
            instr=$(gum write --placeholder 'Instruksi perubahan apa?')
            ai edit "$f" "$instr"
            ;;
        "Lihat isi file (nomor baris)")
            local f
            f=$(fd --type f 2>/dev/null | gum filter --placeholder 'Pilih file')
            [ -n "$f" ] && ai view "$f" | bat --paging=always 2>/dev/null || cat
            ;;
        "Scan project (deteksi bahasa/test cmd)") ai scan ;;
        "Index codebase (scan functions/classes)") ai index ;;
        "Fix kode")
            local f e
            f=$(fd --type f 2>/dev/null | gum filter --placeholder 'Pilih file')
            e=$(gum write --placeholder 'Paste pesan error')
            ai fix "$f" "$e"
            ;;
        "Jalanin & auto-fix script")
            local f
            f=$(fd --type f -e py 2>/dev/null | gum filter --placeholder 'Pilih file .py')
            ai run "$f"
            ;;
        "Buat aplikasi otomatis (satu perintah)")
            ai build "$(gum write --placeholder 'Aplikasi apa yang mau dibuat?')"
            ;;
        "Buat spec aplikasi (buat main.py dulu)")
            ai spec "$(gum write --placeholder 'Deskripsi aplikasi mau dibuat apa?')"
            ;;
        "Buat project multi-file")
            local pname desc
            pname=$(gum input --placeholder 'Nama folder project')
            desc=$(gum write --placeholder 'Deskripsi project (atau path .txt hasil ai spec)')
            ai project "$pname" "$desc"
            ;;
        "Scraper generator")
            local url task
            url=$(gum input --placeholder 'URL target')
            task=$(gum input --placeholder 'Mau ambil data apa?')
            ai scrap "$url" "$task"
            ;;
        "Tanya soal file")
            local f q
            f=$(fd --type f 2>/dev/null | gum filter --placeholder 'Pilih file')
            q=$(gum input --placeholder 'Pertanyaan?')
            ai ask "$f" "$q"
            ;;
        "Auto commit message") ai commit ;;
        "Code review (diff)") ai review ;;
        "Buat rencana/plan") ai plan "$(gum input --placeholder 'Goal/tujuan apa?')" ;;
        "Generate structured prompt") ai prompt "$(gum input --placeholder 'Deskripsi tugas buat LLM lain?')" ;;
        "Ringkes file/url") ai summarize "$(gum input --placeholder 'Path file atau URL')" ;;
        "Tanya dari clipboard") ai clip "$(gum input --placeholder 'Instruksi (kosongin = ringkes aja)')" ;;
        "Shell command helper") ai shell "$(gum input --placeholder 'Mau ngapain?')" ;;
        "Cari riwayat AI") aih ;;
        "Statistik token/usage") aistats ;;
        "Buka workspace tmux") aidev ;;
        "Cek dependency & provider") ai_check_deps ;;
        *) echo "Batal." ;;
    esac
}
