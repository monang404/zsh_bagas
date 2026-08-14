# Cara Pakai Bagas AI CLI v2

Panduan ini mencerminkan paradigma baru **AI-FIRST UX** — satu prompt utama, AI menentukan mode. Untuk struktur folder/arsitektur internal, lihat `README.md`.

---

## 1. Instalasi

1. Copy folder ini ke `~/.zsh_bagas`.
2. Pastikan `~/.zshrc` kamu isinya loader tipis yang sudah ada di
   `.zshrc` (contoh di repo ini) — intinya baris ini yang meng-`source`
   semua modul secara berurutan:

   ```sh
   export ZSH_BAGAS="$HOME/.zsh_bagas"
   for f in "$ZSH_BAGAS"/**/*.zsh(N.on); do source "$f"; done
   ```

3. Buat `~/.secrets.zsh` (di luar `~/.zsh_bagas`, sengaja supaya kalau
   folder ini di-`git init` API key gak ikut ke-commit), isi minimal
   SATU dari key di bawah:

   ```sh
   export GROQ_API_KEY="..."
   export GEMINI_API_KEY="..."
   export CEREBRAS_API_KEY="..."
   export DEEPSEEK_API_KEY="..."
   ```

   ```sh
   chmod 600 ~/.secrets.zsh
   ```

   Gak perlu semuanya diisi — makin banyak yang keisi, makin banyak
   fallback provider yang tersedia kalau satu provider lagi limit/down.

4. Install dependency sesuai platform.

   Termux:
   ```sh
   pkg install zsh gum jq fzf fd bat curl tmux coreutils patch python termux-api
   ```

   Debian/Ubuntu:
   ```sh
   sudo apt install zsh jq fzf fd-find bat curl tmux coreutils patch python3
   ```

   macOS (dukungan parsial):
   ```sh
   brew install zsh jq fzf fd bat curl tmux coreutils
   ```

5. Restart shell, lalu cek dependency:

   ```sh
   ai deps
   ```

---

## 2. Entry Point — AI Workspace

Paradigma baru: **ketik `ai` tanpa argumen** untuk membuka **AI Workspace**.
Tidak ada lagi menu panjang — cukup ketik apa yang ingin kamu kerjakan.

```sh
ai
```

Output yang muncul:

```
────────────────────────────────────────────
 Bagas AI  ·  main  ·  GPT-5.6  ·  ~/project
────────────────────────────────────────────

  Ketik prompt atau / untuk Command Palette

> _
```

Ketik prompt bebas — AI otomatis menentukan mode:

| Prompt kamu | Mode yang dipilih AI |
|---|---|
| `jelaskan JWT` | Chat |
| `buat proposal AI` | Long / Writing |
| `fix auth bug` | Agent / Code |
| `edit app.py tambah validasi` | Code |
| `scan project` | Project |

---

## 3. Slash Commands

Dari dalam workspace, ketik `/` diikuti command untuk aksi langsung:

| Slash Command | Fungsi |
|---|---|
| `/` atau `/?` | Buka **Command Palette** (gum filter, bisa search) |
| `/chat <pesan>` | Chat cepat |
| `/code <deskripsi>` | Generate kode baru |
| `/fix` | Auto-fix file dari error |
| `/scan` | Scan project |
| `/agent <goal>` | Jalankan AI Agent loop |
| `/review` | Code review diff |
| `/commit` | Generate commit message |
| `/session <nama>` | Mulai session baru |
| `/details` | Tampilkan **detail log** aksi terakhir |
| `/config verbosity 0` | Output **minimal** (hanya hasil akhir) |
| `/config verbosity 1` | Output **normal** — default |
| `/config verbosity 2` | Output **detail** (nama tool, file) |
| `/config verbosity 3` | Output **debug** (semua log internal) |
| `/stats` | Statistik token/usage |
| `/dev` | Workspace tmux |
| `/help` | Bantuan lengkap |

Contoh:

```sh
> /fix
> /config verbosity 0
> /details
> /agent fix semua bug di auth module
```

---

## 4. Verbosity — Kontrol Output

Output AI bisa dikontrol dengan level verbosity.

**Level 0 — Minimal** (cocok untuk HP, hemat layar):
```
✓ Done  ·  3 files changed  ·  42s
```

**Level 1 — Normal** (default):
```
◌ Searching...
→ Using rg  ·  Found 24 files
✓ Done  ·  3 files changed  ·  42s
```

**Level 2 — Detailed** (lihat tool + file):
```
◌ Searching auth...
→ Using rg  ·  Found 24 files
  Tool: rg "auth" src/
→ Using edit  ·  auth.ts
✓ Done  ·  3 files changed  ·  42s
```

