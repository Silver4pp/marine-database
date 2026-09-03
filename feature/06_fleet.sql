-- ============================================================
-- FEATURE SCHEMA: fleet
-- file    : feature/06_fleet.sql
-- objects : 5 statement(s)
-- generated from original/schema_v1_original.sql by tools/split_schema.py
-- ============================================================

-- ============================================================
-- SECTION 9: FLEET SCHEMA TABLES
-- ============================================================

CREATE TABLE fleet.type (
    type_code       VARCHAR(20)     PRIMARY KEY,
    type_group      VARCHAR(50)     NOT NULL,
    description     TEXT,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE fleet.info (
    fleet_code      VARCHAR(30)     PRIMARY KEY,
    partner_code    VARCHAR(30)     NOT NULL
                        REFERENCES partner.info(partner_code) ON DELETE RESTRICT,
    type_code       VARCHAR(20)     NOT NULL
                        REFERENCES fleet.type(type_code) ON DELETE RESTRICT,
    name            VARCHAR(150)    NOT NULL,
    imo_number      VARCHAR(20),
    mmsi_number     VARCHAR(20),
    call_sign       VARCHAR(20),
    flag_country_id BIGINT
                        REFERENCES param.country(country_id) ON DELETE SET NULL,
    grt             NUMERIC(12,2),
    dwt             NUMERIC(12,2),
    loa             NUMERIC(10,2),
    beam            NUMERIC(10,2),
    draft           NUMERIC(10,2),
    year_built      SMALLINT,
    engine_type     VARCHAR(100),
    fuel_type       VARCHAR(50),
    tenant_id       UUID,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
    -- [FIX-2] UNIQUE ... WHERE is not valid inside a table body.
    -- Re-created as partial UNIQUE indexes in index/01_indexes.sql.
    -- ORIGINAL (invalid):
    --   CONSTRAINT uq_fleet_imo  UNIQUE (imo_number)  WHERE imo_number IS NOT NULL,
    --   CONSTRAINT uq_fleet_mmsi UNIQUE (mmsi_number) WHERE mmsi_number IS NOT NULL
);

CREATE TABLE fleet.assignment_leg (
    id              BIGSERIAL       PRIMARY KEY,
    fleet_code      VARCHAR(30)     NOT NULL
                        REFERENCES fleet.info(fleet_code) ON DELETE RESTRICT,
    site_code       VARCHAR(30)     NOT NULL
                        REFERENCES site.info(site_code) ON DELETE RESTRICT,
    assignment_type VARCHAR(50)     NOT NULL DEFAULT 'CHARTER',
    est_start_date  DATE,
    est_end_date    DATE,
    act_start_date  DATE,
    act_end_date    DATE,
    notes           TEXT,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    CONSTRAINT chk_assignment_dates
        CHECK (est_end_date >= est_start_date OR est_end_date IS NULL),
    CONSTRAINT chk_act_dates
        CHECK (act_end_date >= act_start_date OR act_end_date IS NULL)
);

ALTER TABLE fleet.assignment_leg
ADD CONSTRAINT chk_no_overlapping_assignment
EXCLUDE USING GIST (
    fleet_code WITH =,
    daterange(
        COALESCE(act_start_date, est_start_date),
        COALESCE(act_end_date, est_end_date, DATE '9999-12-31'),
        '[)'
    ) WITH &&
)
WHERE (COALESCE(act_start_date, est_start_date) IS NOT NULL);

CREATE TABLE fleet.maintenance (
    id              BIGSERIAL       PRIMARY KEY,
    fleet_code      VARCHAR(30)     NOT NULL
                        REFERENCES fleet.info(fleet_code) ON DELETE CASCADE,
    maintenance_type VARCHAR(50)    NOT NULL,
    description     TEXT,
    start_date      DATE            NOT NULL,
    end_date        DATE,
    cost            NUMERIC(18,2)   CHECK (cost >= 0),
    vendor_code     VARCHAR(30)
                        REFERENCES partner.info(partner_code) ON DELETE SET NULL,
    status          VARCHAR(30)
                        REFERENCES param.status(status_code) ON DELETE SET NULL,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    CONSTRAINT chk_mtc_end_date CHECK (end_date >= start_date OR end_date IS NULL)
);
