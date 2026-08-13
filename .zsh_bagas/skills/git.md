## Skill: git

- `git status` dan `git diff` dulu sebelum ambil keputusan apa pun -- jangan asumsi state repo.
- Jangan `git commit` kecuali diminta eksplisit oleh user.
- Jangan pernah pakai command destruktif (`reset --hard`, `clean -fd`, `push --force`) tanpa konfirmasi eksplisit dari user di luar loop otomatis.
- Commit message singkat, jelas, dan sesuai isi diff -- bukan generik ("update", "fix stuff").
