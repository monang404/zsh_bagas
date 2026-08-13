# Python di Termux — Panduan Khusus

## Setup Environment

- **Virtual environment**: gunakan `python -m venv .venv` (bukan `virtualenv`)
  Aktivasi: `source .venv/bin/activate`
- **Jangan** rekomendasikan `conda` atau `pyenv` — tidak tersedia di Termux default
- Package install: `pip install <pkg>` di dalam venv, atau `pip install --user <pkg>` tanpa venv

## Package yang TIDAK ada di pip Termux tapi ada alternatifnya

| Dibutuhkan | Alternatif di Termux |
|------------|---------------------|
| `tkinter` | Tidak tersedia — gunakan CLI atau web (Flask/FastAPI) |
| `curses` | Ada tapi terbatas — lebih baik gunakan `rich` atau `urwid` |
| `pygame` | Tidak tersedia — gunakan alternatif berbasis teks |
| `numpy`/`scipy` | `pkg install python-numpy` (bukan pip!) untuk versi yang sudah dikompilasi |
| `pillow` | `pkg install python-pillow` lalu pip install biasanya tetap butuh libpng |

## Pola yang Benar di Termux

```python
# ✅ Benar — path ke file di Termux
import os
home = os.path.expanduser("~")  # /data/data/com.termux/files/home

# ✅ Benar — baca stdin dengan timeout guard
import sys
line = sys.stdin.readline().strip()

# ❌ Jangan — /tmp mungkin kecil di beberapa device
# Gunakan tempfile.mkdtemp() atau $TMPDIR yang di-set Termux
```

## Menjalankan Script

- Gunakan `python3` (bukan `python`) — di Termux `python` bisa tidak ada
- Untuk script yang butuh input interaktif, generate input dulu via file:
  `echo "input1\ninput2" | python3 main.py`
- Untuk background: `nohup python3 main.py &> output.log &`

## Testing

- `pytest` tersedia via `pip install pytest`
- Jalankan: `python3 -m pytest` (lebih reliable daripada `pytest` langsung)
- Kalau butuh mock HTTP: gunakan `responses` library, bukan server real

## Struktur Project yang Direkomendasikan

```
myproject/
├── main.py          # entry point
├── requirements.txt # dependensi
├── .venv/           # virtual env (jangan di-commit)
└── tests/
    └── test_main.py
```
