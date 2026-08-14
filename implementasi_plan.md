# Audit & Rencana Refactor UX — Bagas AI CLI
*Lead Terminal UX Designer review — sebelum coding, sesuai instruksi.*

## Ringkasan Temuan Utama (baca ini dulu)

Codebase **bukan** masih di UI lama sepenuhnya. Sudah ada `30-ai/60-ui/components/*`
(header, state, approval, progress, timeline, disclosure, verbosity, cards) dan
`30-ai/60-ui/screens/*` (agent.zsh, home.zsh, report.zsh) — ini adalah **v2 design
system yang sudah ditulis dan sudah cukup dekat dengan target Claude-Code-style**.

Masalahnya: **v2 ini tidak terpasang ke jalur eksekusi agent yang sebenarnya**.
Saya cek pemanggilnya (`grep` lintas repo) — `ui_agent_dashboard`, `ui_agent_start`,
`ui_agent_done`, `ui_progress`, `ui_timeline`, `ui_report`, `ui_card_summary` **nol
pemanggil** di luar file definisinya sendiri. Dead code.

Jalur yang benar-benar jalan saat `ai agent ...` dieksekusi adalah:
`30-ai/50-agent/42-execution/00-loop_main.zsh` → `20-presentation/20-tool_step_render.zsh`
→ `44-finalize.zsh`. Jalur ini punya renderer-nya **sendiri**, tidak memakai
`screens/agent.zsh`, dan **tidak** digate oleh `AI_VERBOSITY` (beda dari
`components/state.zsh` yang sudah rapi level-gated).

**Kesimpulan: kerjaan bukan "bangun UI baru dari nol", tapi (1) hubungkan
render loop nyata ke komponen v2 yang sudah benar, (2) buang renderer lama
yang paralel & un-gated, (3) matikan/hapus dead code `screens/*` v2 yang
salah asumsi, dan (4) ganti default verbosity dari 1 ke 0.** Ini kabar baik —
scope patch jauh lebih kecil dari refactor total.

---

## Keputusan yang Sudah Dikonfirmasi (siap masuk implementasi)

1. **AP-7 (dead code v2 components):** tidak dihapus — di-wire dengan benar
   (lihat detail di AP-7 & Deliverable 6/7 di bawah).
2. **Reasoning `◌` di verbosity 0:** **disembunyikan**, sama seperti tree
   render — satu aturan konsisten untuk semua output non-final (gate ke
   `AI_VERBOSITY >= 1`). `_ai_state_done`/`_ai_state_error` tetap always-on
   karena itu hasil final, bukan proses internal.
3. **Long mode (Outline→Draft→Refinement→Review→Final):** **Opsi A** —
   `aicl` dipecah jadi beberapa panggilan LLM berurutan per tahap, tiap tahap
   update `ui_timeline`.

   ⚠️ **Catatan batas scope, wajib dibaca sebelum commit ini dijalankan:**
   Opsi A mengubah *behavior* `aicl` dari 1 panggilan LLM blocking menjadi
   N panggilan berurutan (retry logic, token budget per tahap, kemungkinan
   gagal di tahap tengah perlu ditangani baru). Ini teknisnya **bukan lagi
   murni perubahan UI** — ini perubahan alur `aicl` di
   `20-chat/00-quick_chat.zsh`, yang termasuk area yang di awal brief kamu
   tandai "jangan diubah" (AI engine/dispatcher/workflow). Saya tetap
   implementasikan sesuai pilihanmu, tapi saya pisahkan jadi **commit
   tersendiri di luar 8 commit UX murni**, dengan alasan eksplisit di pesan
   commit, supaya kalau nanti mau di-revert terpisah dari patch UX-nya, bisa.
   Detail teknis di Deliverable 9 (Commit 9).

---



