# Cara Pakai zsh-bagas AI Hub

Panduan ini fokus ke **cara pakai** semua command `ai *`. Untuk struktur folder/arsitektur internal, lihat `README.md`.

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

4. Install dependency sesuai platform. **Jangan menjalankan `pkg` di Linux/macOS.**

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

5. Restart shell (`zsh` baru / buka terminal baru), lalu cek semuanya
   ke-detect dengan benar:

   ```sh
   ai deps
   ```

   Ini nampilin dependency mana yang OK/MISSING, versi `jq`/`curl`,
   status `termux-api` (notifikasi, wake-lock, battery), permission
   `~/.secrets.zsh`, dan skill yang ke-load.

## 2. Cara manggil

Semua fitur lewat satu dispatcher `ai <subcommand> [argumen]`. Beberapa
subcommand juga punya alias command langsung yang lebih pendek (misal
`ai chat` = `aic`, `ai agent` = `aiagent`).

```sh
ai                     # buka menu interaktif (gum) kalau dipanggil tanpa argumen
ai <subcommand> ...    # jalanin subcommand langsung
```

Kalau kamu ketik subcommand yang typo (misal `ai comit`), toolkit ini
nawarin koreksi ("maksudnya 'ai commit'?") sebelum lanjut — gak
langsung nembak jadi chat call ke API begitu aja.

## 3. Chat & tanya-jawab cepat

| Command | Alias | Kegunaan |
|---|---|---|
| `ai chat "<pesan>"` | `aic` | Chat cepat, model kelas *fast*, jawaban streaming (muncul token demi token). |
| `ai long "<pesan>"` | `aicl` | Chat model kelas *smart* (lebih pintar, lebih lambat), non-streaming. |
| `ai shell "<pesan>"` | `aish` | Minta perintah shell/Termux yang aman & langsung bisa dijalankan. |
| `ai ask "<pertanyaan>"` | `aiask` | Tanya-jawab tunggal, **pakai cache** — pertanyaan identik yang diulang gak manggil API lagi. Tambah `--no-cache` buat paksa jawaban baru. |
| `ai clip` | `aiclip` | Kirim isi clipboard ke AI (konten sensitif difilter dulu). |
| `ai session start/end/list/resume/prune` | | Sesi chat multi-turn yang tersimpan, bisa dilanjut lain waktu. |

Contoh:

```sh
ai chat "jelasin apa itu circuit breaker pattern"
ai ask "berapa hari dalam setahun kabisat?"
ai ask "berapa hari dalam setahun kabisat?"   # <- ini instan, dari cache
ai shell "cari semua file .log lebih dari 7 hari lalu hapus"
```

## 4. Kerja dengan kode

| Command | Kegunaan |
|---|---|
| `ai code "<deskripsi>"` | Generate file kode baru (bikin diff+backup kalau file target udah ada). |
| `ai edit <file> "<instruksi>"` | Edit file existing sesuai instruksi (`--force` buat skip guard panjang file). |
| `ai view <file> [start] [end]` | Lihat isi file (opsional per-baris). |
| `ai fix <file> "<pesan error>"` | Perbaiki file berdasarkan pesan error, hasil ditulis ke `<file>.fixed`. |
| `ai run <file.py>` | Jalanin file Python, auto-fix kalau error (sampai 2x percobaan). |
| `ai project <nama_folder> "<deskripsi>"` | Generate project multi-file baru dari nol. Generated code hanya diverifikasi syntax; **tidak dieksekusi otomatis**. |
| `ai build [-o nama_folder] "<deskripsi>"` | Mirip `ai project`, alur workflow yang lebih terpandu. |
| `ai scrap <url/topik>` | Scraping/riset cepat lalu rangkum jadi draft kode/teks. |
| `ai commit` | Generate pesan commit dari `git diff` staged. |
| `ai review` | Review diff/perubahan terakhir. |

Contoh:

