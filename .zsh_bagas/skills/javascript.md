# JavaScript / Node.js — Panduan Domain-Spesifik

Beda fokus dari `web_dev.md` (setup project/stack) — ini soal kebiasaan
kode & debugging JS/Node itu sendiri.

## Async/Await vs Callback vs Promise

- Kalau project sudah pakai `async/await` di file lain, JANGAN campur
  gaya `.then()/.catch()` di file yang sama — ikuti konvensi yang sudah
  ada (`grep_search("async ", path)` dulu buat cek gaya dominan).
- Selalu bungkus `await` yang bisa gagal dengan `try/catch`, jangan
  biarkan Promise rejection gak ke-handle (`UnhandledPromiseRejection`).

## Error yang Sering Muncul & Cara Baca

```
TypeError: Cannot read properties of undefined (reading 'x')
→ Nilai sebelum '.x' itu undefined -- cari di mana variabelnya di-assign,
  bukan langsung tebak fix di baris error.

ReferenceError: xxx is not defined
→ Biasanya lupa import/require, atau typo nama variabel/fungsi.
  grep_search("xxx") dulu buat cek ada di scope mana.

Module not found: Error: Can't resolve 'xxx'
→ Package belum di-install: run_command("npm install xxx")
  atau path import salah (relative vs package name).
```

## CommonJS vs ESM

- Cek `package.json` field `"type"` (`"module"` = ESM, default/absen =
  CommonJS) SEBELUM nulis `import`/`require` — jangan asumsi.
- Jangan campur `require()` dan `import` dalam satu file yang sama.

## Verifikasi Setelah Edit

- `node --check <file>` untuk cek syntax cepat tanpa menjalankan.
- Untuk perubahan logic, jalankan test yang relevan (`run_test`) atau
  jalankan file langsung dengan input sederhana kalau belum ada test.

## Hal yang Perlu Diperhatikan di Termux

- Versi Node.js Termux bisa lebih lama dari LTS terbaru — hindari fitur
  ES2023+ yang belum tentu didukung tanpa cek `node --version` dulu.
- `npm install` lambat karena storage HP — lihat `skills/termux.md`
  untuk detail lebih lanjut soal ini.