**Level 3 — Debug** (semua log internal).

Set via slash command dari workspace:
```
> /config verbosity 0
```

Atau set permanen di `90-local/local.zsh`:
```sh
export AI_VERBOSITY=1
```

---

## 5. Progressive Disclosure — `/details`

Output default sengaja **minimal**. Kalau ingin lihat detail log aksi terakhir (tool apa yang dipakai, file apa yang dibuka), ketik:

```
> /details
```

Output:
```
─────────────────────────────────
 Detail Log
─────────────────────────────────
◌ Searching auth...
→ Using rg | Found 24 matches
→ Using edit | auth.ts
⚠ Needs approval: rm build/
✓ Done
─────────────────────────────────
```

---

## 6. Chat & Tanya-Jawab

| Command | Alias | Kegunaan |
|---|---|---|
| `ai chat "<pesan>"` | `aic` | Chat cepat, model kelas *fast*, jawaban streaming. |
| `ai long "<pesan>"` | `aicl` | Chat model kelas *smart* (lebih pintar, lebih lambat). |
| `ai shell "<pesan>"` | `aish` | Minta perintah shell/Termux yang aman & langsung bisa dijalankan. |
| `ai ask "<pertanyaan>"` | `aiask` | Tanya-jawab tunggal, **pakai cache** — pertanyaan identik tidak manggil API lagi. |
| `ai clip` | `aiclip` | Kirim isi clipboard ke AI. |
| `ai session start/end/list/resume/prune` | | Sesi chat multi-turn yang tersimpan. |

Contoh:

```sh
ai chat "jelasin apa itu circuit breaker pattern"
ai ask "berapa hari dalam setahun kabisat?"
ai ask "berapa hari dalam setahun kabisat?"   # <- instan dari cache
ai shell "cari semua file .log lebih dari 7 hari lalu hapus"
```

---

## 7. Kerja dengan Kode

| Command | Kegunaan |
|---|---|
| `ai code "<deskripsi>"` | Generate file kode baru. |
| `ai edit <file> "<instruksi>"` | Edit file existing sesuai instruksi. |
| `ai view <file> [start] [end]` | Lihat isi file per-baris. |
| `ai fix <file> "<pesan error>"` | Perbaiki file dari pesan error. |
| `ai run <file.py>` | Jalankan Python, auto-fix kalau error (sampai 2x). |
| `ai project <nama> "<deskripsi>"` | Generate project multi-file dari nol. |
| `ai build "<deskripsi>"` | Mirip `ai project`, alur lebih terpandu. |
| `ai scrap <url/topik>` | Scraping/riset cepat lalu rangkum. |
| `ai commit` | Generate pesan commit dari `git diff` staged. |
| `ai review` | Review diff/perubahan terakhir. |

Contoh:

```sh
ai code "bikin script python buat convert csv ke json"
ai edit app.py "tambah validasi input di fungsi login"
ai fix app.py "TypeError: unsupported operand type(s)"
ai run app.py
```

---

## 8. Manajemen File

| Command | Kegunaan |
|---|---|
| `ai undo <file>` | Restore dari backup `.bak.*` terbaru. |
| `ai bakclean [hari]` | Bersihin backup lebih tua dari N hari (default 14). |
| `ai share <file>` | Share file lewat share-sheet Android. |
| `ai scan` | Scan ulang ringkasan project. |
| `ai index [...]` | Bikin/lihat index codebase. |

---

## 9. Perencanaan & Dokumentasi

| Command | Kegunaan |
|---|---|
| `ai plan "<tujuan>"` | Bikin rencana kerja langkah demi langkah. |
| `ai prompt "<deskripsi tugas>"` | Generate prompt siap-pakai buat AI lain. |
| `ai spec "<deskripsi aplikasi>"` | Generate spesifikasi teknis aplikasi. |
| `ai summarize <file\|url>` | Ringkas isi file atau halaman web. |

---

## 10. AI Agent Otomatis

Fitur paling powerful — agent yang bisa baca/tulis file, jalankan command, dan looping sendiri sampai tugas selesai.

```sh
ai agent "<goal>"                       # konfirmasi tiap command berisiko
ai agent --yolo "<goal>"               # auto-run (command destruktif tetap diblokir)
ai agent --no-review "<goal>"          # skip auto-review di akhir
ai agent --resume <nama_checkpoint>    # lanjut sesi yang terpotong
ai agent --list-checkpoints            # lihat daftar checkpoint
```

UI Agent saat berjalan (satu hero box):