```sh
ai code "bikin script python buat convert csv ke json"
ai edit app.py "tambah validasi input di fungsi login"
ai fix app.py "TypeError: unsupported operand type(s)"
ai run app.py
```

## 5. Manajemen file bantu

| Command | Kegunaan |
|---|---|
| `ai undo <file>` | Restore dari backup `.bak.*` terbaru. |
| `ai bakclean [hari]` | Bersihin backup `.bak.*` (dan cache `ai ask`) yang lebih tua dari N hari (default 14). |
| `ai share <file>` | Share file lewat share-sheet Android (`termux-share`). |
| `ai scan` | Scan ulang ringkasan project (manifest `package.json`/`requirements.txt`/dst). Auto re-scan kalau manifest berubah. |
| `ai index [...]` | Bikin/lihat index codebase (dipakai internal oleh `grep_search`/`glob_search` di `ai agent`). |

## 6. Perencanaan & dokumentasi

| Command | Kegunaan |
|---|---|
| `ai plan "<tujuan>"` | Bikin rencana kerja langkah demi langkah. |
| `ai prompt "<deskripsi tugas>"` | Generate prompt siap-pakai buat AI lain. |
| `ai spec "<deskripsi aplikasi>"` | Generate spesifikasi teknis aplikasi. |
| `ai summarize <file\|url>` | Ringkas isi file atau halaman web. |

## 7. Agent otomatis (`ai agent`)

Ini fitur paling "berat" — agent yang bisa baca/tulis file, jalankan
command, dan looping sendiri sampai tugas selesai (atau mentok).

```sh
ai agent "<goal>"                       # jalan normal, minta konfirmasi tiap command berisiko
ai agent --yolo "<goal>"                # command jalan otomatis tanpa konfirmasi manual (command destruktif TETAP diblokir apa pun mode-nya)
ai agent --no-review "<goal>"           # skip auto-review di akhir (hemat token/waktu)
ai agent --resume <nama_checkpoint>     # lanjutin sesi yang kepotong/berhenti di tengah
ai agent --list-checkpoints             # lihat daftar checkpoint yang bisa di-resume
```

Yang perlu diketahui:

- **Checkpoint otomatis** — kalau proses Termux/Android mati di tengah
  jalan, progress gak hilang. Tinggal `ai agent --resume <slug>`.
- **Guard command berbahaya** — pola command yang destruktif (`rm -rf`,
  dsb) selalu diblokir, terlepas dari `--yolo`.
- **Auto-review** — setelah task selesai & ada file yang berubah,
  agent otomatis review sekali (matiin dengan `--no-review`).
- **Notifikasi Android** — kalau `termux-notification` ada, sekali
  aplikasi ini jalan di background kamu tetap dapet update progress
  per-step (notifikasi yang sama ter-update, bukan numpuk) plus
  notifikasi "selesai" di akhir.
- **Subagent researcher** — untuk goal besar/kompleks, agent bisa
  nawarin riset dulu (readonly) sebelum mulai kerja beneran; defaultnya
  "tidak" kalau kamu enter kosong.
- **Log per-sesi** — lihat lewat `ai log` (`aih`), detail lengkap tiap
  step ada di `generate/sessions/agent_checkpoints/` dan tool-run log.

Mode agent lain yang lebih spesifik/terbatas:

| Command | Tujuan | Bisa ubah file? |
|---|---|---|
| `ai review` | Review diff, read-only | Tidak |
| `ai debug "<masalah>"` | Diagnosis pakai run_test/run_command, tidak boleh ubah file | Tidak |
| `ai research "<goal>"` | Riset/inspeksi codebase, readonly | Tidak |
| `ai agent "<goal>"` | Agent full akses (baca+tulis+jalankan) | Ya |
| `ai code "<deskripsi>"` | Generate kode langsung | Ya |

## 8. Update toolkit ini sendiri

```sh
ai update
```

