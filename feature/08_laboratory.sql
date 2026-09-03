-- ============================================================
-- FEATURE SCHEMA: laboratory
-- file    : feature/08_laboratory.sql
-- objects : 6 statement(s)
-- generated from original/schema_v1_original.sql by tools/split_schema.py
-- ============================================================

-- ============================================================
-- SECTION 11: LABORATORY SCHEMA TABLES
-- ============================================================

CREATE TABLE laboratory.info (
    lab_code        VARCHAR(30)     PRIMARY KEY,
    name            VARCHAR(150)    NOT NULL,
    site_code       VARCHAR(30)
                        REFERENCES site.info(site_code) ON DELETE SET NULL,
    address         TEXT,
    accreditation_no VARCHAR(50),
    accreditation_exp DATE,
    tenant_id       UUID,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE laboratory.equipment (
    equipment_id    VARCHAR(30)     PRIMARY KEY,
    lab_code        VARCHAR(30)     NOT NULL
                        REFERENCES laboratory.info(lab_code) ON DELETE RESTRICT,
    name            VARCHAR(150)    NOT NULL,
    model           VARCHAR(100),
    serial_number   VARCHAR(100),
    manufacturer    VARCHAR(100),
    calibration_date DATE,
    next_calibration DATE,
    status          VARCHAR(30)
                        REFERENCES param.status(status_code) ON DELETE SET NULL,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE laboratory.test_category (
    category_code   VARCHAR(30)     PRIMARY KEY,
    category_name   VARCHAR(100)    NOT NULL,
    description     TEXT,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE laboratory.method (
    method_code     VARCHAR(30)     PRIMARY KEY,
    category_code   VARCHAR(30)     NOT NULL
                        REFERENCES laboratory.test_category(category_code) ON DELETE RESTRICT,
    method_name     VARCHAR(200)    NOT NULL,
    description     TEXT,
    standard_ref    VARCHAR(100),
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE laboratory.result (
    id              BIGSERIAL       PRIMARY KEY,
    doc_no          VARCHAR(50)     NOT NULL UNIQUE,
    lab_code        VARCHAR(30)
                        REFERENCES laboratory.info(lab_code) ON DELETE SET NULL,
    sample_id       BIGINT
                        REFERENCES form.sample(sample_id) ON DELETE SET NULL,
    form_no         VARCHAR(30)
                        REFERENCES form.water_sampling(form_no) ON DELETE SET NULL,
    result_date     DATE            NOT NULL,
    tested_by       VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE SET NULL,
    reviewed_by     VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE SET NULL,
    status          VARCHAR(30)
                        REFERENCES param.status(status_code) ON DELETE SET NULL,
    notes           TEXT,
    tenant_id       UUID,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE laboratory.result_detail (
    id              BIGSERIAL       PRIMARY KEY,
    result_id       BIGINT          NOT NULL
                        REFERENCES laboratory.result(id) ON DELETE CASCADE,
    parameter_name  VARCHAR(100)    NOT NULL,
    method_code     VARCHAR(30)
                        REFERENCES laboratory.method(method_code) ON DELETE SET NULL,
    result_value    NUMERIC(18,6),
    uom_code        VARCHAR(20)
                        REFERENCES param.unit_of_measure(uom_code) ON DELETE SET NULL,
    detection_limit NUMERIC(18,6),
    is_exceed       BOOLEAN         DEFAULT FALSE,
    notes           TEXT,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    CONSTRAINT uq_result_parameter UNIQUE (result_id, parameter_name)
);
