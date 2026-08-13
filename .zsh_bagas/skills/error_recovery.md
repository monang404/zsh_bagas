# Error Recovery — Pola Pemulihan dari Kegagalan

## Aturan Utama: Baca Error Sebelum Fix

**JANGAN pernah menebak fix tanpa membaca pesan error terlebih dahulu.**

Urutan yang benar:
```
1. run_command("perintah yang gagal")   → dapat pesan error
2. Baca error dengan seksama
3. Jika error menyebut file, read_file(file_yang_disebut)
4. Baru tentukan fix berdasarkan bukti nyata
5. Terapkan fix
6. Jalankan ulang untuk verifikasi
```

## Klasifikasi Error dan Respons yang Tepat

### Import Error / ModuleNotFoundError
```
ModuleNotFoundError: No module named 'requests'
→ run_command("pip install requests")
→ Jika tidak berhasil: run_command("pip3 install requests")
→ Jika di dalam venv: pastikan venv aktif dulu
```

### SyntaxError Python
```
SyntaxError: invalid syntax (file.py, line 42)
→ read_file("file.py", offset=39, limit=10)  ← baca sekitar baris 42
→ Identifikasi masalah (kurung tidak tutup, indent salah, dll)
→ edit_file dengan perbaikan minimal
→ run_command("python3 -m py_compile file.py")  ← verifikasi
```

### Permission Error
```
PermissionError: [Errno 13] Permission denied
→ JANGAN langsung pakai sudo (tidak ada di Termux)
→ run_command("ls -la <path>")  ← cek permission
→ run_command("chmod +x <file>")  ← jika perlu execute permission
→ Jika file di /usr: tidak bisa diubah tanpa root — cari alternatif path
```

### Command Not Found
```
bash: xyz: command not found
→ run_command("which xyz || pkg search xyz")
→ Jika ada di pkg: run_command("pkg install xyz")
→ Jika pip package: run_command("pip install xyz")
```

### File Not Found
```
FileNotFoundError: [Errno 2] No such file or directory: 'config.json'
→ glob_search("config*")  ← cari file dengan nama mirip
→ list_dir(".")           ← lihat struktur direktori saat ini
→ Jangan buat file config baru sembarangan — tanya user dulu kalau file config kritis
```

## Batas Retry — Kapan Harus Berhenti

- Jika **tool yang SAMA dengan args yang SAMA** gagal 2 kali berturut-turut → **BERHENTI**
  Jangan ngotot retry dengan cara yang persis sama — itu loop yang tidak produktif
- Setelah 2 kali gagal yang sama: laporkan ke user dengan detail error lengkap
- Gunakan `done: false` dan jelaskan kondisi saat ini, jangan declare selesai kalau ada yang belum berfungsi

## Jangan Declare Done Sebelum Verifikasi

Sebelum set `done: true`, WAJIB verifikasi minimal satu dari:
- `run_command("python3 -m py_compile <file>")` untuk Python
- `run_command("node --check <file>")` untuk JavaScript
- `run_command("zsh -n <file>")` untuk Zsh script
- `run_command("python3 <file>")` dengan input sederhana untuk test fungsional

## Pola "Gagal Elegan" ke User

Jika setelah beberapa langkah masalah tidak bisa diselesaikan oleh agent:
- Laporkan **state saat ini** (file apa yang sudah dibuat, command apa yang sudah dicoba)
- Laporkan **error terakhir** yang didapat secara lengkap
- Sarankan **langkah manual** yang bisa dilakukan user
- Set `done: true` dengan penjelasan — jangan biarkan loop terus tanpa harapan
