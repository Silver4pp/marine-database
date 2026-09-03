-- ============================================================
-- FEATURE SCHEMA: telemetry
-- file    : feature/20_telemetry.sql
-- objects : 17 statement(s)
-- generated from original/schema_v1_original.sql by tools/split_schema.py
-- ============================================================

-- ============================================================
-- SECTION 23: TELEMETRY SCHEMA TABLES (GPS/AIS)
-- ============================================================

CREATE TABLE telemetry.raw_message (
    message_id      BIGSERIAL       PRIMARY KEY,
    tenant_id       UUID            NOT NULL,
    partner_code    VARCHAR(30)     NOT NULL,
    fleet_code      VARCHAR(30),
    mmsi            VARCHAR(20),
    imo             VARCHAR(20),
    external_id     VARCHAR(100),
    source_system   VARCHAR(50)     NOT NULL,
    message_type    VARCHAR(30),
    raw_payload     JSONB           NOT NULL,
    received_at     TIMESTAMPTZ     NOT NULL,
    processed_at    TIMESTAMPTZ,
    is_processed    BOOLEAN         DEFAULT FALSE
);

CREATE TABLE telemetry.ais_position (
    -- [FIX-4] A PRIMARY KEY on a partitioned table must include every
    -- partitioning column ("unique constraint on partitioned table must
    -- include all partitioning columns"). PK moved to (position_id, reported_at).
    -- ORIGINAL (invalid): position_id BIGSERIAL PRIMARY KEY,
    position_id     BIGSERIAL       NOT NULL,
    tenant_id       UUID            NOT NULL,
    partner_code    VARCHAR(30)     NOT NULL,
    fleet_code      VARCHAR(30),
    mmsi            VARCHAR(20)     NOT NULL,
    imo             VARCHAR(20),
    message_type    VARCHAR(30),
    latitude        NUMERIC(10,7)   NOT NULL
                        CHECK (latitude >= -90 AND latitude <= 90),
    longitude       NUMERIC(11,7)   NOT NULL
                        CHECK (longitude >= -180 AND longitude <= 180),
    geom            GEOMETRY(Point, 4326) GENERATED ALWAYS AS (
                        ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)
                    ) STORED,
    speed_over_ground NUMERIC(8,2),
    course_over_ground NUMERIC(5,2),
    heading         NUMERIC(5,2),
    navigation_status VARCHAR(30),
    destination     VARCHAR(200),
    eta             TIMESTAMPTZ,
    data_quality    VARCHAR(20),
    reported_at     TIMESTAMPTZ     NOT NULL,
    received_at     TIMESTAMPTZ     NOT NULL,
    source_system   VARCHAR(50),
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    -- partition key first, so the leading column is the one every
    -- time-range query filters on
    PRIMARY KEY (reported_at, position_id)
) PARTITION BY RANGE (reported_at);

-- AIS Partitions
CREATE TABLE telemetry.ais_position_2025 PARTITION OF telemetry.ais_position
    FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');

CREATE TABLE telemetry.ais_position_2026 PARTITION OF telemetry.ais_position
    FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');

CREATE TABLE telemetry.ais_position_2027 PARTITION OF telemetry.ais_position
    FOR VALUES FROM ('2027-01-01') TO ('2028-01-01');

CREATE TABLE telemetry.ais_position_2028 PARTITION OF telemetry.ais_position
    FOR VALUES FROM ('2028-01-01') TO ('2029-01-01');

CREATE TABLE telemetry.ais_position_2029 PARTITION OF telemetry.ais_position
    FOR VALUES FROM ('2029-01-01') TO ('2030-01-01');

CREATE TABLE telemetry.ais_position_2030 PARTITION OF telemetry.ais_position
    FOR VALUES FROM ('2030-01-01') TO ('2031-01-01');

CREATE TABLE telemetry.ais_position_default PARTITION OF telemetry.ais_position DEFAULT;

CREATE TABLE telemetry.vessel_position_latest (
    -- a fleet_code is only unique inside a tenant, so the key is composite
    tenant_id       UUID            NOT NULL,
    fleet_code      VARCHAR(30)     NOT NULL,
    partner_code    VARCHAR(30)     NOT NULL,
    mmsi            VARCHAR(20),
    latitude        NUMERIC(10,7),
    longitude       NUMERIC(11,7),
    geom            GEOMETRY(Point, 4326),
    speed_over_ground NUMERIC(8,2),
    course_over_ground NUMERIC(5,2),
    heading         NUMERIC(5,2),
    navigation_status VARCHAR(30),
    destination     VARCHAR(200),
    eta             TIMESTAMPTZ,
    last_update     TIMESTAMPTZ     NOT NULL,
    data_quality    VARCHAR(20),
    source_system   VARCHAR(50),
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    PRIMARY KEY (tenant_id, fleet_code)
);

