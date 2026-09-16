# Changelog Database — ERP Pasir Laut

Skema final: **13 schema · 74 tabel** (lihat `serah-terima/database/01-schema.sql` untuk DDL lengkap terkini, `02-data-dummy.sql` untuk data insert).

## Struktur Schema (kondisi akhir)

| Schema | Isi | Tabel |
|---|---|---|
| `operational` | trip, NOR, SI, jadwal, permit, waiting log, work area | 10 |
| `commercial` | kontrak, PO, DO, BAP (+koreksi/keberatan), QA, sand spec, standby claim | 11 |
| `financial` | journal (+line), invoice, cost, **pnbp_charge, pnbp_tahap_awal, pnbp_tarif** | 6 |
| `enviro` | station, mon_parameter/report/schedule/work_order, reading_detail, ews_event, remediasi | 8 |
| `hse` | incident, inspection, certificate, toolbox_meeting, induction, capa | 6 |
| `telemetry` | ais_position, **vessel_device, geofence, geofence_event** | 4 |
| `notification` | rule, log, **report_schedule, email_outbox** | 4 |
| `param` | system_parameter, currency, status, **audit_log** | 4 |
| `partner` / `buyer` / `fleet` / `site` / `survey` / `voyage` / `document` | master & tautan dokumen | 17 |

## Perubahan per Gelombang Pengembangan (Task 40–55)

> Format: task · nama — perubahan DDL/data.

### Task 40–43 — Peta v2 & Lingkungan
- **40 peta-v2**: peta Leaflet + SVG server-side; perubahan tampilan (tanpa DDL).
- **42 IKAL**: tabel pemantauan kepatuhan lingkungan + data seed (`uat/13-ikal.sql`).
- EWS event & remediasi terhubung ke work order monitoring.

### Task 44–45 — Keuangan & Kepatuhan
- **44 PNBP**: tabel **`financial.pnbp_tarif`** (master tarif berlaku per periode), **`financial.pnbp_charge`** (tagihan otomatis dari volume BAP), **`financial.pnbp_tahap_awal`** (4 tagihan lama tarif 15.000 — dipertahankan utk audit); jurnal terintegrasi.
- **45 klausul kontrak**: pemetaan klausul ↔ data operasional/komersial utk pantau kepatuhan (tabel master + view; asersi di `uat/` terkait).

### Task 46–50 — Data Operasional & UX
- **46 cuaca**: proxy Open-Meteo Forecast (tanpa DDL — data eksternal).
- **47 hardening data**: constraint/pemeriksaan kualitas data monitoring (duplikat, nilai ekstrem, keterlambatan).
- **48 indeks kualitas air**: agregat indeks per stasiun dari `reading_detail`.
- **49 marine**: Open-Meteo Marine API (gelombang/swell) — tanpa DDL.
- **50 dark mode**: UI (tanpa DDL).

### Task 51–52 — Geofence & IKAL lanjutan
- **51 geofence**: tabel **`telemetry.geofence`** (poligon area kerja), **`telemetry.geofence_event`** (event masuk/keluar kapal), **`telemetry.vessel_device`** (perangkat kapal).
- **52 IKAL v2**: penyempurnaan modul IKAL (pantau abonemen & kepatuhan).

### Task 53 — RBAC & Audit Parameter
- **`param.audit_log`**: log perubahan parameter (nilai lama/baru, siapa, kapan — prinsip P-3).
- **`param.system_parameter`**: parameter efektif dapat disunting ADMIN; pemicu tagihan memakai nilai berlaku.
- Mapping peran↔halaman diterapkan di kode (bukan DDL).

### Task 54 — Approval Berjenjang & Soft-Delete
- **`operational.schedule_proposal`**: usulan rencana jadwal hasil simulasi (belum menulis jadwal resmi).
- **`operational.schedule_plan`**: jadwal resmi — hanya terisi setelah **approval 2 tingkat** (audit siapa/kapan).
- **Soft-delete**: baris tak dihapus fisik — kolom status/tanda hapus (lihat DDL `01-schema.sql`); uji suite approval (21 cek).

### Task 55 — PDF & Email Terjadwal
- **`notification.report_schedule`**: jadwal laporan per email (daily/weekly/monthly, aktif/nonaktif, pemilik).
- **`notification.email_outbox`**: log kiriman (11 kolom — no dokumen PDF, penerima, status SENT, timestamp).
- Nomor dokumen berurutan `RPT/{SLUG}/{YYYYMMDD}/{NNN}` dihitung dari outbox (tanpa window lag — baris pertama aman).
- Arsip PDF demo di folder aplikasi `erp/laporan_pdf/` (bukan tabel).

### Serah terima (patch final, tanpa DDL)
- Filter menu/modul per peran; guard `trip_detail` (BAP None, `je_date` berupa date); sidebar minimize; remark Supabase & flag `AIS_MODE` di `settings.py`; modul `core/ais.py` (integrasi AIS live — belum aktif).

## Konvensi yang Berlaku
- Kolom audit umum: `created_at`/`updated_at` (cek `01-schema.sql` per tabel), data uji via file SQL di `uat/` (run-all 21 suite).
- Setiap perubahan DDL baru **wajib** punya suite/asersi UAT dan masuk `run-all.sh` (standar dipertahankan sejak Task 44).
- Setelah run-all: jalankan `restore/fix-owner.sql` (reparasi kepemilikan objek di lingkungan uji).

## 2026-09-11 · Perbaikan menyeluruh ("perbaiki semua code")

### `database/02-data-dummy.sql` → **v2** (regenerasi)
- v1 hanya memuat data inti **tanpa seed skenario UAT** → cold-start membuat modul
  Klausul GPS (3/5 compliant), PNBP (DUE H-1), Geofence, dsb. tampil kosong/tak sesuai,
  dan suite uji browser gagal. v2 = dump dari kondisi UAT lengkap (112 asersi PASS):
  pemulihan 01+02 satu langkah mereproduksi aplikasi demo penuh — terverifikasi
  15/15 suite browser + uji_prod 28/28 hijau dari cold-start.
- `uat/17-pnbp.sql`: `due_date` DUE absolut `2026-09-10` → **`CURRENT_DATE + 1`**
  (deterministik — tidak lapuk seiring waktu; payload notifikasi ikut relatif).

### Perbaikan kode app (`kode/erp`)
- `core/templates/core/dashboard.html`: tag `{% if %}` terpotong newline oleh formatter
  HTML (Django lexer menolak tag multi-baris) → digabung; format reformat pemilik dipertahankan.