| Layar | File aktif (nyata dipakai) | Status vs target |
|---|---|---|
| Header/context | `60-ui/components/header.zsh` | ✅ Sudah 1 baris, dinamis, tanpa border. Match target. |
| Home/prompt-first | `60-ui/screens/home.zsh`, `60-ui/20-menu.zsh` (`_ai_workspace`) | ✅ Sudah prompt-first, tanpa menu list. `20-menu.zsh` yang benar-benar jadi entry point (`screens/home.zsh` tampak tidak dipanggil dari dispatcher — perlu dikonfirmasi saat implementasi). |
| AI Chat (`aic`) | `20-chat/01-chat_display.zsh` | ✅ Tanpa box, reasoning `◌` opsional + jawaban plain + metadata 1 baris. Sudah sangat dekat target. |
| AI Long (writing mode) | `components/progress.zsh`, `components/timeline.zsh` | ❌ **Dead code** — dibangun tapi tidak pernah dipanggil dari `30-code/*` (project generate/split/report). Mode "Long" di spec belum benar-benar ada di runtime. |
| AI Agent (loop) | `50-agent/42-execution/00-loop_main.zsh` + `20-presentation/20-tool_step_render.zsh` | ❌ Ini biang masalah utama. Detail di Deliverable 2. |
| Approval card | `06-permissions/20-perm_ask.zsh`, `25-perm_write.zsh`, `30-perm_shell.zsh` | ✅ Sudah pakai `_ai_ui_box` 1 judul + command + blank + working dir = pas di budget "maks 4 baris isi". Match target, tidak perlu diubah struktur. |
| Final report | `50-agent/44-finalize.zsh` | ⚠️ Struktur box benar (COMPLETE/BLOCKED sekali di akhir), **tapi isinya bisa meledak tanpa batas** (full git diff, AI review text, daftar semua file). Lihat Deliverable 2. |
| Status line | `components/state.zsh` | ✅ Sudah menggantikan `[AI][TAG]` dengan ikon + sudah level-gated ke `AI_VERBOSITY`. Desainnya benar; masalahnya cuma **tidak dipakai konsisten** oleh loop agent (loop pakai renderer sendiri, lihat Deliverable 2). |
| Verbosity system | `components/verbosity.zsh`, `router.zsh` (`/config verbosity N`) | ⚠️ Mekanismenya sudah ada & benar (0–3), tapi **default masih `1`**, bukan `0` sesuai spec. Dan loop agent yang sebenarnya tidak menghormati level ini sama sekali (lihat di bawah). |

---

## Deliverable 2 — Daftar Anti-pattern yang Ditemukan (dengan lokasi persis)

### ❌ AP-1: `Step N/MAX` tercetak di SETIAP step, tanpa gate verbosity
**Lokasi:** `50-agent/42-execution/00-loop_main.zsh:72-73` memanggil
`_ai_ui_step_rule "$step" "$max_step"` (didefinisikan di `60-ui/05-ui_box.zsh:111-126`)
— dipanggil tanpa cek `AI_VERBOSITY` sama sekali, jadi task 1 langkah pun akan
menampilkan garis "─── Step 1/15 ───". Ini persis contoh terlarang di spec.

### ❌ AP-2: Reasoning `◌` tercetak setiap step tanpa gate
**Lokasi:** `00-loop_main.zsh:80-83`. `_step_reasoning` (nama variabelnya **sama
persis** dengan yang dikeluhkan di spec) dicetak lewat `_ai_ui_line "◌" ...` tanpa
cek level verbosity. Di Level 0 seharusnya ini disembunyikan total.

### ❌ AP-3: Tree render tool per-step tanpa gate
**Lokasi:** `50-agent/20-presentation/20-tool_step_render.zsh:28-46`
(`_ai_agent_render_step_start`, `_ai_agent_render_step_result`), dipanggil dari
`00-loop_main.zsh:119`. Setiap tool call → 2 baris tree (`├─ N tool args` +
`│ ✓ result`) tercetak selalu, walau task-nya sederhana dan verbosity default.
Ini sumber layar penuh sebelum user lihat hasil, sama seperti keluhan di spec.

### ❌ AP-4: Default `AI_VERBOSITY=1`, seharusnya `0`
**Lokasi:** semua fallback `${AI_VERBOSITY:-1}` (`components/state.zsh`,
`components/verbosity.zsh`, `01-logger.zsh`). Spec eksplisit: *"Default adalah
Level 0."* Level 1 saat ini justru sudah menampilkan Searching/Acting — cocok
untuk Level 1 di spec, tapi harus jadi opsional (`/details` atau flag), bukan default.

