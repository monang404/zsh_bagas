# ============================================================
#  30-ai/00-config/40-context_engine_docs.zsh — Task 5.1 progressive context engine mapping (docs only, no code)
#  (split out of the old monolithic 30-ai/00-config.zsh)
# ============================================================

# ============================================================
#  Task 5.1 (fase5_context_engine) — PROGRESSIVE CONTEXT ENGINE
#  Mapping 6 level context ke sumber data/tool yang UDAH ADA.
#  Ini CUMA DOKUMENTASI/MAPPING, BUKAN implementasi. Gak ada
#  function baru, gak ada tool baru, behavior agent gak berubah
#  sama sekali dari task ini. Task 5.2 (nanti, sysprompt di
#  50-agent/40-runtime.zsh) yang bakal benar-benar instruksikan LLM buat
#  ngikutin urutan ini.
#
#  PRINSIP UTAMA:
#  Jangan langsung kirim context sebanyak mungkin ke LLM di awal
#  sesi. Mulai dari context yang PALING MURAH (paling sedikit
#  token, paling cepat didapat), baru NAIK LEVEL kalau level
#  sekarang belum cukup buat nyelesein task. Setiap naik level,
#  token yang dipakai makin mahal -- jadi eskalasi harus SEPERLU-
#  NYA, bukan default langsung ke level tertinggi.
#
#  ALUR (bertahap, berhenti begitu cukup):
#    Level 1 → cukup? → tidak → Level 2 → cukup? → tidak →
#    Level 3 → cukup? → tidak → Level 4 → cukup? → tidak →
#    Level 5 → butuh bukti runtime? → Level 6
#
#  ─── LEVEL 1 — Project metadata ────────────────────────────
#  Sumber : _ai_project_context()  (sudah ada, di 45-project.zsh)
#  Isi    : ringkasan/manifest project (bahasa, struktur besar,
#           dependency) -- ini yang SEKARANG udah dikirim di awal
#           sesi aiagent lewat sysprompt. Paling murah, paling
#           general, cukup buat task yang cuma butuh "gambaran
#           besar" project.
#
#  ─── LEVEL 2 — Directory structure / file discovery ────────
#  Sumber : list_dir / glob_search  (tool registry di 50-agent/,
#           sudah ada)
#  Isi    : daftar file/folder, cari file berdasarkan nama/pola.
#           Dipakai kalau Level 1 belum ngasih tau DI MANA file
#           yang relevan berada.
#
#  ─── LEVEL 3 — Relevant file content ────────────────────────
#  Sumber : read_file  (tool registry di 50-agent/, sudah ada)
#  Isi    : baca isi file penuh. Dipakai kalau udah tau file mana
#           yang relevan (dari Level 2) tapi belum tau bagian mana
#           di dalamnya yang perlu diubah/dibaca.
#
#  ─── LEVEL 4 — Relevant symbols ─────────────────────────────
#  Sumber : grep_search  (tool registry, sudah ada) / data symbol
#           dari index (.files[path].symbols, 46-index.zsh, hasil
#           Fase 3)
#  Isi    : cari fungsi/class/simbol spesifik tanpa baca seluruh
#           file. Lebih presisi & lebih murah dari Level 3 kalau
#           yang dicari cuma lokasi satu simbol di file besar.
#
#  ─── LEVEL 5 — Exact code region ────────────────────────────
#  Sumber : read_file dengan offset + limit  (tool registry,
#           SAMA PERSIS dengan read_file di Level 3, cuma dipanggil
#           lebih presisi -- args offset?/limit? udah ada di
#           registry, bukan tool baru)
#  Isi    : baca cuma range baris tertentu (hasil dari Level 4)
#           alih-alih baca file dari baris 1 sampai habis.
#
#  ─── LEVEL 6 — Execution evidence ───────────────────────────
#  Sumber : run_test / run_command  (tool registry, sudah ada)
#  Isi    : bukti runtime -- output test/command aktual. Dipakai
#           paling terakhir, kalau butuh verifikasi nyata (bukan
#           cuma baca kode statis) bahwa perubahan/asumsi bener.
#
#  RINGKASAN MAPPING:
#    Level 1 → _ai_project_context
#    Level 2 → list_dir / glob_search
#    Level 3 → read_file
#    Level 4 → grep_search / symbol data dari index (46-index.zsh)
#    Level 5 → read_file (offset/limit)
#    Level 6 → run_test / run_command
#
#  CATATAN: tidak ada satu pun level di atas yang butuh tool baru
#  di luar yang sudah ada di tool registry (50-agent/) atau
#  sumber data yang sudah ada (_ai_project_context, index Fase 3).
# ============================================================

