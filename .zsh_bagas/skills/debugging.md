## Skill: debugging

Urutan wajib:
1. Reproduksi dulu masalahnya (jalankan command yang error, lihat output aslinya).
2. Baca pesan error/traceback secara harfiah -- jangan tebak dari nama file/fungsi doang.
3. Cari baris/kondisi spesifik penyebabnya sebelum nulis fix.
4. Fix sekecil mungkin yang langsung menyasar akar masalah.
5. Jalankan ulang command yang tadi error buat verifikasi fix beneran nutup errornya.
6. Kalau error berubah jadi error lain, itu progress -- lanjut ke error baru, bukan tanda gagal.