- `core/views.py` (laporan): tombol "PDF" arsip outbox hanya tampil bila file benar-benar
  ada (`arsip_ada`) — sebelumnya 3 tombol mati 404 (data demo lama memakai path `/demo/*.pdf`).
- `core/views.py` (indeks modul): "Riwayat Versi" tidak lagi memindai folder restore point
  fisik (folder struktur lama `kode/restore/point/` sudah tidak ada) → daftar rilis konstan
  `RIWAYAT_VERSI` (15 gelombang pengembangan) — deterministik, tahan perpindahan struktur.

### Perbaikan perangkat uji (`uji/`)
- `uji_pdf.py`/`uji_hardening.py`: path app hardcode `/home/user/erp` → discovery fleksibel.
- `uji_peta.py`/`uji_ikal.py`: screenshot ditulis ke root `/home/user/*.png` → `uat/shot/`.
- `uji_hardening.py` bagian 5: artefak diperiksa di struktur `serah-terima/` final
  (dokumen/, kode/start.sh +executable, database/fix-owner.sql, restore/*.tar.gz);
  cek `/admin/` disesuaikan perilaku aktual (302 → login, `max_redirects=0`).
- `uji_indeks.py`: cek versi TERBARU dinamis mengikuti `RIWAYAT_VERSI` (bukan nama beku).

### Dokumen
- `DOKUMEN-SERAH-TERIMA.md`: 4 referensi `start-erp.sh` → `serah-terima/kode/start.sh`.

Verifikasi akhir (cold-start 01+02v2): UAT 112/112 · 15 suite browser 0 gagal
(±244 cek) · uji_prod 28/28 · audit statis 19 file Python + 24 template bersih ·
crawl 4 peran × 80 halaman = 320 respons 200, nol 500/nol link mati.

## 2026-09-11 · Kapal (PWA) + Form Draft Survey + TTD 3 Pihak (tugas I)

Penutupan 2 gap audit mockup v0.10 (12 tab: 10 penuh, gap = PWA Kapal & form
Draft Survey) + adaptasi TTD 3 pihak dari nama → pad gambar.

### DDL (satu-satunya)
- `commercial.bap` + 3 kolom: `signed_vessel_img` / `signed_customer_img` /
  `signed_surveyor_img` `text` (PNG data-URL dari pad canvas; ≤±200 KB).
  Terpasang via `uat/22-pwa-survey-ttd.sql` (IF NOT EXISTS) → native di
  `01-schema.sql` hasil regen. Tanpa DDL lain: PWA memakai
  `operational.manual_report` (report_id UUID klien + client_synced_at) dan
  form survey memakai `survey.draft_survey` (draft_readings/soundings jsonb)
  sebagaimana adanya.

### Fitur kode app (`kode/erp`)
- **Kapal (PWA)** `/kapal/` — logbook lapangan offline-first: antrean
  localStorage `pwa_antrean`, badge ONLINE/OFFLINE (navigator.onLine),
  quick-chips 6 jenis event, tombol Sinkronkan; endpoint `POST /kapal/lapor/`
  **idempotent** (UUID dibuat klien, ON CONFLICT DO UPDATE). Blok konfigurasi
  `[API-KAPAL]` di `views.py` (mode LOKAL/API + placeholder base_url/env-var
  token + contoh forward diremark) — satu-satunya titik edit saat API vendor
  kapal didapat.
- **Form Draft Survey** `/survey/<trip_id>/` — 9 titik (BB/TENGAH/SB ×
  DEPAN/TENGAH/BELAKANG), deduksi ballast/bunker/air tawar, koefisien
  hidrostatik (default demo 3040 t/m, tersimpan di soundings), panel hitungan
  readonly (JS pratinjau; server menghitung ulang: displacement = mean×koef,
  koreksi = −deduksi, tonnage, volume = tonnage/density), tombol Simpan Draft
  & Kunci & TTD (`is_locked` + `signed_at` → read-only permanen), prefill
  dari baris existing, upsert UNIQUE(trip_id,tipe).
- **Pad TTD 3 pihak** di `/trips/<id>/` — 3 canvas (pointer events, murni
  JS) → `POST /trips/<id>/bap/ttd/` per pihak (validasi PNG data-URL + nama);
  status BAP sengaja TIDAK diubah otomatis (pengesahan tetap lewat alur BAP
  sah → turunan otomatis konsisten).
- RBAC: menu `kapal` = {ADMIN, OPS}; akses `survey` = {ADMIN, OPS}; pad TTD
  hanya tampil utk ADMIN/OPS (finance boleh lihat detail trip tanpa pad).
  Sidebar admin 10 → 11 item, dispatcher 6 → 7.
- `modul_indeks` + kartu "Kapal (PWA)"; `RIWAYAT_VERSI` + `pwa-survey-ttd-v1`.

### Perangkat uji (`uji/`)
- Baru: `uji_pwa.py` (23 cek: online sync, offline via set_offline, auto-sync
  saat online, idempoten UUID, validasi 400), `uji_survey.py` (22 cek: hitungan
  live+server, simpan, prefill, kunci, RBAC), `uji_ttd.py` (17 cek: gambar
  pointer, simpan, validasi kosong, 3 pihak, status BAP tetap, RBAC) — semua
  idempoten utk run ulang (marker unik / pulihkan seed / bersihkan baris uji).
- Update: `uji_rbac.py` (hitungan menu 11/7, rute kapal/survey), `uji_indeks.py`
  (10 kartu + sub Form Draft Survey), `uat/run-all.sh` (ringkasan + total
  120 asersi).
- `uat/22-pwa-survey-ttd.sql`: 8 asersi — kolom TTD, struktur PWA/survey,
  sync idempoten upsert-by-UUID, insert 9 titik + konsistensi volume =
  tonnage/density, simpan TTD data-URL, cleanup (idempoten run ulang).

### Dump
- `01-schema.sql` regen (schema + 3 kolom TTD native) · `02-data-dummy.sql`
  → **v3** (data identik v2; INSERT commercial.bap kini 3 kolom lebih).
  Reload satu-langkah terverifikasi di DB scratch: trip=33 · bap=4 ·
  kolom_ttd=3 · manual_report=1 · draft_survey=8.

Verifikasi akhir (setelah regen): UAT 120/120 · 18 suite browser 0 gagal
(±276 cek; +uji_pwa/uji_survey/uji_ttd) · uji_prod 28/28 · crawl 52 URL 200
(+1×405 endpoint POST-only) · 0 console error di semua suite.

## 2026-09-11 · Perf-v1 — web lebih smooth & ringan (+ log bebas noise)

Tanpa DDL, tanpa perubahan data — murni kode app.

### Perubahan
- **`GZipMiddleware`** (settings): HTML dinamis di-gzip — dashboard 75 KB →
  21 KB (±71% lebih kecil), semua halaman turun ~3-7×. X-Frame/CSRF/static
  whitenoise tak terpengaruh (uji_prod 28/28).
- **`WHITENOISE_MAX_AGE = 86400`**: static vendor (Leaflet 147 KB) di-cache
  browser 1 hari — kunjungan ulang tanpa request ulang.
- **Prefetch-on-hover** (base.html, ±15 baris JS): link internal yang di-hover
  di-prefetch → klik terasa instan. Otomatis nonaktif bila pengguna
  `saveData` (hemat data). Endpoint POST-only tidak pernah di-link via <a>.
- **`/peta/cuaca/`**: `Cache-Control: public, max-age=300` — kunjungan ulang
  dashboard ≤5 mnt tidak mem-fetch ulang (cache server tetap ada).
- **GET `/kapal/lapor/` → 200 info endpoint** (sebelumnya 405): Django mencatat
  SEMUA respons ≥400 sebagai WARNING di log ("Method Not Allowed: …") — GET
  informatif menghilangkan noise log Back4App + self-documenting (contoh body
  JSON, catatan idempotent). POST tetap seperti sebelumnya.
- `uji_prod.py`: cek versi healthz jadi dinamis (format tanggal-nomor, tidak
  lagi hardcode '2026.09.11-1').

### Hasil terukur (dev, klien curl)
- Dashboard: 75.280 B → 21.523 B (gzip) · /kapal/ 31 KB → 9,9 KB.
- Log dev: GET /kapal/lapor/ 200 tanpa baris WARNING (sebelumnya
  "Method Not Allowed: /kapal/lapor/").

Verifikasi: UAT 120/120 · 18 suite browser 0 gagal (±276 cek) · uji_prod 28/28
· uji_live lokal 15/15 @ 2026.09.11-3. APP_VERSI → **2026.09.11-3**.

## v2026.09.11-4 — sec-v1 · Anti Kebocoran Data + Ganti Sandi (Task L)

> Tanpa DDL. Tiga perbaikan kebocoran nyata di live + hardening middleware +
> fitur ganti sandi. Patch kumulatif: berisi juga seluruh perf-v1 (-3).

### Perbaikan kebocoran (aktif di live -2, tertutup di -4)
- **`/modul/` wajib login** (`@login_required`): sebelumnya 200 tanpa login —
  statistik deposit/PNBP/armada terbaca publik.
- **`/peta/tile/` wajib login**: sebelumnya open-proxy tile OSM publik.
- **healthz `db_user` dimasking** maks 20 karakter + `…` (sebelumnya membocorkan
  project-ref Supabase `postgres.bfdhknecsgjiwxavohke`); diagnostik
  erp-vs-postgres tetap terbaca.

### Hardening middleware (core/middleware.py)
- **`HardeningMiddleware`**: `Cache-Control: private` untuk HTML autentikasi
  (proxy/CDN bersama dilarang cache; prefetch browser tetap jalan);
  `Clear-Site-Data: "cache"` saat POST logout (tombol kembali tak menampilkan
  halaman lama di komputer bersama); CSP `default-src 'self'` + `Permissions-Policy`
  (geolocation/mic/camera/payment dinonaktifkan). Tanpa `frame-ancestors`
  agar preview iframe tetap aman.
- **`SessionIdleMiddleware`**: sesi menganggur > `SESSION_IDLE_MENIT` (default 60,
  env, 0 = nonaktif) → logout paksa + redirect `?idle=1` (JSON → 401). WAJIB
  ditempatkan SETELAH SessionMiddleware (paling akhir di MIDDLEWARE).

### Fitur ganti sandi (semua peran)
- URL `/akun/ganti-sandi/` + link 🔑 di topbar. Validasi: sandi lama benar ·
  baru ≥8 · konfirmasi sama · beda dari lama · `validate_password` (prod).
- Sesi TETAP aktif (`update_session_auth_hash` — sessionid di-cycle,
  anti session-fixation; sessionid lama langsung mati).
- Tercatat di `param.audit_log` (tabel `auth_user`, kolom `password`,
  nilai `••••••`) — sandi asli tidak pernah tersimpan.

### Verifikasi (semua dijalankan ulang pasca sec-v1)
- `uji_akun.py` BARU 31/31 (link semua peran · 4 validasi · sukses · sesi awet ·
  sandi lama ditolak · audit · header · idle in-process · pemulihan demo).
- 20 suite browser 0 gagal (±307 cek) · uji_prod 36/36 (baru: seksi 4
  anti-kebocoran 8 cek) · UAT 120/120 · uji_live lokal OK.
- APP_VERSI → **2026.09.11-4**.

## v2026.09.11-5 — feat-v1 · Penutupan Gap Mockup (audit mockup 2026-09-11)

> Audit 12 tab mockup vs aplikasi: 12/12 terealisasi, 4 gap tertutup di versi ini.
> Patch kumulatif (berisi perf-v1 + sec-v1). DDL baru: **`database/04-fitur-gap-prod.sql`**.

### Gap 1 · Tugaskan Kapal (FR-02-02) — `/trips/do/<id>/kandidat|tugaskan/`
- Modal per DO antre: kandidat kapal + **skor transparan 0–100** (kapasitas 30 ·
  kedekatan posisi AIS→site 30 · beban antre 25 · kesiapan 15); blok pengerukan
  dengan sisa kuota; kapal perawatan **dieliminasi** (hard constraint).
- Pilih kapal → **SI otomatis** (`operational.shipment_instruction`) + **trip baru**
  (`LOADING`) + DO → `SI_ISSUED`. Hanya ADMIN/OPS. 3 baris `param.audit_log`.
- **FIX penting**: sequence `si_id`/`trip_id` tertinggal di 28 (seed memakai id
  eksplisit tanpa setval) → `04-fitur-gap-prod.sql` melakukan setval; INSERT kini
  memakai id eksplisit agar `trip_no` = `trip_id` (konvensi seed).

### Gap 2 · Sanggahan Customer / BapObjection (FR-05-09)
- Kartu "🗣️ Sanggahan Customer" di detail trip (bila BAP ada): daftar keberatan +
  form catat (OPEN, semua peran trips) + putusan **RESOLVED/REJECTED** dengan
  catatan (hanya ADMIN/KEU). Tercatat di `param.audit_log`.

### Gap 3 · QA sample vs spec kontrak
- Kartu "🧪 QA vs Kontrak" di detail trip: sampel MUAT/BONGKAR (lumpur · organik ·
  gradasi · verdict PASS/FAIL/PENDING · claim status) + spec kontrak
  (`commercial.sand_spec`). Read-only (data QA dari proses sampling).

### Gap 4 · Maintenance = hard constraint penjadwalan
- **DDL**: tabel baru `fleet.vessel_maintenance` (jenis DOCKING/PERBAIKAN_RUTIN/
  DARURAT, window mulai/selesai, CHECK window_end > window_start) + 2 seed.
- Seksi "🔧 Perawatan Kapal" di Armada: tambah (ADMIN/OPS) / hapus (ADMIN).
- **Gantt**: jendela digambar merah putus-putus 🔧 per baris kapal (+ legend);
  sumbu waktu otomatis diperpanjang.
- **Modal Tugaskan Kapal**: kapal yang jendelanya bentrok [kini, kini+3 hari]
  DITOLAK/dieliminasi.

### Uji
- `uji_gap.py` BARU 27/27 (modal+skor+eliminasi · SI+trip · RBAC KEU/OPS ·
  QA+spec+FAIL · objection tambah/putusan · maintenance tambah/hapus+gantt).
- UAT +`23-gap-features.sql` (DDL+seed+8 asersi) → **128 asersi** total.
- `uji_live.py` +seksi 5b (bukti DDL 04 & feat-v1 di live). APP_VERSI → **2026.09.11-5**.

## File database lengkap (serah terima)

- **`database/05-database-lengkap.sql`** (v2026.09.11-5): dump SATU file, TIGA
  bagian terpisah — ① pembuatan tabel (pre-data: ekstensi/schema/tipe/tabel/
  sequence/fungsi) · ② data (INSERT seluruh baris) · ③ index, constraint &
  trigger (post-data). Sumber: uat_pasir_laut pasca run-all 128/128 (bersih,
  deterministik). Tervalidasi: restore ke DB scratch → 72 tabel · 150 index ·
  7 trigger · 72 FK · 55 sequence · seluruh baris identik. Tabel auth Django
  tidak termasuk (dibuat `bootstrap_auth` saat boot aplikasi).

## v2026.09.11-6 (log-v1) — log produksi bersih

Rilis opsional (TANPA perubahan database). Empat sumber baris "error" di
dashboard Back4App dihilangkan dari log ke depan (log lama = history permanen):
1. `django.request` WARNING (404 scanner/.env/favicon dsb.) → level `ERROR`
   (status tetap tercatat di access log; 500 tetap terlihat).
2. `favicon.svg` + `<link rel=icon>` di base.html & login.html → browser
   berhenti meminta `/favicon.ico` (404 hilang).
3. Route `/healthz` tanpa slash → health check platform 200 langsung
   (sebelumnya 301 APPEND_SLASH).
4. Dockerfile: gunicorn `--log-level warning` → baris INFO startup (stderr,
   dilabel "error" oleh dashboard) tidak muncul lagi; bukti boot tetap ada
   via "bootstrap_auth OK".
Terverifikasi: prod-mode lokal (DJANGO_ENV=prod) — 4 request 404 ala scanner
menghasilkan 0 baris WARNING; ERROR asli (DisallowedHost) tetap tampil;
uji_live lokal 15/15 @ -6. Paket: `arsip-proses/deploy-v2026.09.11-6.tar.gz`.

## v2026.09.11-7 (feat-v2) — analitik tren · notifikasi instan · 2FA TOTP

**DDL 06 — `database/06-notifikasi-prod.sql`** (idempoten, WAJIB di prod sebelum
fitur notifikasi aktif; tanpa ini app aman — halaman Notifikasi menampilkan
petunjuk):
- BARU `notification.notif_penerima` (kanal TELEGRAM/WHATSAPP, tujuan, label,
  aktif) — dikelola ADMIN di `/modul/notifikasi/`
- BARU `notification.notif_outbox` (event, judul, isi, status
  OUTBOX/TERKIRIM/GAGAL, FK penerima) + 2 index + seed 2 penerima demo

**Tanpa DDL (kode saja):**
1. Analitik tren `/modul/laporan/analitik/` — grafik SVG server-side 12 bulan:
   volume BAP + trip (semua peran), PNBP (ADMIN/KEU), insiden HSE (ADMIN/HSE)
   + kartu KPI (volume, trip, QA pass-rate, PNBP, insiden).
2. Notifikasi instan — hook event otomatis: TUGASKAN · SANGGAHAN ·
   SANGGAHAN_PUTUSAN · MAINTENANCE (views._notif_kirim, fanout ke penerima
   aktif, tak pernah menggagalkan aksi utama). Menu Notifikasi (ADMIN):
   kelola penerima + antrean outbox + kirim uji. Kirim nyata (go-live):
   env `TELEGRAM_BOT_TOKEN` dan/atau `WA_API_URL` + cron
   `python manage.py kirim_notif` (sebelum itu: mode outbox murni).
3. 2FA TOTP opsional per akun — `/akun/2fa/` (pasang/lepas, secret base32
   160-bit, verifikasi kode), login 2 langkah `/accounts/totp/` (maks 5
   percobaan, anti session-fixation, next-URL tervalidasi). Murni stdlib
   (`core/totp.py`) — tanpa dependensi baru. Kolom `totp_secret`/`totp_aktif`
   di `core_peran_user` dibuat migrasi Django `0002_totp` via bootstrap_auth
   otomatis saat deploy (bukan lewat DDL 06).

**File database lengkap diregenerasi**: `database/05-database-lengkap.sql`
kini 74 tabel (+notif_penerima/notif_outbox) · 557 INSERT · tervalidasi
restore ke DB scratch: seluruh baris identik, 154 index · 7 trigger · 73 FK.

**Verifikasi**: UAT run-all 136/136 (24 suite, +24-notifikasi.sql 8 asersi) ·
22 suite browser 0 gagal (BARU uji_2fa 16/16; rbac menu ADMIN 12 item;
uji_akun selektor disesuaikan) · uji_prod 36/36 · uji_live lokal 18/18 @ -7.
Paket: `arsip-proses/deploy-v2026.09.11-7.tar.gz` · restore point:
`restore/feat-v2.tar.gz`.

---

## v2026.09.11-8 — ops-v1: Backup database satu klik (13 Sep 2026)

**Tanpa perubahan skema database** — tidak ada DDL baru, tidak ada restore
point baru (restore point tetap `restore/feat-v2.tar.gz`, kumulatif s.d. -7).
Yang berubah di sisi aplikasi & operasional:

1. Halaman `/modul/pengaturan/backup/` (ADMIN): tombol unduh `.sql.gz` penuh
   DB bisnis via pg_dump subprocess (`core/management/commands/buat_backup.py`;
   CLI: `python manage.py buat_backup --out <dir>`). Pencatatan otomatis:
   `param.system_parameter` key `backup_terakhir` (upsert ON CONFLICT) +
   baris `param.audit_log`. Di prod, DB 'erp' = database penuh termasuk
   tabel akun (hash sandi) — disengaja utk disaster recovery; dicatat
   eksplisit di halaman.
2. Dockerfile: memasang `postgresql-client-17` dari repo PGDG (bookworm
   default = klien 15 yang menolak server PG 17 Supabase) dengan **fallback
   graceful** `(… || echo WARN)` — build tidak pernah gagal karena apt/repo;
   bila klien absen, halaman Backup menampilkan pesan + alternatif skrip.
3. Skrip lokal `uji/backup-prod.sh` (cron-able, rotasi 4 salinan) — alternatif
   bila pg_dump tidak ada di image / utk penjadwalan di mesin sendiri.
4. **Skrip `database/refresh-demo-waktu.sql`** (BARU, opsional, aman diulang):
   menyegarkan data demo berbasis waktu (gap perangkat AIS/Starlink → klausul
   §9.1, jendela maintenance LI02/SL07, jatuh tempo tahap awal PNBP) yang
   menua seiring hari — dipakai di dev saat regresi; bisa dipakai prod.
5. Bugfix marinir (ditemukan regresi malam hari): prakiraan cuaca & marine
   Open-Meteo diperluas D-1 s/d **D+2** (72 jam; semula 48 jam sehingga
   popup 6-jam ke depan kosong bila dibuka malam).

**Verifikasi**: UAT run-all 136/136 (tanpa perubahan) · **23 suite browser
0 gagal** (BARU uji_backup 12/12: RBAC 403 non-ADMIN, unduhan gzip valid +
DDL bisnis, param + audit tercatat) · uji_prod 36/36 · uji_live lokal
**20/20** @ -8 (seksi 7 backup: halaman + unduhan nyata) · regresi penuh
ulang setelah refresh-demo-waktu (klausul 17, marine 14, pnbp 24, gap 27,
simple 13, hardening 12 — semua pulih).
Paket: `arsip-proses/deploy-v2026.09.11-8.tar.gz`.

---

## v2026.09.14-9 — feat-v3: Tata Kelola (BRD v2 W1 · 14 Sep 2026)

Eksekusi gelombang W1 BRD v2.0 rev 2.1. Perubahan DB: **DDL 07** kecil +
migrasi Django **0003_tata_kelola** (dijalankan otomatis `bootstrap_auth`).

1. `07-tata-kelola-prod.sql` — tabel `notification.notif_inapp` (kotak masuk
   notifikasi per pengguna; index username+dibaca). Hook `_notif_kirim`
   diperluas: event TUGASKAN/SANGGAHAN/SANGGAHAN_PUTUSAN/MAINTENANCE/UJI kini
   juga menulis in-app untuk peran terkait (minus aktor).
2. Migrasi 0003: kolom `core_peran_user.wajib_ganti_sandi` (sandi sementara
   dari ADMIN → dipaksa ganti via middleware) + tabel `core_login_attempt`
   (lockout akun 5× gagal → 10 menit, pesan spesifikasi di halaman login,
   tercatat audit).
3. Fitur tanpa DDL: `/modul/pengguna/` (ADMIN: buat/ubah peran/nonaktifkan/
   reset sandi — sandi sementara tampil sekali, semua sesi akun diakhiri,
   proteksi akun sendiri & ADMIN terakhir) · kebijakan sandi 10 karakter
   huruf+angka di semua pintu · `/modul/audit/` (filter + ekspor CSV,
   read-only) · 🔔 topbar + `/notifikasi/saya/` · `/bantuan/` per peran ·
   `/akun/sesi/` · command `backup_terjadwal` (Supabase Storage / fallback
   lokal, retensi 7, param + audit) dengan kartu status di halaman Backup.

**PENTING kebijakan sandi baru:** sandi demo (`admin123` dsb.) kini TIDAK
bisa diset lewat form (memuat nama akun) — hanya `bootstrap_auth`/ORM.
Saat go-live tetap disarankan mengganti sandi semua akun demo (Pengaturan →
Manajemen Pengguna → Reset Sandi).

**Verifikasi:** UAT run-all 136/136 · **26 suite browser 0 gagal** (BARU
`uji_pengguna` 20 · `uji_inapp` 9 · `uji_audit` 9; `uji_backup` 12→16 dengan
terjadwal+retensi; `uji_akun` 31 disesuaikan kebijakan v9 — pemulihan sandi
demo via ORM) · uji_prod 36/36 · uji_live lokal **23/23** @ -9 (seksi 8 baru:
tata kelola) · `05-database-lengkap.sql` regenerasi **75 tabel** restore-valid
(557 INSERT · baris identik · 0 error ON_ERROR_STOP) · restore point
`restore/feat-v3.tar.gz` (465 file) · paket `deploy-v2026.09.14-9.tar.gz`.

## v2026.09.14-10 — feat-v4: Pipeline Telemetri Enviro (BRD v2 W3 · 14 Sep 2026)

Eksekusi gelombang W3 BRD v2.2 (5 stasiun × 7 parameter per menit, retensi
raw 3 bulan, EWS ambang internasional). Perubahan DB: **DDL 08**.

1. `08-enviro-telemetri-prod.sql` — schema baru **`enviro_raw`**:
   `station_token` (token per stasiun utk gateway sensor), `sensor_threshold`
   (8 ambang internasional: PH 7.0–8.5 · **DO min 5.0** · TSS ≤80 ·
   TURBIDITY ≤120 · SALINITY ≤34 · AMONIA ≤0.3 · ORTOFOSFAT ≤0.015 ·
   MINYAK_LEMAK ≤5 — referensi ASEAN MWQC/Kepmen LH 51/2004; IKAL sengaja
   dikecualikan = komposit LAB), `reading` **PARTISI BULANAN**
   (`reading_pYYYY_MM` + default, index, retensi drop-partisi 3 bulan);
   `enviro.reading_daily` (n/avg/min/max/p95) + **VIEW**
   `reading_monthly_v`/`reading_yearly_v`; stasiun ST-04/ST-05
   (geometry WGS84 via `ST_SetSRID(ST_MakePoint)`); perluas CHECK
   `ews_event.trigger_rule` +`SENSOR_15MNT` (level tetap WARNING/EXCEEDED).
2. Endpoint `POST /api/enviro/ingest/` (csrf_exempt, token + batch JSON ≤2000,
   idempoten pre-check + ON CONFLICT, param di luar ambang →
   `param_tak_dikenal`; 401/405/400).
3. Command `rollup_enviro` (cron `5 * * * *`): partisi bulan ini+2 → upsert
   daily (p95 `percentile_cont`) → EWS rata-rata 15 menit vs ambang →
   `ews_event` EXCEEDED/SENSOR_15MNT (sekali per event open) + notif in-app
   `EWS_SENSOR` peran ADMIN+HSE → drop partisi > 3 bulan → param
   `rollup_enviro_terakhir`. Command `tanam_sensor_demo` (seeder deterministik).
4. Halaman `/modul/enviro/sensor/`: status stasiun (token khusus ADMIN),
   kelola ambang (ADMIN + audit P-3), tren SVG harian/bulanan/tahunan +
   **ekspor CSV/XLSX**, EWS sensor, 20 raw terakhir label SENSOR.
5. **Perbaikan alat DB** (ketemu saat regresi feat-v4):
   `fix-owner.sql` kini juga loop **VIEW** (`pg_views` — dulu hanya
   `pg_tables` → `reading_monthly_v`/`reading_yearly_v` tetap milik postgres
   → "permission denied for view" bagi user app) + GRANT schema `enviro_raw`;
   **`refresh-demo-waktu.sql` v2 idempoten-absolut** — versi lama menggeser
   `last_ping_at`/jendela maintenance relatif anchor statis 11 Sep →
   menumpuk bila dijalankan >1× tanpa run-all (ping terdorong ke masa depan
   → gap negatif → KPI klausul salah; jendela tak lagi AKTIF → uji_gap
   gagal). v2 menulis offset absolut dari now() per perangkat.

**Verifikasi:** regresi **28 suite 0 gagal** (BARU `uji_ingest` 11 ·
`uji_rollup` 12; `uji_rbac` 34 — cek kartu modul kini ke JUDUL kartu karena
tabel Riwayat Versi global memuat kata peran) · uji_prod 36/36 · uji_live
lokal **26/26** @ -10 (seksi 9 baru: telemetri sensor) ·
`05-database-lengkap.sql` regenerasi **83 tabel / 731 INSERT** restore-valid
(baris identik, 0 error ON_ERROR_STOP; raw telemetri kosong di baseline) ·
restore point `restore/feat-v4.tar.gz` · paket `deploy-v2026.09.14-10.tar.gz`.

## v2026.09.14-11 — feat-v5: Formulir Lapangan Digital (BRD v2 W4.4 · 14 Sep 2026)

Eksekusi W4.4 (keputusan 13 Sep: semua template sekaligus · foto tak disimpan
mentah · OCR DROPPED). Perubahan DB: **DDL 09** (satu tabel saja).

1. `09-formulir-lapangan-prod.sql` — `document.form_foto` (metadata lampiran
   foto formulir: form_jenis ∈ {DRAFT_SURVEY, BAP, INSPEKSI_HSE, TOOLBOX,
   MONITORING_ENVIRO} · record_id + record_label · file_path · storage
   SUPABASE/DB · ukuran/lebar/tinggi · data bytea KHUSUS fallback dev ·
   diunggah_oleh; index record + waktu). PROD: foto di **Supabase Storage**
   bucket `erp-form-foto` (env `SUPABASE_BUCKET_FOTO`) via REST service key —
   DB hanya metadata; DEV tanpa env: bytea TERKOMPRESI (JPEG sisi ≤1600 px,
   ≤1 MB, EXIF dibuang) supaya tetap teruji. Tidak pernah di filesystem
   container. `MONITORING_ENVIRO` memakai record_id = nomor stasiun
   (ST-03 → 3; kode stasiun tanpa PK numerik — didokumentasikan di DDL).
2. Fitur tanpa DDL lain: `core/formpdf.py` — generator PDF 5 template
   (reportlab; kop PT, no. formulir, header terisi otomatis dari DB,
   **QR code vektor** via `reportlab.graphics.barcode.qr` — TANPA dependensi
   baru; kotak per karakter, checkbox, blok ttd; pageCompression=0 agar
   teks marker bisa divalidasi suite). Halaman `/modul/formulir/` (hub +
   unggah + galeri; kartu di indeks modul, TANPA item sidebar baru).
   Galeri lampiran di 4 halaman record: detail trip (BAP), form draft
   survey, HSE (inspeksi+toolbox), stasiun enviro. Endpoint
   `/modul/formulir/{pdf,unggah,foto,hapus}` — RBAC per jenis (lihat vs
   unggah; hapus ADMIN) + audit P-3. `requirements.txt`: + Pillow eksplisit.
3. Perbaikan suite: `uji_gap` reset_gap kini menghapus
   `operational.manual_report` (trip >911) dulu — sebelumnya FK PWA membuat
   batch reset psql GAGAL SENYAP (satu transaksi → semua rollback) sehingga
   sisa data run yang crash tak terbersihkan.

**Verifikasi:** regresi **29 suite 0 gagal** (BARU `uji_form` 21 cek: PDF 5
jenis valid ber-QR + header terisi · unggah 2,4 MB/3200 px → 148 KB/1600 px
tanpa EXIF · galeri record · RBAC · audit · hapus) · uji_prod 36/36 ·
uji_live lokal **29/29** @ -11 (seksi 10 baru: formulir lapangan) ·
`05-database-lengkap.sql` regenerasi **82 tabel / 731 INSERT** restore-valid ·
restore point `restore/feat-v5.tar.gz` · paket `deploy-v2026.09.14-11.tar.gz`.

## v2026.09.14-12 — ops-v2: Operasi Nyata Dummy-First (BRD v2 §4 W2 + rev 2.2 · 14 Sep 2026)

Prinsip W2 (keputusan 13 Sep): kredensial eksternal belum ada → semua provider
dibangun mode **dummy/simulator**; aktivasi nyata = isi env, tanpa ubah kode.
Perubahan DB: **DDL 10**.

1. `10-ops-v2-prod.sql` — **W2.4**: `financial.pnbp_kode_map` (map kode PNBP
   per jenis tagihan TAHAP_AWAL/REALISASI_BAP/PROYEKSI · kode · dasar_hukum ·
   is_placeholder — diisi placeholder contoh hingga KMA resmi; tagihan PDF
   membaca kode dari TABEL, bukan hardcode; edit via UI ADMIN + audit P-3).
   **W2.5/W2.6**: 5 baris `param.system_parameter` — penanda cron
   `ais_tarik_terakhir` · `notif_kirim_terakhir` · `email_jadwal_terakhir`
   (dibaca halaman Status Sistem; `updated_at` baris = waktu cron jalan) +
   kebijakan `wajib_2fa_peran` (JSON) · `wajib_2fa_tenggat` (tanggal).
   Index `telemetry.ais_position (fleet_code, position_at DESC)` utk
   DISTINCT ON posisi terbaru + simulator.
2. Fitur tanpa DDL lain: command **`tarik_ais`** (W2.1, cron 5 mnt) — provider
   SIMULATOR default: 8 kapal bergerak realistis per fase trip (MUAT drift
   ≤0,9 kn di blok · BERLAYAR 8–10 kn menuju site · SELESAI BONGKAR di site
   drift / di luar site berlayar kotak operasi · DOK/SIAGA diam di dok);
   armada tanpa seed posisi ikut ter-seed. `AIS_MODE=api` → provider nyata
   (parser AISHub di core/ais.py); gagal → posisi terakhir dipertahankan +
   notifikasi `AIS_SIGNAL_LOST` (in-app ADMIN+OPS + notification.log,
   anti-spam 60 mnt). **W2.5**: halaman `/modul/pengaturan/status/` (versi ·
   kesehatan/ukuran DB · cron terakhir + status SEGAR/TERLAMBAT · akun &
   kepatuhan 2FA · mode integrasi dummy-vs-env — nilai rahasia tak tampil).
   **W2.6**: kebijakan 2FA per peran — form ADMIN di Pengaturan (checkbox
   peran + tenggat); masa tenggang = banner pengingat semua halaman; lewat
   tenggat = `Wajib2faMiddleware` mengalihkan semua akses ke `/akun/2fa/`
   sampai aktif; kebijakan dinilai ulang tiap request (hapus kebijakan =
   pulih otomatis). **W2.2**: kirim_email_jadwal kirim NYATA via
   smtplib (env SMTP_HOST/PORT/USER/PASS/TLS/FROM) bila terisi — tanpa env
   perilaku arsip/outbox lama. kirim_notif/kirim_email_jadwal mencatat param
   penanda cron. Kartu indeks "Status Sistem" (ADMIN).
3. Perbaikan proses: baseline EWS IKAL/TURBIDITY (4 baris seed) pernah
   terhapus oleh cleanup demo — dipulihkan dari 05 + dicatat agar cleanup
   demo ke depan TIDAK menyapu `enviro.ews_event` seed.

**Verifikasi:** regresi **30 suite 0 gagal** (BARU `uji_ops` 35 cek: simulator
8 kapal bergerak + invarian geofence · AIS_SIGNAL_LOST + anti-spam · penanda
cron · kode PNBP edit+audit+PDF · Status Sistem + RBAC · kebijakan 2FA
tenggang→paksa→pulih) · uji_prod 36/36 · uji_live lokal **32/32** @ -12
(seksi 11 baru: Status Sistem + map kode PNBP + tagihan PDF) ·
`05-database-lengkap.sql` regenerasi **84 tabel / 739 INSERT** restore-valid ·
restore point `restore/ops-v2.tar.gz` · paket `deploy-v2026.09.14-12.tar.gz`.

## v2026.09.14-13 — feat-v6: Analitik Lanjutan + PWA Surveyor (BRD v2 §6 W4.1–W4.3 · 14 Sep 2026)

Paket L (paling berat): dua laporan analitik baru + aplikasi lapangan
offline-first. Perubahan DB: **DDL 11** (satu tabel).

1. `11-riwayat-bulanan-demo.sql` — `commercial.shipment_monthly`
   (bulan · buyer_code · volume_m3 · source ∈ {DEMO_SEED, AGG_BAP} ·
   PK (bulan, buyer_code), CHECK volume > 0). 15 baris DEMO_SEED Apr–Sep
   2026: B-PRN 21.000→**34.800** (lonjakan >20% utk demo deviasi forecast),
   B-PSR 12.400→15.200, B-WKR sporadis 3 bln (5.200/6.100/7.400 → demo
   "data kurang"). Rationale: transaksional seed hanya Jul–Sep (trip) /
   3 invoice — tidak cukup titik utk Holt per pembeli; produksi ganti
   sumber AGG_BAP (agregat BAP) begitu histori terkumpul.
2. **W4.1 Benchmark armada** `/modul/laporan/benchmark/` — produktivitas
   m³/jam (volume ÷ ts_loading_start→ts_departed, jendela wajar 0,5–72 jam)
   & m³/trip per kapal, biaya per m³ (AKTUAL cost_entry / **CAMPURAN** /
   ESTIMASI rate card PER_M3·vol / PER_TRIP / TC÷4 trip), peringkat +
   deteksi underperformer (<80% median m³/jam — SL02 235 m³/jam vs median
   ±386), tren musiman SVG server-side. RBAC: semua peran 'laporan' lihat
   produktivitas; **kolom biaya hanya ADMIN** (`boleh_biaya`).
3. **W4.2 Forecast** `/modul/laporan/forecast/` — Holt damped per pembeli
   (α/β teroptimasi), **walk-forward MAPE** (butuh ≥4 titik; B-WKR 3 bln →
   tag DATA KURANG/MAPE n/a), forecast volume bulan depan + proyeksi
   pendapatan × harga kontrak aktif + PNBP × tarif (EKSPOR/DOMESTIK),
   disclaimer amber, **peringatan deviasi aktual vs forecast >20%**
   (B-PRN Sep 34.800 vs forecast 26.237 → deviasi +32,6% merah + kartu
   peringatan). RBAC: **ADMIN+KEU saja** (403 render utk lainnya).
4. **W4.3 PWA surveyor** `/pwa/surveyor/` + `POST /pwa/surveyor/sync/` —
   form draft survey (9 titik + sounding + densitas + saksi) & BAP bisa
   diisi **di kapal tanpa sinyal**: antrean **IndexedDB** per perangkat,
   **passkey perangkat** (XOR+base64 — obfuscation sederhana sesuai BRD,
   `encodeURIComponent` agar aman non-ASCII), TTD canvas pointer ~500×150,
   geotag GPS (Permissions-Policy `geolocation=(self) camera=(self)` —
   mic/payment tetap diblok), foto kamera dikompres klien (JPEG ≤1600 px
   q0,72) lalu dikompres ulang server (`_kompres_jpeg`) via helper
   `_simpan_foto_bytes` (refaktor dari formulir_unggah feat-v5; decorator
   login dipindah ke pemanggil), pratinjau hitungan reaktif (server tetap
   menghitung ulang via `_survey_hitung`). Sinkronisasi **idempotent by
   client_id UUID**: survey upsert `ON CONFLICT (trip_id,tipe) DO UPDATE
   WHERE NOT is_locked`; konflik survey dobel (client_id beda) → KONFLIK +
   tombol **Timpa (force)/Buang** di UI; survey TERKUNCI / BAP
   SIGNED/CORRECTED → KONFLIK tanpa Timpa; BAP baru `BAP-YYYY-NNNN` DRAFT;
   meta client_id+geo+TTD+flag pwa di `draft_readings` jsonb (kolom
   `signed_at` TIDAK disentuh dari PWA — invariant web: signed_at ⟺
   is_locked "Kunci & TTD"); foto tak dikirim ulang setelah OK (anti
   duplikat); antrean diurutkan kronologis (`urut` timestamp, bukan urutan
   UUID keyPath). RBAC peran survey (ADMIN+OPS); GET endpoint = info JSON.
5. Menu sidebar baru **Surveyor (PWA)** (ikon penggaris) utk ADMIN+OPS;
   fix `Permissions-Policy` hardening (geolocation/kamera self).

**Verifikasi:** regresi **32 suite 0 gagal** (BARU `uji_bench` 29 cek:
peringkat+underperformer+RBAC biaya+MAPE+deviasi+RBAC 403 · BARU
`uji_pwa_surveyor` 44 cek: set_offline → IndexedDB antrean → auto-sync
online → verifikasi DB (survey volume/BAP DRAFT/2 foto/geo/client_id) →
idempoten → konflik dobel Buang/Timpa → TERKUNCI tanpa Timpa → BAP SIGNED
→ RBAC) · uji_prod 36/36 · uji_live lokal **38/38** @ -13 (13 seksi + idempoten sync
PWA; reported_at kini dinamis now() agar selalu tampak di riwayat) · `05-database-lengkap.sql` regenerasi **85 tabel /
1.053 INSERT** restore-valid (ON_ERROR_STOP 0 error, 84 tabel data baris
IDENTIK; +CREATE EXTENSION postgis eksplisit) · restore point
`restore/feat-v6.tar.gz` · paket `deploy-v2026.09.14-13.tar.gz`.

**Pasca-rilis — pembersihan workspace & perbaikan (14 Sep 2026, masih -13):**
1. **Pembersihan**: workspace 144 MB → 8,4 MB · **413 PNG → 0** (aset UI murni
   SVG) · cache tile peta pindah ke `/tmp/erp-tilecache` (override env
   `ERP_TILE_DIR`; tilecache = proxy OSM regeneratif) · screenshot 28 suite
   pindah ke `/tmp/uji-shot/` (44 kemunculan) · 11 checkpoint `restore/` lama
   + 11 deploy tarball lama dihapus (satu checkpoint/tarball aktif saja) ·
   folder runtime `backup_auto/`+`laporan_pdf/` dikosongkan (dibuat ulang
   `mkdir exist_ok` saat runtime) · unused import `_b64x` dihapus.
2. **Fix bug laten views.py** — baru tampak saat DB dipulihkan dari dump
   (schema `public` kosong): 8 query mentah di view `pengaturan` +
   `status_sistem` menjalankan `core_peran_user`/`auth_user`/
   `core_login_attempt` via koneksi **'erp'** (schema bisnis), padahal tabel
   ORM ada di koneksi **default** (sqlite dev / public+bootstrap prod) →
   halaman 500. Kini memakai **ORM Django koneksi default** (konsisten dgn
   cara `users` & suite uji_2fa/uji_pengguna membacanya); kebijakan 2FA
   dihitung sekali per render.
3. **Fix suite agar mandiri/idempoten**: `uji_pwa_surveyor` setup+teardown
   kini hapus `manual_report` (FK trip — sisa run lama yang ikut ter-dump
   tak lagi memblokir; suite punya cek cleanup sendiri) · `uji_ops`
   bersihkan() hapus manual_report sebelum trip (psql() senyap thd error) ·
   `uji_rollup` menanam raw ST-02/PH sendiri — dump 05 memang TIDAK memuat
   `enviro_raw.reading` (telemetri regeneratif via tanam_sensor_demo/ingest)
   sehingga tak boleh bergantung data sesi lain · bit executable
   `kode/start.sh` dipulihkan.
4. **Verifikasi ulang pasca-perbaikan**: DB dipulihkan penuh dari
   `05-database-lengkap.sql` (disaster-recovery terbukti) → regresi penuh
   **33 suite 0 gagal** (±800 cek; termasuk audit_tombol2; 4 suite yang
   sempat gagal pasca-restore kini hijau: hardening 12 · ops 35 ·
   pwa_surveyor 44 · rollup 12) · sisa data uji di DB (trip SI-UJI-W43-*/
   SI-UJI-AIS-OPS2 + manual_report) dibersihkan.
5. **Artefak di-rebuild pasca-bersih** (yang lama berisi PNG): restore point
   `restore/feat-v6.tar.gz` (793 KB · 209 file · 0 PNG · kode+db+dokumen+uji)
   · paket `deploy-v2026.09.14-13.tar.gz` (top-dir `erp-v2026.09.14-13/`,
   tanpa PNG/uat-shot/tilecache/db.sqlite3 — 461→91 entri bersih).
6. **Ronde-2 perapihan (14 Sep 2026)**: 3 import mati dihapus (`middleware.py`
   SimpleCookie · `backup_terjadwal.py` q1 · `kirim_email_jadwal.py` settings —
   `manage.py check` 0 issue) · log runtime `uji/uat/hasil/` (121 KB) dihapus
   (runner `mkdir -p` ulang) · README + STRUKTUR-FOLDER paket UAT disinkronkan
   (25 tahap/136 asersi) · `dokumen/README.md` + `DOKUMEN-SERAH-TERIMA.md`
   disegarkan (pohon folder, 33 suite, restore point tunggal, tilecache→/tmp) ·
   sesi uji sqlite dipruning 631→147 KB · checkpoint & paket deploy di-rebuild.
