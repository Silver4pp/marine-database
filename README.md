# Marine Database (Skema Pasir Laut - Final Version)

Repositori ini berisi skema database PostgreSQL untuk platform manajemen operasional dan lingkungan pasir laut (**VesselCore / Pasir Laut Platform**). Skema ini mencakup total 11 schema yang saling terintegrasi dengan struktur yang dioptimalkan untuk performa, auditabilitas, dan integritas data.

---

## 📂 Struktur Schema

Database ini dibagi menjadi beberapa schema berikut:

1. **`param`**: Parameterisasi sistem, konfigurasi global, notifikasi, uom (unit of measure), komoditas, dan data organisasi.
2. **`usr`**: Manajemen pengguna (*user*), peran (*role*), perizinan (*permission*), dan informasi kontak (*contact*). *Catatan: Sebelumnya dinamai `user` (dihindari karena reserved keyword).*
3. **`site`**: Lokasi operasional (tambang/dermaga) dan jadwal kerja PIC lapangan (*roster*).
4. **`partner`**: Pihak ketiga seperti kontraktor, surveyor, atau agen pemeliharaan kapal.
5. **`vessel`**: Manajemen kapal (isap, tongkang, tugboat), sertifikat, kru, pemeliharaan (*maintenance*), dan log pergerakan kapal (*movement log*).
6. **`buyer`**: Informasi pembeli, lokasi bongkar muat (*discharge location*), dan buku besar deposit (*deposit ledger*).
7. **`operational`**: Dokumen operasional utama termasuk PO (Purchase Order), DO (Delivery Order), persetujuan (*approval*), produksi harian, survei kargo, Bill of Lading (B/L), dan Statement of Facts (SoF).
8. **`finance`**: Invoice (penjualan & pembelian), pencatatan pajak, pembayaran (*payment*), dan retribusi pemerintah (*government dues / PNBP*).
9. **`enviro`**: Monitoring lingkungan laut melalui buoy (salinitas, kekeruhan, dll), kualitas air (*water quality*), log cuaca, kepatuhan (*compliance report*), dan log insiden lingkungan.
10. **`document`**: Registri dokumen fisik atau file digital (*file registry*) yang dapat ditautkan ke entitas mana pun melalui tabel relasi dinamis.
11. **`audit`**: Log aktivitas, penanganan galat (*error log*), dan riwayat masuk log masuk pengguna (*login history*).

---

## 📊 Detail Tabel per Schema

### 1. Schema `param` (Sistem & Parameter)
*   **`system_config`**: Konfigurasi sistem global (contoh: batas toleransi, kunci API).
*   **`dropdown_list`**: Pilihan dropdown dinamis di UI. Menggunakan constraint unique `uq_dropdown` pada `(category, code_value)`.
*   **`notification_template`**: Template pesan notifikasi berdasarkan platform (WhatsApp, Email, dll).
*   **`notification_log`**: Log pengiriman notifikasi dengan relasi foreign key ke template.
*   **`abbreviation`**: Singkatan istilah maritim/teknis.
*   **`uom`**: Daftar satuan pengukuran (*Unit of Measure*), misalnya `M3`, `MT`, `LTR`, `KG`.
*   **`commodity`**: Jenis komoditas tambang (contoh: `SEA_SAND` / Pasir Laut, `GRAVEL` / Kerikil) dengan default UOM.
*   **`organization`**: Struktur organisasi instansi/perusahaan terkait.

### 2. Schema `usr` (Pengguna & Akses)
*   **`role`**: Peran pengguna (contoh: `Admin`, `Operations`, `Finance`).
*   **`permission`**: Daftar hak akses modul sistem.
*   **`role_permission`**: Penghubung banyak-ke-banyak (*many-to-many*) antara role dan permission.
*   **`info`**: Profil user utama, menyimpan `password_hash` yang terenkripsi dan terhubung ke organisasi.
*   **`contact`**: Data kontak user (email, telepon) dengan penanda kontak utama (`is_primary`).

### 3. Schema `site` (Lokasi Kerja)
*   **`type`**: Jenis site (contoh: Tambang Pasir, Pelabuhan Bongkar, Kantor Pusat).
*   **`info`**: Informasi detail site lengkap dengan koordinat spasial (`latitude`, `longitude`).
*   **`roster`**: Jadwal kerja PIC lapangan. Dilengkapi unique constraint `roster_prevent_double_booking` pada `(code_user, work_date, shift)`.

### 4. Schema `partner` (Mitra Kerja)
*   **`type`**: Jenis partner (contoh: Surveyor, Agen Pemeliharaan, Pemilik Kapal Mitra).
*   **`info`**: Profil perusahaan mitra.
*   **`contact`**: Kontak PIC dan alamat komunikasi mitra.