### ❌ AP-5: Dua sistem render paralel, tidak sinkron
`components/state.zsh` (level-gated, rapi) **vs** `20-tool_step_render.zsh` +
`_ai_ui_step_rule` (tidak level-gated, dipanggil langsung dari loop). Loop agent
memanggil keduanya secara campur — inilah kenapa hasil akhirnya masih terasa
seperti debugger walau komponen "benar" sudah ada di repo.

### ❌ AP-6: `44-finalize.zsh` box akhir bisa tak terbatas panjangnya
**Lokasi:** `44-finalize.zsh` baris ~90-150. `final_lines` diisi: judul + jumlah
file + **daftar setiap file berubah** + hasil verifikasi py/js + **hasil npm
test/lint mentah** + **`git diff` mentah (di-guard tapi tetap bisa panjang)** +
**teks AI review**. Semua masuk SATU `_ai_ui_box`. Ini melanggar Density Budget
(footer maks 1 baris) dan prinsip "jangan tampilkan detail otomatis" — diff
mentah seharusnya di balik `/details`, bukan default.

### ❌ AP-7: `screens/agent.zsh`, `screens/report.zsh`, `components/progress.zsh`,
`components/timeline.zsh`, `components/cards.zsh` — dead code
Sudah didesain sesuai blueprint v2, nol pemanggil nyata. Bukan bug tampilan,
tapi risiko: siapapun yang audit cepat repo ini akan salah kira UI sudah
selesai — padahal user (dari screenshot) masih melihat versi lama.

**Keputusan (dikonfirmasi user): tidak dihapus — di-wire dengan benar.**
Artinya untuk tiap file di atas, per-file:
- `screens/agent.zsh` (`ui_agent_start`, `ui_agent_dashboard`, `ui_agent_done`) →
  ini overlap langsung dengan `00-loop_main.zsh` + `20-tool_step_render.zsh` +
  `44-finalize.zsh`. Karena dua-duanya tidak boleh hidup berbarengan (itu
  sumber AP-5), keputusan implementasinya: **`00-loop_main.zsh` dan
  `44-finalize.zsh` di-refactor untuk memanggil fungsi-fungsi di
  `screens/agent.zsh`** (bukan sebaliknya) — `screens/agent.zsh` sudah lebih
  dekat ke target spec, jadi dijadikan satu-satunya sumber render, dan
  `20-tool_step_render.zsh`'s tree renderer dipanggil dari dalamnya sebagai
  detail level (bukan dihapus, jadi bagian internal yang di-gate).
- `screens/report.zsh` (`ui_report`) → dipanggil dari `44-finalize.zsh`
  menggantikan box `Completed` besar saat ini.
- `components/progress.zsh` + `components/timeline.zsh` → di-wire ke
  `30-code/10-project_generate.zsh` dkk untuk Long mode (lihat Deliverable 9,
  perlu konfirmasi command persisnya).
- `components/cards.zsh` (`ui_card_summary`, `ui_card_stats`) → **catatan
  desain:** fungsi ini masih pakai box multi-baris ala style lama (bukan
  format `_ai_ui_box` yang konsisten dengan komponen lain, dan tidak
  ASCII-fallback-aware seperti punya `05-ui_box.zsh`). Sebelum di-wire perlu
  diputuskan dipakai di mana — kalau tidak ada pemanggil yang jelas dari spec,
  opsi paling aman adalah menyamakan implementasinya ke `_ai_ui_box` (reuse,
  bukan reimplement) baru di-wire, supaya tidak menambah gaya visual ketiga.

### ⚠️ AP-8: `01-logger.zsh` — nama fungsi lama `[AI][START]` dkk masih ada
**Lokasi:** `60-ui/01-logger.zsh:14-24`. Ini **aman** (hanya cetak ke stderr,
hanya di verbosity 3, sudah dikomentari sebagai "debug mode only") — bukan
pelanggaran aktif, tapi nama fungsi & tag `[AI][TAG]` sebaiknya dirapikan biar
tidak membingungkan saat maintenance, dan dipastikan tidak pernah leak ke stdout
di level manapun selain 3.

