-- ============================================================
-- FEATURE SCHEMA: survey
-- file    : feature/09_survey.sql
-- objects : 3 statement(s)
-- generated from original/schema_v1_original.sql by tools/split_schema.py
-- ============================================================

-- ============================================================
-- SECTION 12: SURVEY SCHEMA TABLES
-- ============================================================

CREATE TABLE survey.type (
    type_code       VARCHAR(30)     PRIMARY KEY,
    type_name       VARCHAR(100)    NOT NULL,
    description     TEXT,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE survey.water_sampling (
    form_no         VARCHAR(30)     PRIMARY KEY,
    type_code       VARCHAR(30)     NOT NULL
                        REFERENCES survey.type(type_code) ON DELETE RESTRICT,
    survey_name     VARCHAR(200),
    sampling_date   DATE            NOT NULL,
    total_sample    INT             NOT NULL DEFAULT 0,
    recorder_by     VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE SET NULL,
    received_by     VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE SET NULL,
    site_code       VARCHAR(30)
                        REFERENCES site.info(site_code) ON DELETE SET NULL,
    location_desc   TEXT,
    status          VARCHAR(30)
                        REFERENCES param.status(status_code) ON DELETE SET NULL,
    tenant_id       UUID,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE survey.measurement (
    id              BIGSERIAL       PRIMARY KEY,
    form_no         VARCHAR(30)     NOT NULL
                        REFERENCES survey.water_sampling(form_no) ON DELETE CASCADE,
    measurement_no  INT             NOT NULL,
    station_name    VARCHAR(100),
    lat             NUMERIC(10,7),
    long            NUMERIC(11,7),
    depth           NUMERIC(10,2),
    parameter_name  VARCHAR(100)    NOT NULL,
    parameter_value NUMERIC(18,6),
    uom_code        VARCHAR(20)
                        REFERENCES param.unit_of_measure(uom_code) ON DELETE SET NULL,
    method          VARCHAR(100),
    is_exceed       BOOLEAN         DEFAULT FALSE,
    notes           TEXT,
    tenant_id       UUID,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    CONSTRAINT uq_survey_measurement UNIQUE (form_no, measurement_no, parameter_name)
);
