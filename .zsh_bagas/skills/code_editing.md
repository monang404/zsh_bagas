# Code Editing — Strategi Aman untuk edit_file & write_file

Skill ini mengatur bagaimana agen harus mendekati tugas edit kode.
SELALU ikuti urutan ini sebelum memodifikasi file apa pun.

## Urutan Wajib Sebelum Edit

1. **Baca dulu, baru edit** — gunakan `read_file` untuk melihat konten dan nomor baris
2. **Cari konteks spesifik** — gunakan `grep_search` untuk menemukan fungsi/class target
3. **Baru edit** — gunakan `edit_file` dengan `old_str` yang PERSIS sama (termasuk spasi/indent)
4. **Verifikasi** — gunakan `read_file` lagi di area yang diubah untuk konfirmasi

## Aturan old_str di edit_file

- `old_str` harus **unik di seluruh file** — jika teks muncul lebih dari sekali, tambahkan
  beberapa baris konteks di atas/bawahnya sampai string itu unik
- Jangan potong indent/whitespace — copy PERSIS termasuk spasi di awal baris
- Jika file panjang, gunakan `grep_search` dulu untuk menemukan baris pastinya,
  lalu `read_file` dengan offset ke sekitar baris itu untuk mendapat old_str yang akurat

## Strategi Minimal Diff

- Ubah HANYA yang diperlukan — jangan rewrite fungsi yang tidak diminta
- Jika diminta "tambahkan logging ke fungsi X", edit hanya fungsi X saja
- Jangan pernah menulis ulang seluruh file untuk perubahan kecil → pakai `edit_file`
- `write_file` hanya untuk file BARU yang belum ada

## Verifikasi Setelah Edit

- Untuk file Python: jalankan `python3 -m py_compile <file>` via `run_command` untuk cek syntax
- Untuk file JS/TS: gunakan `node --check <file>` jika tersedia
- Untuk file Zsh: gunakan `zsh -n <file>` untuk syntax check
- Jika verifikasi gagal, segera perbaiki sebelum declare `done: true`

## Urutan Standar untuk Bug Fix

```
1. read_file(path) — lihat keseluruhan kode
2. grep_search(pattern="error|bug_related_keyword", path) — temukan area masalah
3. read_file(path, offset=<baris_masalah-5>, limit=20) — baca sekitar area masalah
4. edit_file(path, old_str=<tepat>, new_str=<perbaikan>)
5. run_command("python3 -m py_compile <path>") — verifikasi
```