### ⚠️ AP-9: `ui_home()` di `screens/home.zsh` kemungkinan tidak pernah dipanggil
Entry point nyata adalah `_ai_workspace()` di `20-menu.zsh`, yang punya logika
sendiri (mirip tapi terpisah dari `screens/home.zsh`). Duplikasi source-of-truth
untuk layar yang sama — perlu dikonfirmasi mana yang jadi entry sebenarnya
sebelum salah satu dihapus.

---

## Deliverable 3 — Mockup ASCII Sebelum / Sesudah (state nyata, bukan hipotetis)

### AI Agent — task sederhana ("cari folder .git")

**Sebelum (kondisi nyata sekarang, dari `00-loop_main.zsh` + `20-tool_step_render.zsh`):**
```
> cari folder .git

──────────────── Step 1/15 ────────────────
◌ Mencari direktori .git di dalam home...
  ├─ 1  search_files  pattern=".git" maxdepth=3
  │     ✓ 4 matches found

╭─ ✓ Completed ────────────────────────────╮
│ Task completed successfully              │
│ Files changed: 0                         │
│                                           │
│ 1 actions · 0 files changed              │
╰───────────────────────────────────────────╯
```
7 baris non-hasil sebelum user lihat isi. Untuk task 1-step, "Step 1/15" dan
tree tool call tidak menambah keputusan apapun buat user — murni noise.

**Sesudah (target, Level 0 default, memakai `components/state.zsh` yang
sudah ada + tanpa `_ai_ui_step_rule`/tree render untuk task ≤2 langkah):**
```
> cari folder .git

● Searching...

Found 4 repositories.

~/dotfiles
~/lunawave
~/zsh_bagas
~/.icons/candy-icons

✓ Done · 1s · 1 action · 0 changes
```

### AI Agent — task approval (delete file), sudah dekat target sekarang

**Sekarang** (`perm_shell.zsh:41`, sudah cukup baik — tidak perlu dirombak):
```
╭─ File change requires approval ───────────╮
│ File: build/tmp.log                       │
│                                            │
│ Operation: delete                         │
╰────────────────────────────────────────────╯

Run process? [y/N]
```
Ini sudah sesuai budget (≤4 baris isi). **Tidak masuk anti-pattern list** —
dipertahankan apa adanya.

### Finalize box — task besar (banyak file berubah)

**Sekarang** (bisa jadi 20+ baris kalau diff besar — melanggar density budget):
```
╭─ ✓ Completed ────────────────────────────╮
│ Task completed successfully              │
│ Files changed: 6                         │
│   - src/auth.ts                          │
│   - src/auth.test.ts                     │
│   - ... (4 lainnya)                      │
│ Verifikasi: py_compile OK (2 file python)│
│                                           │
│ Changes:                                 │
│ <diff mentah, bisa puluhan baris>        │
│                                           │
│ Review:                                  │
│ <teks AI review, beberapa kalimat>       │
│                                           │
│ 4 actions · 6 files changed              │
╰────────────────────────────────────────────╯
```

**Sesudah (target — ringkas dulu, diff & review disimpan ke detail-log untuk `/details`):**
```
✓ Done · 42s · 4 actions · 6 files changed

  src/auth.ts
  src/auth.test.ts
  +4 more

Ketik /details untuk lihat diff & review lengkap.
```

---

## Deliverable 4 — Design System Terminal (ringkas, 80-kolom)

- **Spacing:** 1 blank line antar blok logis (prompt→status→hasil→footer).
  Tidak ada blank line ganda.
- **Hierarchy warna** (semua sudah ada di `02-ui_colors.zsh`, dipakai konsisten):
  `AI_C_PRIMARY` untuk prompt `>` dan nama session; `AI_C_INFO` untuk status
  sedang-berjalan (`●`); `AI_C_OK` untuk selesai (`✓`); `AI_C_WARN` untuk approval
  (`⚠`); `AI_C_ERR` untuk error (`✗`); `AI_C_MUTED` untuk metadata sekunder
  (path, waktu, jumlah token).
