# Patch Notes — hasil debug & perbaikan

## v7 — Tanggal: 2026-08-13 — UI polish (warna ANSI)

Murni tampilan, NOL perubahan logic/behavior. Ditambahkan warna ANSI ke
box (`_ai_ui_box`), baris compact (`_ai_ui_line`), dan spinner
(`_ai_spinner_start`):

- Box `✓ COMPLETE` -> border hijau, `✗ BLOCKED` -> border merah, box
  lain -> accent cyan netral. Judul dicetak bold.
- Icon `_ai_ui_line`: ✓ hijau, ✗ merah, → cyan, ◌ kuning, • dim —
  ke-detect di kedua bentuk (unicode ATAU ASCII fallback), jadi tetap
  jalan walau `AI_UI_ASCII_FALLBACK=1`.
- Spinner: frame cyan, `(Ns)` elapsed dim.

**Keamanan perubahan ini (biar gak bikin bug baru):**

1. Semua kode warna DISISIPKAN ke string yang SUDAH selesai dihitung
   lebar/paddingnya — perhitungan `title_len`/`avail`/`pad` semuanya
   tetap pakai teks POLOS (tanpa kode warna), sama persis kayak
   sebelumnya. Dibuktikan dengan diff otomatis: versi baru dengan warna
   dipaksa OFF (`AI_UI_NO_COLOR=1`) menghasilkan output BYTE-IDENTIK
   dengan implementasi lama (sebelum ada warna sama sekali).
2. Warna otomatis mati (fallback ke output polos, TANPA kode ANSI sama
   sekali) kalau: `NO_COLOR` di-set (standar no-color.org), atau
   `AI_UI_NO_COLOR=1` (toggle manual baru, `00-config/25-persona.zsh`,
   pola sama kayak `AI_UI_ASCII_FALLBACK`), atau `TERM=dumb`, atau
   output-nya bukan tty (dipipe/di-log/redirect ke file) — jadi log
   file / `ai agent --log` / output yang di-`grep`/di-parsing gak pernah
   ketiban byte escape code yang bikin sampah.
3. `_ai_ui_box`/`_ai_ui_line` sudah diverifikasi (grep seluruh repo)
   TIDAK PERNAH dipanggil lewat `$(...)` / ditangkap ke variable di
   mana pun di codebase ini — selalu langsung di-print ke terminal —
   jadi menambah kode ANSI ke outputnya gak mempengaruhi logic lain.
4. Signature fungsi TIDAK berubah (`_ai_ui_box(title, lines...)` sama
   persis) — tone warna box dideteksi dari ISI teks title yang udah ada
   (✓/COMPLETE/✗/BLOCKED), bukan parameter baru, jadi semua caller lama
   (`44-finalize.zsh`, `40-runtime/20-print_header.zsh`, dst) jalan
   tanpa perubahan apa pun.

Semua file yang disentuh (`00-config/25-persona.zsh`,
`60-ui/00-ui_text.zsh`, `60-ui/05-ui_box.zsh`, `10-core/15-spinner.zsh`)
lolos `zsh -n`, dan seluruh 128 file `.zsh` di repo tetap lolos `zsh -n`
sesudahnya.

## v6 — Tanggal: 2026-08-13

Audit manual line-by-line terhadap `30-ai/20-chat/*`, `30-ai/60-ui/*`,
`30-ai/30-code/*`, dan `30-ai/50-agent/*` (dibaca penuh, bukan cuma grep
pola lama). Sebagian besar sudah bersih / sudah pernah di-fix di v5
(termasuk bug `move_file` tracking dan `$'\n'` replacement-side yang
sebelumnya diaudit — sudah terverifikasi ulang masih benar).

**BUG BARU ditemukan & di-fix — `echo` menulis konten AI-generated
langsung ke file, bukan `printf '%s\n'`:**

