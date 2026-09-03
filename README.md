# Marine Database

Skema PostgreSQL untuk platform VesselCore (13 schema terintegrasi).

## 📂 Struktur Schema

1. **`param`**: Parameter sistem, konfigurasi negara, mata uang, unit pengukuran (UOM) beserta konversinya, status, dan threshold.
2. **`site`**: Informasi lokasi kerja/operasi beserta tipe dan koordinat geospasialnya.
3. **`user`**: Informasi pengguna, peran (role), dan detail kontak.
4. **`partner`**: Data pihak ketiga (mitra/partner) dan tipenya.
5. **`buyer`**: Data pembeli, lokasi pembeli, dan riwayat ledger (transaksi kredit/debit).
6. **`fleet`**: Manajemen kapal (fleet), penugasan (assignment leg), dan pemeliharaan (maintenance) kapal.
7. **`form`**: Pencatatan pengambilan sampel air dan hasil pengukurannya.
8. **`laboratory`**: Informasi laboratorium dan hasil uji lab dari sampel.
9. **`survey`**: Form survei lapangan untuk pengambilan sampel air dan pengukuran.
10. **`enviro`**: Data stasiun pemantauan lingkungan, kualitas air, pasang surut laut, pembacaan buoy, serta pemeliharaannya.
11. **`commercial`**: Transaksi komersial mencakup *Purchase Order* (PO) dan *Delivery Order* (DO).
12. **`operational`**: Area kerja spasial, instruksi pengiriman (*Shipment Instruction*), aktivitas kerja, dan catatan harian pengerukan (*dredging records*).
13. **`voyage`**: Pelacakan posisi spasial kapal secara *real-time* dan riwayat perjalanannya (*voyage history*).

## ⚙️ Otomatisasi & Performa

- **Triggers**: 
  - *Auto-update* `updated_at` secara global untuk semua tabel.
  - *Immutability* (mencegah update/delete) pada *ledger history* pembeli, mengharuskan *reversal entry*.
  - Validasi otomatis volume pengerukan agar tidak melebihi target di *Delivery Order*.
- **Constraint Eksklusi**: Mencegah tumpang tindih (*overlap*) jadwal penugasan kapal secara otomatis menggunakan GIST *daterange*.
- **Indeks**: Menggunakan indeks BRIN untuk efisiensi data *time-series* skala besar pada log pergerakan kapal dan sensor lingkungan (buoy, pasang surut, kualitas air). Indeks GIST terpasang untuk pencarian koordinat spasial (titik/poligon), serta indeks B-Tree standar pada *foreign key* dan kolom pencarian utama.
- **Views**: Tersedia *view* kalkulasi otomatis seperti saldo deposit/ledger pembeli dan status pemeliharaan terakhir untuk kapal serta stasiun pemantauan.