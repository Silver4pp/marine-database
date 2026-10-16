# Raw SQL — database baru atau pemulihan terpisah

## Pilihan yang disarankan

`BARU.sql` adalah snapshot lengkap level DDL65: schema dan data demo/UAT yang sudah ada di snapshot. Jalankan **hanya** ke database baru yang kosong atau clone disposable yang memang akan dibuang, setelah DBA menyetujui ekstensi PostGIS dan hak akses: `psql -d <database_baru_kosong> -f BARU.sql`. Setelah itu aplikasi memerlukan migrasi/bootstrap Django sebagaimana runbook.

**Jangan jalankan `BARU.sql` atau file DML terhadap database utama, Step124, atau LIVE.** Data di dalamnya adalah isi snapshot lokal termasuk seed demo; jangan perlakukan sebagai kejadian bisnis atau bukti produksi. Tidak ada database yang dibuat/diubah saat folder ini disiapkan.

## Berkas di dalam folder

- `BARU.sql` — snapshot satu berkas untuk restore ke database kosong, level65.
- `01-schema.sql` dan file bernomor sampai DDL65 — rantai schema/migrasi resmi yang sama seperti sumber di folder induk; gunakan hanya melalui prosedur restore/upgrade yang telah ditinjau dan secara berurutan. Nomor DDL yang tidak ada mengikuti rancangan rantai resmi.
- `02-data-dummy.sql` dan file yang secara eksplisit bernama demo — DML seed yang sudah ada di proyek. Ini opsional untuk database demo/disposable, bukan data produksi.
- `MANIFEST-SHA256SUMS.txt` — checksum salinan yang dibundel.

## Tidak dibundel

`00-truncate.sql` sengaja tidak disalin karena mengosongkan data bisnis. `refresh-demo-waktu.sql`, perbaikan ad-hoc, dan skrip `UPGRADE-LIVE-*` juga tidak termasuk paket database baru: bukan bagian snapshot restore yang disarankan dan dapat salah diterapkan pada baseline yang berbeda.

Untuk database existing atau unggahan ke layanan lain, jangan menganggap snapshot ini sebagai skrip upgrade. Tinjau backup, baseline DDL, ekstensi, role/ownership, DDL yang sudah terpasang, serta proses restore dengan DBA; jalankan verifikasi read-only setelahnya.
