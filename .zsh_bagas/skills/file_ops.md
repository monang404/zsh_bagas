# File Operations — Panduan Tool Registry

## Kapan Pakai Tool Apa

| Situasi | Tool yang Tepat |
|---------|----------------|
| Ingin tahu isi file | `read_file(path)` |
| Ingin tahu isi file di baris tertentu | `read_file(path, offset=N, limit=M)` |
| Ingin tahu file apa saja ada | `list_dir(path)` |
| Cari teks/fungsi di dalam file | `grep_search(pattern, path)` |
| Cari file berdasarkan nama | `glob_search(pattern)` |
| Buat file baru | `write_file(path, content)` |
| Ubah sebagian isi file existing | `edit_file(path, old_str, new_str)` |
| Jalankan perintah shell | `run_command(command)` |

## Strategi Navigasi Project Besar

**Jangan langsung baca semua file** — itu boros token dan lambat.

Urutan yang efisien:
```
1. list_dir(".")           → lihat struktur folder
2. glob_search("*.py")     → temukan file yang relevan
3. grep_search("def <nama_fungsi>", ".")  → temukan lokasi spesifik
4. read_file(path, offset=<baris>, limit=30)  → baca area yang relevan saja
```

## Batasan yang Harus Diketahui

- **`read_file` limit**: `AI_FILE_MAX_CHARS=40000` karakter — untuk file yang lebih besar,
  gunakan `offset` + `limit` untuk membaca per bagian
- **`grep_search` limit**: `AI_GREP_MAX_RESULTS=100` baris — jika hasil terlalu banyak,
  persempit `path` ke subfolder yang lebih spesifik atau tambahkan `glob` filter
- **`write_file` menolak file existing** — jika file sudah ada, WAJIB pakai `edit_file`
- **`list_dir` default 50 entry** — untuk folder dengan banyak file, gunakan `glob_search`

## Menulis File Baru dengan Konten Panjang

Jika konten file terlalu panjang untuk satu `write_file`, buat dulu file kosong
lalu gunakan rangkaian `edit_file` untuk menambahkan section:

```json
// Langkah 1: buat file dengan struktur dasar
{"tool": "write_file", "args": {"path": "main.py", "content": "# main module\n"}}

// Langkah 2: tambahkan import
{"tool": "edit_file", "args": {"path": "main.py", "old_str": "# main module\n", "new_str": "# main module\nimport os\nimport sys\n"}}
```

## Path Relatif vs Absolut

- Selalu gunakan path relatif dari direktori project saat ini (`./`)
- Jika harus menggunakan path absolut di luar `$PWD`, sistem akan meminta konfirmasi user
- Jangan asumsikan path seperti `/home/user/` — di Termux HOME adalah `/data/data/com.termux/files/home`

## Membaca File Binary / Gambar

- `read_file` akan menolak file binary secara otomatis
- Untuk inspeksi file binary, gunakan `run_command("file <path>")` atau `run_command("xxd <path> | head -20")`
