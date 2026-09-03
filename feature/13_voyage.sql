-- ============================================================
-- FEATURE SCHEMA: voyage
-- file    : feature/13_voyage.sql
-- objects : 4 statement(s)
-- generated from original/schema_v1_original.sql by tools/split_schema.py
-- ============================================================

-- ============================================================
-- SECTION 16: VOYAGE SCHEMA TABLES
-- ============================================================

CREATE TABLE voyage.voyage (
    id              BIGSERIAL       PRIMARY KEY,
    fleet_code      VARCHAR(30)     NOT NULL
                        REFERENCES fleet.info(fleet_code) ON DELETE RESTRICT,
    do_num          VARCHAR(30)
                        REFERENCES commercial.delivery_order(do_num) ON DELETE SET NULL,
    voyage_no       VARCHAR(30),
    lat             NUMERIC(10,7)
                        CHECK (lat >= -90 AND lat <= 90),
    long            NUMERIC(11,7)
                        CHECK (long >= -180 AND long <= 180),
    geom            GEOMETRY(Point, 4326) GENERATED ALWAYS AS (
                        CASE
                            WHEN lat IS NOT NULL AND long IS NOT NULL
                            THEN ST_SetSRID(ST_MakePoint(long, lat), 4326)
                            ELSE NULL
                        END
                    ) STORED,
    speed           NUMERIC(8,2),
    heading         NUMERIC(5,2),
    record_time     TIMESTAMPTZ     NOT NULL,
    status          VARCHAR(30)
                        REFERENCES param.status(status_code) ON DELETE SET NULL,
    source          VARCHAR(30)     DEFAULT 'AIS',
    tenant_id       UUID,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE voyage.voyage_hist (
    id              BIGSERIAL       PRIMARY KEY,
    fleet_code      VARCHAR(30)     NOT NULL
                        REFERENCES fleet.info(fleet_code) ON DELETE RESTRICT,
    voyage_no       VARCHAR(30),
    lat             NUMERIC(10,7),
    long            NUMERIC(11,7),
    geom            GEOMETRY(Point, 4326) GENERATED ALWAYS AS (
                        CASE
                            WHEN lat IS NOT NULL AND long IS NOT NULL
                            THEN ST_SetSRID(ST_MakePoint(long, lat), 4326)
                            ELSE NULL
                        END
                    ) STORED,
    speed           NUMERIC(8,2),
    heading         NUMERIC(5,2),
    record_time     TIMESTAMPTZ     NOT NULL,
    tenant_id       UUID,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    CONSTRAINT uq_voyage_hist_fleet_time UNIQUE (fleet_code, record_time)
);

-- Voyage: Archive to history
CREATE OR REPLACE FUNCTION voyage.fn_archive_to_history()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO voyage.voyage_hist (fleet_code, voyage_no, lat, long, speed, heading, record_time)
    VALUES (OLD.fleet_code, OLD.voyage_no, OLD.lat, OLD.long, OLD.speed, OLD.heading, OLD.record_time);
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- Voyage: Archive to history
CREATE OR REPLACE TRIGGER trg_archive_voyage
BEFORE UPDATE ON voyage.voyage
FOR EACH ROW EXECUTE FUNCTION voyage.fn_archive_to_history();
