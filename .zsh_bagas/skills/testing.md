## Skill: testing

- Cari dulu test command yang beneran dipakai project ini (lihat project summary/package.json/pyproject) sebelum nebak `pytest`/`npm test`.
- Jalankan test yang relevan aja dulu (targeted) sebelum full test suite, biar cepat dapat sinyal.
- Test gagal karena assertion beda dengan test gagal karena error/crash itu dua kelas masalah berbeda -- tangani sesuai jenisnya, jangan disamain.
- Setelah fix, jalankan ulang test yang tadi gagal DULU, baru full suite buat cek regresi.