- **Density:** header 1 baris, status 1 baris per state, approval maks 4 baris
  isi, footer 1 baris. (Sudah didefinisikan di dokumen spec — dipakai sebagai
  acceptance criteria, lihat Deliverable 8.)
- **Box** (`_ai_ui_box`) **hanya** untuk: approval card. Tidak untuk chat reply,
  tidak untuk step biasa, tidak untuk finalize ringkas (finalize pakai
  `_ai_state_done` + list singkat, box besar hanya untuk kasus BLOCKED yang
  ringkasnya juga tetap dibatasi 4 baris).
- **Verbosity 0 = default.** Level 1+ adalah opt-in lewat `/details` atau
  `/config verbosity N`, bukan default baru.

---

## Deliverable 5 — Komponen Reusable → Sudah Ada, Tinggal Dipakai

| Komponen | File | Aksi |
|---|---|---|
| Header | `components/header.zsh` | Pertahankan, tidak diubah. |
| StatusLine | `components/state.zsh` | Pertahankan API-nya, **jadikan satu-satunya** jalur render status (hapus jalur paralel di `20-tool_step_render.zsh` + `_ai_ui_step_rule`). |
| ApprovalCard | `components/approval.zsh` + `_ai_ui_box` | Pertahankan, tidak diubah. |
| Footer/Done | `_ai_state_done` (`components/state.zsh`) | Jadikan satu-satunya sumber baris "✓ Done · ..." — dipakai finalize.zsh menggantikan box `Completed` besar. |
| Progress (Long mode) | `components/progress.zsh`, `components/timeline.zsh` | **Sambungkan** ke `30-code/10-project_generate.zsh` dkk (saat ini dead code). |
| Detail log | `components/disclosure.zsh` | Sambungkan: diff mentah & review text dari finalize.zsh dialihkan ke `_ai_detail_push` alih-alih langsung masuk box. |

---

## Deliverable 6 — Mapping Komponen ke File (revisi dari draft awal di spec)

Draft awal di spec menyebut `30-ai/55-subagent/*` sebagai "status line" — setelah
audit, itu tidak akurat: file status line sebenarnya adalah `components/state.zsh`,
dan subagent tidak memanggilnya sama sekali (grep kosong). Mapping yang benar:

| File | Tugas patch |
|---|---|
| `30-ai/60-ui/05-ui_box.zsh` | Hapus/nonaktifkan `_ai_ui_step_rule` sebagai pemanggilan wajib; jadikan opt-in verbosity≥2. |
| `30-ai/50-agent/42-execution/00-loop_main.zsh` | Hapus panggilan langsung `_ai_ui_step_rule` & `◌` reasoning tanpa gate; ganti dengan `_ai_state_step`/`_ai_state_thinking` dari `state.zsh` yang sudah level-gated. |
| `30-ai/50-agent/20-presentation/20-tool_step_render.zsh` | Gate `_ai_agent_render_step_start/result` di belakang `AI_VERBOSITY>=1`; default (0) diam, hanya kirim ke `_ai_detail_push`. |
| `30-ai/50-agent/44-finalize.zsh` | Ganti box `Completed` panjang → `_ai_state_done` + maks beberapa nama file + `/details` untuk diff/review lengkap (`_ai_detail_push`). |
| `30-ai/60-ui/components/verbosity.zsh`, `01-logger.zsh`, `state.zsh` | Ganti semua fallback `${AI_VERBOSITY:-1}` → `${AI_VERBOSITY:-0}`. |
| `30-ai/30-code/10-project_generate.zsh` (Long mode) | Sambungkan ke `components/progress.zsh`/`timeline.zsh` yang sudah ada. |
| `30-ai/60-ui/screens/agent.zsh`, `screens/report.zsh` | **Wire, bukan hapus.** Jadikan ini satu-satunya sumber render loop — `00-loop_main.zsh` & `44-finalize.zsh` dipanggil ulang untuk memanggil `ui_agent_start/dashboard/done` dan `ui_report` alih-alih mencetak sendiri. |
| `30-ai/60-ui/components/cards.zsh` | Wire setelah disamakan gaya ke `_ai_ui_box` (lihat catatan AP-7) — tunggu keputusan di mana dipakai. |
| `30-ai/60-ui/20-menu.zsh` vs `screens/home.zsh` | Konfirmasi entry point tunggal, hapus yang tidak dipakai. |