### 5. Schema `vessel` (Armada Kapal)
*   **`type`**: Tipe kapal (contoh: TSHD, Sand Carrier, Tugboat).
*   **`info`**: Informasi kapal dengan nomor IMO dan Call Sign yang bersifat unik (`UNIQUE`).
*   **`site_assignment`**: Penugasan kapal ke site operasional dalam rentang tanggal tertentu (dengan pengecekan validitas tanggal lewat constraint `chk_site_assignment_dates`).
*   **`certificate`**: Dokumen sertifikasi kelayakan kapal beserta masa kedaluwarsa.
*   **`crew_history`**: Sejarah penugasan kru kapal beserta perannya (status dibatasi oleh constraint `chk_crew_status` antara `ON_BOARD` atau `SIGNED_OFF`).
*   **`maintenance`**: Jadwal dan status perbaikan kapal (status dibatasi oleh constraint `chk_mt_status`: `SCHEDULED`, `IN PROGRESS`, `COMPLETED`, `CANCELLED`).
*   **`movement_log`**: Log pergerakan kapal yang **dipotong berdasarkan rentang waktu (*partition by range* pada kolom `log_time`)** untuk performa skala besar.
    *   *Partisi contoh*: `movement_log_202601` dan `movement_log_202602`.

### 6. Schema `buyer` (Pembeli & Keuangan Buyer)
*   **`type`**: Klasifikasi buyer (Domestik / Ekspor).
*   **`info`**: Profil perusahaan pembeli beserta kolom saldo deposit (`deposit_balance`).
*   **`discharge_location`**: Titik koordinat lokasi pembongkaran pasir laut yang diizinkan untuk buyer.
*   **`deposit_ledger`**: Catatan riwayat setoran/debit dana deposit buyer.

### 7. Schema `operational` (Transaksi Operasional)
*   **`purchase_order`**: Dokumen Purchase Order dari buyer. Status dibatasi constraint `chk_po_status` (`DRAFT`, `SUBMITTED`, `APPROVED`, `IN PROGRESS`, `COMPLETED`, `CANCELLED`).
*   **`approval_log`**: Log alur persetujuan PO/DO oleh admin/user berwenang.
*   **`daily_production`**: Log produksi harian pasir laut per kapal per hari (terdapat unique constraint pada kombinasi `code_vessel` dan `production_date`).
*   **`delivery_order`**: Dokumen jalan/instruksi pengiriman kapal. Status dibatasi constraint `chk_do_status` (`ISSUED`, `LOADING`, `SAILING`, `DELIVERED`, `CANCELLED`).
*   **`cargo_survey`**: Hasil pengukuran volume pasir laut oleh pihak ketiga. Dilengkapi constraint status `chk_survey_status` (`PENDING`, `VERIFIED`, `REJECTED`).
*   **`bill_of_lading`**: Dokumen Bill of Lading (B/L) untuk pengapalan kargo. Status dibatasi constraint `chk_bl_status` (`ISSUED`, `RELEASED`, `SURRENDERED`).
*   **`statement_of_fact`**: Urutan kronologi aktivitas kapal selama proses loading/unloading (SoF).

### 8. Schema `finance` (Keuangan & Retribusi)
*   **`exchange_rate`**: Kurs nilai tukar mata uang asing ke IDR (terdapat unique constraint pada `currency_from`, `currency_to`, `rate_date`, dan `rate_type`).
*   **`invoice`**: Dokumen penagihan. Memiliki constraint integritas entitas `chk_invoice_entity` (jika tipe `SALES` wajib ada `code_buyer` dan tanpa `code_partner`, jika `PURCHASE` wajib ada `code_partner` tanpa `code_buyer`). Status dibatasi constraint `chk_invoice_status` (`DRAFT`, `ISSUED`, `PAID`, `PARTIAL`, `CANCELLED`).
*   **`invoice_delivery_order`**: Tabel jembatan banyak-ke-banyak (*many-to-many*) antara invoice dan delivery order.
*   **`invoice_item`**: Detail item barang/jasa dalam invoice.
*   **`invoice_tax`**: Detail pajak penambahan nilai (PPN/PPH) per invoice.
*   **`payment`**: Log pembayaran invoice. Status dibatasi constraint `chk_payment_status` (`PENDING`, `COMPLETED`, `FAILED`).
*   **`government_dues`**: Kewajiban PNBP (Penerimaan Negara Bukan Pajak) dan iuran eksploitasi pasir laut berdasarkan volume DO. Status dibatasi constraint `chk_govdues_status` (`UNPAID`, `PAID`).
*   **`v_invoice_summary` (VIEW)**: View analisis untuk validasi integritas total tagihan invoice antara subtotal yang disimpan vs hasil kalkulasi item + pajak (menghasilkan status `VALID` atau `MISMATCH`).

### 9. Schema `enviro` (Pemantauan Lingkungan)
*   **`buoy_info`**: Detail alat pelampung sensor (buoy) pemantau air laut. Status dibatasi constraint `chk_buoy_status` (`ACTIVE`, `INACTIVE`, `MAINTENANCE`).
*   **`buoy_reading`**: Log berkala sensor buoy (salinitas, kekeruhan air, DO, level pasang surut) yang **dipotong berdasarkan waktu (*partition by range* pada `record_time`)**.
    *   *Partisi contoh*: `buoy_reading_202601` dan `buoy_reading_202602`.
