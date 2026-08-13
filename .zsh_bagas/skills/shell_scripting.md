# Shell Scripting (Zsh/Bash) — Panduan Domain-Spesifik

Relevan tiap kali goal-nya nyentuh script shell itu sendiri (termasuk
repo `agent-zsh` ini sendiri) — bukan cuma manjalankan command lewat
`run_command`, tapi nulis/edit `.zsh`/`.sh` file.

## Zsh vs Bash — Jangan Disamain

- Kalau file target ber-shebang `#!/bin/zsh` atau ada di dalam repo yang
  jelas zsh (`.zshrc`, `.zsh_bagas/`), JANGAN pakai sintaks bash-only
  (`[[ ]]` aman di keduanya, tapi array indexing beda: zsh 1-indexed,
  bash 0-indexed; `${(z)var}`/`${(k)assoc}` cuma valid di zsh).
- Kalau file `.sh` polos tanpa indikasi zsh, asumsikan POSIX sh/bash —
  hindari zsh-ism (`${(s: :)var}`, `typeset -A` tanpa `-g` di scope
  global, dst).

## Verifikasi Wajib Sebelum Declare Done

```
zsh -n <file>     # syntax check untuk .zsh, TANPA menjalankan
bash -n <file>    # syntax check untuk .sh/bash
shellcheck <file> # kalau tersedia -- nangkep bug logic umum (unquoted
                   # var, [ ] vs [[ ]], dst), bukan cuma syntax error
```

`zsh -n`/`bash -n` HANYA cek syntax, bukan bukti fungsi berjalan benar —
kalau memungkinkan, jalankan juga skenario minimal (`source <file>` di
subshell lalu panggil fungsi yang diedit) sebelum declare `done: true`.

## Kebiasaan Aman

- Selalu quote variabel (`"$var"`, bukan `$var` polos) kecuali memang
  sengaja butuh word-splitting/glob — ini sumber bug paling umum di
  script shell (path dengan spasi, argumen kosong jadi hilang).
- Command destruktif (`rm -rf`, redirect ke `/dev/*`) di dalam SCRIPT
  yang ditulis agent tetap harus dianggap seserius `run_command` biasa —
  jangan generate command berbahaya cuma karena ditulis ke file, bukan
  dieksekusi langsung saat itu (skrip itu akan dijalankan user nanti).
- Function baru ikuti konvensi penamaan yang sudah ada di file
  (`grep_search("^_ai_\|^[a-z_]*()", path)` dulu buat lihat pola).

## Menambah Fungsi/Modul ke Repo Zsh Modular (kayak agent-zsh ini)

- Baca `README.md` dulu buat paham urutan load (`NN-nama.zsh`, prefix
  angka nentuin urutan `source`, bukan alfabetis biasa).
- Modul baru dapat prefix angka sesuai DEPENDENSI-nya (butuh fungsi apa
  dari modul mana), bukan asal ditaruh di akhir.
- Update `CHANGELOG.md` (bernomor, ngikutin pola `v-fix`/entri existing)
  tiap kali nambah/ubah fungsi — ini konvensi eksplisit repo ini,
  bukan opsional.
