# ============================================================
#  30-ai/55-subagent.zsh — Subagent System (Fase 6)
#
#  Task 6.1 (fase6_subagent_system): INI CUMA DOKUMENTASI KONTRAK.
#  File ini SENGAJA belum berisi function apa pun (_ai_subagent_run
#  dkk BELUM ada -- itu scope Task 6.2). Ditaruh di sini duluan biar
#  kontrak desainnya jelas SEBELUM ada kode, biar implementasi Task
#  6.2/6.3/6.4 gak improvisasi/over-engineer di tengah jalan.
#
#  PRINSIP UTAMA: SIMPLICITY > kelengkapan. Fase 6 BUKAN berarti
#  semua task lewat subagent -- subagent cuma buat kasus yang MEMANG
#  butuh kerja paralel/spesialisasi lintas banyak file (contoh: audit
#  seluruh backend, review banyak file, refactor lintas banyak file,
#  investigasi area project yang luas). Task kecil (ubah satu fungsi,
#  fix satu bug, edit satu file) TETAP lewat aiagent biasa, TIDAK
#  pernah didorong ke subagent.
# ============================================================


# ─── 1. Trigger heuristic ──────────────────────────────────────
# Delegasi CUMA "dipertimbangkan" (bukan otomatis dipakai) kalau:
#   - goal mengandung kata/frasa indikatif seperti: "audit",
#     "refactor seluruh", "semua file", "seluruh backend",
#     "review seluruh" (dan variasi kasar sejenis) -- ATAU
#   - project index (Fase 3, 46-index.zsh) nunjukin jumlah file
#     relevan yang cukup banyak buat goal ini.
# Ini heuristik KASAR (string match sederhana / jumlah file dari
# index), BUKAN NLP classifier, BUKAN scoring model, BUKAN training
# data apa pun. Hasilnya cuma dua kemungkinan:
#   "task ini MUNGKIN cocok buat subagent"   -> tawarin ke user
#   (default)  tidak match -> lanjut aiagent biasa, gak ada tawaran
# Heuristik ini TIDAK PERNAH menyimpulkan "PASTI pakai subagent" --
# itu keputusan user, bukan keputusan heuristik (lihat §2).

# ─── 2. User approval (wajib, bukan opsional) ──────────────────
# Kalau heuristik di atas match, subagent TETAP TIDAK langsung
# jalan. User ditawarin dulu (mis. "Task ini kelihatannya butuh
# audit banyak file, mau pakai mode subagent (lebih lambat, lebih
# banyak API call, tapi lebih thorough)? [y/N]").
#   - Default jawaban: N.
#   - User diam/Enter/jawab apa pun selain "y" eksplisit -> LANJUT
#     MODE BIASA (main agent tunggal). TIDAK auto-pilih subagent
#     kondisi apa pun, termasuk kalau heuristik match kuat.
# Ini karena mode subagent secara desain LEBIH MAHAL token (jalanin
# loop tambahan per subagent) -- gak boleh nyalain diam-diam.

# ─── 3. Role: researcher ───────────────────────────────────────
# Tujuan: read-only investigation, context gathering, inventory,
# analysis. TIDAK PERNAH mengubah project.
# Tool set: HANYA tool yang ditandai readonly di AI_TOOL_REGISTRY
# (05-tools.zsh) -- read_file, list_dir, grep_search, glob_search,
# count_lines, git_status, git_diff, todo_read, dst. Tool write
# (write_file/edit_file/patch_file/move_file/delete_file) dan tool
# shell (run_command/run_test/web_fetch) TIDAK tersedia buat role
# ini -- ini WAJIB ditegakkan lewat permission/filter tool beneran
# di Task 6.2, bukan cuma diomongin di sysprompt (sysprompt doang
# gak cukup buat guarantee read-only).

# ─── 4. Role: coder ─────────────────────────────────────────────
# Tujuan: eksekusi perubahan (implementasi hasil investigasi
# researcher, atau langsung eksekusi kalau goal-nya memang minta
# perubahan lintas banyak file).
# Tool set: tool set existing PENUH, sesuai permission yang udah
# ada (06-permissions.zsh, ask-once-per-file) -- TIDAK ada tool
# baru, TIDAK ada permission model baru buat role ini.
# Round pertama Fase 6 CUMA 2 role ini (researcher, coder). Role
# lain (reviewer subagent, tester subagent, planner subagent)
# SENGAJA TIDAK dibuat -- reviewer tetap pakai mekanisme Fase 4 di
# level main agent (auto-review sekali setelah verifikasi sukses),
# bukan subagent terpisah.

