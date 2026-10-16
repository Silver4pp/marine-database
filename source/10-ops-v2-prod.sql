-- ============================================================================
-- DDL 10 — OPS-V2: Operasi Nyata Dummy-First (BRD v2 §4 W2 · 14 Sep 2026)
-- ============================================================================
-- Keputusan 13 Sep: kredensial eksternal belum ada → SEMUA provider dibangun
-- mode dummy/simulator; aktivasi nyata = isi env (tanpa ubah kode).
--
-- Isi:
--   1. financial.pnbp_kode_map      — W2.4: map kode PNBP (placeholder hingga
--                                     KMA resmi; diisi ADMIN via UI + audit P-3;
--                                     tagihan PDF membaca kode dari sini —
--                                     TIDAK ADA hardcode di kode aplikasi).
--   2. param.system_parameter (5)   — penanda cron terakhir (W2.5 Status Sistem):
--                                     ais_tarik_terakhir · notif_kirim_terakhir ·
--                                     email_jadwal_terakhir
--                                     + kebijakan W2.6: wajib_2fa_peran (JSON
--                                     list peran) · wajib_2fa_tenggat (ISO date;
--                                     setelah tenggat = wajib mutlak: login
--                                     dipaksa ke halaman aktivasi 2FA).
--   3. INDEX telemetry.ais_position (fleet_code, position_at DESC)
--                                     — akselerasi DISTINCT ON terbaru per kapal
--                                       (peta/kapal) + simulator tarik_ais.
-- Idempoten: ON CONFLICT DO NOTHING / IF NOT EXISTS.

-- 1. Map kode PNBP ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS financial.pnbp_kode_map (
    map_id      bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    jenis       varchar(30)  NOT NULL UNIQUE,   -- TAHAP_AWAL | REALISASI_BAP | PROYEKSI
    label       text         NOT NULL,
    kode        varchar(40)  NOT NULL,          -- kode PNBP resmi (KMA) / placeholder
    dasar_hukum text,
    keterangan  text,
    is_placeholder boolean   NOT NULL DEFAULT true,   -- true = contoh, belum KMA resmi
    updated_at  timestamptz  NOT NULL DEFAULT now(),
    updated_by  text         NOT NULL DEFAULT 'seed',
    CONSTRAINT pnbp_kode_jenis_check CHECK (jenis IN ('TAHAP_AWAL', 'REALISASI_BAP', 'PROYEKSI'))
);
COMMENT ON TABLE financial.pnbp_kode_map IS
  'W2.4: map kode PNBP per jenis tagihan — placeholder hingga KMA resmi; edit via UI ADMIN (audit P-3); tagihan PDF membaca dari sini';

INSERT INTO financial.pnbp_kode_map (jenis, label, kode, dasar_hukum, keterangan, is_placeholder, updated_by)
VALUES
  ('TAHAP_AWAL',    'PNBP tahap awal 5% (setoran awal pemanfaatan)',
   'PNBP-PLH-000-001', 'Permen KP 41/2023', 'CONTOH — ganti dengan kode KMA resmi saat terbit', true, 'seed'),
  ('REALISASI_BAP', 'PNBP realisasi pemanfaatan (per BAP)',
   'PNBP-PLH-000-002', 'PP 85/2021 jo. PP 26/2023', 'CONTOH — ganti dengan kode KMA resmi saat terbit', true, 'seed'),
  ('PROYEKSI',      'PNBP proyeksi volume kontrak (informasi)',
   'PNBP-PLH-000-003', 'PP 26/2023', 'CONTOH — ganti dengan kode KMA resmi saat terbit', true, 'seed')
ON CONFLICT (jenis) DO NOTHING;

-- 2. Parameter sistem (cron terakhir + kebijakan 2FA) -------------------------------
INSERT INTO param.system_parameter (param_key, label, nilai, satuan, keterangan, updated_by) VALUES
  ('ais_tarik_terakhir',     'Tarik AIS terakhir',            '—', 'waktu',
   'Pembaruan posisi kapal (AIS) — simulasi default; provider nyata via AIS_MODE=api', 'sistem'),
  ('notif_kirim_terakhir',   'Kirim notif instan terakhir',   '—', 'waktu',
   'Pengiriman notifikasi — mode outbox default; kirim nyata via TELEGRAM_BOT_TOKEN/WA_API_URL', 'sistem'),
  ('email_jadwal_terakhir',  'Kirim email terjadwal terakhir','—', 'waktu',
   'Email laporan terjadwal — mode arsip default; SMTP nyata via kredensial', 'sistem'),
  ('wajib_2fa_peran',        'Peran wajib 2FA (JSON)',       '[]', 'json',
   'Daftar peran (JSON) yang wajib 2FA — kosong = semua opsional', 'seed'),
  ('wajib_2fa_tenggat',      'Tenggat wajib 2FA',             '',  'tanggal',
   'Sebelum tanggal ini = masa tenggang (banner pengingat); setelah = wajib mutlak', 'seed')
ON CONFLICT (param_key) DO NOTHING;

-- 3. Index posisi AIS ----------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_ais_pos_fleet_waktu
    ON telemetry.ais_position (fleet_code, position_at DESC);