CREATE TABLE telemetry.tracking_health (
    id              BIGSERIAL       PRIMARY KEY,
    tenant_id       UUID            NOT NULL,
    fleet_code      VARCHAR(30)     NOT NULL,
    partner_code    VARCHAR(30)     NOT NULL,
    check_time      TIMESTAMPTZ     NOT NULL,
    is_online       BOOLEAN         NOT NULL,
    last_position_at TIMESTAMPTZ,
    last_message_at TIMESTAMPTZ,
    gap_minutes     NUMERIC(10,2),
    alert_type      VARCHAR(30),
    alert_level     VARCHAR(20),
    notes           TEXT,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE telemetry.geofence (
    geofence_id     BIGSERIAL       PRIMARY KEY,
    tenant_id       UUID            NOT NULL,
    geofence_code   VARCHAR(50)     NOT NULL UNIQUE,
    name            VARCHAR(200)    NOT NULL,
    geofence_type   VARCHAR(30)     NOT NULL,
    geom            GEOMETRY        NOT NULL,
    radius_meters   NUMERIC(12,2),
    site_code       VARCHAR(30)
                        REFERENCES site.info(site_code) ON DELETE SET NULL,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE telemetry.geofence_event (
    event_id        BIGSERIAL       PRIMARY KEY,
    tenant_id       UUID            NOT NULL,
    geofence_id     BIGINT          NOT NULL
                        REFERENCES telemetry.geofence(geofence_id) ON DELETE RESTRICT,
    fleet_code      VARCHAR(30)     NOT NULL,
    event_type      VARCHAR(20)     NOT NULL,
    event_time      TIMESTAMPTZ     NOT NULL,
    position_at_event GEOMETRY(Point, 4326),
    distance_from_center NUMERIC(12,2),
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    CONSTRAINT uq_geofence_event UNIQUE (geofence_id, fleet_code, event_time)
);

-- Telemetry: Update latest position
CREATE OR REPLACE FUNCTION telemetry.fn_update_latest_position()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO telemetry.vessel_position_latest (
        fleet_code, tenant_id, partner_code, mmsi, latitude, longitude, geom,
        speed_over_ground, course_over_ground, heading, navigation_status,
        destination, eta, last_update, data_quality, source_system
    ) VALUES (
        NEW.fleet_code, NEW.tenant_id, NEW.partner_code, NEW.mmsi,
        NEW.latitude, NEW.longitude, NEW.geom,
        NEW.speed_over_ground, NEW.course_over_ground, NEW.heading, NEW.navigation_status,
        NEW.destination, NEW.eta, NEW.reported_at, NEW.data_quality, NEW.source_system
    )
    -- the conflict target must match the new composite key
    ON CONFLICT (tenant_id, fleet_code) DO UPDATE SET
        tenant_id = EXCLUDED.tenant_id, partner_code = EXCLUDED.partner_code,
        mmsi = EXCLUDED.mmsi, latitude = EXCLUDED.latitude, longitude = EXCLUDED.longitude,
        geom = EXCLUDED.geom, speed_over_ground = EXCLUDED.speed_over_ground,
        course_over_ground = EXCLUDED.course_over_ground, heading = EXCLUDED.heading,
        navigation_status = EXCLUDED.navigation_status, destination = EXCLUDED.destination,
        eta = EXCLUDED.eta, last_update = EXCLUDED.last_update,
        data_quality = EXCLUDED.data_quality, source_system = EXCLUDED.source_system,
        updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Telemetry: Check geofence
CREATE OR REPLACE FUNCTION telemetry.fn_check_geofence()
RETURNS TRIGGER AS $$
DECLARE v_geofence RECORD; v_prev_pos RECORD; v_prev_in_geofence BOOLEAN; v_curr_in_geofence BOOLEAN;
BEGIN
    SELECT latitude, longitude, geom INTO v_prev_pos
    FROM telemetry.vessel_position_latest WHERE fleet_code = NEW.fleet_code;
    FOR v_geofence IN SELECT * FROM telemetry.geofence WHERE is_active = TRUE AND tenant_id = NEW.tenant_id LOOP
        IF v_prev_pos.geom IS NOT NULL THEN
            SELECT ST_Contains(v_geofence.geom, v_prev_pos.geom) INTO v_prev_in_geofence;
        ELSE v_prev_in_geofence := FALSE; END IF;
        SELECT ST_Contains(v_geofence.geom, NEW.geom) INTO v_curr_in_geofence;
        IF NOT v_prev_in_geofence AND v_curr_in_geofence THEN
            INSERT INTO telemetry.geofence_event (
                tenant_id, geofence_id, fleet_code, event_type, event_time, position_at_event, distance_from_center
            ) VALUES (NEW.tenant_id, v_geofence.geofence_id, NEW.fleet_code, 'ENTRY', NEW.reported_at, NEW.geom, ST_Distance(v_geofence.geom, NEW.geom));
        END IF;
        IF v_prev_in_geofence AND NOT v_curr_in_geofence THEN
            INSERT INTO telemetry.geofence_event (
                tenant_id, geofence_id, fleet_code, event_type, event_time, position_at_event, distance_from_center
            ) VALUES (NEW.tenant_id, v_geofence.geofence_id, NEW.fleet_code, 'EXIT', NEW.reported_at, NEW.geom, ST_Distance(v_geofence.geom, NEW.geom));
        END IF;
    END LOOP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Telemetry: Update latest position
CREATE OR REPLACE TRIGGER trg_update_latest_position
AFTER INSERT ON telemetry.ais_position
FOR EACH ROW EXECUTE FUNCTION telemetry.fn_update_latest_position();

-- Telemetry: Check geofence
CREATE OR REPLACE TRIGGER trg_check_geofence
AFTER INSERT ON telemetry.ais_position
FOR EACH ROW EXECUTE FUNCTION telemetry.fn_check_geofence();
