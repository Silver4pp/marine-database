-- ============================================================================
-- 16-enviro-kuartal.sql — feat-v9 (BRD-v6 FR-6-08): view agregat KUARTAL
-- enviro.reading_daily → enviro.reading_quarterly_v — konsisten definisi
-- dengan reading_monthly_v / reading_yearly_v (avg(avg) tak-tertimbang ·
-- min(min) · max(max) · sum(n)). Sumber utama Analisis Riwayat Enviro
-- (mode "Riwayat & Tren" di /modul/enviro/).
-- Idempoten: CREATE OR REPLACE VIEW — aman dijalankan berulang.
-- ============================================================================

CREATE OR REPLACE VIEW enviro.reading_quarterly_v AS
SELECT station_code, parameter_code,
       date_trunc('quarter', hari)::date AS periode,
       sum(n)::int AS n, round(avg(avg), 4) AS avg,
       min(min) AS min, max(max) AS max
FROM enviro.reading_daily
GROUP BY station_code, parameter_code, date_trunc('quarter', hari)::date;

COMMENT ON VIEW enviro.reading_quarterly_v IS
  'feat-v9 BRD-v6 FR-6-08: agregat kuartalan dari reading_daily (Analisis Riwayat Enviro)';