```
┌──────────────────────────────────┐
│ AI Agent RUNNING                 │
├──────────────────────────────────┤
│ Goal: fix auth bug               │
│ Progress 3/7                     │
│ ███████░░░░░░░░░░░░░             │
├──────────────────────────────────┤
│ ✓ Scan project                   │
│ ✓ Found auth module              │
│ ● Editing auth.ts                │
│ ○ Run tests                      │
│ ○ Generate report                │
├──────────────────────────────────┤
│ Current command                  │
│ rg "auth" src/                   │
└──────────────────────────────────┘
```

Setelah selesai (SUCCESS box):

```
┌──────────────────────────────────┐
│ SUCCESS                          │
├──────────────────────────────────┤
│ Files: 3                         │
│ Time:  42s                       │
├──────────────────────────────────┤
│ ✓ JWT fixed                      │
│ ✓ Tests passed                   │
└──────────────────────────────────┘
```

Yang perlu diketahui:

- **Checkpoint otomatis** — kalau proses Termux/Android mati, progress tidak hilang.
- **Guard command berbahaya** — pola destruktif (`rm -rf`, dsb) selalu diblokir terlepas dari `--yolo`.
- **Auto-review** — setelah task selesai & ada file yang berubah, agent auto-review sekali.
- **Notifikasi Android** — kalau `termux-notification` ada, dapat update progress per-step.
- **Approval UX** — command yang butuh konfirmasi muncul sebagai card:

  ```
  ⚠  Needs approval
    rm -rf build/

  [Approve]  [Deny]
  ```

Mode agent terbatas:

| Command | Tujuan | Bisa ubah file? |
|---|---|---|
| `ai review` | Review diff, read-only | Tidak |
| `ai debug "<masalah>"` | Diagnosis, tidak ubah file | Tidak |
| `ai research "<goal>"` | Riset/inspeksi codebase, readonly | Tidak |
| `ai agent "<goal>"` | Agent full akses | Ya |

---

## 11. Update Toolkit

```sh
ai update
```

Selalu minta konfirmasi `[Approve] / [Deny]` sebelum `git pull`. Tidak ada auto-pull diam-diam.

---

## 12. Info & Maintenance

| Command | Kegunaan |
|---|---|
| `ai stats` | Statistik pemakaian token. |
| `ai log` | History chat/perintah (`aih`). |
| `ai deps` | Cek semua dependency & konfigurasi. |
| `ai dev` | Tools development toolkit ini sendiri. |
| `ai testmodels` | Test konektivitas ke semua provider. |
| `ai h` | Bantuan ringkas semua subcommand. |

> **`ai menu`** sekarang adalah alias untuk membuka **AI Workspace** (sama seperti `ai` tanpa argumen).

---

## 13. Mode Hemat Data & Baterai

Secara otomatis toolkit ini:

- **Cek baterai** sebelum operasi berat — minta konfirmasi kalau baterai rendah.
- **Cek jaringan** — info kalau kemungkinan pakai data seluler.
- **Cek budget token harian** — warning kalau lewat ambang `AI_DAILY_TOKEN_WARN`.
- **Fail-open** — kalau `termux-api` tidak terinstall, semua cek ini skip tanpa error.

---

## 14. Override Konfigurasi Personal

Taruh override di `90-local/local.zsh` — file ini tidak ikut ter-commit ke Git. Contoh:

```sh
# Verbosity default
export AI_VERBOSITY=1

# Provider priority
export AI_PROVIDER_ORDER="groq gemini cerebras"

# Matikan warning data seluler
export AI_DATA_SAVER_WARN=0

# Ambang token harian
export AI_DAILY_TOKEN_WARN=50000
```

---

## 15. Semua Subcommand (Referensi Cepat)

```
chat  long  code  edit  view  scan  fix  run  build  project  scrap
ask   shell commit review debug research plan prompt spec summarize
clip  session  agent  stats  log  menu  deps  dev  testmodels
undo  bakclean  share  index  update  h
```

Ketik `ai h` kapan saja buat lihat daftar ini plus penjelasan singkat.

---

## 16. Security Behavior

- Tool filesystem agent dibatasi ke project root secara canonical path. Relative path, `..`, prefix collision, dan symlink escape ditolak.
- `move_file` memvalidasi source **dan** destination.
- `web_fetch` hanya menerima HTTP/HTTPS, menolak URL userinfo, private/loopback/reserved IP.
- `--yolo` tidak menjadi izin universal untuk shell arbitrary. Command di luar safe-shell allowlist tetap meminta konfirmasi.
- Generated code dari `ai project` tidak dieksekusi otomatis.
- File `.aiagent/permissions.zsh` tidak dieksekusi otomatis — perlu `AI_ALLOW_PROJECT_CONFIG=1`.
- `AI_AGENT_YOLO_MODE` tidak diekspor ke child process dan dipulihkan setelah sesi agent selesai.
