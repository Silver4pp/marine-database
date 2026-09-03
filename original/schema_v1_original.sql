-- ============================================================
-- DATABASE SCHEMA - COMPLETE & PRODUCTION READY
-- Single File - Organized Structure
-- Last Updated: 2026-09-03
-- ============================================================

-- ============================================================
-- SECTION 1: EXTENSIONS
-- ============================================================
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS btree_gist;
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- ============================================================
-- SECTION 2: GLOBAL FUNCTIONS
-- ============================================================

-- Auto-update updated_at trigger function
CREATE OR REPLACE FUNCTION public.fn_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- SECTION 3: SCHEMA CREATION
-- ============================================================
CREATE SCHEMA IF NOT EXISTS param;
CREATE SCHEMA IF NOT EXISTS site;
CREATE SCHEMA IF NOT EXISTS "user";
CREATE SCHEMA IF NOT EXISTS partner;
CREATE SCHEMA IF NOT EXISTS buyer;
CREATE SCHEMA IF NOT EXISTS fleet;
CREATE SCHEMA IF NOT EXISTS form;
CREATE SCHEMA IF NOT EXISTS laboratory;
CREATE SCHEMA IF NOT EXISTS survey;
CREATE SCHEMA IF NOT EXISTS enviro;
CREATE SCHEMA IF NOT EXISTS commercial;
CREATE SCHEMA IF NOT EXISTS operational;
CREATE SCHEMA IF NOT EXISTS voyage;
CREATE SCHEMA IF NOT EXISTS financial;
CREATE SCHEMA IF NOT EXISTS hse;
CREATE SCHEMA IF NOT EXISTS reporting;
CREATE SCHEMA IF NOT EXISTS security;
CREATE SCHEMA IF NOT EXISTS audit;
CREATE SCHEMA IF NOT EXISTS workflow;
CREATE SCHEMA IF NOT EXISTS document;
CREATE SCHEMA IF NOT EXISTS telemetry;

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

-- ============================================================
-- SECTION 5: SITE SCHEMA TABLES
-- ============================================================

