# Marine Database

Skema PostgreSQL untuk platform VesselCore (11 schema terintegrasi).

## 📂 Struktur Schema

1. **`param`**: Parameter sistem, konfigurasi, dan data organisasi.
2. **`usr`**: Pengguna, hak akses (RBAC), dan kontak.
3. **`site`**: Lokasi kerja dan roster.
4. **`partner`**: Pihak ketiga (kontraktor, surveyor).
5. **`vessel`**: Manajemen kapal, sertifikat, kru, dan log pergerakan.
6. **`buyer`**: Data pembeli dan ledger deposit.
7. **`operational`**: PO, DO, log produksi, survei, dan Bill of Lading (B/L).
8. **`finance`**: Invoice, pajak, pembayaran, dan retribusi (PNBP).
9. **`enviro`**: Data buoy laut, kualitas air, cuaca, dan insiden.
10. **`document`**: Registri dokumen fisik/digital untuk semua entitas.
11. **`audit`**: Log aktivitas CUD, error, dan riwayat login.

## ⚙️ Otomatisasi & Performa

- **Triggers**: Auto-update timestamp, audit activity otomatis, dan kalkulasi deposit real-time.
- **Partisi & Indeks**: Log pergerakan kapal dan buoy dipartisi berdasarkan waktu untuk efisiensi kueri skala besar. Indeks terpasang pada foreign key dan koordinat geospasial.