-- ============================================================
-- FEATURE SCHEMA: param
-- file    : feature/01_param.sql
-- objects : 8 statement(s)
-- generated from original/schema_v1_original.sql by tools/split_schema.py
-- ============================================================

-- ============================================================
-- SECTION 4: PARAM SCHEMA TABLES
-- ============================================================

CREATE TABLE param.country (
    country_id      BIGSERIAL       PRIMARY KEY,
    iso_alpha2      CHAR(2)         NOT NULL UNIQUE,
    iso_alpha3      CHAR(3)         NOT NULL UNIQUE,
    iso_name        VARCHAR(120)    NOT NULL,
    iso_numeric     SMALLINT        UNIQUE,
    name            VARCHAR(120)    NOT NULL,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE param.currency (
    currency_code   CHAR(3)         PRIMARY KEY,
    name            VARCHAR(100)    NOT NULL,
    symbol          VARCHAR(10),
    decimal_places  SMALLINT        NOT NULL DEFAULT 2,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE param.unit_of_measure (
    uom_code        VARCHAR(20)     PRIMARY KEY,
    name            VARCHAR(100)    NOT NULL,
    category        VARCHAR(50)     NOT NULL
                        CHECK (category IN (
                            'LENGTH','AREA','VOLUME','MASS',
                            'TEMPERATURE','TIME','PRESSURE','OTHER'
                        )),
    symbol          VARCHAR(20),
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE param.unit_conversion (
    uc_code         VARCHAR(20)     PRIMARY KEY,
    uom_from        VARCHAR(20)     NOT NULL
                        REFERENCES param.unit_of_measure(uom_code) ON DELETE RESTRICT,
    uom_to          VARCHAR(20)     NOT NULL
                        REFERENCES param.unit_of_measure(uom_code) ON DELETE RESTRICT,
    conv_value      NUMERIC(18,8)   NOT NULL CHECK (conv_value > 0),
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    CONSTRAINT uq_conversion_pair UNIQUE (uom_from, uom_to),
    CONSTRAINT chk_diff_uom CHECK (uom_from <> uom_to)
);

CREATE TABLE param.status_group (
    group_code      VARCHAR(50)     PRIMARY KEY,
    group_name      VARCHAR(100)    NOT NULL,
    description     TEXT,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE param.status (
    status_code     VARCHAR(30)     PRIMARY KEY,
    status_group    VARCHAR(50)     NOT NULL
                        REFERENCES param.status_group(group_code) ON DELETE RESTRICT,
    display_name    VARCHAR(100),
    description     TEXT,
    sort_order      SMALLINT        DEFAULT 0,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    CONSTRAINT uq_status_group_code UNIQUE (status_group, status_code)
);

CREATE TABLE param.threshold (
    threshold_code  VARCHAR(30)     PRIMARY KEY,
    parameter_name  VARCHAR(100)    NOT NULL,
    parameter_value NUMERIC(18,6)   NOT NULL,
    uom_code        VARCHAR(20)     NOT NULL
                        REFERENCES param.unit_of_measure(uom_code) ON DELETE RESTRICT,
    min_value       NUMERIC(18,6),
    max_value       NUMERIC(18,6),
    description     TEXT,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    CONSTRAINT uq_threshold_param UNIQUE (parameter_name, uom_code)
);

CREATE TABLE param.role (
    role_code       VARCHAR(50)     PRIMARY KEY,
    role_name       VARCHAR(100)    NOT NULL,
    description     TEXT,
    permissions     JSONB,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);