CREATE TABLE site.type (
    type_code       VARCHAR(20)     PRIMARY KEY,
    type_group      VARCHAR(50)     NOT NULL,
    description     TEXT,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE site.info (
    site_code       VARCHAR(30)     PRIMARY KEY,
    type_code       VARCHAR(20)     NOT NULL
                        REFERENCES site.type(type_code) ON DELETE RESTRICT,
    name            VARCHAR(150)    NOT NULL,
    address         TEXT,
    city            VARCHAR(100),
    province        VARCHAR(100),
    postal_code     VARCHAR(20),
    country_id      BIGINT
                        REFERENCES param.country(country_id) ON DELETE SET NULL,
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
    tenant_id       UUID,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

-- ============================================================
-- SECTION 6: USER SCHEMA TABLES
-- ============================================================

CREATE TABLE "user".info (
    user_code       VARCHAR(30)     PRIMARY KEY,
    name            VARCHAR(150)    NOT NULL,
    role            VARCHAR(50)     NOT NULL
                        REFERENCES param.role(role_code) ON DELETE RESTRICT,
    employee_id     VARCHAR(30),
    department      VARCHAR(100),
    tenant_id       UUID,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE "user".detail (
    id              BIGSERIAL       PRIMARY KEY,
    user_code       VARCHAR(30)     NOT NULL
                        REFERENCES "user".info(user_code) ON DELETE CASCADE,
    contact_type    VARCHAR(30)     NOT NULL
                        CHECK (contact_type IN ('PHONE','EMAIL','FAX','ADDRESS','EMERGENCY')),
    contact_value   VARCHAR(200)    NOT NULL,
    is_primary      BOOLEAN         NOT NULL DEFAULT FALSE,
    is_verified     BOOLEAN         NOT NULL DEFAULT FALSE,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    CONSTRAINT uq_user_contact UNIQUE (user_code, contact_type, contact_value)
);

CREATE TABLE "user".session_log (
    id              BIGSERIAL       PRIMARY KEY,
    user_code       VARCHAR(30)     NOT NULL
                        REFERENCES "user".info(user_code) ON DELETE CASCADE,
    session_id      VARCHAR(100),
    ip_address      INET,
    user_agent      TEXT,
    login_time      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    logout_time     TIMESTAMPTZ,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE
);

-- ============================================================
-- SECTION 7: PARTNER SCHEMA TABLES
-- ============================================================

CREATE TABLE partner.type (
    type_code       VARCHAR(20)     PRIMARY KEY,
    type_group      VARCHAR(50)     NOT NULL,
    description     TEXT,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE partner.info (
    partner_code    VARCHAR(30)     PRIMARY KEY,
    type_code       VARCHAR(20)     NOT NULL
                        REFERENCES partner.type(type_code) ON DELETE RESTRICT,
    name            VARCHAR(150)    NOT NULL,
    legal_name      VARCHAR(200),
    tax_id          VARCHAR(50),
    registration_no VARCHAR(50),
    website         VARCHAR(200),
    site_code       VARCHAR(30)
                        REFERENCES site.info(site_code) ON DELETE SET NULL,
    address         TEXT,
    city            VARCHAR(100),
    country_id      BIGINT
                        REFERENCES param.country(country_id) ON DELETE SET NULL,
    contact_person  VARCHAR(150),
    contact_phone   VARCHAR(50),
    contact_email   VARCHAR(100),
    tenant_id       UUID,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

-- ============================================================
-- SECTION 8: BUYER SCHEMA TABLES
-- ============================================================

CREATE TABLE buyer.info (
    buyer_code      VARCHAR(30)     PRIMARY KEY,
    name            VARCHAR(150)    NOT NULL,
    site_code       VARCHAR(30)
                        REFERENCES site.info(site_code) ON DELETE SET NULL,
    credit_limit    NUMERIC(18,2)   DEFAULT 0 CHECK (credit_limit >= 0),
    payment_terms   VARCHAR(50),
    tax_id          VARCHAR(50),
    contact_person  VARCHAR(150),
    contact_phone   VARCHAR(50),
    contact_email   VARCHAR(100),
    address         TEXT,
    tenant_id       UUID,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE buyer.site (
    id              BIGSERIAL       PRIMARY KEY,
    buyer_code      VARCHAR(30)     NOT NULL
                        REFERENCES buyer.info(buyer_code) ON DELETE CASCADE,
    name            VARCHAR(150),
    site_code       VARCHAR(30)     NOT NULL
                        REFERENCES site.info(site_code) ON DELETE RESTRICT,
    is_primary      BOOLEAN         NOT NULL DEFAULT FALSE,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    CONSTRAINT uq_buyer_site UNIQUE (buyer_code, site_code)
);

CREATE TABLE buyer.ledger_hist (
    id              BIGSERIAL       PRIMARY KEY,
    buyer_code      VARCHAR(30)     NOT NULL
                        REFERENCES buyer.info(buyer_code) ON DELETE RESTRICT,
    transaction_date DATE           NOT NULL,
    transaction_type VARCHAR(20)    NOT NULL
                        CHECK (transaction_type IN ('CREDIT','DEBIT')),
    amount          NUMERIC(18,2)   NOT NULL CHECK (amount >= 0),
    currency_code   CHAR(3)         NOT NULL
                        REFERENCES param.currency(currency_code) ON DELETE RESTRICT,
    ref_doc         VARCHAR(100),
    ref_type        VARCHAR(50),
    description     TEXT,
    reversal_of_id  BIGINT          REFERENCES buyer.ledger_hist(id) ON DELETE SET NULL,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    tenant_id       UUID,
    CONSTRAINT uq_ledger_ref_doc UNIQUE (buyer_code, ref_doc, ref_type)
                        WHERE ref_doc IS NOT NULL
);

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
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    CONSTRAINT uq_fleet_imo   UNIQUE (imo_number)   WHERE imo_number IS NOT NULL,
    CONSTRAINT uq_fleet_mmsi  UNIQUE (mmsi_number)  WHERE mmsi_number IS NOT NULL
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

-- ============================================================
-- SECTION 10: FORM SCHEMA TABLES
-- ============================================================

CREATE TABLE form.water_sampling (
    form_no         VARCHAR(30)     PRIMARY KEY,
    form_type       VARCHAR(50)     NOT NULL DEFAULT 'WATER_SAMPLING',
    sampling_date   DATE            NOT NULL,
    total_sample    INT             NOT NULL DEFAULT 0 CHECK (total_sample >= 0),
    recorder_by     VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE SET NULL,
    received_by     VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE SET NULL,
    status          VARCHAR(30)
                        REFERENCES param.status(status_code) ON DELETE SET NULL,
    site_code       VARCHAR(30)
                        REFERENCES site.info(site_code) ON DELETE SET NULL,
    weather         VARCHAR(50),
    temperature     NUMERIC(8,2),
    humidity        NUMERIC(5,2),
    notes           TEXT,
    approved_by     VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE SET NULL,
    approved_at     TIMESTAMPTZ,
    tenant_id       UUID,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE form.sample (
    sample_id       BIGSERIAL       PRIMARY KEY,
    form_no         VARCHAR(30)     NOT NULL
                        REFERENCES form.water_sampling(form_no) ON DELETE CASCADE,
    sample_no       INT             NOT NULL,
    type_sample     VARCHAR(50)     NOT NULL,
    source_location VARCHAR(200),
    depth           NUMERIC(10,2),
    volume          NUMERIC(10,2),
    container_type  VARCHAR(50),
    preservation    VARCHAR(100),
    description     TEXT,
    status          VARCHAR(30)
                        REFERENCES param.status(status_code) ON DELETE SET NULL,
    received_at     TIMESTAMPTZ,
    analyzed_at     TIMESTAMPTZ,
    tenant_id       UUID,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    CONSTRAINT uq_sample_per_form UNIQUE (form_no, sample_no)
);

CREATE TABLE form.measurement (
    id              BIGSERIAL       PRIMARY KEY,
    form_no         VARCHAR(30)     NOT NULL
                        REFERENCES form.water_sampling(form_no) ON DELETE CASCADE,
    sample_id       BIGINT          NOT NULL
                        REFERENCES form.sample(sample_id) ON DELETE CASCADE,
    parameter_name  VARCHAR(100)    NOT NULL,
    parameter_value NUMERIC(18,6),
    uom_code        VARCHAR(20)
                        REFERENCES param.unit_of_measure(uom_code) ON DELETE SET NULL,
    method          VARCHAR(100),
    equipment_id    VARCHAR(50),
    analyst         VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE SET NULL,
    status          VARCHAR(30)
                        REFERENCES param.status(status_code) ON DELETE SET NULL,
    is_exceed       BOOLEAN         DEFAULT FALSE,
    notes           TEXT,
    tenant_id       UUID,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    CONSTRAINT uq_form_measurement UNIQUE (form_no, sample_id, parameter_name)
);

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

-- ============================================================
-- SECTION 14: COMMERCIAL SCHEMA TABLES
-- ============================================================

CREATE TABLE commercial.purchase_order (
    po_num              VARCHAR(30)     PRIMARY KEY,
    buyer_code          VARCHAR(30)     NOT NULL
                            REFERENCES buyer.info(buyer_code) ON DELETE RESTRICT,
    contract_number     VARCHAR(50),
    po_date             DATE            NOT NULL,
    uom_code            VARCHAR(20)     NOT NULL
                            REFERENCES param.unit_of_measure(uom_code) ON DELETE RESTRICT,
    total_volume        NUMERIC(18,4)   NOT NULL CHECK (total_volume >= 0),
    unit_price          NUMERIC(18,4)   NOT NULL CHECK (unit_price >= 0),
    currency_code       CHAR(3)         NOT NULL
                            REFERENCES param.currency(currency_code) ON DELETE RESTRICT,
    total_amount        NUMERIC(18,2) GENERATED ALWAYS AS (
                            ROUND(total_volume * unit_price, 2)
                        ) STORED,
    incoterm            VARCHAR(20),
    target_start_date   DATE,
    target_end_date     DATE,
    status              VARCHAR(30)
                            REFERENCES param.status(status_code) ON DELETE SET NULL,
    actual_start_date   DATE,
    actual_end_date     DATE,
    description         TEXT,
    created_by          VARCHAR(30)
                            REFERENCES "user".info(user_code) ON DELETE SET NULL,
    approved_by         VARCHAR(30)
                            REFERENCES "user".info(user_code) ON DELETE SET NULL,
    approved_at         TIMESTAMPTZ,
    tenant_id           UUID,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT now(),
    CONSTRAINT chk_po_target_dates  CHECK (target_end_date >= target_start_date OR target_end_date IS NULL),
    CONSTRAINT chk_po_actual_dates CHECK (actual_end_date >= actual_start_date OR actual_end_date IS NULL)
);

CREATE TABLE commercial.delivery_order (
    do_num              VARCHAR(30)     PRIMARY KEY,
    po_num              VARCHAR(30)     NOT NULL
                            REFERENCES commercial.purchase_order(po_num) ON DELETE RESTRICT,
    do_date             DATE            NOT NULL,
    discharge_site      VARCHAR(30)
                            REFERENCES site.info(site_code) ON DELETE SET NULL,
    uom_code            VARCHAR(20)     NOT NULL
                            REFERENCES param.unit_of_measure(uom_code) ON DELETE RESTRICT,
    target_volume       NUMERIC(18,4)   CHECK (target_volume >= 0),
    actual_volume       NUMERIC(18,4),
    target_start_date   DATE,
    target_end_date     DATE,
    status              VARCHAR(30)
                            REFERENCES param.status(status_code) ON DELETE SET NULL,
    actual_start_date   DATE,
    actual_end_date     DATE,
    vessel_name         VARCHAR(150),
    captain_name        VARCHAR(150),
    voyage_number       VARCHAR(50),
    created_by          VARCHAR(30)
                            REFERENCES "user".info(user_code) ON DELETE SET NULL,
    approved_by         VARCHAR(30)
                            REFERENCES "user".info(user_code) ON DELETE SET NULL,
    tenant_id           UUID,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT now(),
    CONSTRAINT chk_do_target_dates  CHECK (target_end_date >= target_start_date OR target_end_date IS NULL),
    CONSTRAINT chk_do_actual_dates  CHECK (actual_end_date >= actual_start_date OR actual_end_date IS NULL)
);

-- ============================================================
-- SECTION 15: OPERATIONAL SCHEMA TABLES
-- ============================================================

CREATE TABLE operational.work_area (
    area_code       VARCHAR(30)     PRIMARY KEY,
    name            VARCHAR(150)    NOT NULL,
    area_type       VARCHAR(50)     NOT NULL DEFAULT 'DREDGING',
    geom            GEOMETRY(Polygon, 4326),
    lat             NUMERIC(10,7) GENERATED ALWAYS AS (
                        CASE WHEN geom IS NOT NULL THEN ST_Y(ST_Centroid(geom)) ELSE NULL END
                    ) STORED,
    long            NUMERIC(11,7) GENERATED ALWAYS AS (
                        CASE WHEN geom IS NOT NULL THEN ST_X(ST_Centroid(geom)) ELSE NULL END
                    ) STORED,
    site_code       VARCHAR(30)
                        REFERENCES site.info(site_code) ON DELETE SET NULL,
    description     TEXT,
    tenant_id       UUID,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE operational.shipment_instruction (
    si_num              VARCHAR(30)     PRIMARY KEY,
    do_num              VARCHAR(30)     NOT NULL
                            REFERENCES commercial.delivery_order(do_num) ON DELETE RESTRICT,
    fleet_main_code     VARCHAR(30)     NOT NULL
                            REFERENCES fleet.info(fleet_code) ON DELETE RESTRICT,
    fleet_assist_code   VARCHAR(30)
                            REFERENCES fleet.info(fleet_code) ON DELETE SET NULL,
    working_site        VARCHAR(30)
                            REFERENCES site.info(site_code) ON DELETE SET NULL,
    discharge_site      VARCHAR(30)
                            REFERENCES site.info(site_code) ON DELETE SET NULL,
    work_area_code      VARCHAR(30)
                            REFERENCES operational.work_area(area_code) ON DELETE SET NULL,
    status              VARCHAR(30)
                            REFERENCES param.status(status_code) ON DELETE SET NULL,
    planned_start       TIMESTAMPTZ,
    planned_end         TIMESTAMPTZ,
    actual_start        TIMESTAMPTZ,
    actual_end          TIMESTAMPTZ,
    notes               TEXT,
    created_by          VARCHAR(30)
                            REFERENCES "user".info(user_code) ON DELETE SET NULL,
    approved_by         VARCHAR(30)
                            REFERENCES "user".info(user_code) ON DELETE SET NULL,
    tenant_id           UUID,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT now(),
    CONSTRAINT chk_different_fleet CHECK (
        fleet_assist_code IS NULL OR fleet_assist_code <> fleet_main_code
    )
);

CREATE TABLE operational.work_activity (
    activity_num    BIGSERIAL       PRIMARY KEY,
    si_num          VARCHAR(30)     NOT NULL
                        REFERENCES operational.shipment_instruction(si_num) ON DELETE CASCADE,
    fleet_code      VARCHAR(30)     NOT NULL
                        REFERENCES fleet.info(fleet_code) ON DELETE RESTRICT,
    area_code       VARCHAR(30)
                        REFERENCES operational.work_area(area_code) ON DELETE SET NULL,
    activity_type   VARCHAR(50)     NOT NULL,
    activity_name   VARCHAR(200),
    planned_start   TIMESTAMPTZ,
    planned_end     TIMESTAMPTZ,
    status          VARCHAR(30)
                        REFERENCES param.status(status_code) ON DELETE SET NULL,
    actual_start    TIMESTAMPTZ,
    actual_end      TIMESTAMPTZ,
    notes           TEXT,
    tenant_id       UUID,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    CONSTRAINT chk_planned_dates CHECK (planned_end >= planned_start OR planned_end IS NULL),
    CONSTRAINT chk_actual_dates  CHECK (actual_end >= actual_start  OR actual_end IS NULL)
);

CREATE TABLE operational.dredging_records (
    id               BIGSERIAL      PRIMARY KEY,
    si_num           VARCHAR(30)    NOT NULL
                            REFERENCES operational.shipment_instruction(si_num) ON DELETE RESTRICT,
    activity_num     BIGINT         NOT NULL
                            REFERENCES operational.work_activity(activity_num) ON DELETE RESTRICT,
    record_date      DATE           NOT NULL,
    dredging_volume  NUMERIC(18,4)  NOT NULL CHECK (dredging_volume >= 0),
    uom_code         VARCHAR(20)    NOT NULL
                            REFERENCES param.unit_of_measure(uom_code) ON DELETE RESTRICT,
    quality_class    VARCHAR(50),
    disposal_method  VARCHAR(100),
    created_by       VARCHAR(30)
                            REFERENCES "user".info(user_code) ON DELETE SET NULL,
    notes            TEXT,
    tenant_id        UUID,
    created_at       TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ     NOT NULL DEFAULT now(),
    CONSTRAINT uq_dredging_daily UNIQUE (activity_num, record_date)
);

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

-- ============================================================
-- SECTION 17: FINANCIAL SCHEMA TABLES
-- ============================================================

CREATE TABLE financial.account (
    account_code    VARCHAR(30)     PRIMARY KEY,
    account_name    VARCHAR(200)    NOT NULL,
    account_type    VARCHAR(30)     NOT NULL
                        CHECK (account_type IN (
                            'ASSET','LIABILITY','EQUITY',
                            'REVENUE','EXPENSE','OTHER'
                        )),
    parent_code     VARCHAR(30)
                        REFERENCES financial.account(account_code) ON DELETE SET NULL,
    account_level   SMALLINT        NOT NULL DEFAULT 1,
    is_detail       BOOLEAN         NOT NULL DEFAULT TRUE,
    currency_code   CHAR(3)
                        REFERENCES param.currency(currency_code) ON DELETE SET NULL,
    description     TEXT,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE financial.journal (
    journal_id      BIGSERIAL       PRIMARY KEY,
    journal_no      VARCHAR(30)     NOT NULL UNIQUE,
    journal_date    DATE            NOT NULL,
    period_year     SMALLINT        NOT NULL,
    period_month    SMALLINT        NOT NULL,
    journal_type    VARCHAR(30)     NOT NULL,
    reference       VARCHAR(100),
    description     TEXT,
    source_module   VARCHAR(30),
    source_id       VARCHAR(50),
    is_posted       BOOLEAN         NOT NULL DEFAULT FALSE,
    posted_by       VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE SET NULL,
    posted_at       TIMESTAMPTZ,
    created_by      VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE SET NULL,
    tenant_id       UUID,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    CONSTRAINT uq_journal_no UNIQUE (journal_no),
    CONSTRAINT chk_period_month CHECK (period_month BETWEEN 1 AND 12)
);

CREATE TABLE financial.journal_line (
    line_id         BIGSERIAL       PRIMARY KEY,
    journal_id      BIGINT          NOT NULL
                        REFERENCES financial.journal(journal_id) ON DELETE CASCADE,
    account_code    VARCHAR(30)     NOT NULL
                        REFERENCES financial.account(account_code) ON DELETE RESTRICT,
    debit           NUMERIC(18,2)   DEFAULT 0 CHECK (debit >= 0),
    credit          NUMERIC(18,2)   DEFAULT 0 CHECK (credit >= 0),
    currency_code   CHAR(3)         NOT NULL
                        REFERENCES param.currency(currency_code) ON DELETE RESTRICT,
    exchange_rate   NUMERIC(18,6)   DEFAULT 1,
    description     TEXT,
    cost_center     VARCHAR(30),
    project_code    VARCHAR(30),
    partner_code    VARCHAR(30)
                        REFERENCES partner.info(partner_code) ON DELETE SET NULL,
    tenant_id       UUID,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    CONSTRAINT chk_debit_or_credit CHECK (
        (debit > 0 AND credit = 0) OR (debit = 0 AND credit > 0)
    )
);

CREATE TABLE financial.invoice (
    invoice_id      BIGSERIAL       PRIMARY KEY,
    invoice_no      VARCHAR(50)     NOT NULL UNIQUE,
    invoice_type    VARCHAR(20)     NOT NULL CHECK (invoice_type IN ('SALES','PURCHASE')),
    partner_code    VARCHAR(30)     NOT NULL
                        REFERENCES partner.info(partner_code) ON DELETE RESTRICT,
    invoice_date    DATE            NOT NULL,
    due_date        DATE,
    currency_code   CHAR(3)         NOT NULL
                        REFERENCES param.currency(currency_code) ON DELETE RESTRICT,
    subtotal        NUMERIC(18,2)   NOT NULL DEFAULT 0,
    tax_amount      NUMERIC(18,2)   NOT NULL DEFAULT 0,
    discount_amount NUMERIC(18,2)   NOT NULL DEFAULT 0,
    total_amount    NUMERIC(18,2)   NOT NULL DEFAULT 0,
    status          VARCHAR(30)
                        REFERENCES param.status(status_code) ON DELETE SET NULL,
    source_module   VARCHAR(30),
    source_doc_no   VARCHAR(50),
    notes           TEXT,
    created_by      VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE SET NULL,
    approved_by     VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE SET NULL,
    tenant_id       UUID,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE financial.invoice_line (
    line_id         BIGSERIAL       PRIMARY KEY,
    invoice_id      BIGINT          NOT NULL
                        REFERENCES financial.invoice(invoice_id) ON DELETE CASCADE,
    description     VARCHAR(500)   NOT NULL,
    quantity        NUMERIC(18,4)  NOT NULL DEFAULT 1,
    uom_code        VARCHAR(20)
                        REFERENCES param.unit_of_measure(uom_code) ON DELETE SET NULL,
    unit_price      NUMERIC(18,4)  NOT NULL DEFAULT 0,
    tax_code        VARCHAR(30),
    tax_rate        NUMERIC(5,2)    DEFAULT 0,
    line_total      NUMERIC(18,2)   NOT NULL DEFAULT 0,
    discount_amount NUMERIC(18,2)   DEFAULT 0,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE financial.payment (
    payment_id      BIGSERIAL       PRIMARY KEY,
    payment_no      VARCHAR(50)     NOT NULL UNIQUE,
    payment_type    VARCHAR(20)     NOT NULL CHECK (payment_type IN ('RECEIPT','DISBURSEMENT')),
    payment_method  VARCHAR(30)     NOT NULL
                        CHECK (payment_method IN ('CASH','BANK_TRANSFER','CHECK','GIRO','OTHER')),
    partner_code    VARCHAR(30)     NOT NULL
                        REFERENCES partner.info(partner_code) ON DELETE RESTRICT,
    payment_date    DATE            NOT NULL,
    currency_code   CHAR(3)         NOT NULL
                        REFERENCES param.currency(currency_code) ON DELETE RESTRICT,
    amount          NUMERIC(18,2)   NOT NULL,
    bank_account    VARCHAR(50),
    reference       VARCHAR(100),
    notes           TEXT,
    status          VARCHAR(30)
                        REFERENCES param.status(status_code) ON DELETE SET NULL,
    created_by      VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE SET NULL,
    tenant_id       UUID,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE financial.payment_line (
    line_id         BIGSERIAL       PRIMARY KEY,
    payment_id      BIGINT          NOT NULL
                        REFERENCES financial.payment(payment_id) ON DELETE CASCADE,
    invoice_id      BIGINT
                        REFERENCES financial.invoice(invoice_id) ON DELETE SET NULL,
    amount          NUMERIC(18,2)   NOT NULL,
    currency_code   CHAR(3)         NOT NULL
                        REFERENCES param.currency(currency_code) ON DELETE RESTRICT,
    exchange_rate   NUMERIC(18,6)   DEFAULT 1,
    notes           TEXT,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE financial.bank_account (
    account_id      VARCHAR(30)     PRIMARY KEY,
    bank_name       VARCHAR(100)    NOT NULL,
    account_number  VARCHAR(50)     NOT NULL,
    account_name    VARCHAR(150)    NOT NULL,
    account_type    VARCHAR(30)     NOT NULL CHECK (account_type IN ('SAVINGS','CHECKING','DEPOSIT')),
    currency_code   CHAR(3)         NOT NULL
                        REFERENCES param.currency(currency_code) ON DELETE RESTRICT,
    branch          VARCHAR(100),
    swift_code      VARCHAR(20),
    tenant_id       UUID,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE financial.bank_transaction (
    trans_id        BIGSERIAL       PRIMARY KEY,
    account_id      VARCHAR(30)     NOT NULL
                        REFERENCES financial.bank_account(account_id) ON DELETE RESTRICT,
    trans_date      DATE            NOT NULL,
    trans_type      VARCHAR(20)     NOT NULL CHECK (trans_type IN ('DEPOSIT','WITHDRAWAL','TRANSFER')),
    amount          NUMERIC(18,2)   NOT NULL,
    currency_code   CHAR(3)         NOT NULL
                        REFERENCES param.currency(currency_code) ON DELETE RESTRICT,
    reference       VARCHAR(100),
    description     TEXT,
    balance_before  NUMERIC(18,2),
    balance_after   NUMERIC(18,2),
    created_by      VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE SET NULL,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE financial.cost_center (
    cost_center_code VARCHAR(30)    PRIMARY KEY,
    cost_center_name VARCHAR(200)    NOT NULL,
    parent_code     VARCHAR(30)
                        REFERENCES financial.cost_center(cost_center_code) ON DELETE SET NULL,
    site_code       VARCHAR(30)
                        REFERENCES site.info(site_code) ON DELETE SET NULL,
    manager_user    VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE SET NULL,
    budget_amount   NUMERIC(18,2),
    tenant_id       UUID,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

-- ============================================================
-- SECTION 18: HSE SCHEMA TABLES
-- ============================================================

CREATE TABLE hse.incident_type (
    type_code       VARCHAR(30)     PRIMARY KEY,
    type_name       VARCHAR(100)    NOT NULL,
    severity_levels JSONB,
    description     TEXT,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE hse.incident (
    incident_id     BIGSERIAL       PRIMARY KEY,
    incident_no     VARCHAR(30)     NOT NULL UNIQUE,
    incident_type   VARCHAR(30)     NOT NULL
                        REFERENCES hse.incident_type(type_code) ON DELETE RESTRICT,
    severity        VARCHAR(20)     NOT NULL
                        CHECK (severity IN ('LOW','MEDIUM','HIGH','CRITICAL')),
    incident_date   TIMESTAMPTZ     NOT NULL,
    site_code       VARCHAR(30)
                        REFERENCES site.info(site_code) ON DELETE SET NULL,
    location_desc   VARCHAR(200),
    lat             NUMERIC(10,7),
    long            NUMERIC(11,7),
    title           VARCHAR(300)    NOT NULL,
    description     TEXT            NOT NULL,
    immediate_action TEXT,
    root_cause      TEXT,
    corrective_action TEXT,
    preventive_action TEXT,
    status          VARCHAR(30)
                        REFERENCES param.status(status_code) ON DELETE SET NULL,
    reported_by     VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE SET NULL,
    assigned_to     VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE SET NULL,
    approved_by     VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE SET NULL,
    closed_at       TIMESTAMPTZ,
    tenant_id       UUID,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE hse.incident_witness (
    witness_id      BIGSERIAL       PRIMARY KEY,
    incident_id     BIGINT          NOT NULL
                        REFERENCES hse.incident(incident_id) ON DELETE CASCADE,
    witness_name    VARCHAR(150)    NOT NULL,
    witness_contact VARCHAR(100),
    statement       TEXT,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE hse.permit (
    permit_id       BIGSERIAL       PRIMARY KEY,
    permit_no       VARCHAR(30)     NOT NULL UNIQUE,
    permit_type     VARCHAR(50)     NOT NULL,
    work_type       VARCHAR(100)    NOT NULL,
    site_code       VARCHAR(30)
                        REFERENCES site.info(site_code) ON DELETE SET NULL,
    location_desc   VARCHAR(200),
    lat             NUMERIC(10,7),
    long            NUMERIC(11,7),
    description     TEXT,
    start_date      TIMESTAMPTZ     NOT NULL,
    end_date        TIMESTAMPTZ     NOT NULL,
    hazard_analysis TEXT,
    ppe_required    VARCHAR(200),
    status          VARCHAR(30)
                        REFERENCES param.status(status_code) ON DELETE SET NULL,
    applicant       VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE SET NULL,
    approved_by     VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE SET NULL,
    issued_at       TIMESTAMPTZ,
    tenant_id       UUID,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    CONSTRAINT chk_permit_dates CHECK (end_date >= start_date)
);

CREATE TABLE hse.permit_approval (
    approval_id     BIGSERIAL       PRIMARY KEY,
    permit_id       BIGINT          NOT NULL
                        REFERENCES hse.permit(permit_id) ON DELETE CASCADE,
    approver_role   VARCHAR(50)     NOT NULL,
    approver_user   VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE SET NULL,
    decision        VARCHAR(20)     NOT NULL CHECK (decision IN ('APPROVED','REJECTED','CONDITIONAL')),
    comments        TEXT,
    approved_at     TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE hse.inspection (
    inspection_id   BIGSERIAL       PRIMARY KEY,
    inspection_no   VARCHAR(30)     NOT NULL UNIQUE,
    inspection_type VARCHAR(50)      NOT NULL,
    site_code       VARCHAR(30)
                        REFERENCES site.info(site_code) ON DELETE SET NULL,
    work_area_code  VARCHAR(30)
                        REFERENCES operational.work_area(area_code) ON DELETE SET NULL,
    fleet_code      VARCHAR(30)
                        REFERENCES fleet.info(fleet_code) ON DELETE SET NULL,
    inspection_date TIMESTAMPTZ     NOT NULL,
    inspector       VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE SET NULL,
    findings_count  INT             DEFAULT 0,
    compliance_score NUMERIC(5,2),
    status          VARCHAR(30)
                        REFERENCES param.status(status_code) ON DELETE SET NULL,
    summary         TEXT,
    tenant_id       UUID,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE hse.inspection_finding (
    finding_id      BIGSERIAL       PRIMARY KEY,
    inspection_id   BIGINT          NOT NULL
                        REFERENCES hse.inspection(inspection_id) ON DELETE CASCADE,
    finding_no      INT             NOT NULL,
    category        VARCHAR(50)     NOT NULL,
    severity        VARCHAR(20)     NOT NULL CHECK (severity IN ('LOW','MEDIUM','HIGH','CRITICAL')),
    description     TEXT            NOT NULL,
    location_desc   VARCHAR(200),
    corrective_action TEXT,
    due_date        DATE,
    status          VARCHAR(30)
                        REFERENCES param.status(status_code) ON DELETE SET NULL,
    assigned_to     VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE SET NULL,
    closed_at       TIMESTAMPTZ,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    CONSTRAINT uq_inspection_finding UNIQUE (inspection_id, finding_no)
);

CREATE TABLE hse.training (
    training_id     BIGSERIAL       PRIMARY KEY,
    training_code   VARCHAR(30)     NOT NULL UNIQUE,
    training_name   VARCHAR(200)    NOT NULL,
    training_type   VARCHAR(50)     NOT NULL,
    description     TEXT,
    duration_hours  NUMERIC(6,2),
    valid_for_days  INT,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE hse.employee_training (
    record_id       BIGSERIAL       PRIMARY KEY,
    user_code       VARCHAR(30)     NOT NULL
                        REFERENCES "user".info(user_code) ON DELETE CASCADE,
    training_id     BIGINT          NOT NULL
                        REFERENCES hse.training(training_id) ON DELETE RESTRICT,
    training_date   DATE            NOT NULL,
    expiry_date     DATE,
    score           NUMERIC(5,2),
    certificate_no  VARCHAR(50),
    certificate_file VARCHAR(200),
    status          VARCHAR(30)
                        REFERENCES param.status(status_code) ON DELETE SET NULL,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE hse.ppe_inventory (
    ppe_id          BIGSERIAL       PRIMARY KEY,
    ppe_code        VARCHAR(30)     NOT NULL UNIQUE,
    ppe_name        VARCHAR(150)    NOT NULL,
    category        VARCHAR(50)      NOT NULL,
    size            VARCHAR(20),
    color           VARCHAR(30),
    quantity_total  INT             NOT NULL DEFAULT 0,
    quantity_available INT          NOT NULL DEFAULT 0,
    quantity_in_use INT             NOT NULL DEFAULT 0,
    site_code       VARCHAR(30)
                        REFERENCES site.info(site_code) ON DELETE SET NULL,
    storage_location VARCHAR(100),
    reorder_level   INT,
    tenant_id       UUID,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE hse.ppe_distribution (
    dist_id         BIGSERIAL       PRIMARY KEY,
    user_code       VARCHAR(30)     NOT NULL
                        REFERENCES "user".info(user_code) ON DELETE CASCADE,
    ppe_id          BIGINT          NOT NULL
                        REFERENCES hse.ppe_inventory(ppe_id) ON DELETE RESTRICT,
    quantity        INT             NOT NULL DEFAULT 1,
    issue_date      DATE            NOT NULL,
    return_date     DATE,
    condition_when_issue VARCHAR(30),
    condition_when_return VARCHAR(30),
    issued_by       VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE SET NULL,
    notes           TEXT,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE hse.risk_assessment (
    assessment_id   BIGSERIAL       PRIMARY KEY,
    assessment_no   VARCHAR(30)     NOT NULL UNIQUE,
    activity_name  VARCHAR(200)    NOT NULL,
    site_code       VARCHAR(30)
                        REFERENCES site.info(site_code) ON DELETE SET NULL,
    assessment_date DATE            NOT NULL,
    assessor        VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE SET NULL,
    risk_level     VARCHAR(20)
                        CHECK (risk_level IN ('LOW','MEDIUM','HIGH','CRITICAL')),
    hazard_identified TEXT,
    risk_controls   TEXT,
    residual_risk   TEXT,
    status          VARCHAR(30)
                        REFERENCES param.status(status_code) ON DELETE SET NULL,
    approved_by     VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE SET NULL,
    tenant_id       UUID,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

-- ============================================================
-- SECTION 19: SECURITY SCHEMA TABLES (Supabase Integration)
-- ============================================================

CREATE TABLE security.app_user (
    auth_user_id    UUID            PRIMARY KEY
                        REFERENCES auth.users(id) ON DELETE CASCADE,
    user_code       VARCHAR(30)     NOT NULL UNIQUE,
    name            VARCHAR(150)    NOT NULL,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    is_super_admin  BOOLEAN         NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE security.tenant (
    tenant_id       UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_code     VARCHAR(30)     NOT NULL UNIQUE,
    tenant_name     VARCHAR(200)    NOT NULL,
    site_code       VARCHAR(30)
                        REFERENCES site.info(site_code) ON DELETE SET NULL,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE security.user_scope (
    scope_id        BIGSERIAL       PRIMARY KEY,
    auth_user_id    UUID            NOT NULL
                        REFERENCES security.app_user(auth_user_id) ON DELETE CASCADE,
    tenant_id       UUID            NOT NULL
                        REFERENCES security.tenant(tenant_id) ON DELETE RESTRICT,
    partner_code    VARCHAR(30),
    buyer_code      VARCHAR(30),
    role_code       VARCHAR(50)      NOT NULL,
    is_primary      BOOLEAN         NOT NULL DEFAULT FALSE,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    valid_from      TIMESTAMPTZ,
    valid_until     TIMESTAMPTZ,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    CONSTRAINT uq_user_tenant UNIQUE (auth_user_id, tenant_id)
);

CREATE TABLE security.permission (
    permission_id   BIGSERIAL       PRIMARY KEY,
    permission_code VARCHAR(100)    NOT NULL UNIQUE,
    permission_name VARCHAR(200)     NOT NULL,
    module          VARCHAR(50)     NOT NULL,
    description     TEXT,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE security.role_permission (
    id              BIGSERIAL       PRIMARY KEY,
    role_code       VARCHAR(50)     NOT NULL,
    permission_code VARCHAR(100)    NOT NULL
                        REFERENCES security.permission(permission_code) ON DELETE CASCADE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    CONSTRAINT uq_role_permission UNIQUE (role_code, permission_code)
);

-- ============================================================
-- SECTION 20: AUDIT SCHEMA TABLES
-- ============================================================

CREATE TABLE audit.log (
    log_id              BIGSERIAL       PRIMARY KEY,
    tenant_id          UUID,
    auth_user_id       UUID,
    user_code          VARCHAR(30),
    action             VARCHAR(20)     NOT NULL,
    table_schema        VARCHAR(100)    NOT NULL,
    table_name          VARCHAR(100)    NOT NULL,
    record_pk          TEXT,
    record_pk_name      VARCHAR(100),
    old_data            JSONB,
    new_data            JSONB,
    changed_fields      JSONB,
    request_id          UUID,
    source_ip           INET,
    user_agent          TEXT,
    app_version         VARCHAR(50),
    executed_at         TIMESTAMPTZ     NOT NULL DEFAULT now(),
    execution_time_ms   BIGINT
);

-- ============================================================
-- SECTION 21: WORKFLOW SCHEMA TABLES
-- ============================================================

CREATE TABLE workflow.definition (
    workflow_id     BIGSERIAL       PRIMARY KEY,
    workflow_code   VARCHAR(50)     NOT NULL UNIQUE,
    workflow_name   VARCHAR(200)    NOT NULL,
    module          VARCHAR(50)     NOT NULL,
    description     TEXT,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE workflow.step (
    step_id                 BIGSERIAL       PRIMARY KEY,
    workflow_id             BIGINT          NOT NULL
                                REFERENCES workflow.definition(workflow_id) ON DELETE CASCADE,
    step_order              SMALLINT        NOT NULL,
    step_name               VARCHAR(100)    NOT NULL,
    step_type               VARCHAR(30)     NOT NULL
                                CHECK (step_type IN ('START','APPROVAL','NOTIFICATION','CONDITION','END')),
    approver_role           VARCHAR(50),
    approver_user           VARCHAR(30),
    is_auto_approve         BOOLEAN         DEFAULT FALSE,
    timeout_hours           INT,
    required_approval_count INT             DEFAULT 1,
    next_step_order_approve  SMALLINT,
    next_step_order_reject  SMALLINT,
    can_skip                BOOLEAN         DEFAULT FALSE,
    is_active               BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at              TIMESTAMPTZ     NOT NULL DEFAULT now(),
    CONSTRAINT uq_workflow_step_order UNIQUE (workflow_id, step_order)
);

CREATE TABLE workflow.instance (
    instance_id     BIGSERIAL       PRIMARY KEY,
    instance_code   VARCHAR(50)     NOT NULL UNIQUE,
    workflow_id     BIGINT          NOT NULL
                        REFERENCES workflow.definition(workflow_id) ON DELETE RESTRICT,
    document_type   VARCHAR(50)     NOT NULL,
    document_id     VARCHAR(50)     NOT NULL,
    current_step_order SMALLINT     NOT NULL DEFAULT 1,
    status          VARCHAR(30)     NOT NULL
                        CHECK (status IN ('PENDING','IN_PROGRESS','APPROVED','REJECTED','CANCELLED','EXPIRED')),
    initiated_by    VARCHAR(30),
    initiated_at    TIMESTAMPTZ     NOT NULL DEFAULT now(),
    completed_at    TIMESTAMPTZ,
    due_date        TIMESTAMPTZ,
    priority        VARCHAR(20)     DEFAULT 'NORMAL',
    notes           TEXT,
    is_locked       BOOLEAN         DEFAULT FALSE,
    metadata        JSONB,
    tenant_id       UUID,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    CONSTRAINT uq_instance_doc UNIQUE (document_type, document_id)
);

CREATE TABLE workflow.instance_step (
    instance_step_id BIGSERIAL      PRIMARY KEY,
    instance_id     BIGINT         NOT NULL
                        REFERENCES workflow.instance(instance_id) ON DELETE CASCADE,
    step_id         BIGINT         NOT NULL
                        REFERENCES workflow.step(step_id) ON DELETE RESTRICT,
    step_order      SMALLINT       NOT NULL,
    status          VARCHAR(30)     NOT NULL
                        CHECK (status IN ('PENDING','IN_PROGRESS','APPROVED','REJECTED','SKIPPED')),
    started_at      TIMESTAMPTZ,
    completed_at    TIMESTAMPTZ,
    due_at          TIMESTAMPTZ,
    assigned_to     VARCHAR(30),
    comments        TEXT,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    CONSTRAINT uq_instance_step_order UNIQUE (instance_id, step_order)
);

CREATE TABLE workflow.approval (
    approval_id     BIGSERIAL       PRIMARY KEY,
    instance_step_id BIGINT         NOT NULL
                        REFERENCES workflow.instance_step(instance_step_id) ON DELETE CASCADE,
    approver_user   VARCHAR(30),
    approver_name   VARCHAR(150),
    decision        VARCHAR(20)     NOT NULL
                        CHECK (decision IN ('APPROVED','REJECTED','CONDITIONAL')),
    comments        TEXT,
    sequence_no     SMALLINT        NOT NULL,
    decided_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    ip_address      INET,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE workflow.history (
    history_id      BIGSERIAL       PRIMARY KEY,
    instance_id     BIGINT         NOT NULL
                        REFERENCES workflow.instance(instance_id) ON DELETE CASCADE,
    action          VARCHAR(50)     NOT NULL,
    from_step_order INT,
    to_step_order   INT,
    performed_by    VARCHAR(30),
    performed_at    TIMESTAMPTZ     NOT NULL DEFAULT now(),
    details         JSONB
);

-- ============================================================
-- SECTION 22: DOCUMENT SCHEMA TABLES
-- ============================================================

CREATE TABLE document.type (
    type_id         BIGSERIAL       PRIMARY KEY,
    type_code       VARCHAR(50)     NOT NULL UNIQUE,
    type_name       VARCHAR(200)    NOT NULL,
    description     TEXT,
    max_size_kb     INT             DEFAULT 10240,
    allowed_extensions TEXT,
    category        VARCHAR(50),
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE document.document (
    document_id     BIGSERIAL       PRIMARY KEY,
    document_code   VARCHAR(50)     NOT NULL UNIQUE,
    document_name   VARCHAR(300)    NOT NULL,
    type_code       VARCHAR(50)     NOT NULL
                        REFERENCES document.type(type_code) ON DELETE RESTRICT,
    entity_type     VARCHAR(50)     NOT NULL,
    entity_id       VARCHAR(50)     NOT NULL,
    tenant_id       UUID,
    current_version INT             NOT NULL DEFAULT 1,
    status          VARCHAR(30),
    uploaded_by     VARCHAR(30),
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    CONSTRAINT uq_document_entity UNIQUE (entity_type, entity_id)
);

CREATE TABLE document.version (
    version_id      BIGSERIAL       PRIMARY KEY,
    document_id     BIGINT          NOT NULL
                        REFERENCES document.document(document_id) ON DELETE CASCADE,
    version_no      INT             NOT NULL,
    file_name       VARCHAR(300)    NOT NULL,
    file_path       VARCHAR(500)    NOT NULL,
    file_size       BIGINT,
    mime_type       VARCHAR(100),
    checksum        VARCHAR(64),
    storage_bucket  VARCHAR(100),
    is_current      BOOLEAN         NOT NULL DEFAULT FALSE,
    version_notes   TEXT,
    uploaded_by     VARCHAR(30),
    uploaded_at     TIMESTAMPTZ     NOT NULL DEFAULT now(),
    CONSTRAINT uq_document_version UNIQUE (document_id, version_no),
    CONSTRAINT uq_current_version UNIQUE (document_id) WHERE is_current = TRUE
);

CREATE TABLE document.permission (
    perm_id         BIGSERIAL       PRIMARY KEY,
    document_id     BIGINT          NOT NULL
                        REFERENCES document.document(document_id) ON DELETE CASCADE,
    user_code       VARCHAR(30),
    role_name       VARCHAR(50),
    can_view        BOOLEAN         DEFAULT TRUE,
    can_download    BOOLEAN         DEFAULT TRUE,
    can_edit        BOOLEAN         DEFAULT FALSE,
    can_delete      BOOLEAN         DEFAULT FALSE,
    expires_at      TIMESTAMPTZ,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE document.signature (
    sign_id         BIGSERIAL       PRIMARY KEY,
    document_id     BIGINT          NOT NULL
                        REFERENCES document.document(document_id) ON DELETE CASCADE,
    sign_order      SMALLINT        NOT NULL,
    signer_user     VARCHAR(30),
    signer_name     VARCHAR(150),
    signer_role     VARCHAR(50),
    signature_data  TEXT,
    signed_at       TIMESTAMPTZ,
    is_valid        BOOLEAN,
    reason          VARCHAR(200),
    ip_address      INET,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE document.audit (
    audit_id        BIGSERIAL       PRIMARY KEY,
    document_id     BIGINT          NOT NULL
                        REFERENCES document.document(document_id) ON DELETE CASCADE,
    action          VARCHAR(50)     NOT NULL,
    user_code       VARCHAR(30),
    version_no      INT,
    details         JSONB,
    executed_at     TIMESTAMPTZ     NOT NULL DEFAULT now()
);

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
    position_id     BIGSERIAL       PRIMARY KEY,
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
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
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
    fleet_code      VARCHAR(30)     PRIMARY KEY,
    tenant_id       UUID            NOT NULL,
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
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
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

-- ============================================================
-- SECTION 24: REPORTING MATERIALIZED VIEWS
-- ============================================================

CREATE MATERIALIZED VIEW reporting.tide_read_daily (
    tenant_id, station_code, station_name, site_code, record_date,
    reading_count, avg_tide_level, min_tide_level, max_tide_level,
    avg_salinity, avg_dissolved_oxygen, last_reading_time
) AS
SELECT
    COALESCE(s.tenant_id, '00000000-0000-0000-0000-000000000000'::UUID),
    s.station_code, s.name, s.site_code,
    DATE_TRUNC('day', tr.record_time),
    COUNT(*)::INT, AVG(tr.tide_level), MIN(tr.tide_level), MAX(tr.tide_level),
    AVG(tr.salinity), AVG(tr.dissolved_oxygen), MAX(tr.record_time)
FROM enviro.tide_reading tr
JOIN enviro.station s ON s.station_code = tr.station_code
GROUP BY s.tenant_id, s.station_code, s.name, s.site_code, DATE_TRUNC('day', tr.record_time)
WITH DATA;

CREATE MATERIALIZED VIEW reporting.buoy_read_daily (
    tenant_id, station_code, station_name, site_code, record_date,
    reading_count, avg_tide_level, avg_salinity, avg_current_speed
) AS
SELECT
    COALESCE(s.tenant_id, '00000000-0000-0000-0000-000000000000'::UUID),
    s.station_code, s.name, s.site_code,
    DATE_TRUNC('day', br.record_time),
    COUNT(*)::INT, AVG(br.tide_level), AVG(br.salinity), AVG(br.current_speed)
FROM enviro.buoy_reading br
JOIN enviro.station s ON s.station_code = br.station_code
GROUP BY s.tenant_id, s.station_code, s.name, s.site_code, DATE_TRUNC('day', br.record_time)
WITH DATA;

CREATE MATERIALIZED VIEW reporting.dredging_production (
    tenant_id, si_num, do_num, po_num, buyer_code, buyer_name,
    fleet_code, fleet_name, work_date, daily_volume, uom_code, record_count
) AS
SELECT
    COALESCE(si.tenant_id, '00000000-0000-0000-0000-000000000000'::UUID),
    si.si_num, si.do_num, p.po_num, p.buyer_code, b.name,
    fa.fleet_code, fa.name,
    DATE_TRUNC('day', dr.record_date),
    SUM(dr.dredging_volume), dr.uom_code, COUNT(dr.id)::INT
FROM operational.dredging_records dr
JOIN operational.shipment_instruction si ON si.si_num = dr.si_num
JOIN commercial.delivery_order d_o ON d_o.do_num = si.do_num
JOIN commercial.purchase_order p ON p.po_num = d_o.po_num
JOIN buyer.info b ON b.buyer_code = p.buyer_code
JOIN fleet.info fa ON fa.fleet_code = si.fleet_main_code
GROUP BY si.tenant_id, si.si_num, si.do_num, p.po_num, p.buyer_code, b.name,
         fa.fleet_code, fa.name, DATE_TRUNC('day', dr.record_date), dr.uom_code
WITH DATA;

CREATE MATERIALIZED VIEW reporting.account_balance (
    account_code, account_name, account_type, tenant_id,
    total_debit, total_credit, balance, currency_code
) AS
SELECT
    fa.account_code, fa.account_name, fa.account_type,
    COALESCE(fjl.tenant_id, '00000000-0000-0000-0000-000000000000'::UUID),
    COALESCE(SUM(fjl.debit), 0), COALESCE(SUM(fjl.credit), 0),
    COALESCE(SUM(fjl.debit), 0) - COALESCE(SUM(fjl.credit), 0),
    fjl.currency_code
FROM financial.account fa
LEFT JOIN financial.journal_line fjl ON fjl.account_code = fa.account_code
LEFT JOIN financial.journal fj ON fj.journal_id = fjl.journal_id AND fj.is_posted = TRUE
GROUP BY fa.account_code, fa.account_name, fa.account_type, fjl.tenant_id, fjl.currency_code
WITH DATA;

CREATE MATERIALIZED VIEW reporting.hse_incident_summary (
    tenant_id, incident_type, type_name, severity, incident_month,
    incident_count, closed_count, open_count
) AS
SELECT
    COALESCE(hi.tenant_id, '00000000-0000-0000-0000-000000000000'::UUID),
    hi.incident_type, hit.type_name, hi.severity,
    DATE_TRUNC('month', hi.incident_date),
    COUNT(*)::INT,
    COUNT(CASE WHEN hi.status = 'CLOSED' THEN 1 END)::INT,
    COUNT(CASE WHEN hi.status != 'CLOSED' THEN 1 END)::INT
FROM hse.incident hi
JOIN hse.incident_type hit ON hit.type_code = hi.incident_type
GROUP BY hi.tenant_id, hi.incident_type, hit.type_name, hi.severity,
         DATE_TRUNC('month', hi.incident_date)
WITH DATA;

-- ============================================================
-- END OF TABLES
-- ============================================================

-- ============================================================
-- SECTION 25: FUNCTIONS
-- ============================================================

-- Buyer: Prevent ledger updates
CREATE OR REPLACE FUNCTION buyer.fn_prevent_ledger_update()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Ledger entries are immutable. Create a reversal entry instead.';
END;
$$ LANGUAGE plpgsql;

-- Buyer: Reverse ledger entry
CREATE OR REPLACE FUNCTION buyer.fn_reverse_ledger_entry(
    p_entry_id BIGINT,
    p_reason TEXT
) RETURNS BIGINT AS $$
DECLARE
    v_new_id BIGINT;
    v_entry buyer.ledger_hist%ROWTYPE;
BEGIN
    SELECT * INTO v_entry FROM buyer.ledger_hist WHERE id = p_entry_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Ledger entry not found: %', p_entry_id;
    END IF;
    INSERT INTO buyer.ledger_hist (
        buyer_code, transaction_date, transaction_type, amount,
        currency_code, ref_doc, ref_type, description, reversal_of_id
    ) VALUES (
        v_entry.buyer_code, CURRENT_DATE,
        CASE v_entry.transaction_type WHEN 'CREDIT' THEN 'DEBIT' ELSE 'CREDIT' END,
        v_entry.amount, v_entry.currency_code, v_entry.ref_doc,
        v_entry.ref_type, 'REVERSAL: ' || p_reason, p_entry_id
    ) RETURNING id INTO v_new_id;
    RETURN v_new_id;
END;
$$ LANGUAGE plpgsql;

-- Form: Auto-update sample count
CREATE OR REPLACE FUNCTION form.fn_update_sample_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE form.water_sampling SET total_sample = total_sample + 1 WHERE form_no = NEW.form_no;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE form.water_sampling SET total_sample = total_sample - 1 WHERE form_no = OLD.form_no;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Operational: Convert volume to target UOM
CREATE OR REPLACE FUNCTION operational.fn_convert_volume_to_target_uom(
    p_volume NUMERIC, p_from_uom VARCHAR, p_to_uom VARCHAR
) RETURNS NUMERIC AS $$
DECLARE v_converted NUMERIC;
BEGIN
    IF p_from_uom = p_to_uom THEN RETURN p_volume; END IF;
    SELECT conv_value * p_volume INTO v_converted
    FROM param.unit_conversion
    WHERE uom_from = p_from_uom AND uom_to = p_to_uom AND is_active = TRUE;
    IF v_converted IS NULL THEN
        SELECT (p_volume / conv_value) INTO v_converted
        FROM param.unit_conversion
        WHERE uom_from = p_to_uom AND uom_to = p_from_uom AND is_active = TRUE;
    END IF;
    RETURN COALESCE(v_converted, p_volume);
END;
$$ LANGUAGE plpgsql;

-- Operational: Validate dredging volume
CREATE OR REPLACE FUNCTION operational.fn_validate_dredging_volume()
RETURNS TRIGGER AS $$
DECLARE
    v_do_num VARCHAR(30); v_target NUMERIC(18,4); v_target_uom VARCHAR(20);
    v_total NUMERIC(18,4); v_converted_vol NUMERIC(18,4);
BEGIN
    SELECT si.do_num, d_o.target_volume, d_o.uom_code
    INTO v_do_num, v_target, v_target_uom
    FROM operational.shipment_instruction si
    JOIN commercial.delivery_order d_o ON d_o.do_num = si.do_num
    WHERE si.si_num = NEW.si_num;
    IF v_do_num IS NULL OR v_target IS NULL THEN RETURN NEW; END IF;
    v_converted_vol := operational.fn_convert_volume_to_target_uom(NEW.dredging_volume, NEW.uom_code, v_target_uom);
    SELECT COALESCE(SUM(
        operational.fn_convert_volume_to_target_uom(dr.dredging_volume, dr.uom_code, v_target_uom)
    ), 0) INTO v_total
    FROM operational.dredging_records dr
    JOIN operational.shipment_instruction si ON si.si_num = dr.si_num
    WHERE si.do_num = v_do_num AND dr.id <> COALESCE(NEW.id, -1);
    IF (v_total + v_converted_vol) > v_target THEN
        RAISE EXCEPTION 'VOLUME_EXCEEDED: Total volume (%) exceeds target (%) for DO %',
            ROUND(v_total + v_converted_vol, 4), ROUND(v_target, 4), v_do_num;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Financial: Validate journal balance
CREATE OR REPLACE FUNCTION financial.fn_validate_journal_balance()
RETURNS TRIGGER AS $$
DECLARE v_total_debit NUMERIC(18,2); v_total_credit NUMERIC(18,2);
BEGIN
    SELECT COALESCE(SUM(debit), 0), COALESCE(SUM(credit), 0)
    INTO v_total_debit, v_total_credit
    FROM financial.journal_line WHERE journal_id = NEW.journal_id;
    IF v_total_debit <> v_total_credit THEN
        RAISE EXCEPTION 'JOURNAL_UNBALANCED: Debit: % | Credit: %', v_total_debit, v_total_credit;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Voyage: Archive to history
CREATE OR REPLACE FUNCTION voyage.fn_archive_to_history()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO voyage.voyage_hist (fleet_code, voyage_no, lat, long, speed, heading, record_time)
    VALUES (OLD.fleet_code, OLD.voyage_no, OLD.lat, OLD.long, OLD.speed, OLD.heading, OLD.record_time);
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- Security: Get current tenant ID
CREATE OR REPLACE FUNCTION security.fn_get_current_tenant_id()
RETURNS UUID AS $$
BEGIN RETURN (
    SELECT tenant_id FROM security.user_scope
    WHERE auth_user_id = auth.uid() AND is_active = TRUE
    ORDER BY is_primary DESC LIMIT 1
);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Security: Check if super admin
CREATE OR REPLACE FUNCTION security.fn_is_super_admin()
RETURNS BOOLEAN AS $$
BEGIN RETURN (
    SELECT is_super_admin FROM security.app_user WHERE auth_user_id = auth.uid()
);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

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
    ON CONFLICT (fleet_code) DO UPDATE SET
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

-- Workflow: Start instance
CREATE OR REPLACE FUNCTION workflow.fn_start_instance(
    p_workflow_code VARCHAR, p_document_type VARCHAR, p_document_id VARCHAR,
    p_initiated_by VARCHAR, p_priority VARCHAR DEFAULT 'NORMAL'
) RETURNS BIGINT AS $$
DECLARE
    v_workflow_id BIGINT; v_instance_id BIGINT; v_first_step_id BIGINT;
    v_first_step_order SMALLINT; v_instance_code VARCHAR(50);
BEGIN
    SELECT workflow_id INTO v_workflow_id FROM workflow.definition WHERE workflow_code = p_workflow_code AND is_active = TRUE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Workflow not found: %', p_workflow_code; END IF;
    IF EXISTS (SELECT 1 FROM workflow.instance WHERE document_type = p_document_type AND document_id = p_document_id) THEN
        RAISE EXCEPTION 'Workflow already exists for document: % / %', p_document_type, p_document_id;
    END IF;
    SELECT step_id, step_order INTO v_first_step_id, v_first_step_order
    FROM workflow.step WHERE workflow_id = v_workflow_id AND step_order = 1 AND is_active = TRUE;
    v_instance_code := p_workflow_code || '_' || p_document_id || '_' || TO_CHAR(now(), 'YYYYMMDDHH24MISS');
    INSERT INTO workflow.instance (instance_code, workflow_id, document_type, document_id, current_step_order, status, initiated_by, due_date, priority)
    VALUES (v_instance_code, v_workflow_id, p_document_type, p_document_id, v_first_step_order, 'IN_PROGRESS', p_initiated_by, now() + INTERVAL '7 days', p_priority)
    RETURNING instance_id INTO v_instance_id;
    INSERT INTO workflow.instance_step (instance_id, step_id, step_order, status, started_at, assigned_to)
    VALUES (v_instance_id, v_first_step_id, v_first_step_order, 'IN_PROGRESS', now(), (SELECT approver_user FROM workflow.step WHERE step_id = v_first_step_id));
    RETURN v_instance_id;
END;
$$ LANGUAGE plpgsql;

-- Workflow: Process step
CREATE OR REPLACE FUNCTION workflow.fn_process_step(
    p_instance_id BIGINT, p_approver_user VARCHAR, p_decision VARCHAR, p_comments TEXT DEFAULT NULL
) RETURNS BOOLEAN AS $$
DECLARE
    v_instance RECORD; v_current_step RECORD; v_current_step_def RECORD;
    v_next_step_order SMALLINT; v_next_step_id BIGINT; v_approval_count INT; v_required_count INT; v_row_locked BIGINT;
BEGIN
    SELECT instance_id INTO v_row_locked FROM workflow.instance WHERE instance_id = p_instance_id AND is_locked = FALSE FOR UPDATE;
    IF v_row_locked IS NULL THEN RAISE EXCEPTION 'Instance is locked or not found: %', p_instance_id; END IF;
    UPDATE workflow.instance SET is_locked = TRUE WHERE instance_id = p_instance_id;
    BEGIN
        SELECT * INTO v_instance FROM workflow.instance WHERE instance_id = p_instance_id;
        SELECT ws.*, wsi.instance_step_id INTO v_current_step
        FROM workflow.instance_step wsi JOIN workflow.step ws ON ws.step_id = wsi.step_id
        WHERE wsi.instance_id = p_instance_id AND wsi.step_order = v_instance.current_step_order;
        SELECT COUNT(*) INTO v_approval_count FROM workflow.approval WHERE instance_step_id = v_current_step.instance_step_id AND approver_user = p_approver_user;
        IF v_approval_count > 0 THEN RAISE EXCEPTION 'User % has already processed this step', p_approver_user; END IF;
        SELECT required_approval_count INTO v_required_count FROM workflow.step WHERE step_id = v_current_step.step_id;
        INSERT INTO workflow.approval (instance_step_id, approver_user, decision, comments, sequence_no)
        VALUES (v_current_step.instance_step_id, p_approver_user, p_decision, p_comments, v_approval_count + 1);
        IF p_decision = 'REJECTED' THEN
            UPDATE workflow.instance_step SET status = 'REJECTED', completed_at = now() WHERE instance_step_id = v_current_step.instance_step_id;
            UPDATE workflow.instance SET status = 'REJECTED', current_step_order = 0, completed_at = now(), is_locked = FALSE WHERE instance_id = p_instance_id;
            INSERT INTO workflow.history (instance_id, action, from_step_order, performed_by, details)
            VALUES (p_instance_id, 'REJECTED', v_instance.current_step_order, p_approver_user, jsonb_build_object('decision', p_decision, 'comments', p_comments));
            RETURN TRUE;
        END IF;
        SELECT COUNT(*) INTO v_approval_count FROM workflow.approval WHERE instance_step_id = v_current_step.instance_step_id AND decision = 'APPROVED';
        IF v_approval_count < v_required_count THEN UPDATE workflow.instance SET is_locked = FALSE WHERE instance_id = p_instance_id; RETURN TRUE; END IF;
        UPDATE workflow.instance_step SET status = 'APPROVED', completed_at = now() WHERE instance_step_id = v_current_step.instance_step_id;
        SELECT * INTO v_current_step_def FROM workflow.step WHERE step_id = v_current_step.step_id;
        v_next_step_order := v_current_step_def.next_step_order_approve;
        IF v_next_step_order IS NULL THEN
            UPDATE workflow.instance SET status = 'APPROVED', completed_at = now(), is_locked = FALSE WHERE instance_id = p_instance_id;
            INSERT INTO workflow.history (instance_id, action, from_step_order, performed_by, details)
            VALUES (p_instance_id, 'COMPLETED', v_instance.current_step_order, p_approver_user, jsonb_build_object('decision', p_decision));
            RETURN TRUE;
        END IF;
        SELECT step_id INTO v_next_step_id FROM workflow.step WHERE workflow_id = v_instance.workflow_id AND step_order = v_next_step_order;
        UPDATE workflow.instance SET current_step_order = v_next_step_order, is_locked = FALSE WHERE instance_id = p_instance_id;
        INSERT INTO workflow.instance_step (instance_id, step_id, step_order, status, started_at, assigned_to)
        VALUES (p_instance_id, v_next_step_id, v_next_step_order, 'IN_PROGRESS', now(), (SELECT approver_user FROM workflow.step WHERE step_id = v_next_step_id));
        INSERT INTO workflow.history (instance_id, action, from_step_order, to_step_order, performed_by, details)
        VALUES (p_instance_id, 'APPROVED', v_instance.current_step_order, v_next_step_order, p_approver_user, jsonb_build_object('decision', p_decision, 'comments', p_comments));
        RETURN TRUE;
    EXCEPTION WHEN OTHERS THEN UPDATE workflow.instance SET is_locked = FALSE WHERE instance_id = p_instance_id; RAISE;
    END;
END;
$$ LANGUAGE plpgsql;

-- Document: Upload document
CREATE OR REPLACE FUNCTION document.fn_upload_document(
    p_document_name VARCHAR, p_type_code VARCHAR, p_entity_type VARCHAR, p_entity_id VARCHAR,
    p_file_name VARCHAR, p_file_path VARCHAR, p_file_size BIGINT, p_mime_type VARCHAR,
    p_checksum VARCHAR, p_storage_bucket VARCHAR, p_uploaded_by VARCHAR,
    p_version_notes TEXT DEFAULT NULL, p_is_update BOOLEAN DEFAULT FALSE
) RETURNS BIGINT AS $$
DECLARE
    v_document_id BIGINT; v_version_no INT; v_document_code VARCHAR(50);
BEGIN
    IF p_is_update THEN
        SELECT document_id, current_version + 1 INTO v_document_id, v_version_no
        FROM document.document WHERE entity_type = p_entity_type AND entity_id = p_entity_id;
        IF NOT FOUND THEN RAISE EXCEPTION 'Document not found for update: % / %', p_entity_type, p_entity_id; END IF;
        UPDATE document.version SET is_current = FALSE WHERE document_id = v_document_id AND is_current = TRUE;
        UPDATE document.document SET document_name = p_document_name, current_version = v_version_no, updated_at = now() WHERE document_id = v_document_id;
    ELSE
        v_document_code := p_entity_type || '_' || p_entity_id || '_' || EXTRACT(EPOCH FROM now())::TEXT;
        v_version_no := 1;
        INSERT INTO document.document (document_code, document_name, type_code, entity_type, entity_id, current_version, uploaded_by)
        VALUES (v_document_code, p_document_name, p_type_code, p_entity_type, p_entity_id, v_version_no, p_uploaded_by)
        RETURNING document_id INTO v_document_id;
    END IF;
    INSERT INTO document.version (document_id, version_no, file_name, file_path, file_size, mime_type, checksum, storage_bucket, is_current, version_notes, uploaded_by)
    VALUES (v_document_id, v_version_no, p_file_name, p_file_path, p_file_size, p_mime_type, p_checksum, p_storage_bucket, TRUE, p_version_notes, p_uploaded_by);
    INSERT INTO document.audit (document_id, action, user_code, version_no, details)
    VALUES (v_document_id, CASE WHEN p_is_update THEN 'VERSION_UPLOADED' ELSE 'CREATED' END, p_uploaded_by, v_version_no, jsonb_build_object('file_name', p_file_name, 'checksum', p_checksum));
    RETURN v_document_id;
END;
$$ LANGUAGE plpgsql;

-- Create yearly partition
CREATE OR REPLACE FUNCTION public.fn_create_yearly_partition(p_schema_name TEXT, p_table_name TEXT, p_year INT)
RETURNS VOID AS $$
DECLARE v_partition_name TEXT := p_table_name || '_' || p_year;
    v_start_date TEXT := p_year || '-01-01'; v_end_date TEXT := (p_year + 1) || '-01-01';
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = p_schema_name AND tablename = v_partition_name) THEN
        EXECUTE format('CREATE TABLE %I.%I PARTITION OF %I.%I FOR VALUES FROM (%L) TO (%L)', p_schema_name, v_partition_name, p_schema_name, p_table_name, v_start_date, v_end_date);
        RAISE NOTICE 'Created partition: %.%', p_schema_name, v_partition_name;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Create future partitions
CREATE OR REPLACE FUNCTION public.fn_create_future_partitions(p_schema_name TEXT, p_table_name TEXT, p_years_ahead INT DEFAULT 5)
RETURNS VOID AS $$
DECLARE v_current_year INT := EXTRACT(YEAR FROM CURRENT_DATE)::INT; v_year INT;
BEGIN
    FOR v_year IN v_current_year..(v_current_year + p_years_ahead) LOOP PERFORM public.fn_create_yearly_partition(p_schema_name, p_table_name, v_year); END LOOP;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- SECTION 26: TRIGGERS
-- ============================================================

-- Buyer: Prevent ledger updates
CREATE OR REPLACE TRIGGER trg_prevent_ledger_update
BEFORE UPDATE OR DELETE ON buyer.ledger_hist
FOR EACH ROW EXECUTE FUNCTION buyer.fn_prevent_ledger_update();

-- Form: Auto-update sample count
CREATE OR REPLACE TRIGGER trg_update_sample_count
AFTER INSERT OR DELETE ON form.sample
FOR EACH ROW EXECUTE FUNCTION form.fn_update_sample_count();

-- Operational: Validate dredging volume
CREATE OR REPLACE TRIGGER trg_validate_dredging_volume
BEFORE INSERT OR UPDATE OF dredging_volume, uom_code ON operational.dredging_records
FOR EACH ROW EXECUTE FUNCTION operational.fn_validate_dredging_volume();

-- Financial: Validate journal balance
CREATE OR REPLACE TRIGGER trg_validate_journal_balance
AFTER INSERT OR UPDATE ON financial.journal_line
FOR EACH ROW EXECUTE FUNCTION financial.fn_validate_journal_balance();

-- Voyage: Archive to history
CREATE OR REPLACE TRIGGER trg_archive_voyage
BEFORE UPDATE ON voyage.voyage
FOR EACH ROW EXECUTE FUNCTION voyage.fn_archive_to_history();

-- Telemetry: Update latest position
CREATE OR REPLACE TRIGGER trg_update_latest_position
AFTER INSERT ON telemetry.ais_position
FOR EACH ROW EXECUTE FUNCTION telemetry.fn_update_latest_position();

-- Telemetry: Check geofence
CREATE OR REPLACE TRIGGER trg_check_geofence
AFTER INSERT ON telemetry.ais_position
FOR EACH ROW EXECUTE FUNCTION telemetry.fn_check_geofence();

-- ============================================================
-- SECTION 27: GLOBAL updated_at TRIGGER
-- ============================================================

DO $$
DECLARE r RECORD; trigger_exists BOOLEAN;
BEGIN
    FOR r IN
        SELECT n.nspname AS table_schema, c.relname AS table_name
        FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        JOIN pg_attribute a ON a.attrelid = c.oid
        WHERE a.attname = 'updated_at' AND a.attnum > 0 AND NOT a.attisdropped AND c.relkind = 'r'
          AND n.nspname NOT IN ('pg_catalog','information_schema','extensions','graphql','graphql_public','realtime','supabase_functions','supabase_migrations','net','cron','pgsodium','pgbouncer')
          AND n.nspname NOT LIKE 'pg\_%' AND n.nspname NOT LIKE 'supabase\_%'
          AND has_table_privilege(c.oid, 'TRIGGER')
    LOOP
        SELECT EXISTS (SELECT 1 FROM information_schema.triggers WHERE trigger_name = 'trg_updated_at' AND event_object_schema = r.table_schema AND event_object_table = r.table_name) INTO trigger_exists;
        IF NOT trigger_exists THEN
            BEGIN
                EXECUTE format('CREATE TRIGGER trg_updated_at BEFORE UPDATE ON %I.%I FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at()', r.table_schema, r.table_name);
            EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'SKIP: %.% -> %', r.table_schema, r.table_name, SQLERRM;
            END;
        END IF;
    END LOOP;
END;
$$;

-- ============================================================
-- SECTION 28: INDEXES
-- ============================================================

-- Param indexes
CREATE INDEX IF NOT EXISTS idx_param_country_active ON param.country(is_active) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_param_currency_active ON param.currency(is_active) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_param_uom_category ON param.unit_of_measure(category) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_param_status_group ON param.status(status_group) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_param_threshold_param ON param.threshold(parameter_name) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_param_role_active ON param.role(is_active) WHERE is_active = TRUE;

-- Site indexes
CREATE INDEX IF NOT EXISTS idx_site_info_type ON site.info(type_code);
CREATE INDEX IF NOT EXISTS idx_site_info_geom ON site.info USING GIST(geom) WHERE geom IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_site_info_tenant ON site.info(tenant_id) WHERE tenant_id IS NOT NULL;

-- User indexes
CREATE INDEX IF NOT EXISTS idx_user_info_role ON "user".info(role);
CREATE INDEX IF NOT EXISTS idx_user_detail_user ON "user".detail(user_code);
CREATE UNIQUE INDEX IF NOT EXISTS uq_user_primary_contact ON "user".detail(user_code) WHERE is_primary = TRUE AND is_active = TRUE;

-- Partner indexes
CREATE INDEX IF NOT EXISTS idx_partner_info_type ON partner.info(type_code);
CREATE INDEX IF NOT EXISTS idx_partner_info_tenant ON partner.info(tenant_id) WHERE tenant_id IS NOT NULL;

-- Buyer indexes
CREATE INDEX IF NOT EXISTS idx_buyer_info_tenant ON buyer.info(tenant_id) WHERE tenant_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_buyer_ledger_buyer_date ON buyer.ledger_hist(buyer_code, transaction_date DESC, id DESC);
CREATE INDEX IF NOT EXISTS idx_buyer_ledger_ref ON buyer.ledger_hist(ref_doc) WHERE ref_doc IS NOT NULL;

-- Fleet indexes
CREATE INDEX IF NOT EXISTS idx_fleet_info_partner ON fleet.info(partner_code);
CREATE INDEX IF NOT EXISTS idx_fleet_info_type ON fleet.info(type_code);
CREATE INDEX IF NOT EXISTS idx_fleet_assign_site ON fleet.assignment_leg(site_code);
CREATE INDEX IF NOT EXISTS idx_fleet_mtc_fleet_date ON fleet.maintenance(fleet_code, start_date DESC);

-- Form indexes
CREATE INDEX IF NOT EXISTS idx_form_sampling_date ON form.water_sampling(sampling_date DESC);
CREATE INDEX IF NOT EXISTS idx_form_sampling_site ON form.water_sampling(site_code) WHERE site_code IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_form_sample_form ON form.sample(form_no);
CREATE INDEX IF NOT EXISTS idx_form_measurement_sample ON form.measurement(sample_id);

-- Laboratory indexes
CREATE INDEX IF NOT EXISTS idx_lab_result_doc ON laboratory.result(doc_no);
CREATE INDEX IF NOT EXISTS idx_lab_result_sample ON laboratory.result(sample_id) WHERE sample_id IS NOT NULL;

-- Survey indexes
CREATE INDEX IF NOT EXISTS idx_survey_sampling_date ON survey.water_sampling(sampling_date DESC);
CREATE INDEX IF NOT EXISTS idx_survey_measurement_form ON survey.measurement(form_no);

-- Enviro indexes
CREATE INDEX IF NOT EXISTS idx_env_station_site ON enviro.station(site_code) WHERE site_code IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_env_station_geom ON enviro.station USING GIST(geom) WHERE geom IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_env_wq_station_time ON enviro.water_quality(station_code, record_time DESC);
CREATE INDEX IF NOT EXISTS idx_env_tide_station_time ON enviro.tide_reading(station_code, record_time DESC);
CREATE INDEX IF NOT EXISTS idx_env_buoy_station_time ON enviro.buoy_reading(station_code, record_time DESC);
CREATE INDEX IF NOT EXISTS idx_env_reading_station ON enviro.reading(station_code, record_time DESC);

-- Commercial indexes
CREATE INDEX IF NOT EXISTS idx_po_buyer_date ON commercial.purchase_order(buyer_code, po_date DESC);
CREATE INDEX IF NOT EXISTS idx_po_status_date ON commercial.purchase_order(status, po_date DESC) WHERE status IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_do_po_num ON commercial.delivery_order(po_num);

-- Operational indexes
CREATE INDEX IF NOT EXISTS idx_work_area_geom ON operational.work_area USING GIST(geom) WHERE geom IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_si_do ON operational.shipment_instruction(do_num);
CREATE INDEX IF NOT EXISTS idx_si_fleet_main ON operational.shipment_instruction(fleet_main_code);
CREATE INDEX IF NOT EXISTS idx_work_activity_si ON operational.work_activity(si_num, planned_start DESC);
CREATE INDEX IF NOT EXISTS idx_dredging_si_activity ON operational.dredging_records(si_num, activity_num);
CREATE INDEX IF NOT EXISTS idx_dredging_date ON operational.dredging_records(record_date DESC);

-- Voyage indexes
CREATE INDEX IF NOT EXISTS idx_voyage_fleet_time ON voyage.voyage(fleet_code, record_time DESC);
CREATE INDEX IF NOT EXISTS idx_voyage_geom ON voyage.voyage USING GIST(geom) WHERE geom IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_voyage_hist_fleet ON voyage.voyage_hist(fleet_code, record_time DESC);
CREATE INDEX IF NOT EXISTS idx_voyage_hist_geom ON voyage.voyage_hist USING GIST(geom) WHERE geom IS NOT NULL;

-- Financial indexes
CREATE INDEX IF NOT EXISTS idx_fin_account_type ON financial.account(account_type) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_fin_journal_no ON financial.journal(journal_no);
CREATE INDEX IF NOT EXISTS idx_fin_journal_period ON financial.journal(period_year, period_month);
CREATE INDEX IF NOT EXISTS idx_fin_journal_line_journal ON financial.journal_line(journal_id);
CREATE INDEX IF NOT EXISTS idx_fin_invoice_no ON financial.invoice(invoice_no);
CREATE INDEX IF NOT EXISTS idx_fin_invoice_partner ON financial.invoice(partner_code, invoice_date DESC);
CREATE INDEX IF NOT EXISTS idx_fin_payment_no ON financial.payment(payment_no);
CREATE INDEX IF NOT EXISTS idx_fin_payment_partner ON financial.payment(partner_code, payment_date DESC);

-- HSE indexes
CREATE INDEX IF NOT EXISTS idx_hse_incident_no ON hse.incident(incident_no);
CREATE INDEX IF NOT EXISTS idx_hse_incident_date ON hse.incident(incident_date DESC);
CREATE INDEX IF NOT EXISTS idx_hse_incident_severity ON hse.incident(incident_type, severity);
CREATE INDEX IF NOT EXISTS idx_hse_incident_status ON hse.incident(status) WHERE status IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_hse_inspection_no ON hse.inspection(inspection_no);
CREATE INDEX IF NOT EXISTS idx_hse_permit_no ON hse.permit(permit_no);
CREATE INDEX IF NOT EXISTS idx_hse_permit_dates ON hse.permit(start_date, end_date);
CREATE INDEX IF NOT EXISTS idx_hse_emp_training_user ON hse.employee_training(user_code);
CREATE INDEX IF NOT EXISTS idx_hse_emp_training_exp ON hse.employee_training(expiry_date) WHERE expiry_date IS NOT NULL;

-- Security indexes
CREATE INDEX IF NOT EXISTS idx_security_user_scope_auth ON security.user_scope(auth_user_id);
CREATE INDEX IF NOT EXISTS idx_security_user_scope_tenant ON security.user_scope(tenant_id);
CREATE INDEX IF NOT EXISTS idx_security_permission_module ON security.permission(module) WHERE is_active = TRUE;

-- Audit indexes
CREATE INDEX IF NOT EXISTS idx_audit_log_tenant ON audit.log(tenant_id) WHERE tenant_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_audit_log_user ON audit.log(auth_user_id, executed_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_log_schema_table ON audit.log(table_schema, table_name);
CREATE INDEX IF NOT EXISTS idx_audit_log_time ON audit.log(executed_at DESC);

-- Workflow indexes
CREATE INDEX IF NOT EXISTS idx_workflow_instance_doc ON workflow.instance(document_type, document_id);
CREATE INDEX IF NOT EXISTS idx_workflow_instance_status ON workflow.instance(status);
CREATE INDEX IF NOT EXISTS idx_workflow_instance_step ON workflow.instance_step(instance_id, step_order);

-- Document indexes
CREATE INDEX IF NOT EXISTS idx_document_entity ON document.document(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_document_version_doc ON document.version(document_id, version_no);
CREATE INDEX IF NOT EXISTS idx_document_version_current ON document.version(document_id) WHERE is_current = TRUE;

-- Telemetry indexes
CREATE INDEX IF NOT EXISTS idx_telemetry_raw_partner ON telemetry.raw_message(partner_code, received_at DESC);
CREATE INDEX IF NOT EXISTS idx_telemetry_ais_fleet ON telemetry.ais_position(fleet_code, reported_at DESC);
CREATE INDEX IF NOT EXISTS idx_telemetry_ais_mmsi ON telemetry.ais_position(mmsi, received_at DESC);
CREATE INDEX IF NOT EXISTS idx_telemetry_ais_geom ON telemetry.ais_position USING GIST(geom);
CREATE INDEX IF NOT EXISTS idx_telemetry_latest_partner ON telemetry.vessel_position_latest(partner_code);
CREATE INDEX IF NOT EXISTS idx_telemetry_health_fleet ON telemetry.tracking_health(fleet_code, check_time DESC);
CREATE INDEX IF NOT EXISTS idx_telemetry_geofence_geom ON telemetry.geofence USING GIST(geom);
CREATE INDEX IF NOT EXISTS idx_telemetry_geofence_event ON telemetry.geofence_event(fleet_code, event_time DESC);

-- BRIN indexes for time-series data
CREATE INDEX IF NOT EXISTS brin_env_wq_time ON enviro.water_quality USING BRIN(record_time);
CREATE INDEX IF NOT EXISTS brin_env_tide_time ON enviro.tide_reading USING BRIN(record_time);
CREATE INDEX IF NOT EXISTS brin_env_buoy_time ON enviro.buoy_reading USING BRIN(record_time);
CREATE INDEX IF NOT EXISTS brin_voyage_time ON voyage.voyage USING BRIN(record_time);
CREATE INDEX IF NOT EXISTS brin_voyage_hist_time ON voyage.voyage_hist USING BRIN(record_time);
CREATE INDEX IF NOT EXISTS brin_form_meas_time ON form.measurement USING BRIN(created_at);

-- Reporting view indexes
CREATE UNIQUE INDEX IF NOT EXISTS idx_report_tide_daily ON reporting.tide_read_daily(tenant_id, station_code, record_date);
CREATE UNIQUE INDEX IF NOT EXISTS idx_report_buoy_daily ON reporting.buoy_read_daily(tenant_id, station_code, record_date);
CREATE UNIQUE INDEX IF NOT EXISTS idx_report_dredging_si_date ON reporting.dredging_production(tenant_id, si_num, work_date);
CREATE UNIQUE INDEX IF NOT EXISTS idx_report_account_code ON reporting.account_balance(account_code);
CREATE UNIQUE INDEX IF NOT EXISTS idx_report_hse_month ON reporting.hse_incident_summary(tenant_id, incident_type, severity, incident_month);

-- ============================================================
-- SECTION 29: SEED DATA
-- ============================================================

-- Countries
INSERT INTO param.country (iso_alpha2, iso_alpha3, iso_name, iso_numeric, name) VALUES
('ID','IDN','Indonesia',360,'Indonesia'),('MY','MYS','Malaysia',458,'Malaysia'),
('SG','SGP','Singapore',702,'Singapore'),('TH','THA','Thailand',764,'Thailand'),
('PH','PHL','Philippines',608,'Philippines'),('VN','VNM','Vietnam',704,'Vietnam'),
('CN','CHN','China',156,'China'),('JP','JPN','Japan',392,'Japan'),
('KR','KOR','South Korea',410,'South Korea'),('AU','AUS','Australia',36,'Australia'),
('US','USA','United States',840,'United States'),('GB','GBR','United Kingdom',826,'United Kingdom'),
('DE','DEU','Germany',276,'Germany'),('NL','NLD','Netherlands',528,'Netherlands'),
('PA','PAN','Panama',591,'Panama'),('LR','LBR','Liberia',430,'Liberia');

-- Currencies
INSERT INTO param.currency (currency_code, name, symbol, decimal_places) VALUES
('IDR','Indonesian Rupiah','Rp',0),('USD','US Dollar','$',2),
('EUR','Euro','€',2),('GBP','British Pound','£',2),('SGD','Singapore Dollar','S$',2),
('MYR','Malaysian Ringgit','RM',2),('THB','Thai Baht','฿',2),('JPY','Japanese Yen','¥',0);

-- Unit of Measures
INSERT INTO param.unit_of_measure (uom_code, name, category, symbol) VALUES
('M3','Cubic Meter','VOLUME','m³'),('M2','Square Meter','AREA','m²'),('M','Meter','LENGTH','m'),
('CM','Centimeter','LENGTH','cm'),('MM','Millimeter','LENGTH','mm'),('KM','Kilometer','LENGTH','km'),
('FT','Foot','LENGTH','ft'),('IN','Inch','LENGTH','in'),('L','Liter','VOLUME','L'),
('ML','Milliliter','VOLUME','mL'),('GAL','Gallon','VOLUME','gal'),('BBL','Barrel','VOLUME','bbl'),
('KG','Kilogram','MASS','kg'),('G','Gram','MASS','g'),('MG','Milligram','MASS','mg'),
('LB','Pound','MASS','lb'),('TON','Metric Ton','MASS','t'),('MT','Metric Ton','MASS','mt'),
('CELSIUS','Celsius','TEMPERATURE','°C'),('FAHRENHEIT','Fahrenheit','TEMPERATURE','°F'),
('HOUR','Hour','TIME','h'),('DAY','Day','TIME','d'),('SHIFT','Shift','TIME','shift'),
('PSI','PSI','PRESSURE','psi'),('BAR','Bar','PRESSURE','bar');

-- Unit Conversions
INSERT INTO param.unit_conversion (uom_code, uom_from, uom_to, conv_value) VALUES
('UC001','M3','BBL',6.28981),('UC002','BBL','M3',0.158987),('UC003','M','FT',3.28084),
('UC004','FT','M',0.3048),('UC005','KG','LB',2.20462),('UC006','LB','KG',0.453592),
('UC007','L','GAL',0.264172),('UC008','GAL','L',3.78541),('UC009','MT','M3',1.0),
('UC010','TON','KG',1000),('UC011','KG','TON',0.001);

-- Status Groups
INSERT INTO param.status_group (group_code, group_name) VALUES
('FORM_STATUS','Form Status'),('PO_STATUS','Purchase Order Status'),
('DO_STATUS','Delivery Order Status'),('SI_STATUS','Shipment Instruction Status'),
('ACTIVITY_STATUS','Activity Status'),('INCIDENT_STATUS','Incident Status'),
('PAYMENT_STATUS','Payment Status'),('INVOICE_STATUS','Invoice Status'),
('PERMIT_STATUS','Permit Status'),('INSPECTION_STATUS','Inspection Status');

-- Status Codes
INSERT INTO param.status (status_code, status_group, display_name, sort_order) VALUES
('DRAFT','FORM_STATUS','Draft',1),('SUBMITTED','FORM_STATUS','Submitted',2),
('APPROVED','FORM_STATUS','Approved',3),('REJECTED','FORM_STATUS','Rejected',4),
('PO_DRAFT','PO_STATUS','Draft',1),('PO_PENDING','PO_STATUS','Pending Approval',2),
('PO_APPROVED','PO_STATUS','Approved',3),('PO_IN_PROGRESS','PO_STATUS','In Progress',4),
('PO_COMPLETED','PO_STATUS','Completed',5),('PO_CANCELLED','PO_STATUS','Cancelled',6),
('DO_DRAFT','DO_STATUS','Draft',1),('DO_LOADING','DO_STATUS','Loading',2),
('DO_DEPARTED','DO_STATUS','Departed',3),('DO_ARRIVED','DO_STATUS','Arrived',4),
('DO_COMPLETED','DO_STATUS','Completed',5),('DO_CANCELLED','DO_STATUS','Cancelled',6),
('ACT_PLANNED','ACTIVITY_STATUS','Planned',1),('ACT_STARTED','ACTIVITY_STATUS','Started',2),
('ACT_IN_PROGRESS','ACTIVITY_STATUS','In Progress',3),('ACT_COMPLETED','ACTIVITY_STATUS','Completed',4),
('INC_OPEN','INCIDENT_STATUS','Open',1),('INC_INVESTIGATING','INCIDENT_STATUS','Investigating',2),
('INC_CLOSED','INCIDENT_STATUS','Closed',3),
('PAY_PENDING','PAYMENT_STATUS','Pending',1),('PAY_COMPLETED','PAYMENT_STATUS','Completed',2),
('INV_DRAFT','INVOICE_STATUS','Draft',1),('INV_ISSUED','INVOICE_STATUS','Issued',2),
('INV_PAID','INVOICE_STATUS','Paid',3),('INV_OVERDUE','INVOICE_STATUS','Overdue',4);

-- Roles
INSERT INTO param.role (role_code, role_name, description) VALUES
('SUPER_ADMIN','Super Administrator','Full system access'),
('ADMIN','Administrator','Full access within tenant'),
('MANAGER','Manager','Managerial access'),
('OPERATOR','Operator','Operational user'),
('VIEWER','Viewer','Read-only access'),
('SAFETY_OFFICER','Safety Officer','HSE dedicated role');

-- Fleet Types
INSERT INTO fleet.type (type_code, type_group, description) VALUES
('TS','TUGBOAT','Tugboat'),('TB','TUGBOAT','Tug Boat'),('BG','BARGE','Barge'),
('DP','DREDGER','Dredger Pump'),('DC','DREDGER','Dredger Cutter'),
('HD','DREDGER','Hopper Dredger'),('SB','SURVEY','Survey Boat'),
('CR','CARGO','Cargo Vessel'),('TK','TANKER','Tanker Vessel');

-- Site Types
INSERT INTO site.type (type_code, type_group, description) VALUES
('PORT','PORT','Port Facility'),('TERMINAL','TERMINAL','Terminal'),
('OFFSHORE','OFFSHORE','Offshore Location'),('DREDGE','DREDGE','Dredging Area'),
('DISPOSAL','DISPOSAL','Disposal Site'),('OFFICE','OFFICE','Office Building'),
('WAREHOUSE','WAREHOUSE','Warehouse');

-- Partner Types
INSERT INTO partner.type (type_code, type_group, description) VALUES
('VENDOR','VENDOR','Material/Service Vendor'),('CONTRACTOR','CONTRACTOR','Contractor'),
('SUPPLIER','SUPPLIER','Supplier'),('CLIENT','CLIENT','Client/Customer'),
('CONSULTANT','CONSULTANT','Consultant'),('TRANSPORTER','TRANSPORTER','Transporter');

-- Enviro Reading Types
INSERT INTO enviro.reading_type (type_code, type_name, description) VALUES
('TIDE','Tide Station','Tide measurement station'),('BUOY','Buoy Station','Buoy measurement station'),
('METEO','Meteorological','Meteorological station'),('WAVE','Wave Station','Wave measurement station');

-- HSE Incident Types
INSERT INTO hse.incident_type (type_code, type_name, description) VALUES
('NEAR_MISS','Near Miss','Near miss incident'),('INJURY','Personal Injury','Personal injury'),
('ENVIRONMENTAL','Environmental','Environmental incident'),('PROPERTY','Property Damage','Property damage'),
('FIRE','Fire','Fire incident'),('SPILL','Spill','Spill incident');

-- Document Types
INSERT INTO document.type (type_code, type_name, category, max_size_kb, allowed_extensions) VALUES
('CONTRACT','Contract','LEGAL',20480,'.pdf,.doc,.docx'),('CERTIFICATE','Certificate','CERT',5120,'.pdf,.jpg,.png'),
('REPORT','Report','REPORT',10240,'.pdf,.xlsx,.docx'),('IMAGE','Image','IMAGE',5120,'.jpg,.jpeg,.png,.gif'),
('DRAWING','Drawing','TECHNICAL',20480,'.pdf,.dwg,.dxf'),('INVOICE_DOC','Invoice','FINANCIAL',5120,'.pdf'),
('APPROVAL_DOC','Approval Doc','ADMIN',5120,'.pdf,.doc,.docx'),('PERMIT_DOC','Permit','HSE',10240,'.pdf');

-- Survey Types
INSERT INTO survey.type (type_code, type_name, description) VALUES
('BATHYMETRIC','Bathymetric Survey','Bathymetric survey'),('GEOTECHNICAL','Geotechnical Survey','Geotechnical investigation'),
('ENVIRONMENTAL','Environmental Survey','Environmental assessment'),('HYDROGRAPHIC','Hydrographic Survey','Hydrographic survey');

-- Permissions
INSERT INTO security.permission (permission_code, permission_name, module) VALUES
('form.read','Read Forms','FORM'),('form.write','Write Forms','FORM'),
('commercial.read','Read Commercial','COMMERCIAL'),('commercial.write','Write Commercial','COMMERCIAL'),
('financial.read','Read Financial','FINANCIAL'),('financial.write','Write Financial','FINANCIAL'),
('hse.read','Read HSE','HSE'),('hse.write','Write HSE','HSE'),
('operational.read','Read Operational','OPERATIONAL'),('operational.write','Write Operational','OPERATIONAL'),
('fleet.read','Read Fleet','FLEET'),('fleet.write','Write Fleet','FLEET'),
('admin.users','Manage Users','ADMIN'),('admin.tenant','Manage Tenant','ADMIN');

-- Workflow: PO Approval
INSERT INTO workflow.definition (workflow_code, workflow_name, module) VALUES
('WF_PO_APPROVAL','Purchase Order Approval','COMMERCIAL');
WITH wf AS (SELECT workflow_id FROM workflow.definition WHERE workflow_code = 'WF_PO_APPROVAL')
INSERT INTO workflow.step (workflow_id, step_order, step_name, step_type, approver_role, timeout_hours, next_step_order_approve)
SELECT wf.workflow_id, 1, 'Manager Review', 'APPROVAL', 'MANAGER', 24, 2 FROM wf;
WITH wf AS (SELECT workflow_id FROM workflow.definition WHERE workflow_code = 'WF_PO_APPROVAL')
INSERT INTO workflow.step (workflow_id, step_order, step_name, step_type, next_step_order_approve)
SELECT wf.workflow_id, 2, 'Finalize', 'END', NULL FROM wf;

-- Workflow: HSE Incident
INSERT INTO workflow.definition (workflow_code, workflow_name, module) VALUES
('WF_INCIDENT','Incident Investigation','HSE');
WITH wf AS (SELECT workflow_id FROM workflow.definition WHERE workflow_code = 'WF_INCIDENT')
INSERT INTO workflow.step (workflow_id, step_order, step_name, step_type, next_step_order_approve)
SELECT wf.workflow_id, 1, 'Start', 'START', 2 FROM wf;
WITH wf AS (SELECT workflow_id FROM workflow.definition WHERE workflow_code = 'WF_INCIDENT')
INSERT INTO workflow.step (workflow_id, step_order, step_name, step_type, approver_role, timeout_hours, next_step_order_approve)
SELECT wf.workflow_id, 2, 'Safety Officer Review', 'APPROVAL', 'SAFETY_OFFICER', 24, 3 FROM wf;
WITH wf AS (SELECT workflow_id FROM workflow.definition WHERE workflow_code = 'WF_INCIDENT')
INSERT INTO workflow.step (workflow_id, step_order, step_name, step_type, next_step_order_approve)
SELECT wf.workflow_id, 3, 'Close', 'END', NULL FROM wf;

-- ============================================================
-- END OF FILE
-- ============================================================
