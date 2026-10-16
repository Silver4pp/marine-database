-- ============================================================================
-- 08-enviro-telemetri-prod.sql — FEAT-V4 (W3): PIPELINE TELEMETRI ENVIRO · PROD
-- ============================================================================
-- Arsitektur 3-tier (BRD v2 §5, keputusan final 13 Sep 2026):
--   T1 RAW   : enviro_raw.reading — data sensor per menit, PARTISI BULANAN,
--              retensi 3 bulan (drop partisi oleh command `rollup_enviro`)
--   T2 ROLLUP: command `rollup_enviro` (cron per jam) — agregat + EWS + retensi
--   T3 AGREGAT: enviro.reading_daily (permanen) + VIEW bulanan/tahunan
-- Pelengkap: enviro_raw.station_token (token per stasiun utk endpoint
--   POST /api/enviro/ingest/) + enviro_raw.sensor_threshold (ambang taraf
--   internasional — ASEAN MWQC / Kepmen LH 51/2004, diubah ADMIN + audit P-3).
-- Stasiun sensor tambahan ST-04/ST-05 (total 5, sesuai kesepakatan volume).
-- Idempoten — aman dijalankan berulang.
-- Pemakaian PROD (Supabase): psql "$DATABASE_URL" -f 08-enviro-telemetri-prod.sql
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS enviro_raw;

-- ---------- 0 · perluas CHECK ews_event utk pipeline sensor ----------
-- level tetap WARNING/EXCEEDED (semantik lama); trigger_rule bertambah SENSOR_15MNT
-- (rata-rata 15 menit vs ambang internasional — dijalankan rollup_enviro berkala).
ALTER TABLE enviro.ews_event DROP CONSTRAINT IF EXISTS ews_event_trigger_rule_check;
ALTER TABLE enviro.ews_event ADD CONSTRAINT ews_event_trigger_rule_check
    CHECK (trigger_rule IN ('THRESHOLD', 'TREND', 'COMPOSITE', 'TIDE_WINDOW', 'SENSOR_15MNT'));

-- ---------- 1 · stasiun sensor tambahan (total 5) ----------
INSERT INTO enviro.station (station_code, station_name, station_type, location)
SELECT v.code, v.nama, 'SENSOR',
       ST_SetSRID(ST_MakePoint(v.lng, v.lat), 4326)      -- kolom geometry (PostGIS)
FROM (VALUES
    ('ST-04', 'Zona Pengerukan Blok B-07', 106.24, -5.90),
    ('ST-05', 'Perairan Site H (cadangan)', 106.42, -6.05)
) AS v(code, nama, lng, lat)
WHERE NOT EXISTS (SELECT 1 FROM enviro.station s WHERE s.station_code = v.code);

-- ---------- 2 · token per stasiun ----------
CREATE TABLE IF NOT EXISTS enviro_raw.station_token (
    station_code varchar(16) PRIMARY KEY
        REFERENCES enviro.station (station_code) ON DELETE CASCADE,
    token        varchar(64) NOT NULL UNIQUE,
    aktif        boolean NOT NULL DEFAULT true,
    updated_at   timestamptz NOT NULL DEFAULT now()
);
INSERT INTO enviro_raw.station_token (station_code, token)
SELECT s.station_code, 'tok-' || lower(s.station_code) || '-pasirlaut'
FROM enviro.station s
ON CONFLICT (station_code) DO NOTHING;

-- ---------- 3 · ambang sensor (taraf internasional, editable ADMIN + audit) ----------
CREATE TABLE IF NOT EXISTS enviro_raw.sensor_threshold (
    parameter_code varchar(24) PRIMARY KEY
        REFERENCES enviro.mon_parameter (parameter_code),
    ambang_min numeric(12,4),
    ambang_max numeric(12,4),
    satuan     varchar(16) NOT NULL DEFAULT '',
    referensi  varchar(160) NOT NULL DEFAULT '',
    updated_by varchar(80) NOT NULL DEFAULT 'seed',
    updated_at timestamptz NOT NULL DEFAULT now()
);
INSERT INTO enviro_raw.sensor_threshold (parameter_code, ambang_min, ambang_max, satuan, referensi)
SELECT v.p, v.mn, v.mx, v.u, v.ref
FROM (VALUES
    ('DO',           5.0,  NULL,  'mg/L',  'ASEAN MWQC — DO minimum 5 mg/L (di bawah ambang = pelanggaran)'),
    ('PH',           7.0,  8.5,   '-',     'ASEAN MWQC — rentang pH 7,0-8,5'),
    ('TSS',          NULL, 80.0,  'mg/L',  'ASEAN MWQC — maksimum 80 mg/L'),
    ('TURBIDITY',    NULL, 120.0, 'NTU',   'ASEAN MWQC — maksimum 120 NTU'),
    ('SALINITY',     NULL, 34.0,  'permil','ASEAN MWQC — maksimum 34 permil'),
    ('AMONIA_TOTAL', NULL, 0.3,   'mg/L',  'Kepmen LH 51/2004 — maksimum 0,3 mg/L'),
    ('ORTOFOSFAT',   NULL, 0.015, 'mg/L',  'Kepmen LH 51/2004 — maksimum 0,015 mg/L'),
    ('MINYAK_LEMAK', NULL, 5.0,   'mg/L',  'Kepmen LH 51/2004 — maksimum 5 mg/L')
) AS v(p, mn, mx, u, ref)
WHERE NOT EXISTS (SELECT 1 FROM enviro_raw.sensor_threshold t
                  WHERE t.parameter_code = v.p);

