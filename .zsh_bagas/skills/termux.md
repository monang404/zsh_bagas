# Termux (Android) — hal yang wajib diinget

Ini environment Termux di Android, BUKAN Linux server/desktop biasa.
Command yang lazim di server sering gak jalan sama sekali di sini.

## Gak ada / beda dari Linux biasa
- **Gak ada `sudo`/root.** Jangan pernah usulin command berawalan `sudo`.
  Kalau butuh privilege lebih (mis. install ke `/usr`), itu biasanya
  gak perlu di Termux -- semua paket ke-install ke prefix Termux sendiri
  (`/data/data/com.termux/files/usr`), bukan `/usr` sistem Android.
- **Gak ada systemd/systemctl/service.** Termux gak punya init system.
  Proses background pakai `nohup cmd &`, `tmux`/`screen`, atau paket
  `termux-services` (`sv-enable`) kalau memang ke-install.
- **Package manager itu `pkg`** (wrapper tipis di atas `apt` khusus
  repo Termux) — pakai `pkg install`/`pkg upgrade`/`pkg search`, JANGAN
  `apt-get`/`apt` langsung (bisa nunjuk ke repo yang salah).
- **Gak ada cron bawaan.** Buat task terjadwal, pakai
  `termux-job-scheduler` (kalau `termux-api` ke-install) atau
  `tmux` + loop `sleep`.

## Path & storage
- `$HOME` = `/data/data/com.termux/files/home`.
- Storage HP (Download/DCIM/Pictures/dll) BUKAN langsung bisa dibaca
  lewat `/sdcard`. Wajib `termux-setup-storage` dulu (sekali, minta izin
  Android), baru bisa diakses lewat `~/storage/shared`,
  `~/storage/downloads`, dst.
- Kalau command butuh nulis ke storage bersama dan `~/storage` belum
  ada, sarankan `termux-setup-storage` dulu sebagai langkah terpisah,
  jangan asumsikan udah ke-setup.

## Baterai & jaringan
- Proses Termux bisa di-throttle/dibunuh Android (Doze/OOM killer)
  kalau app di-background & layar mati. Command yang makan waktu lama
  (build, download besar, loop AI berturut-turut) sebaiknya disaranin
  jalan di dalam `tmux` session (`aidev`/`tm`), bukan foreground shell
  polos yang mati begitu app di-swipe.
- Jaringan mobile data gampang putus-nyambung (ganti wifi<->seluler,
  masuk terowongan/lift, dst) — command yang nge-`curl`/`wget` panjang
  sebaiknya idempotent/bisa di-retry, bukan sekali jalan tanpa guard.

## Notifikasi & interaksi (kalau `termux-api` ke-install)
- `termux-notification` buat kasih tau user command panjang udah
  selesai walau app lagi di-background.
- `termux-toast`, `termux-vibrate` buat feedback cepat non-intrusive.
- `termux-battery-status` buat cek level baterai sebelum operasi berat.
- `termux-share` buat kirim file hasil kerja ke app Android lain
  (WhatsApp, GitHub, dst) lewat share sheet, tanpa perlu `cd` manual.

## Ringkasan buat command generation
Kalau ragu command tertentu ada di Termux atau nggak, lebih aman
asumsikan environment MINIMAL (gak ada root, gak ada systemd, gak ada
banyak tool GNU/server yang lazim di distro besar) dan pakai
alternatif yang eksplisit tersedia lewat `pkg`.
