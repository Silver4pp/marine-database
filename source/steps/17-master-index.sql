-- ============================================================================
-- 17-master-index.sql — feat-v10 (gelombang perbaikan #3–#8 + #12):
--   · index pendukung Analisis Riwayat Enviro utk query lintas-stasiun
--     (parameter_code, hari) — PK (station, param, hari) tak efisien saat
--     memfilter satu parameter utk SEMUA stasiun (FR BRD-v6 NFR-6-03).
--   · Tanpa tabel baru: hub "Master & Parameter" (#12) memakai tabel eksisting
--     (mon_parameter, pnbp_tarif, pnbp_kode_map, sensor_threshold,
--      mon_schedule, survey.instrument, fleet.info).
-- Idempoten — aman dijalankan berulang.
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_reading_daily_param_hari
  ON enviro.reading_daily (parameter_code, hari);

ANALYZE enviro.reading_daily;