- Kalau `~/.zsh_bagas` adalah Git working tree: cek status dulu (branch,
  ada perubahan lokal yang belum commit atau nggak), **selalu** minta
  konfirmasi `y/n` sebelum benar-benar `git pull`, dan backup config
  lokal (mis. `90-local/local.zsh`) dulu kalau berpotensi conflict.
  Tidak ada auto-pull diam-diam, tidak ada `git reset`/`git clean`
  paksa kalau pull gagal.
- Kalau bukan Git repo: dikasih instruksi update manual, **tidak** ada
  percobaan download otomatis dari mana pun.

## 9. Info & maintenance

| Command | Kegunaan |
|---|---|
| `ai stats` | Statistik pemakaian (token per hari, dst). |
| `ai log` | Lihat history chat/perintah (`aih`). |
| `ai deps` | Cek semua dependency & konfigurasi (jalankan ini pertama kali / kalau ada yang aneh). |
| `ai dev` | Tools tambahan buat development toolkit ini sendiri. |
| `ai testmodels` | Test konektivitas ke semua provider/model yang dikonfigurasi. |
| `ai menu` | Buka menu interaktif `gum` (sama seperti manggil `ai` tanpa argumen). |
| `ai h` | Bantuan ringkas semua subcommand. |

## 10. Mode hemat data & baterai

Tanpa perlu diapa-apain, toolkit ini otomatis:

- **Cek baterai** sebelum operasi berat (`ai agent`/`ai project`) —
  minta konfirmasi kalau baterai rendah & tidak sedang charging.
- **Cek jaringan** — kasih 1 baris info kalau kemungkinan lagi pakai
  data seluler (bukan WiFi), bukan blocking. Matiin lewat
  `AI_DATA_SAVER_WARN=0` di `90-local/local.zsh`.
- **Cek budget token harian** — warning kalau pemakaian token hari itu
  udah lewat ambang (`AI_DAILY_TOKEN_WARN`), minta konfirmasi lanjut.
- Semuanya **fail-open**: kalau `termux-api` gak ke-install sama
  sekali, semua cek ini otomatis skip tanpa error/nge-block apa pun —
  jadi toolkit ini tetap jalan normal di Linux desktop biasa (bukan
  cuma Termux).

## 11. Override konfigurasi personal

Taruh override di `90-local/local.zsh` (copy dari
`90-local/local.zsh.example`) — file ini **tidak** ikut ter-commit ke
Git (sudah di-`.gitignore`). Contoh yang biasa diubah: urutan provider
default, ambang baterai/token, atau mematikan warning tertentu.

## 12. Semua subcommand (referensi cepat)

```
chat long code edit view scan fix run build project scrap ask shell
commit review debug research plan prompt spec summarize clip session
agent stats log menu deps dev testmodels undo bakclean share index
update h
```

Ketik `ai h` kapan saja buat lihat daftar ini plus penjelasan singkat
langsung dari terminal.

## 7. Security behavior penting

- Tool filesystem agent dibatasi ke project root secara canonical path. Relative path, `..`, prefix collision, dan symlink escape ditolak.
- `move_file` memvalidasi source **dan** destination.
- `web_fetch` hanya menerima HTTP/HTTPS, menolak URL userinfo, private/loopback/link-local/reserved IP, mengikat koneksi ke alamat hasil DNS validation, dan tidak mengikuti redirect otomatis.
- `--yolo` tidak lagi menjadi izin universal untuk shell arbitrary. Command yang tidak masuk safe-shell allowlist tetap meminta konfirmasi.
- Generated code dari `ai project` tidak dieksekusi otomatis. Project hanya menjalani syntax check Python.
- File `.aiagent/permissions.zsh` di dalam project tidak dieksekusi otomatis. Jika memang ingin memakai konfigurasi project-local, set `AI_ALLOW_PROJECT_CONFIG=1` secara eksplisit sebelum menjalankan agent.
- `AI_AGENT_YOLO_MODE` tidak diekspor ke child process dan dipulihkan setelah sesi agent selesai.
