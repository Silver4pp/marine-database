-- ============================================================
-- FEATURE SCHEMA: enviro + survey - the canonical environmental data path
-- file    : feature/22_enviro.sql
-- note    : The tables themselves already exist in feature/09_survey.sql and
--           feature/10_enviro.sql (generated from the original). This file only
--           ADDS what the original lacked: measurement provenance.
--
--           ONE canonical path, four destinations:
--             buoy / continuous sensor -> enviro.reading
--             field survey             -> survey.water_sampling / survey.measurement
--             official sampling + CoC  -> form.*  (chain of custody)
--             laboratory               -> laboratory.result / result_detail
--
--           enviro.tide_reading and enviro.buoy_reading stay as legacy
--           compatibility tables: existing writers keep working, but no new
--           dashboard reads them. reporting.tide_read_daily and
--           reporting.buoy_read_daily still aggregate the legacy tables
--           (see NOTES.md N-10); migrate them to enviro.reading deliberately.
--
--           Every reading on the canonical path now carries:
--             record_time            when it was measured
--             received_at            when it arrived
--             ingest_latency_seconds arrival lag, derived
--             source_system          which feed produced it
--             data_quality           GOOD / SUSPECT / INTERPOLATED / DELAYED / MISSING / REJECTED
--             delay_status           ON_TIME / WARN / DELAYED, derived
--           so a dashboard can always show source, arrival time, quality and
--           delay status. See enviro.v_reading_provenance and
--           enviro.v_station_latency in view/02_views.sql.
-- depends : feature/09_survey.sql, feature/10_enviro.sql
-- ============================================================

-- ------------------------------------------------------------
-- enviro.station - how often this station promises to report
-- ------------------------------------------------------------
ALTER TABLE enviro.station
    ADD COLUMN expected_interval_minutes INT NOT NULL DEFAULT 15
        CHECK (expected_interval_minutes > 0),
    ADD COLUMN reporting_system VARCHAR(50),
    ADD COLUMN last_calibration_at DATE,
    ADD COLUMN next_calibration_due DATE;

COMMENT ON COLUMN enviro.station.expected_interval_minutes IS
    'Promised reporting cadence. enviro.v_station_latency grades a station CRITICAL past twice this.';
COMMENT ON TABLE enviro.tide_reading IS
    'LEGACY COMPATIBILITY. New continuous data belongs in enviro.reading; no new dashboard may read this.';
COMMENT ON TABLE enviro.buoy_reading IS
    'LEGACY COMPATIBILITY. New continuous data belongs in enviro.reading; no new dashboard may read this.';
COMMENT ON TABLE enviro.water_quality IS
    'Depth-profiled water quality. NOT a duplicate of enviro.reading: it is the only table that carries a depth dimension. Surface readings belong in enviro.reading.';

-- ------------------------------------------------------------
-- enviro.reading - provenance on the canonical continuous-sensor store
-- ------------------------------------------------------------
ALTER TABLE enviro.reading
    ADD COLUMN received_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    ADD COLUMN source_system VARCHAR(50) NOT NULL DEFAULT 'MANUAL',
    ADD COLUMN data_quality VARCHAR(20) NOT NULL DEFAULT 'GOOD'
        CHECK (data_quality IN ('GOOD','SUSPECT','INTERPOLATED','DELAYED','MISSING','REJECTED')),
    ADD COLUMN ingest_latency_seconds INT
        GENERATED ALWAYS AS (
            GREATEST(0, ROUND(EXTRACT(EPOCH FROM (received_at - record_time)))::INT)
        ) STORED,
    ADD COLUMN delay_status VARCHAR(20)
        GENERATED ALWAYS AS (
            CASE
                WHEN received_at - record_time > INTERVAL '2 hours'   THEN 'DELAYED'
                WHEN received_at - record_time > INTERVAL '30 minutes' THEN 'WARN'
                ELSE 'ON_TIME'
            END
        ) STORED;