Tidak menyentuh: dispatcher inti (`40-dispatcher.zsh` routing logic), tool
registry, provider/engine, workflow (`40-workflow/*`), permission decision logic
(hanya tampilannya yang sudah oke, tidak disentuh).

---

## Deliverable 7 — Patch Plan Per File (before → after, ringkas)

1. **`components/verbosity.zsh`, `01-logger.zsh`, `state.zsh`**
   Before: `${AI_VERBOSITY:=1}` → After: `${AI_VERBOSITY:=0}`.
2. **`05-ui_box.zsh`**
   Before: `_ai_ui_step_rule` dipanggil tanpa syarat dari loop.
   After: fungsi tetap ada (dipakai kalau verbosity≥2), tapi caller wajib cek level.
3. **`00-loop_main.zsh`**
   Before: baris 72-83 mencetak step-rule + reasoning tanpa syarat.
   After: bungkus keduanya dengan `if [ "${AI_VERBOSITY:-0}" -ge 1 ]; then ...`
   — step-rule dan `◌` reasoning sama-sama disembunyikan di level 0 (keputusan
   dikonfirmasi: satu aturan gate untuk semua output proses-internal).
4. **`20-tool_step_render.zsh`**
   Before: render tree tanpa gate.
   After: `[ "${AI_VERBOSITY:-0}" -ge 1 ] && _ai_agent_render_step_start ... || _ai_detail_push ...`.
5. **`44-finalize.zsh`**
   Before: satu box raksasa dengan diff+review+file list.
   After: `_ai_state_done "N files changed" "$runtime"` + maks 5 nama file
   (`+N more` kalau lebih) + diff/review masuk `_ai_detail_push`, baris penutup
   `Ketik /details untuk lihat diff & review.` muncul hanya kalau ada detail.
6. **`30-code/10-project_generate.zsh` (Long mode)**
   Before: tidak ada progress visual terhubung.
   After: panggil `ui_timeline` di setiap tahap (Outline/Draft/Refinement/dst),
   sesuai contoh di spec.
7. **`screens/agent.zsh`, `screens/report.zsh`**
   Before: dead code, tidak dipanggil.
   After: `00-loop_main.zsh` dan `44-finalize.zsh` direfactor supaya memanggil
   `ui_agent_start/dashboard/done` dan `ui_report` langsung — logika lama
   (step-rule, tree render, box Completed manual) dipindah jadi implementasi
   *di dalam* fungsi-fungsi ini (masih ada, tapi satu sumber, ter-gate verbosity).
8. **`components/cards.zsh`**
   Before: gaya box berbeda dari `_ai_ui_box`, tidak dipanggil.
   After: disamakan implementasinya ke `_ai_ui_box` dulu, baru di-wire — lokasi
   pemanggilan menunggu keputusan (belum ada di spec secara eksplisit).

---

## Deliverable 8 — Acceptance Test (Termux 80-column)

Uji dengan `COLUMNS=80` (atau device fisik Termux) untuk setiap skenario:

1. `ai agent "cari folder .git"` (1 tool call) → **≤ 8 baris total** dari prompt
   sampai footer, **tanpa** teks "Step" dan tanpa tree `├─`/`│` di verbosity default.
2. `ai agent "refactor auth module"` (banyak file berubah, diff besar) → box
   final **≤ 6 baris**, ada baris "Ketik /details..." kalau ada diff.
3. `/details` setelah task di atas → menampilkan log lengkap (tree, diff, review)
   dengan format `disclosure.zsh` yang sudah ada.
4. `/config verbosity 2` lalu ulangi task 1 → tree tool muncul, step-rule muncul
   (opsional, sesuai keputusan poin 3 di Patch Plan).
5. Approval flow (delete file) → tetap identik seperti sekarang (regresi nol),
   ≤4 baris isi box.
