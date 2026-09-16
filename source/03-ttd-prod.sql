-- ============================================================
-- 03-ttd-prod.sql — MIGRASI DDL untuk DB PRODUKSI (Supabase)
-- Dijalankan SEKALI sebelum/sama-saat dengan deploy v2026.09.11-2
-- (Kapal PWA + Form Draft Survey + TTD 3 pihak).
--
-- PWA (operational.manual_report) dan form Draft Survey
-- (survey.draft_survey) TIDAK butuh DDL — tabel sudah ada.
-- Satu-satunya perubahan schema: 3 kolom gambar TTD di commercial.bap
-- (sama dengan yang dipasang suite uat/22-pwa-survey-ttd.sql).
--
-- Cara pakai (string koneksi dari env-var Back4App / Supabase dashboard):
--   PGPASSWORD='<password-supabase>' psql \
--     -h aws-0-ap-south-1.pooler.supabase.com -p 5432 \
--     -U postgres.bfdhknecsgjiwxavohke -d postgres \
--     -f serah-terima/database/03-ttd-prod.sql
--
-- Idempoten (IF NOT EXISTS) — aman dijalankan berulang.
-- ============================================================

ALTER TABLE commercial.bap ADD COLUMN IF NOT EXISTS signed_vessel_img   text;
ALTER TABLE commercial.bap ADD COLUMN IF NOT EXISTS signed_customer_img text;
ALTER TABLE commercial.bap ADD COLUMN IF NOT EXISTS signed_surveyor_img text;

-- verifikasi (harus 3):
SELECT count(*) AS kolom_ttd
  FROM information_schema.columns
 WHERE table_schema = 'commercial'
   AND table_name = 'bap'
   AND column_name LIKE 'signed_%_img';