COMMENT ON COLUMN enviro.reading.received_at IS 'When the reading arrived, as opposed to when it was measured.';
COMMENT ON COLUMN enviro.reading.data_quality IS 'Quality flag set by the ingest job; dashboards must surface it.';

-- ------------------------------------------------------------
-- survey.measurement - the same provenance on the field-survey path
-- ------------------------------------------------------------
ALTER TABLE survey.measurement
    ADD COLUMN received_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    ADD COLUMN measured_at TIMESTAMPTZ,
    ADD COLUMN source_system VARCHAR(50) NOT NULL DEFAULT 'FIELD_SURVEY',
    ADD COLUMN data_quality VARCHAR(20) NOT NULL DEFAULT 'GOOD'
        CHECK (data_quality IN ('GOOD','SUSPECT','INTERPOLATED','DELAYED','MISSING','REJECTED'));

-- ------------------------------------------------------------
-- Indexes: provenance queries are always "recent + by station" or "not GOOD"
-- ------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_enviro_reading_station_time
    ON enviro.reading (station_code, record_time DESC);
CREATE INDEX IF NOT EXISTS idx_enviro_reading_received
    ON enviro.reading (received_at DESC);
CREATE INDEX IF NOT EXISTS idx_enviro_reading_quality
    ON enviro.reading (data_quality) WHERE data_quality <> 'GOOD';
CREATE INDEX IF NOT EXISTS idx_enviro_reading_delay
    ON enviro.reading (delay_status) WHERE delay_status <> 'ON_TIME';
CREATE INDEX IF NOT EXISTS idx_survey_measurement_quality
    ON survey.measurement (data_quality) WHERE data_quality <> 'GOOD';

-- ------------------------------------------------------------
-- A single entry point for ingest jobs, so the provenance columns can never be
-- written inconsistently by hand.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION enviro.fn_ingest_reading(
    p_station_code  VARCHAR,
    p_reading_type  VARCHAR,
    p_record_time   TIMESTAMPTZ,
    p_source_system VARCHAR,
    p_data_quality  VARCHAR DEFAULT 'GOOD',
    p_payload       JSONB   DEFAULT NULL
) RETURNS BIGINT AS $$
DECLARE
    v_id BIGINT;
BEGIN
    INSERT INTO enviro.reading (
        station_code, reading_type, record_time, received_at,
        source_system, data_quality,
        salinity, turbidity, current_speed, current_direction, dissolved_oxygen,
        water_density, tide_level, wave_height, wind_speed, wind_direction,
        air_temperature, pressure, visibility, notes
    ) VALUES (
        p_station_code, p_reading_type, p_record_time, now(),
        p_source_system, p_data_quality,
        NULLIF(p_payload ->> 'salinity','')::NUMERIC,
        NULLIF(p_payload ->> 'turbidity','')::NUMERIC,
        NULLIF(p_payload ->> 'current_speed','')::NUMERIC,
        NULLIF(p_payload ->> 'current_direction','')::NUMERIC,
        NULLIF(p_payload ->> 'dissolved_oxygen','')::NUMERIC,
        NULLIF(p_payload ->> 'water_density','')::NUMERIC,
        NULLIF(p_payload ->> 'tide_level','')::NUMERIC,
        NULLIF(p_payload ->> 'wave_height','')::NUMERIC,
        NULLIF(p_payload ->> 'wind_speed','')::NUMERIC,
        NULLIF(p_payload ->> 'wind_direction','')::NUMERIC,
        NULLIF(p_payload ->> 'air_temperature','')::NUMERIC,
        NULLIF(p_payload ->> 'pressure','')::NUMERIC,
        NULLIF(p_payload ->> 'visibility','')::NUMERIC,
        p_payload ->> 'notes'
    )
    ON CONFLICT (station_code, reading_type, record_time) DO UPDATE
        SET received_at   = now(),
            source_system = EXCLUDED.source_system,
            data_quality  = EXCLUDED.data_quality
    RETURNING id INTO v_id;

    RETURN v_id;
END;
$$ LANGUAGE plpgsql;