# ─── 5. Kontrak hasil (output subagent) ────────────────────────
# Subagent TIDAK PERNAH ngembaliin transcript penuh (seluruh
# riwayat step/tool-call-nya) ke main agent -- itu boros token dan
# balik lagi ke masalah yang mau dihindarin (kirim context
# sebanyak mungkin). Yang dikembaliin cukup RINGKASAN terstruktur:
#   - status          (selesai / gagal / partial)
#   - summary         (ringkasan singkat apa yang dikerjain)
#   - key_findings    (buat researcher: temuan penting)
#   - files_affected  (daftar path yang dibaca/diubah)
#   - recommendations / changes  (buat coder: perubahan apa yang
#     udah/perlu dilakukan)
#   - errors          (kalau ada, jangan disembunyiin)
# Ringkas & gampang disuntikkan balik ke history/context main
# agent -- bukan dump JSON mentah semua step subagent.

# ─── 6. Hubungan ke main agent ──────────────────────────────────
# Hasil ringkasan subagent (§5) HARUS balik ke main agent
# context/history, dipakai main agent buat lanjut kerja. Main agent
# TETAP jadi pengendali utama sesi -- subagent BUKAN agent
# independen yang ngambil alih sesi atau nentuin sendiri kapan
# selesai. Subagent dipanggil, kerja terbatas, lapor balik, main
# agent yang lanjut memutuskan langkah berikutnya (termasuk apakah
# perlu panggil subagent lagi).

# ─── 7. Budget ───────────────────────────────────────────────────
# Subagent PAKAI batas step yang SAMA (AI_AGENT_MAX_STEPS,
# 00-config.zsh) ATAU limit yang LEBIH KECIL -- tidak boleh lebih
# besar dari main agent, dan tidak boleh unlimited/tanpa batas.
# Subagent tetap tunduk ke semua guard yang udah ada: budget token
# harian (AI_DAILY_TOKEN_WARN/_ai_budget_check, 10-core.zsh),
# circuit breaker per provider/model, battery check -- TIDAK ada
# guard baru yang perlu dibikin khusus buat subagent, REUSE yang
# udah ada.

# ─── 8. Checkpoint/resume ───────────────────────────────────────
# Delegasi harus dirancang supaya TIDAK merusak checkpoint/resume
# yang udah ada ($AI_AGENT_CHECKPOINT_DIR/<slug>.json, 50-agent/40-runtime.zsh).
# Desain awal yang aman (Fase 6 round pertama): kalau --resume
# terjadi di tengah sesi yang sempat/lagi pakai delegasi, main
# agent BOLEH lanjut sebagai main-agent-only (anggap delegasi yang
# belum kelar sebagai selesai/gagal, bukan nyoba nyambungin ulang
# state internal subagent) -- BUKAN bikin sistem recovery subagent
# yang kompleks (checkpoint bertingkat, resume parsial di dalam
# subagent, dst). Sederhana & gak nyangkut lebih penting daripada
# resume yang "sempurna".

# ============================================================
#  BELUM ADA DI FILE INI (scope task selanjutnya):
#    - trigger heuristik beneran di 50-agent/ sebelum loop
#      utama mulai (offer ke user, [y/N])      -> Task 6.3
#    - merge hasil subagent ke context/checkpoint main agent
#      secara konkret, dipanggil otomatis dari aiagent()
#                                               -> Task 6.4
#  _ai_subagent_run(role, sub_goal) di bawah ini (Task 6.2) SUDAH
#  ADA & bisa dipanggil manual, TAPI belum di-wire ke aiagent().
# ============================================================


# ─── Task 6.2: _ai_subagent_run(role, sub_goal) ─────────────────
#
#  Runner MINIMAL, bukan copy dari aiagent() (50-agent/) --
#  reuse arsitektur existing sebanyak mungkin:
#    _ai_chat_request  (10-core.zsh, TIDAK diubah)
#    _ai_agent_parse   (50-agent/40-runtime.zsh, TIDAK diubah)
#    _ai_tool_dispatch (05-tools.zsh, TIDAK diubah -- ini yang
#                        tetap menjaga write-permission/shell-
#                        permission/dangerous-command-protection/
#                        outside-project-protection existing)
#    _ai_agent_slug    (50-agent/40-runtime.zsh, dipakai buat nama log)
#    _ai_trim_session  (10-core.zsh, guard context existing)
#
#  Yang BARU di file ini cuma: helper permission LOKAL
#  (_ai_subagent_tool_allowed, dipakai CUMA di dalam runner ini,
#  BUKAN permission model global baru, TIDAK mengubah
#  AI_TOOL_REGISTRY/AI_PERM_WRITE_MODE/AI_PERM_SHELL_MODE), dua
#  sysprompt sempit (researcher/coder), dan loop bounded yang
#  return ringkasan terstruktur -- BUKAN checkpoint baru, BUKAN
#  resume baru, BUKAN parser JSON baru, BUKAN logging system baru.