*   **`incident`**: Log kejadian luar biasa di area tambang/kapal (umpama: tumpahan minyak). Status dibatasi constraint `chk_incident_status` (`INVESTIGATING`, `RESOLVED`, `CLOSED`).
*   **`water_quality`**: Hasil uji kualitas air laut berkala di laboratorium site. Status dibatasi constraint `chk_wq_status` (`NORMAL`, `WARNING`, `CRITICAL`).
*   **`water_quality_parameter`**: Nilai parameter kimia/fisika air hasil uji lab (TSS, logam berat, dll).
*   **`weather_log`**: Catatan cuaca harian di site pertambangan.
*   **`compliance_report`**: Dokumen laporan analisis dampak lingkungan (AMDAL) berkala yang diserahkan ke instansi pemerintah. Status dibatasi constraint `chk_compliance_status` (`DRAFT`, `SUBMITTED`, `APPROVED`, `REJECTED`).

### 10. Schema `document` (Dokumen & Lampiran)
*   **`category`**: Kategori dokumen (contoh: Kontrak PO, Dokumen Surveyor, Sertifikat Kapal).
*   **`file_registry`**: Tempat penyimpanan informasi URL unduh file (AWS S3 / Supabase Storage) dan ukurannya.
*   **`entity_link`**: Penghubung dinamis untuk melampirkan file ke tabel mana pun di database menggunakan pencocokan kolom `reference_schema`, `reference_table`, dan `reference_id`.

### 11. Schema `audit` (Log Keamanan & Audit)
*   **`activity_log`**: Rekaman aktivitas perubahan data (CUD). Kolom `code_user` sengaja tidak diberi foreign key ke `usr.info` agar log tidak hilang apabila data user tersebut dihapus atau ketika aksi dilakukan oleh sistem otomatis (`SYSTEM`).
*   **`error_log`**: Rekaman error runtime aplikasi backend untuk mempermudah debugging pengembang.
*   **`login_history`**: Log riwayat otentikasi login pengguna (menyimpan IP address dan user agent).

---

## ⚙️ Otomatisasi Database (Functions & Triggers)

Database ini dilengkapi beberapa fungsi otomatis:

1.  **Auto Update Timestamp (`update_updated_at_column`)**:
    *   Pemicu (*trigger*) yang memperbarui kolom `updated_at` secara otomatis menjadi `NOW()` setiap kali baris data pada tabel berikut diubah (*UPDATE*):
        *   `usr.info`
        *   `vessel.info`
        *   `operational.purchase_order`
        *   `operational.delivery_order`
        *   `finance.invoice`
        *   `buyer.deposit_ledger`
2.  **Auto Audit Activity (`fn_audit_activity` & `trg_audit_*`)**:
    *   Setiap aksi *INSERT*, *UPDATE*, dan *DELETE* pada tabel inti (`usr.info`, `vessel.info`, `operational.purchase_order`, `operational.delivery_order`, `finance.invoice`, `finance.payment`) akan otomatis dicatat ke dalam `audit.activity_log` lengkap dengan data lama (`old_data`) dan data baru (`new_data`) dalam tipe JSONB.
3.  **Auto Balance Deposit (`update_buyer_deposit_balance` & `trg_update_deposit_balance`)**:
    *   Setiap kali ada transaksi deposit baru (*CREDIT* atau *DEBIT*) di `buyer.deposit_ledger`, saldo akhir di `buyer.info.deposit_balance` milik buyer tersebut akan otomatis dikalkulasi ulang dan diperbarui secara *real-time*.

---

## ⚡ Optimalisasi Kinerja (Indexes)

Untuk mendukung kecepatan pencarian data pada tabel berukuran besar, database ini mengimplementasikan indeks-indeks berikut:
*   **Indeks Audit**: `idx_audit_activity_user` (berdasarkan pembuat aksi), `idx_audit_activity_table` (berdasarkan target baris data), dan `idx_audit_activity_time` (berdasarkan waktu kejadian).
*   **Indeks Operasional**: Indeks foreign key pada alur DO ke PO, kapal utama, cargo survey, dan Bill of Lading.
*   **Indeks Keuangan**: Indeks pencarian cepat invoice berdasarkan buyer, partner, DO, serta indeks transaksi pembayaran.
*   **Indeks Waktu & Geospasial**: Indeks temporal untuk data sensor buoy (`idx_env_buoy_reading_time`), pergerakan kapal (`idx_vessel_movement_time`), dan kondisi cuaca (`idx_env_weather_time`).
*   **Indeks Produksi & Approval**: Mempercepat visualisasi dashboard produksi dan pencarian log otorisasi PO/DO.