6. Header tidak pernah 2 baris pada `PWD` path panjang (wrap dicek manual di
   layar 80 kolom — kalau overflow, perlu keputusan truncate `pwd_str` dengan `…`).
7. Tidak ada string `_step_reasoning=`, `[AI][`, atau `Step \d+/\d+` yang keluar
   ke stdout pada verbosity 0/1 — cek dengan `grep` pada output aktual, bukan cuma
   pada source.
8. Mode Long (`ai code proposal ...` atau setara) menampilkan `ui_timeline`
   dengan progres bertahap, bukan diam saja.

---

## Deliverable 9 — Checklist Implementasi (commit-per-commit)

- [ ] **Commit 1:** Ganti default `AI_VERBOSITY` 1→0 di 3 file (`verbosity.zsh`,
      `01-logger.zsh`, `state.zsh`). Test: `/config verbosity` tanpa argumen
      menampilkan level saat ini = 0.
- [ ] **Commit 2:** Gate `_ai_ui_step_rule` & reasoning line di `00-loop_main.zsh`
      di belakang verbosity check. Test: acceptance test #1.
- [ ] **Commit 3:** Gate tree render di `20-tool_step_render.zsh`, alihkan ke
      `_ai_detail_push` saat verbosity 0. Test: acceptance test #1 & #4.
- [ ] **Commit 4:** Ringkas `44-finalize.zsh` — box Completed jadi ringkas,
      diff/review ke `_ai_detail_push`. Test: acceptance test #2 & #3.
- [ ] **Commit 5:** Sambungkan `components/progress.zsh`/`timeline.zsh` ke
      `30-code/10-project_generate.zsh` (Long mode). Test: acceptance test #8.
- [ ] **Commit 6:** Wire `screens/agent.zsh` & `screens/report.zsh` sebagai
      satu-satunya sumber render loop (gabungkan dengan hasil Commit 2 & 3,
      bukan lapisan ketiga). Hapus render duplikat lama di `00-loop_main.zsh`
      setelah `screens/agent.zsh` terbukti jalan. Test: acceptance test #1 & #2.
- [ ] **Commit 6b:** Samakan gaya `components/cards.zsh` ke `_ai_ui_box`, wire
      ke pemanggil yang disepakati.
- [ ] **Commit 7:** Konfirmasi & konsolidasi entry point ganda `20-menu.zsh`
      vs `screens/home.zsh`.
- [ ] **Commit 8:** Full regression pass — jalankan seluruh acceptance test
      di Termux fisik (80 kolom), bukan cuma di dev shell.

---

- [ ] **Commit 9 (di luar 8 commit UX murni — ada perubahan behavior `aicl`,
      lihat catatan batas scope di atas):**
      Pecah `aicl()` di `20-chat/00-quick_chat.zsh` jadi 5 panggilan `_ai_quick`
      berurutan (Outline → Draft → Refinement → Review → Final), tiap tahap:
      1. panggil `ui_timeline` (update tahap aktif) sebelum request,
      2. kirim hasil tahap sebelumnya sebagai context ke tahap berikutnya,
      3. kalau satu tahap gagal (`_ai_quick` non-zero exit), stop di situ,
         tandai tahap itu gagal di timeline (bukan lanjut ke tahap berikutnya
         dengan context kosong), laporkan ke user tahap mana yang gagal.
      4. `_ai_log "chat-long"` tetap dipanggil di akhir dengan hasil gabungan,
         supaya histori (`generate/logs/history.jsonl`) tidak regresi format.
      Test: jalankan `aicl "tulis proposal AI"`, pastikan `ui_timeline` di
      `components/timeline.zsh` menunjukkan 5 tahap dengan status berjalan
      benar, dan hasil akhir tetap satu jawaban utuh seperti `aicl` versi lama
      (regresi behavior akhir = nol, cuma prosesnya yang sekarang bertahap).

---

## Status: siap implementasi

Semua 3 keputusan terbuka sudah dikonfirmasi (lihat bagian "Keputusan yang
Sudah Dikonfirmasi" di awal dokumen). Saya lanjut ke Commit 1 sesuai urutan
checklist di atas.