-- ---------- 4 · T1 RAW — partisi bulanan ----------
CREATE TABLE IF NOT EXISTS enviro_raw.reading (
    station_code   varchar(16) NOT NULL,
    parameter_code varchar(24) NOT NULL,
    ts             timestamptz NOT NULL,
    value          numeric(12,4) NOT NULL,
    PRIMARY KEY (station_code, parameter_code, ts)
) PARTITION BY RANGE (ts);
CREATE INDEX IF NOT EXISTS idx_raw_ts ON enviro_raw.reading (ts);

DO $$
DECLARE
    d0  date := date_trunc('month', now())::date;
    i   int;
    nm  text;
BEGIN
    FOR i IN 0..2 LOOP
        nm := 'reading_p' || to_char(d0 + (i || ' month')::interval, 'YYYY_MM');
        IF NOT EXISTS (SELECT 1 FROM pg_class c
                       JOIN pg_namespace n ON n.oid = c.relnamespace
                       WHERE n.nspname = 'enviro_raw' AND c.relname = nm) THEN
            EXECUTE format(
                'CREATE TABLE enviro_raw.%I PARTITION OF enviro_raw.reading '
                'FOR VALUES FROM (%L) TO (%L)',
                nm, d0 + (i || ' month')::interval, d0 + ((i + 1) || ' month')::interval);
        END IF;
    END LOOP;
    IF NOT EXISTS (SELECT 1 FROM pg_class c
                   JOIN pg_namespace n ON n.oid = c.relnamespace
                   WHERE n.nspname = 'enviro_raw' AND c.relname = 'reading_default') THEN
        EXECUTE 'CREATE TABLE enviro_raw.reading_default PARTITION OF enviro_raw.reading DEFAULT';
    END IF;
END $$;

-- ---------- 5 · T3 AGREGAT harian (permanen) + VIEW bulanan/tahunan ----------
CREATE TABLE IF NOT EXISTS enviro.reading_daily (
    station_code   varchar(16) NOT NULL,
    parameter_code varchar(24) NOT NULL,
    hari           date NOT NULL,
    n              integer NOT NULL,
    avg            numeric(12,4) NOT NULL,
    min            numeric(12,4) NOT NULL,
    max            numeric(12,4) NOT NULL,
    p95            numeric(12,4) NOT NULL,
    PRIMARY KEY (station_code, parameter_code, hari)
);

CREATE OR REPLACE VIEW enviro.reading_monthly_v AS
SELECT station_code, parameter_code,
       date_trunc('month', hari)::date AS periode,
       sum(n)::int AS n, round(avg(avg), 4) AS avg,
       min(min) AS min, max(max) AS max
FROM enviro.reading_daily
GROUP BY station_code, parameter_code, date_trunc('month', hari)::date;

CREATE OR REPLACE VIEW enviro.reading_yearly_v AS
SELECT station_code, parameter_code,
       date_trunc('year', hari)::date AS periode,
       sum(n)::int AS n, round(avg(avg), 4) AS avg,
       min(min) AS min, max(max) AS max
FROM enviro.reading_daily
GROUP BY station_code, parameter_code, date_trunc('year', hari)::date;

-- Cron produksi (Back4App / crontab):
--   5 * * * *  cd /app && python manage.py rollup_enviro     (tiap jam, menit 05)
-- Ingest gateway sensor: POST /api/enviro/ingest/  (JSON, token per stasiun)
