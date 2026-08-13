# Web Development di Termux

## Setup Node.js

```bash
pkg install nodejs
node --version   # cek versi
npm --version
```

- **Jangan** rekomendasikan `nvm` — tidak compatible dengan Termux langsung
- Versi Node.js di Termux bisa lebih lama dari latest LTS — cek dulu sebelum pakai fitur bleeding edge

## Membuat Project Baru

```bash
# Vite (paling ringan, cocok untuk Termux)
npm create vite@latest myapp -- --template vanilla
cd myapp && npm install && npm run dev

# React dengan Vite
npm create vite@latest myapp -- --template react
cd myapp && npm install && npm run dev

# Hindari create-react-app — sangat lambat dan berat untuk HP
```

## Backend Sederhana

```bash
# FastAPI (Python, cocok untuk Termux)
pip install fastapi uvicorn
uvicorn main:app --reload --host 0.0.0.0 --port 8000

# Express.js (Node)
npm init -y && npm install express
node server.js
```

## Pola Port & Akses

- Server berjalan di `localhost` atau `0.0.0.0` — akses dari browser HP di `http://127.0.0.1:<port>`
- Kalau mau akses dari HP lain di WiFi yang sama: gunakan IP lokal HP (cek via `ip addr`)
- Port di bawah 1024 butuh root — gunakan port >= 3000, 8000, 8080

## HTML/CSS/JS Vanilla (Paling Ringan)

Untuk project sederhana di Termux, pertimbangkan vanilla tanpa framework:
```bash
# Langsung buka di browser HP
termux-open index.html
# atau serve via Python
python3 -m http.server 8080
```

## Hal yang Perlu Diperhatikan

- `npm install` bisa lambat karena storage HP — gunakan `--prefer-offline` jika sudah pernah install
- Node modules besar — pertimbangkan `.npmrc` dengan `cache=/sdcard/npm-cache` untuk hemat storage internal
- Build production (`npm run build`) bisa makan RAM 500MB+ — pastikan device tidak OOM
- Jika build OOM: kurangi worker di vite.config: `build: { minify: false }` dulu untuk debug

## Stack Rekomendasi untuk Termux

| Kebutuhan | Rekomendasi |
|-----------|-------------|
| Landing page | HTML + CSS vanilla + Python http.server |
| Web app interaktif | Vite + Vanilla JS |
| REST API | FastAPI (Python) atau Express (Node) |
| Full-stack sederhana | FastAPI + Jinja2 template |
| Database | SQLite (`sqlite3` built-in Python) |