zsh builtin `echo` (beda dari bash) nge-interpret backslash-escape
(`\n`, `\t`, dst) secara default. Kalau konten yang ditulis punya
literal `\n` (dua karakter, bukan newline beneran) — hal yang wajar
muncul di teks/kode/JSON hasil AI — `echo` diam-diam mengubahnya jadi
newline BENERAN, merusak file. Dibuktikan empiris: `echo` mengubah
`\n` literal jadi 1 byte newline; `printf '%s\n'` menyimpan persis
2 karakter aslinya. Sebagian file di codebase ini sudah pakai
`printf '%s\n'` untuk alasan ini (`30-code/00-scrap.zsh`,
`30-code/05-code.zsh`), tapi 6 file berikut masih pakai `echo` mentah:

- `30-ai/30-code/45-fix.zsh` — hasil `aifix` ditulis ke `<file>.fixed`
- `30-ai/05-tools/50-tool_todo.zsh` — todo list JSON (paling parah:
  `\n` literal di dalam string JSON yang berubah jadi newline mentah
  bikin JSON-nya INVALID, gagal di-parse `jq` lagi)
- `30-ai/40-workflow/20-aibuild.zsh` — spec file yang dibaca ulang oleh
  `aiproject`
- `30-ai/40-workflow/05-aiplan.zsh` — file rencana `.md`
- `30-ai/40-workflow/15-aispec.zsh` — spec file (dibaca ulang oleh
  `aiproject`) + salinan clipboard
- `30-ai/40-workflow/10-aiprompt.zsh` — file prompt tersimpan + salinan
  clipboard

Semua diganti ke `printf '%s\n' "$var"`. Di-cek `zsh -n` (syntax check)
lolos di semua 6 file.

Tanggal: 2026-08-12

Repo ini identik dengan `config.zip` asli (149 file), plus 4 perbaikan bug.

## FIX 1 — `ai edit` / `aipatch` crash tanpa argumen

**File:** `.zsh_bagas/30-ai/35-files/10-aipatch.zsh`

**Masalah:** `shift` dipanggil sebelum memeriksa jumlah argumen → error  
`shift count must be <= $#` saat `ai edit` tanpa argumen.

**Perbaikan:** Cek `$# -lt 2` sebelum `shift`, tampilkan usage.

## FIX 2 — `ai session` crash tanpa subcommand

**File:** `.zsh_bagas/30-ai/20-chat/20-session_mgmt.zsh`

**Masalah:** `local action="$1"; shift` tanpa cek `$#`.

**Perbaikan:** Jika tanpa argumen, langsung masuk REPL session default (`main`).

## FIX 3 — Deteksi file binary false-positive

**File:** `.zsh_bagas/30-ai/35-files/00-guards.zsh`

**Masalah:** Fallback `grep -qU $'\x00'` (tanpa perintah `file`) sering  
menganggap file teks sebagai binary, terutama dengan ugrep/grep wrapper.

**Perbaikan:** Bandingkan ukuran byte sebelum/sesudah `tr -d '\0'`.

## FIX 4 — Checkpoint diklaim tersimpan padahal tidak ditulis

**File:** `.zsh_bagas/30-ai/50-agent/42-execution/05-get_plan.zsh`

**Masalah:** Saat API gagal di step pertama, pesan  
`[checkpoint tersimpan: ...]` dicetak tanpa memanggil  
`_ai_agent_checkpoint_save` → `--resume` tidak bisa dipakai.

**Perbaikan:** Panggil `_ai_agent_checkpoint_save` sebelum pesan;  
laporkan gagal jika file tidak tercipta.

## Temuan yang belum di-patch (opsional)

1. Pola dangerous-command package-manager tidak menangkap prefix `sudo`
   (`sudo apt-get remove -y ...` masih allowed).
2. `ai view` dengan range di luar file: silent empty, exit 0.
3. `ai log` dengan history.jsonl kosong masih memanggil fzf (ioctl error
   di non-TTY).

## Cara pakai (singkat)

Lihat `CARA-PAKAI.md`. Intinya:

```sh
# copy ke home
cp -a .zsh_bagas ~/.zsh_bagas
# pastikan ~/.zshrc me-load modul (lihat .zshrc di archive ini)
# isi API key
cat > ~/.secrets.zsh <<'EOK'
export GROQ_API_KEY="..."
# export GEMINI_API_KEY="..."
EOK
chmod 600 ~/.secrets.zsh
# cek
ai deps
ai h
```
