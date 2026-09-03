-- ============================================================
-- FEATURE SCHEMA: enviro
-- file    : feature/10_enviro.sql
-- objects : 7 statement(s)
-- generated from original/schema_v1_original.sql by tools/split_schema.py
-- ============================================================

-- ============================================================
-- SECTION 13: ENVIRO SCHEMA TABLES
-- ============================================================

CREATE TABLE enviro.station (
    station_code    VARCHAR(30)     PRIMARY KEY,
    site_code       VARCHAR(30)
                        REFERENCES site.info(site_code) ON DELETE SET NULL,
    name            VARCHAR(150)    NOT NULL,
    station_type    VARCHAR(50)     NOT NULL,
    lat             NUMERIC(10,7),
    long            NUMERIC(11,7),
    geom            GEOMETRY(Point, 4326) GENERATED ALWAYS AS (
                        CASE
                            WHEN lat IS NOT NULL AND long IS NOT NULL
                            THEN ST_SetSRID(ST_MakePoint(long, lat), 4326)
                            ELSE NULL
                        END
                    ) STORED,
    elevation       NUMERIC(10,2),
    status          VARCHAR(30)
                        REFERENCES param.status(status_code) ON DELETE SET NULL,
    installation_date DATE,
    description     TEXT,
    tenant_id       UUID,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE enviro.water_quality (
    id              BIGSERIAL       PRIMARY KEY,
    station_code    VARCHAR(30)     NOT NULL
                        REFERENCES enviro.station(station_code) ON DELETE CASCADE,
    record_time     TIMESTAMPTZ     NOT NULL,
    depth           NUMERIC(10,2),
    depth_uom       VARCHAR(20)     DEFAULT 'M',
    brightness      NUMERIC(10,2),
    temperature     NUMERIC(8,2),
    temperature_uom VARCHAR(20)     DEFAULT 'CELSIUS',
    turbidity       NUMERIC(10,2),
    turbidity_uom   VARCHAR(20)     DEFAULT 'NTU',
    dissolved_oxygen NUMERIC(8,2),
    do_uom          VARCHAR(20)     DEFAULT 'MG/L',
    ph_level        NUMERIC(5,2),
    salt            NUMERIC(8,2),
    conductivity    NUMERIC(12,4),
    chlorophyll     NUMERIC(10,4),
    condition       VARCHAR(50),
    recorded_by     VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE SET NULL,
    tenant_id       UUID,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    CONSTRAINT uq_wq_station_time UNIQUE (station_code, record_time, depth)
);

CREATE TABLE enviro.reading_type (
    type_code       VARCHAR(30)     PRIMARY KEY,
    type_name       VARCHAR(100)    NOT NULL,
    description     TEXT,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE enviro.reading (
    id              BIGSERIAL       PRIMARY KEY,
    station_code    VARCHAR(30)     NOT NULL
                        REFERENCES enviro.station(station_code) ON DELETE CASCADE,
    reading_type    VARCHAR(30)     NOT NULL
                        REFERENCES enviro.reading_type(type_code) ON DELETE RESTRICT,
    record_time     TIMESTAMPTZ     NOT NULL,
    salinity        NUMERIC(8,2),
    turbidity       NUMERIC(10,2),
    current_speed   NUMERIC(8,2),
    current_direction NUMERIC(5,2),
    dissolved_oxygen NUMERIC(8,2),
    water_density   NUMERIC(8,4),
    tide_level      NUMERIC(8,2),
    wave_height     NUMERIC(8,2),
    wind_speed      NUMERIC(8,2),
    wind_direction  NUMERIC(5,2),
    air_temperature NUMERIC(8,2),
    pressure        NUMERIC(10,2),
    visibility      NUMERIC(10,2),
    notes           TEXT,
    recorded_by     VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE SET NULL,
    tenant_id       UUID,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    CONSTRAINT uq_reading_station_type_time UNIQUE (station_code, reading_type, record_time)
);

-- Legacy tables for backward compatibility (will be deprecated)
CREATE TABLE enviro.tide_reading (
    id              BIGSERIAL       PRIMARY KEY,
    station_code    VARCHAR(30)     NOT NULL
                        REFERENCES enviro.station(station_code) ON DELETE CASCADE,
    record_time     TIMESTAMPTZ     NOT NULL,
    salinity        NUMERIC(8,2),
    turbidity       NUMERIC(10,2),
    current_speed   NUMERIC(8,2),
    dissolved_oxygen NUMERIC(8,2),
    water_density   NUMERIC(8,4),
    tide_level      NUMERIC(8,2),
    tenant_id       UUID,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    CONSTRAINT uq_tide_station_time UNIQUE (station_code, record_time)
);

CREATE TABLE enviro.buoy_reading (
    id              BIGSERIAL       PRIMARY KEY,
    station_code    VARCHAR(30)     NOT NULL
                        REFERENCES enviro.station(station_code) ON DELETE CASCADE,
    record_time     TIMESTAMPTZ     NOT NULL,
    salinity        NUMERIC(8,2),
    turbidity       NUMERIC(10,2),
    current_speed   NUMERIC(8,2),
    dissolved_oxygen NUMERIC(8,2),
    water_density   NUMERIC(8,4),
    tide_level      NUMERIC(8,2),
    tenant_id       UUID,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    CONSTRAINT uq_buoy_station_time UNIQUE (station_code, record_time)
);

CREATE TABLE enviro.maintenance (
    id              BIGSERIAL       PRIMARY KEY,
    station_code    VARCHAR(30)     NOT NULL
                        REFERENCES enviro.station(station_code) ON DELETE CASCADE,
    maintenance_type VARCHAR(50)   NOT NULL,
    description     TEXT,
    start_date      DATE            NOT NULL,
    end_date        DATE,
    cost            NUMERIC(18,2),
    vendor_code     VARCHAR(30)
                        REFERENCES partner.info(partner_code) ON DELETE SET NULL,
    status          VARCHAR(30)
                        REFERENCES param.status(status_code) ON DELETE SET NULL,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    CONSTRAINT chk_env_maint_end_date CHECK (end_date >= start_date OR end_date IS NULL)
);
