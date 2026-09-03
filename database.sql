-- ============================================================
-- DATABASE SCHEMA - COMPLETE & CORRECTED
-- Last Updated: 2026-09-03
-- ============================================================

-- ============================================================
-- EXTENSIONS
-- ============================================================
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS btree_gist;
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- ============================================================
-- GLOBAL TRIGGER FUNCTION: auto-update updated_at
-- ============================================================
CREATE OR REPLACE FUNCTION public.fn_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- SCHEMA: param (Parameters/Reference Data)
-- ============================================================
CREATE SCHEMA IF NOT EXISTS param;

-- Country Reference
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

-- Currency Reference
CREATE TABLE param.currency (
    currency_code   CHAR(3)         PRIMARY KEY,
    name            VARCHAR(100)    NOT NULL,
    symbol          VARCHAR(10),
    decimal_places  SMALLINT        NOT NULL DEFAULT 2 CHECK (decimal_places >= 0),
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

-- Unit of Measure Reference
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

-- Unit Conversion Reference
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
    CONSTRAINT chk_diff_uom       CHECK  (uom_from <> uom_to)
);

-- Status Reference (Generic status for all modules)
CREATE TABLE param.status (
    status_code     VARCHAR(30)     PRIMARY KEY,
    status_group    VARCHAR(50)     NOT NULL,
    display_name    VARCHAR(100),
    description     TEXT,
    sort_order      SMALLINT        DEFAULT 0,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),

    CONSTRAINT uq_status_group_code UNIQUE (status_group, status_code)
);

-- Status Groups (Lookup untuk konsistensi)
CREATE TABLE param.status_group (
    group_code      VARCHAR(50)     PRIMARY KEY,
    group_name      VARCHAR(100)    NOT NULL,
    description     TEXT,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

-- Threshold/Parameter Reference
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

-- Role Reference (untuk user management)
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
-- SCHEMA: site (Location Data)
-- ============================================================
CREATE SCHEMA IF NOT EXISTS site;

-- Site Type
CREATE TABLE site.type (
    type_code       VARCHAR(20)     PRIMARY KEY,
    type_group      VARCHAR(50)     NOT NULL,
    description     TEXT,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

-- Site Information
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
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

-- ============================================================
-- SCHEMA: "user" (User Management)
-- ============================================================
CREATE SCHEMA IF NOT EXISTS "user";

-- User Information
CREATE TABLE "user".info (
    user_code       VARCHAR(30)     PRIMARY KEY,
    name            VARCHAR(150)    NOT NULL,
    role            VARCHAR(50)     NOT NULL
                        REFERENCES param.role(role_code) ON DELETE RESTRICT,
    employee_id     VARCHAR(30),
    department      VARCHAR(100),
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

-- User Contact Details
CREATE TABLE "user".detail (
    id              BIGSERIAL       PRIMARY KEY,
    user_code       VARCHAR(30)     NOT NULL
                        REFERENCES "user".info(user_code) ON DELETE CASCADE,
    contact_type    VARCHAR(30)     NOT NULL
                        CHECK (contact_type IN ('PHONE','EMAIL','FAX','ADDRESS','EMERGENCY')),
    contact_value   VARCHAR(200)    NOT NULL,
    is_primary      BOOLEAN         NOT NULL DEFAULT FALSE,
    is_verified      BOOLEAN         NOT NULL DEFAULT FALSE,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),

    CONSTRAINT uq_user_contact UNIQUE (user_code, contact_type, contact_value)
);

-- User Session/Audit Log
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
-- SCHEMA: partner (Business Partners)
-- ============================================================
CREATE SCHEMA IF NOT EXISTS partner;

-- Partner Type
CREATE TABLE partner.type (
    type_code       VARCHAR(20)     PRIMARY KEY,
    type_group      VARCHAR(50)     NOT NULL,
    description     TEXT,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

-- Partner Information
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
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

-- ============================================================
-- SCHEMA: buyer (Buyer/Customer Management)
-- ============================================================
CREATE SCHEMA IF NOT EXISTS buyer;

-- Buyer Information
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
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

-- Buyer-Site Assignment
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

-- Buyer Ledger History (Immutable)
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

    CONSTRAINT uq_ledger_ref_doc UNIQUE (buyer_code, ref_doc, ref_type)
                        WHERE ref_doc IS NOT NULL
);

-- Function to prevent ledger updates
CREATE OR REPLACE FUNCTION buyer.fn_prevent_ledger_update()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Ledger entries are immutable. Create a reversal entry instead.';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_prevent_ledger_update
BEFORE UPDATE OR DELETE ON buyer.ledger_hist
FOR EACH ROW EXECUTE FUNCTION buyer.fn_prevent_ledger_update();

-- Function to reverse a ledger entry
CREATE OR REPLACE FUNCTION buyer.fn_reverse_ledger_entry(
    p_entry_id BIGINT,
    p_reason TEXT
) RETURNS BIGINT AS $$
DECLARE
    v_new_id BIGINT;
    v_entry buyer.ledger_hist%ROWTYPE;
BEGIN
    -- Get original entry
    SELECT * INTO v_entry FROM buyer.ledger_hist WHERE id = p_entry_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Ledger entry not found: %', p_entry_id;
    END IF;

    -- Create reversal entry
    INSERT INTO buyer.ledger_hist (
        buyer_code, transaction_date, transaction_type, amount,
        currency_code, ref_doc, ref_type, description, reversal_of_id
    ) VALUES (
        v_entry.buyer_code,
        CURRENT_DATE,
        CASE v_entry.transaction_type WHEN 'CREDIT' THEN 'DEBIT' ELSE 'CREDIT' END,
        v_entry.amount,
        v_entry.currency_code,
        v_entry.ref_doc,
        v_entry.ref_type,
        'REVERSAL: ' || p_reason,
        p_entry_id
    ) RETURNING id INTO v_new_id;

    RETURN v_new_id;
END;
$$ LANGUAGE plpgsql;

-- View: Buyer with Ledger Balance
CREATE OR REPLACE VIEW buyer.v_info_with_ledger AS
SELECT
    bi.*,
    c.symbol AS currency_symbol,
    COALESCE(agg.balance, 0) AS amount_ledger,
    COALESCE(agg.last_transaction, NULL) AS last_transaction_date
FROM buyer.info bi
LEFT JOIN (
    SELECT
        buyer_code,
        currency_code,
        SUM(CASE
            WHEN transaction_type = 'CREDIT' THEN  amount
            WHEN transaction_type = 'DEBIT'  THEN -amount
        END) AS balance,
        MAX(transaction_date) AS last_transaction
    FROM buyer.ledger_hist
    GROUP BY buyer_code, currency_code
) agg ON agg.buyer_code = bi.buyer_code
LEFT JOIN param.currency c ON c.currency_code = agg.currency_code;

-- ============================================================
-- SCHEMA: fleet (Vessels/Equipment)
-- ============================================================
CREATE SCHEMA IF NOT EXISTS fleet;

-- Fleet Type
CREATE TABLE fleet.type (
    type_code       VARCHAR(20)     PRIMARY KEY,
    type_group      VARCHAR(50)     NOT NULL,
    description     TEXT,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

-- Fleet Information (Vessels)
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
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),

    CONSTRAINT uq_fleet_imo   UNIQUE (imo_number)   WHERE imo_number IS NOT NULL,
    CONSTRAINT uq_fleet_mmsi  UNIQUE (mmsi_number)  WHERE mmsi_number IS NOT NULL
);

-- Fleet Assignment to Site
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

-- Exclusion constraint untuk prevent overlapping assignments
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
WHERE (
    COALESCE(act_start_date, est_start_date) IS NOT NULL
);

-- Fleet Maintenance Records
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

-- View: Fleet with Maintenance Info
CREATE OR REPLACE VIEW fleet.v_info_with_maintenance AS
SELECT
    fi.*,
    ft.type_group,
    pc.name AS partner_name,
    lm.last_mtc_date,
    lm.last_mtc_type,
    lm.last_mtc_description,
    lm.maintenance_count
FROM fleet.info fi
LEFT JOIN fleet.type ft ON ft.type_code = fi.type_code
LEFT JOIN partner.info pc ON pc.partner_code = fi.partner_code
LEFT JOIN LATERAL (
    SELECT 
        fm.start_date AS last_mtc_date,
        fm.maintenance_type AS last_mtc_type,
        fm.description AS last_mtc_description,
        COUNT(*) OVER () AS maintenance_count
    FROM fleet.maintenance fm
    WHERE fm.fleet_code = fi.fleet_code
    ORDER BY fm.start_date DESC
    LIMIT 1
) lm ON TRUE;

-- ============================================================
-- SCHEMA: form (Form Management - Sampling Forms)
-- ============================================================
CREATE SCHEMA IF NOT EXISTS form;

-- Water Sampling Form Header
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
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

-- Sample Detail (Fixed: Add FK to form.water_sampling)
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
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    
    CONSTRAINT uq_sample_per_form UNIQUE (form_no, sample_no)
);

-- Sample Measurement Result
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
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),

    CONSTRAINT uq_form_measurement UNIQUE (form_no, sample_id, parameter_name)
);

-- Trigger to auto-update total_sample count
CREATE OR REPLACE FUNCTION form.fn_update_sample_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE form.water_sampling
        SET total_sample = total_sample + 1
        WHERE form_no = NEW.form_no;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE form.water_sampling
        SET total_sample = total_sample - 1
        WHERE form_no = OLD.form_no;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_update_sample_count
AFTER INSERT OR DELETE ON form.sample
FOR EACH ROW EXECUTE FUNCTION form.fn_update_sample_count();

-- ============================================================
-- SCHEMA: laboratory (Laboratory Management)
-- ============================================================
CREATE SCHEMA IF NOT EXISTS laboratory;

-- Laboratory Information
CREATE TABLE laboratory.info (
    lab_code        VARCHAR(30)     PRIMARY KEY,
    name            VARCHAR(150)    NOT NULL,
    site_code       VARCHAR(30)
                        REFERENCES site.info(site_code) ON DELETE SET NULL,
    address         TEXT,
    accreditation_no VARCHAR(50),
    accreditation_exp DATE,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

-- Laboratory Equipment
CREATE TABLE laboratory.equipment (
    equipment_id    VARCHAR(30)     PRIMARY KEY,
    lab_code        VARCHAR(30)     NOT NULL
                        REFERENCES laboratory.info(lab_code) ON DELETE RESTRICT,
    name            VARCHAR(150)    NOT NULL,
    model           VARCHAR(100),
    serial_number   VARCHAR(100),
    manufacturer     VARCHAR(100),
    calibration_date DATE,
    next_calibration DATE,
    status          VARCHAR(30)
                        REFERENCES param.status(status_code) ON DELETE SET NULL,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

-- Test Categories
CREATE TABLE laboratory.test_category (
    category_code   VARCHAR(30)     PRIMARY KEY,
    category_name   VARCHAR(100)    NOT NULL,
    description     TEXT,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

-- Test Methods
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

-- Laboratory Result
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
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

-- Laboratory Result Detail
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
-- SCHEMA: survey (Survey Data - terpisah dari form lab)
-- ============================================================
CREATE SCHEMA IF NOT EXISTS survey;

-- Survey Type
CREATE TABLE survey.type (
    type_code       VARCHAR(30)     PRIMARY KEY,
    type_name       VARCHAR(100)    NOT NULL,
    description     TEXT,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

-- Survey Water Sampling Header
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
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

-- Survey Measurement
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
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),

    CONSTRAINT uq_survey_measurement UNIQUE (form_no, measurement_no, parameter_name)
);

-- ============================================================
-- SCHEMA: enviro (Environmental Monitoring)
-- ============================================================
CREATE SCHEMA IF NOT EXISTS enviro;

-- Environmental Station
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
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

-- Water Quality Readings
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
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),

    CONSTRAINT uq_wq_station_time UNIQUE (station_code, record_time, depth)
);

-- Environmental Reading Type (Unified for tide/buoy)
CREATE TABLE enviro.reading_type (
    type_code       VARCHAR(30)     PRIMARY KEY,
    type_name       VARCHAR(100)    NOT NULL,
    description     TEXT,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

-- Environmental Readings (Unified table for tide/buoy)
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
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),

    CONSTRAINT uq_reading_station_type_time UNIQUE (station_code, reading_type, record_time)
);

-- DEPRECATED: Keep for backward compatibility, will be removed
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
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),

    CONSTRAINT uq_tide_station_time UNIQUE (station_code, record_time)
);

-- DEPRECATED: Keep for backward compatibility
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
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),

    CONSTRAINT uq_buoy_station_time UNIQUE (station_code, record_time)
);

-- Station Maintenance
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

-- View: Station with Maintenance Info
CREATE OR REPLACE VIEW enviro.v_station_with_maintenance AS
SELECT
    es.*,
    lm.last_mtc_start,
    lm.last_mtc_end,
    lm.last_mtc_type
FROM enviro.station es
LEFT JOIN LATERAL (
    SELECT 
        em.start_date AS last_mtc_start,
        em.end_date   AS last_mtc_end,
        em.maintenance_type AS last_mtc_type
    FROM   enviro.maintenance em
    WHERE  em.station_code = es.station_code
    ORDER  BY em.start_date DESC
    LIMIT  1
) lm ON TRUE;

-- ============================================================
-- SCHEMA: commercial (Commercial/Procurement)
-- ============================================================
CREATE SCHEMA IF NOT EXISTS commercial;

-- Purchase Order Header
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
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT now(),

    CONSTRAINT chk_po_target_dates  CHECK (target_end_date >= target_start_date OR target_end_date IS NULL),
    CONSTRAINT chk_po_actual_dates CHECK (actual_end_date >= actual_start_date OR actual_end_date IS NULL)
);

-- Delivery Order
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
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT now(),

    CONSTRAINT chk_do_target_dates  CHECK (target_end_date >= target_start_date OR target_end_date IS NULL),
    CONSTRAINT chk_do_actual_dates  CHECK (actual_end_date >= actual_start_date OR actual_end_date IS NULL)
);

-- View: DO with remaining volume
CREATE OR REPLACE VIEW commercial.v_do_remaining_volume AS
SELECT
    d.*,
    p.total_volume AS po_total_volume,
    p.target_volume AS do_target_volume,
    COALESCE(d.actual_volume, 0) AS delivered_volume,
    p.target_volume - COALESCE(d.actual_volume, 0) AS remaining_volume,
    CASE 
        WHEN p.target_volume > 0 
        THEN ROUND((COALESCE(d.actual_volume, 0) / p.target_volume) * 100, 2)
        ELSE 0 
    END AS delivery_percentage
FROM commercial.delivery_order d
JOIN commercial.purchase_order p ON p.po_num = d.po_num;

-- ============================================================
-- SCHEMA: operational (Operations Management)
-- ============================================================
CREATE SCHEMA IF NOT EXISTS operational;

-- Work Area
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
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

-- Shipment Instruction
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
    actual_start       TIMESTAMPTZ,
    actual_end         TIMESTAMPTZ,
    notes               TEXT,
    created_by          VARCHAR(30)
                            REFERENCES "user".info(user_code) ON DELETE SET NULL,
    approved_by         VARCHAR(30)
                            REFERENCES "user".info(user_code) ON DELETE SET NULL,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT now(),

    CONSTRAINT chk_different_fleet CHECK (
        fleet_assist_code IS NULL OR fleet_assist_code <> fleet_main_code
    )
);

-- Work Activity
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
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),

    CONSTRAINT chk_planned_dates CHECK (planned_end >= planned_start OR planned_end IS NULL),
    CONSTRAINT chk_actual_dates  CHECK (actual_end >= actual_start  OR actual_end IS NULL)
);

-- Dredging Records (FIXED: Remove duplicate FK)
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
    created_at       TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ     NOT NULL DEFAULT now(),

    CONSTRAINT uq_dredging_daily UNIQUE (activity_num, record_date)
);

-- Function to convert volume to target UOM
CREATE OR REPLACE FUNCTION operational.fn_convert_volume_to_target_uom(
    p_volume     NUMERIC,
    p_from_uom   VARCHAR,
    p_to_uom     VARCHAR
) RETURNS NUMERIC AS $$
DECLARE
    v_converted NUMERIC;
BEGIN
    IF p_from_uom = p_to_uom THEN
        RETURN p_volume;
    END IF;

    SELECT conv_value * p_volume INTO v_converted
    FROM param.unit_conversion
    WHERE uom_from = p_from_uom
      AND uom_to   = p_to_uom
      AND is_active = TRUE;

    IF v_converted IS NULL THEN
        -- Try reverse conversion
        SELECT (p_volume / conv_value) INTO v_converted
        FROM param.unit_conversion
        WHERE uom_from = p_to_uom
          AND uom_to   = p_from_uom
          AND is_active = TRUE;
    END IF;

    RETURN COALESCE(v_converted, p_volume);
END;
$$ LANGUAGE plpgsql;

-- Function to validate dredging volume (FIXED: with UOM conversion)
CREATE OR REPLACE FUNCTION operational.fn_validate_dredging_volume() 
RETURNS TRIGGER AS $$
DECLARE 
    v_do_num         VARCHAR(30); 
    v_target         NUMERIC(18,4); 
    v_target_uom     VARCHAR(20); 
    v_total          NUMERIC(18,4); 
    v_converted_vol  NUMERIC(18,4);
BEGIN 
    -- Get DO and target info
    SELECT si.do_num, d_o.target_volume, d_o.uom_code
    INTO v_do_num, v_target, v_target_uom
    FROM operational.shipment_instruction si 
    JOIN commercial.delivery_order d_o ON d_o.do_num = si.do_num 
    WHERE si.si_num = NEW.si_num;

    IF v_do_num IS NULL OR v_target IS NULL THEN
        RETURN NEW;  -- Allow if no DO linked or no target
    END IF;

    -- Convert new volume to target UOM
    v_converted_vol := operational.fn_convert_volume_to_target_uom(
        NEW.dredging_volume,
        NEW.uom_code,
        v_target_uom
    );

    -- Calculate total already recorded for this DO
    SELECT COALESCE(SUM(
        operational.fn_convert_volume_to_target_uom(dr.dredging_volume, dr.uom_code, v_target_uom)
    ), 0)
    INTO v_total
    FROM operational.dredging_records dr
    JOIN operational.shipment_instruction si ON si.si_num = dr.si_num
    WHERE si.do_num = v_do_num
      AND dr.id <> COALESCE(NEW.id, -1);

    -- Check if exceeds
    IF (v_total + v_converted_vol) > v_target THEN
        RAISE EXCEPTION 
            'VOLUME_EXCEEDED: Batas Volume Terlampaui! Pengerukan baru sebesar % % akan membuat total volume (%) melebihi batas target Delivery Order % (%) sebesar % %.',
            NEW.dredging_volume, NEW.uom_code, 
            ROUND(v_total + v_converted_vol, 4), 
            v_do_num, 
            ROUND(v_target, 4), v_target_uom,
            ROUND((v_total + v_converted_vol) - v_target, 4), v_target_uom;
    END IF;

    RETURN NEW;
END;  
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_validate_dredging_volume
BEFORE INSERT OR UPDATE OF dredging_volume, uom_code
ON operational.dredging_records
FOR EACH ROW
EXECUTE FUNCTION operational.fn_validate_dredging_volume();

-- ============================================================
-- SCHEMA: voyage (Vessel Tracking)
-- ============================================================
CREATE SCHEMA IF NOT EXISTS voyage;

-- Current Voyage Position
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
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

-- Voyage History (Immutable)
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
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),

    CONSTRAINT uq_voyage_hist_fleet_time UNIQUE (fleet_code, record_time)
);

-- Function to archive current position to history
CREATE OR REPLACE FUNCTION voyage.fn_archive_to_history()
RETURNS TRIGGER AS $$
BEGIN
    -- Archive to history before updating
    INSERT INTO voyage.voyage_hist (
        fleet_code, voyage_no, lat, long, speed, heading, record_time
    ) VALUES (
        OLD.fleet_code, OLD.voyage_no, OLD.lat, OLD.long, OLD.speed, OLD.heading, OLD.record_time
    );
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_archive_voyage
BEFORE UPDATE ON voyage.voyage
FOR EACH ROW EXECUTE FUNCTION voyage.fn_archive_to_history();

-- ============================================================
-- SCHEMA: financial (Financial/Accounting)
-- ============================================================
CREATE SCHEMA IF NOT EXISTS financial;

-- Chart of Accounts
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

-- Journal Entry Header
CREATE TABLE financial.journal (
    journal_id      BIGSERIAL       PRIMARY KEY,
    journal_no      VARCHAR(30)     NOT NULL UNIQUE,
    journal_date     DATE            NOT NULL,
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
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),

    CONSTRAINT uq_journal_no UNIQUE (journal_no),
    CONSTRAINT chk_period_month CHECK (period_month BETWEEN 1 AND 12)
);

-- Journal Entry Line
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
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),

    CONSTRAINT chk_debit_or_credit CHECK (
        (debit > 0 AND credit = 0) OR (debit = 0 AND credit > 0)
    )
);

-- Function to validate journal balance
CREATE OR REPLACE FUNCTION financial.fn_validate_journal_balance()
RETURNS TRIGGER AS $$
DECLARE
    v_total_debit  NUMERIC(18,2);
    v_total_credit NUMERIC(18,2);
    v_journal_no   VARCHAR(30);
BEGIN
    SELECT journal_no INTO v_journal_no
    FROM financial.journal WHERE journal_id = NEW.journal_id;

    SELECT COALESCE(SUM(debit), 0), COALESCE(SUM(credit), 0)
    INTO v_total_debit, v_total_credit
    FROM financial.journal_line
    WHERE journal_id = NEW.journal_id;

    IF v_total_debit <> v_total_credit THEN
        RAISE EXCEPTION 
            'JOURNAL_UNBALANCED: Journal % has unbalanced entries. Debit: % | Credit: %',
            v_journal_no, v_total_debit, v_total_credit;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_validate_journal_balance
AFTER INSERT OR UPDATE ON financial.journal_line
FOR EACH ROW EXECUTE FUNCTION financial.fn_validate_journal_balance();

-- Invoice Header
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
    total_amount    NUMERIC(18,2)  NOT NULL DEFAULT 0,
    status          VARCHAR(30)
                        REFERENCES param.status(status_code) ON DELETE SET NULL,
    source_module   VARCHAR(30),
    source_doc_no   VARCHAR(50),
    notes           TEXT,
    created_by      VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE SET NULL,
    approved_by     VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE SET NULL,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

-- Invoice Line
CREATE TABLE financial.invoice_line (
    line_id         BIGSERIAL       PRIMARY KEY,
    invoice_id      BIGINT          NOT NULL
                        REFERENCES financial.invoice(invoice_id) ON DELETE CASCADE,
    description     VARCHAR(500)    NOT NULL,
    quantity        NUMERIC(18,4)   NOT NULL DEFAULT 1,
    uom_code        VARCHAR(20)
                        REFERENCES param.unit_of_measure(uom_code) ON DELETE SET NULL,
    unit_price      NUMERIC(18,4)   NOT NULL DEFAULT 0,
    tax_code        VARCHAR(30),
    tax_rate        NUMERIC(5,2)    DEFAULT 0,
    line_total      NUMERIC(18,2)   NOT NULL DEFAULT 0,
    discount_amount NUMERIC(18,2)   DEFAULT 0,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

-- Payment Header
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
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

-- Payment Line (for linking to invoices)
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

-- Bank Account
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
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

-- Bank Transaction
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

-- Cost Center
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
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

-- ============================================================
-- SCHEMA: hse (Health, Safety, Environment)
-- ============================================================
CREATE SCHEMA IF NOT EXISTS hse;

-- HSE Incident Type
CREATE TABLE hse.incident_type (
    type_code       VARCHAR(30)     PRIMARY KEY,
    type_name       VARCHAR(100)    NOT NULL,
    severity_levels JSONB,
    description     TEXT,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

-- HSE Incident
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
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

-- Incident Witness
CREATE TABLE hse.incident_witness (
    witness_id      BIGSERIAL       PRIMARY KEY,
    incident_id     BIGINT          NOT NULL
                        REFERENCES hse.incident(incident_id) ON DELETE CASCADE,
    witness_name    VARCHAR(150)    NOT NULL,
    witness_contact VARCHAR(100),
    statement       TEXT,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

-- HSE Permit
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
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),

    CONSTRAINT chk_permit_dates CHECK (end_date >= start_date)
);

-- Permit Approval/Rejection Log
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

-- HSE Inspection
CREATE TABLE hse.inspection (
    inspection_id   BIGSERIAL       PRIMARY KEY,
    inspection_no   VARCHAR(30)     NOT NULL UNIQUE,
    inspection_type VARCHAR(50)     NOT NULL,
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
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

-- Inspection Finding
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

-- HSE Training
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

-- Employee Training Record
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

-- HSE PPE Inventory
CREATE TABLE hse.ppe_inventory (
    ppe_id          BIGSERIAL       PRIMARY KEY,
    ppe_code        VARCHAR(30)     NOT NULL UNIQUE,
    ppe_name        VARCHAR(150)    NOT NULL,
    category        VARCHAR(50)     NOT NULL,
    size            VARCHAR(20),
    color           VARCHAR(30),
    quantity_total  INT             NOT NULL DEFAULT 0,
    quantity_available INT          NOT NULL DEFAULT 0,
    quantity_in_use INT             NOT NULL DEFAULT 0,
    site_code       VARCHAR(30)
                        REFERENCES site.info(site_code) ON DELETE SET NULL,
    storage_location VARCHAR(100),
    reorder_level   INT,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

-- PPE Distribution
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

-- HSE Risk Assessment
CREATE TABLE hse.risk_assessment (
    assessment_id   BIGSERIAL       PRIMARY KEY,
    assessment_no   VARCHAR(30)     NOT NULL UNIQUE,
    activity_name   VARCHAR(200)    NOT NULL,
    site_code       VARCHAR(30)
                        REFERENCES site.info(site_code) ON DELETE SET NULL,
    assessment_date DATE            NOT NULL,
    assessor        VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE SET NULL,
    risk_level      VARCHAR(20)
                        CHECK (risk_level IN ('LOW','MEDIUM','HIGH','CRITICAL')),
    hazard_identified TEXT,
    risk_controls   TEXT,
    residual_risk   TEXT,
    status          VARCHAR(30)
                        REFERENCES param.status(status_code) ON DELETE SET NULL,
    approved_by     VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE SET NULL,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

-- ============================================================
-- SCHEMA: reporting (Materialized Views for Reporting)
-- ============================================================
CREATE SCHEMA IF NOT EXISTS reporting;

-- Materialized View: Daily Tide Readings Summary
CREATE MATERIALIZED VIEW IF NOT EXISTS reporting.tide_read_daily AS
SELECT
    s.station_code,
    s.name AS station_name,
    s.site_code,
    DATE_TRUNC('day', tr.record_time) AS record_date,
    COUNT(*) AS reading_count,
    AVG(tr.tide_level) AS avg_tide_level,
    MIN(tr.tide_level) AS min_tide_level,
    MAX(tr.tide_level) AS max_tide_level,
    AVG(tr.salinity) AS avg_salinity,
    AVG(tr.dissolved_oxygen) AS avg_dissolved_oxygen,
    AVG(tr.current_speed) AS avg_current_speed,
    MAX(tr.record_time) AS last_reading_time
FROM enviro.station s
JOIN enviro.tide_reading tr ON tr.station_code = s.station_code
GROUP BY s.station_code, s.name, s.site_code,
         DATE_TRUNC('day', tr.record_time)
WITH DATA;

CREATE UNIQUE INDEX IF NOT EXISTS idx_tide_daily_station_date
    ON reporting.tide_read_daily(station_code, record_date);

-- Materialized View: Weekly Tide Readings Summary
CREATE MATERIALIZED VIEW IF NOT EXISTS reporting.tide_read_weekly AS
SELECT
    s.station_code,
    s.name AS station_name,
    s.site_code,
    DATE_TRUNC('week', tr.record_time) AS record_week,
    COUNT(*) AS reading_count,
    AVG(tr.tide_level) AS avg_tide_level,
    MIN(tr.tide_level) AS min_tide_level,
    MAX(tr.tide_level) AS max_tide_level,
    AVG(tr.salinity) AS avg_salinity,
    AVG(tr.dissolved_oxygen) AS avg_dissolved_oxygen,
    AVG(tr.current_speed) AS avg_current_speed
FROM enviro.station s
JOIN enviro.tide_reading tr ON tr.station_code = s.station_code
GROUP BY s.station_code, s.name, s.site_code,
         DATE_TRUNC('week', tr.record_time)
WITH DATA;

CREATE UNIQUE INDEX IF NOT EXISTS idx_tide_weekly_station_week
    ON reporting.tide_read_weekly(station_code, record_week);

-- Materialized View: Yearly Tide Readings Summary
CREATE MATERIALIZED VIEW IF NOT EXISTS reporting.tide_read_yearly AS
SELECT
    s.station_code,
    s.name AS station_name,
    s.site_code,
    EXTRACT(YEAR FROM tr.record_time) AS record_year,
    COUNT(*) AS reading_count,
    AVG(tr.tide_level) AS avg_tide_level,
    MIN(tr.tide_level) AS min_tide_level,
    MAX(tr.tide_level) AS max_tide_level,
    AVG(tr.salinity) AS avg_salinity,
    AVG(tr.dissolved_oxygen) AS avg_dissolved_oxygen
FROM enviro.station s
JOIN enviro.tide_reading tr ON tr.station_code = s.station_code
GROUP BY s.station_code, s.name, s.site_code,
         EXTRACT(YEAR FROM tr.record_time)
WITH DATA;

CREATE UNIQUE INDEX IF NOT EXISTS idx_tide_yearly_station_year
    ON reporting.tide_read_yearly(station_code, record_year);

-- Materialized View: Daily Buoy Readings Summary
CREATE MATERIALIZED VIEW IF NOT EXISTS reporting.buoy_read_daily AS
SELECT
    s.station_code,
    s.name AS station_name,
    s.site_code,
    DATE_TRUNC('day', br.record_time) AS record_date,
    COUNT(*) AS reading_count,
    AVG(br.tide_level) AS avg_tide_level,
    MIN(br.tide_level) AS min_tide_level,
    MAX(br.tide_level) AS max_tide_level,
    AVG(br.salinity) AS avg_salinity,
    AVG(br.dissolved_oxygen) AS avg_dissolved_oxygen,
    AVG(br.current_speed) AS avg_current_speed,
    AVG(br.water_density) AS avg_water_density
FROM enviro.station s
JOIN enviro.buoy_reading br ON br.station_code = s.station_code
GROUP BY s.station_code, s.name, s.site_code,
         DATE_TRUNC('day', br.record_time)
WITH DATA;

CREATE UNIQUE INDEX IF NOT EXISTS idx_buoy_daily_station_date
    ON reporting.buoy_read_daily(station_code, record_date);

-- Materialized View: Weekly Buoy Readings Summary
CREATE MATERIALIZED VIEW IF NOT EXISTS reporting.buoy_read_weekly AS
SELECT
    s.station_code,
    s.name AS station_name,
    s.site_code,
    DATE_TRUNC('week', br.record_time) AS record_week,
    COUNT(*) AS reading_count,
    AVG(br.tide_level) AS avg_tide_level,
    MIN(br.tide_level) AS min_tide_level,
    MAX(br.tide_level) AS max_tide_level,
    AVG(br.salinity) AS avg_salinity,
    AVG(br.dissolved_oxygen) AS avg_dissolved_oxygen,
    AVG(br.current_speed) AS avg_current_speed
FROM enviro.station s
JOIN enviro.buoy_reading br ON br.station_code = s.station_code
GROUP BY s.station_code, s.name, s.site_code,
         DATE_TRUNC('week', br.record_time)
WITH DATA;

CREATE UNIQUE INDEX IF NOT EXISTS idx_buoy_weekly_station_week
    ON reporting.buoy_read_weekly(station_code, record_week);

-- Materialized View: Yearly Buoy Readings Summary
CREATE MATERIALIZED VIEW IF NOT EXISTS reporting.buoy_read_yearly AS
SELECT
    s.station_code,
    s.name AS station_name,
    s.site_code,
    EXTRACT(YEAR FROM br.record_time) AS record_year,
    COUNT(*) AS reading_count,
    AVG(br.tide_level) AS avg_tide_level,
    MIN(br.tide_level) AS min_tide_level,
    MAX(br.tide_level) AS max_tide_level,
    AVG(br.salinity) AS avg_salinity,
    AVG(br.dissolved_oxygen) AS avg_dissolved_oxygen
FROM enviro.station s
JOIN enviro.buoy_reading br ON br.station_code = s.station_code
GROUP BY s.station_code, s.name, s.site_code,
         EXTRACT(YEAR FROM br.record_time)
WITH DATA;

CREATE UNIQUE INDEX IF NOT EXISTS idx_buoy_yearly_station_year
    ON reporting.buoy_read_yearly(station_code, record_year);

-- Materialized View: Dredging Production Summary
CREATE MATERIALIZED VIEW IF NOT EXISTS reporting.dredging_production AS
SELECT
    si.si_num,
    si.do_num,
    p.po_num,
    p.buyer_code,
    b.name AS buyer_name,
    fa.name AS fleet_name,
    DATE_TRUNC('day', dr.record_date) AS work_date,
    SUM(dr.dredging_volume) AS daily_volume,
    dr.uom_code,
    COUNT(dr.id) AS record_count
FROM operational.dredging_records dr
JOIN operational.shipment_instruction si ON si.si_num = dr.si_num
JOIN commercial.delivery_order d_o ON d_o.do_num = si.do_num
JOIN commercial.purchase_order p ON p.po_num = d_o.po_num
JOIN buyer.info b ON b.buyer_code = p.buyer_code
JOIN fleet.info fa ON fa.fleet_code = si.fleet_main_code
GROUP BY si.si_num, si.do_num, p.po_num, p.buyer_code, b.name,
         fa.name, DATE_TRUNC('day', dr.record_date), dr.uom_code
WITH DATA;

CREATE UNIQUE INDEX IF NOT EXISTS idx_dredging_prod_si_date
    ON reporting.dredging_production(si_num, work_date);

-- Materialized View: Financial Summary by Account
CREATE MATERIALIZED VIEW IF NOT EXISTS reporting.account_balance AS
SELECT
    fa.account_code,
    fa.account_name,
    fa.account_type,
    fa.parent_code,
    fa.account_level,
    COALESCE(SUM(fjl.debit), 0) AS total_debit,
    COALESCE(SUM(fjl.credit), 0) AS total_credit,
    COALESCE(SUM(fjl.debit), 0) - COALESCE(SUM(fjl.credit), 0) AS balance,
    fjl.currency_code
FROM financial.account fa
LEFT JOIN financial.journal_line fjl ON fjl.account_code = fa.account_code
LEFT JOIN financial.journal fj ON fj.journal_id = fjl.journal_id AND fj.is_posted = TRUE
GROUP BY fa.account_code, fa.account_name, fa.account_type,
         fa.parent_code, fa.account_level, fjl.currency_code
WITH DATA;

CREATE UNIQUE INDEX IF NOT EXISTS idx_account_balance_code
    ON reporting.account_balance(account_code);

-- Materialized View: HSE Incident Summary
CREATE MATERIALIZED VIEW IF NOT EXISTS reporting.hse_incident_summary AS
SELECT
    hi.incident_type,
    hit.type_name AS type_name,
    hi.severity,
    DATE_TRUNC('month', hi.incident_date) AS incident_month,
    COUNT(*) AS incident_count,
    COUNT(CASE WHEN hi.status = 'CLOSED' THEN 1 END) AS closed_count,
    COUNT(CASE WHEN hi.status != 'CLOSED' THEN 1 END) AS open_count
FROM hse.incident hi
JOIN hse.incident_type hit ON hit.type_code = hi.incident_type
GROUP BY hi.incident_type, hit.type_name, hi.severity,
         DATE_TRUNC('month', hi.incident_date)
WITH DATA;

CREATE UNIQUE INDEX IF NOT EXISTS idx_hse_incident_type_severity_month
    ON reporting.hse_incident_summary(incident_type, severity, incident_month);

-- Materialized View: Fleet Utilization
CREATE MATERIALIZED VIEW IF NOT EXISTS reporting.fleet_utilization AS
SELECT
    fi.fleet_code,
    fi.name AS fleet_name,
    ft.type_name,
    si.work_area_code,
    owa.name AS work_area_name,
    COUNT(DISTINCT si.si_num) AS total_shipments,
    SUM(EXTRACT(EPOCH FROM (COALESCE(si.actual_end, si.planned_end) - COALESCE(si.actual_start, si.planned_start)))/3600) AS total_hours_worked,
    COUNT(DISTINCT DATE_TRUNC('day', COALESCE(si.actual_start, si.planned_start))) AS working_days
FROM fleet.info fi
LEFT JOIN fleet.type ft ON ft.type_code = fi.type_code
LEFT JOIN operational.shipment_instruction si ON si.fleet_main_code = fi.fleet_code
LEFT JOIN operational.work_area owa ON owa.area_code = si.work_area_code
GROUP BY fi.fleet_code, fi.name, ft.type_name, si.work_area_code, owa.name
WITH DATA;

CREATE UNIQUE INDEX IF NOT EXISTS idx_fleet_utilization_code
    ON reporting.fleet_utilization(fleet_code);

-- ============================================================
-- GLOBAL AUTO updated_at TRIGGER
-- ============================================================
DO $$
DECLARE
    r RECORD;
    trigger_exists BOOLEAN;
BEGIN
    FOR r IN
        SELECT n.nspname AS table_schema,
               c.relname  AS table_name
        FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        JOIN pg_attribute a ON a.attrelid = c.oid
        WHERE a.attname = 'updated_at'
          AND a.attnum > 0
          AND NOT a.attisdropped
          AND c.relkind = 'r'
          AND n.nspname NOT IN (
              'pg_catalog', 'information_schema', 'reporting',
              'vault', 'auth', 'storage', 'extensions',
              'graphql', 'graphql_public', 'realtime',
              'supabase_functions', 'supabase_migrations',
              'net', 'cron', 'pgsodium', 'pgbouncer'
          )
          AND n.nspname NOT LIKE 'pg\_%'
          AND n.nspname NOT LIKE 'supabase\_%'
          AND has_table_privilege(c.oid, 'TRIGGER')
    LOOP
        SELECT EXISTS (
            SELECT 1
            FROM information_schema.triggers
            WHERE trigger_name = 'trg_updated_at'
              AND event_object_schema = r.table_schema
              AND event_object_table  = r.table_name
        ) INTO trigger_exists;

        IF NOT trigger_exists THEN
            BEGIN
                EXECUTE format(
                    'CREATE TRIGGER trg_updated_at
                     BEFORE UPDATE ON %I.%I
                     FOR EACH ROW
                     EXECUTE FUNCTION public.fn_set_updated_at()',
                    r.table_schema, r.table_name
                );
            EXCEPTION WHEN OTHERS THEN
                RAISE NOTICE 'SKIP: %.% -> %', r.table_schema, r.table_name, SQLERRM;
            END;
        END IF;
    END LOOP;
END;
$$;

-- ============================================================
-- REFRESH COMMANDS (untuk cron / pg_cron)
-- ============================================================
-- REFRESH MATERIALIZED VIEW CONCURRENTLY reporting.tide_read_daily;
-- REFRESH MATERIALIZED VIEW CONCURRENTLY reporting.tide_read_weekly;
-- REFRESH MATERIALIZED VIEW CONCURRENTLY reporting.tide_read_yearly;
-- REFRESH MATERIALIZED VIEW CONCURRENTLY reporting.buoy_read_daily;
-- REFRESH MATERIALIZED VIEW CONCURRENTLY reporting.buoy_read_weekly;
-- REFRESH MATERIALIZED VIEW CONCURRENTLY reporting.buoy_read_yearly;
-- REFRESH MATERIALIZED VIEW CONCURRENTLY reporting.dredging_production;
-- REFRESH MATERIALIZED VIEW CONCURRENTLY reporting.account_balance;
-- REFRESH MATERIALIZED VIEW CONCURRENTLY reporting.hse_incident_summary;
-- REFRESH MATERIALIZED VIEW CONCURRENTLY reporting.fleet_utilization;

-- ============================================================
-- INDEXING
-- ============================================================

-- 1. PARAM INDEXES
CREATE INDEX IF NOT EXISTS idx_param_country_active ON param.country(is_active) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_param_currency_active  ON param.currency(is_active)  WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_param_uom_active       ON param.unit_of_measure(is_active) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_param_uom_category     ON param.unit_of_measure(category) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_param_conversion_from  ON param.unit_conversion(uom_from) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_param_conversion_to    ON param.unit_conversion(uom_to)   WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_param_status_group     ON param.status(status_group)     WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_param_status_active    ON param.status(status_group, is_active) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_param_threshold_param  ON param.threshold(parameter_name) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_param_threshold_uom    ON param.threshold(uom_code)       WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_param_role_active      ON param.role(is_active)          WHERE is_active = TRUE;

-- 2. SITE INDEXES
CREATE INDEX IF NOT EXISTS idx_site_type_active      ON site.type(type_group, is_active) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_site_info_type         ON site.info(type_code);
CREATE INDEX IF NOT EXISTS idx_site_info_geom         ON site.info USING GIST(geom)    WHERE geom IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_site_info_city         ON site.info(city)               WHERE city IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_site_info_country      ON site.info(country_id)         WHERE country_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_site_info_active       ON site.info(is_active)          WHERE is_active = TRUE;

-- 3. USER INDEXES
CREATE INDEX IF NOT EXISTS idx_user_info_role         ON "user".info(role);
CREATE INDEX IF NOT EXISTS idx_user_info_active       ON "user".info(is_active)        WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_user_detail_code        ON "user".detail(user_code);
CREATE INDEX IF NOT EXISTS idx_user_detail_type        ON "user".detail(contact_type);
CREATE UNIQUE INDEX IF NOT EXISTS uq_user_one_primary ON "user".detail(user_code)      WHERE is_primary = TRUE AND is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_user_session_user       ON "user".session_log(user_code);
CREATE INDEX IF NOT EXISTS idx_user_session_time       ON "user".session_log(login_time DESC);

-- 4. PARTNER INDEXES
CREATE INDEX IF NOT EXISTS idx_partner_type_active    ON partner.type(type_group, is_active) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_partner_info_type       ON partner.info(type_code);
CREATE INDEX IF NOT EXISTS idx_partner_info_site       ON partner.info(site_code)       WHERE site_code IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_partner_info_country    ON partner.info(country_id)      WHERE country_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_partner_info_active     ON partner.info(is_active)       WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_partner_info_name       ON partner.info(name)            WHERE is_active = TRUE;

-- 5. BUYER INDEXES
CREATE INDEX IF NOT EXISTS idx_buyer_info_site        ON buyer.info(site_code)         WHERE site_code IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_buyer_info_active      ON buyer.info(is_active)         WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_buyer_site_code        ON buyer.site(buyer_code);
CREATE INDEX IF NOT EXISTS idx_buyer_site_site         ON buyer.site(site_code);
CREATE INDEX IF NOT EXISTS uq_buyer_site_primary       ON buyer.site(buyer_code)        WHERE is_primary = TRUE AND is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_buyer_ledger_buyer_date ON buyer.ledger_hist(buyer_code, transaction_date DESC, id DESC);
CREATE INDEX IF NOT EXISTS idx_buyer_ledger_type       ON buyer.ledger_hist(transaction_type);
CREATE INDEX IF NOT EXISTS idx_buyer_ledger_ref        ON buyer.ledger_hist(ref_doc)    WHERE ref_doc IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_buyer_ledger_reversal   ON buyer.ledger_hist(reversal_of_id) WHERE reversal_of_id IS NOT NULL;

-- 6. FLEET INDEXES
CREATE INDEX IF NOT EXISTS idx_fleet_type_active      ON fleet.type(type_group, is_active) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_fleet_info_partner      ON fleet.info(partner_code);
CREATE INDEX IF NOT EXISTS idx_fleet_info_type         ON fleet.info(type_code);
CREATE INDEX IF NOT EXISTS idx_fleet_info_flag         ON fleet.info(flag_country_id)  WHERE flag_country_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_fleet_info_active       ON fleet.info(is_active)        WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_fleet_info_name         ON fleet.info(name)             WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_fleet_assign_site       ON fleet.assignment_leg(site_code);
CREATE INDEX IF NOT EXISTS idx_fleet_assign_active     ON fleet.assignment_leg(fleet_code, est_start_date) WHERE act_end_date IS NULL;
CREATE INDEX IF NOT EXISTS idx_fleet_assign_all        ON fleet.assignment_leg(fleet_code, est_start_date, est_end_date);
CREATE INDEX IF NOT EXISTS idx_fleet_mtc_fleet_date    ON fleet.maintenance(fleet_code, start_date DESC);
CREATE INDEX IF NOT EXISTS idx_fleet_mtc_status        ON fleet.maintenance(status)    WHERE status IS NOT NULL;

-- 7. FORM INDEXES
CREATE INDEX IF NOT EXISTS idx_form_sampling_date      ON form.water_sampling(sampling_date DESC);
CREATE INDEX IF NOT EXISTS idx_form_sampling_site      ON form.water_sampling(site_code) WHERE site_code IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_form_sampling_status    ON form.water_sampling(status)   WHERE status IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_form_sampling_recorder  ON form.water_sampling(recorder_by) WHERE recorder_by IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_form_sample_form        ON form.sample(form_no);
CREATE INDEX IF NOT EXISTS idx_form_sample_status      ON form.sample(status)           WHERE status IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_form_measurement_form   ON form.measurement(form_no);
CREATE INDEX IF NOT EXISTS idx_form_measurement_sample  ON form.measurement(sample_id);
CREATE INDEX IF NOT EXISTS idx_form_measurement_param  ON form.measurement(parameter_name);
CREATE INDEX IF NOT EXISTS idx_form_measurement_exceed ON form.measurement(is_exceed)   WHERE is_exceed = TRUE;

-- 8. LABORATORY INDEXES
CREATE INDEX IF NOT EXISTS idx_lab_info_site           ON laboratory.info(site_code)    WHERE site_code IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_lab_info_active         ON laboratory.info(is_active)   WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_lab_equipment_lab      ON laboratory.equipment(lab_code);
CREATE INDEX IF NOT EXISTS idx_lab_equipment_cal      ON laboratory.equipment(next_calibration) WHERE next_calibration IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_lab_method_category    ON laboratory.method(category_code);
CREATE INDEX IF NOT EXISTS idx_lab_result_doc          ON laboratory.result(doc_no);
CREATE INDEX IF NOT EXISTS idx_lab_result_lab          ON laboratory.result(lab_code) WHERE lab_code IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_lab_result_sample       ON laboratory.result(sample_id) WHERE sample_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_lab_result_date         ON laboratory.result(result_date DESC);
CREATE INDEX IF NOT EXISTS idx_lab_result_detail       ON laboratory.result_detail(result_id);
CREATE INDEX IF NOT EXISTS idx_lab_result_detail_param ON laboratory.result_detail(result_id, parameter_name);

-- 9. SURVEY INDEXES
CREATE INDEX IF NOT EXISTS idx_survey_type_active      ON survey.type(is_active)        WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_survey_sampling_date    ON survey.water_sampling(sampling_date DESC);
CREATE INDEX IF NOT EXISTS idx_survey_sampling_type    ON survey.water_sampling(type_code);
CREATE INDEX IF NOT EXISTS idx_survey_sampling_site    ON survey.water_sampling(site_code) WHERE site_code IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_survey_sampling_status  ON survey.water_sampling(status) WHERE status IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_survey_measurement_form ON survey.measurement(form_no);
CREATE INDEX IF NOT EXISTS idx_survey_measurement_param ON survey.measurement(parameter_name);
CREATE INDEX IF NOT EXISTS idx_survey_measurement_exceed ON survey.measurement(is_exceed) WHERE is_exceed = TRUE;

-- 10. ENVIRO INDEXES
CREATE INDEX IF NOT EXISTS idx_env_station_site        ON enviro.station(site_code)    WHERE site_code IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_env_station_type        ON enviro.station(station_type);
CREATE INDEX IF NOT EXISTS idx_env_station_geom        ON enviro.station USING GIST(geom) WHERE geom IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_env_station_status      ON enviro.station(status)        WHERE status IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_env_wq_station_time     ON enviro.water_quality(station_code, record_time DESC);
CREATE INDEX IF NOT EXISTS idx_env_wq_param            ON enviro.water_quality(record_time, station_code) WHERE station_code IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_env_reading_type        ON enviro.reading_type(is_active) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_env_reading_station     ON enviro.reading(station_code, record_time DESC);
CREATE INDEX IF NOT EXISTS idx_env_reading_type_time   ON enviro.reading(reading_type, record_time DESC);
CREATE INDEX IF NOT EXISTS idx_env_tide_station_time   ON enviro.tide_reading(station_code, record_time DESC);
CREATE INDEX IF NOT EXISTS idx_env_buoy_station_time   ON enviro.buoy_reading(station_code, record_time DESC);
CREATE INDEX IF NOT EXISTS idx_env_mtc_station_date    ON enviro.maintenance(station_code, start_date DESC);
CREATE INDEX IF NOT EXISTS idx_env_mtc_status          ON enviro.maintenance(status)   WHERE status IS NOT NULL;

-- 11. COMMERCIAL INDEXES
CREATE INDEX IF NOT EXISTS idx_po_buyer_date           ON commercial.purchase_order(buyer_code, po_date DESC);
CREATE INDEX IF NOT EXISTS idx_po_status_date          ON commercial.purchase_order(status, po_date DESC) WHERE status IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_po_uom                  ON commercial.purchase_order(uom_code);
CREATE INDEX IF NOT EXISTS idx_po_currency             ON commercial.purchase_order(currency_code);
CREATE INDEX IF NOT EXISTS idx_po_target_date          ON commercial.purchase_order(target_start_date, target_end_date);
CREATE INDEX IF NOT EXISTS idx_po_created_by           ON commercial.purchase_order(created_by) WHERE created_by IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_do_po_num               ON commercial.delivery_order(po_num);
CREATE INDEX IF NOT EXISTS idx_do_status_date          ON commercial.delivery_order(status, do_date DESC) WHERE status IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_do_discharge_site      ON commercial.delivery_order(discharge_site) WHERE discharge_site IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_do_target_date         ON commercial.delivery_order(target_start_date, target_end_date);

-- 12. OPERATIONAL INDEXES
CREATE INDEX IF NOT EXISTS idx_work_area_geom          ON operational.work_area USING GIST(geom) WHERE geom IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_work_area_site          ON operational.work_area(site_code)    WHERE site_code IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_work_area_active        ON operational.work_area(is_active)   WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_si_do                  ON operational.shipment_instruction(do_num);
CREATE INDEX IF NOT EXISTS idx_si_fleet_main           ON operational.shipment_instruction(fleet_main_code);
CREATE INDEX IF NOT EXISTS idx_si_fleet_assist         ON operational.shipment_instruction(fleet_assist_code) WHERE fleet_assist_code IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_si_working_site         ON operational.shipment_instruction(working_site) WHERE working_site IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_si_discharge_site      ON operational.shipment_instruction(discharge_site) WHERE discharge_site IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_si_work_area           ON operational.shipment_instruction(work_area_code) WHERE work_area_code IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_si_status              ON operational.shipment_instruction(status) WHERE status IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_si_planned             ON operational.shipment_instruction(planned_start DESC);
CREATE INDEX IF NOT EXISTS idx_activity_si_planned     ON operational.work_activity(si_num, planned_start DESC);
CREATE INDEX IF NOT EXISTS idx_activity_fleet         ON operational.work_activity(fleet_code, planned_start DESC);
CREATE INDEX IF NOT EXISTS idx_activity_area           ON operational.work_activity(area_code) WHERE area_code IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_activity_status        ON operational.work_activity(status) WHERE status IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_activity_type          ON operational.work_activity(activity_type);
CREATE INDEX IF NOT EXISTS idx_dredging_si_activity   ON operational.dredging_records(si_num, activity_num);
CREATE INDEX IF NOT EXISTS idx_dredging_date          ON operational.dredging_records(record_date DESC);
CREATE INDEX IF NOT EXISTS idx_dredging_uom           ON operational.dredging_records(uom_code);
CREATE INDEX IF NOT EXISTS idx_dredging_created_by     ON operational.dredging_records(created_by) WHERE created_by IS NOT NULL;

-- 13. VOYAGE INDEXES
CREATE INDEX IF NOT EXISTS idx_voyage_fleet_time      ON voyage.voyage(fleet_code, record_time DESC);
CREATE INDEX IF NOT EXISTS idx_voyage_do              ON voyage.voyage(do_num)                WHERE do_num IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_voyage_status          ON voyage.voyage(status)                WHERE status IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_voyage_geom             ON voyage.voyage USING GIST(geom)        WHERE geom IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_voyage_hist_fleet       ON voyage.voyage_hist(fleet_code, record_time DESC);
CREATE INDEX IF NOT EXISTS idx_voyage_hist_geom       ON voyage.voyage_hist USING GIST(geom)  WHERE geom IS NOT NULL;

-- 14. FINANCIAL INDEXES
CREATE INDEX IF NOT EXISTS idx_fin_account_type       ON financial.account(account_type)    WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_fin_account_parent      ON financial.account(parent_code)     WHERE parent_code IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_fin_journal_no         ON financial.journal(journal_no);
CREATE INDEX IF NOT EXISTS idx_fin_journal_date       ON financial.journal(journal_date DESC);
CREATE INDEX IF NOT EXISTS idx_fin_journal_period     ON financial.journal(period_year, period_month);
CREATE INDEX IF NOT EXISTS idx_fin_journal_posted     ON financial.journal(is_posted, journal_date) WHERE is_posted = TRUE;
CREATE INDEX IF NOT EXISTS idx_fin_journal_source     ON financial.journal(source_module, source_id) WHERE source_module IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_fin_journal_line_journal ON financial.journal_line(journal_id);
CREATE INDEX IF NOT EXISTS idx_fin_journal_line_account ON financial.journal_line(account_code);
CREATE INDEX IF NOT EXISTS idx_fin_journal_line_cost   ON financial.journal_line(cost_center) WHERE cost_center IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_fin_journal_line_partner ON financial.journal_line(partner_code) WHERE partner_code IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_fin_invoice_no          ON financial.invoice(invoice_no);
CREATE INDEX IF NOT EXISTS idx_fin_invoice_partner     ON financial.invoice(partner_code, invoice_date DESC);
CREATE INDEX IF NOT EXISTS idx_fin_invoice_status     ON financial.invoice(status)           WHERE status IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_fin_invoice_date       ON financial.invoice(invoice_date DESC);
CREATE INDEX IF NOT EXISTS idx_fin_invoice_line       ON financial.invoice_line(invoice_id);
CREATE INDEX IF NOT EXISTS idx_fin_payment_no         ON financial.payment(payment_no);
CREATE INDEX IF NOT EXISTS idx_fin_payment_partner    ON financial.payment(partner_code, payment_date DESC);
CREATE INDEX IF NOT EXISTS idx_fin_payment_status     ON financial.payment(status)           WHERE status IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_fin_payment_line       ON financial.payment_line(payment_id);
CREATE INDEX IF NOT EXISTS idx_fin_payment_line_inv   ON financial.payment_line(invoice_id) WHERE invoice_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_fin_bank_account       ON financial.bank_account(bank_name, currency_code) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_fin_bank_trans_account ON financial.bank_transaction(account_id, trans_date DESC);
CREATE INDEX IF NOT EXISTS idx_fin_cost_center_site   ON financial.cost_center(site_code)   WHERE site_code IS NOT NULL;

-- 15. HSE INDEXES
CREATE INDEX IF NOT EXISTS idx_hse_incident_type       ON hse.incident_type(is_active)      WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_hse_incident_no         ON hse.incident(incident_no);
CREATE INDEX IF NOT EXISTS idx_hse_incident_date       ON hse.incident(incident_date DESC);
CREATE INDEX IF NOT EXISTS idx_hse_incident_type_sev   ON hse.incident(incident_type, severity);
CREATE INDEX IF NOT EXISTS idx_hse_incident_site      ON hse.incident(site_code)            WHERE site_code IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_hse_incident_status     ON hse.incident(status)               WHERE status IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_hse_incident_reporter   ON hse.incident(reported_by)         WHERE reported_by IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_hse_witness_incident    ON hse.incident_witness(incident_id);
CREATE INDEX IF NOT EXISTS idx_hse_permit_no           ON hse.permit(permit_no);
CREATE INDEX IF NOT EXISTS idx_hse_permit_site         ON hse.permit(site_code)              WHERE site_code IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_hse_permit_status       ON hse.permit(status)                 WHERE status IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_hse_permit_dates        ON hse.permit(start_date, end_date);
CREATE INDEX IF NOT EXISTS idx_hse_permit_approval     ON hse.permit_approval(permit_id);
CREATE INDEX IF NOT EXISTS idx_hse_inspection_no       ON hse.inspection(inspection_no);
CREATE INDEX IF NOT EXISTS idx_hse_inspection_site     ON hse.inspection(site_code)         WHERE site_code IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_hse_inspection_date    ON hse.inspection(inspection_date DESC);
CREATE INDEX IF NOT EXISTS idx_hse_inspection_status  ON hse.inspection(status)             WHERE status IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_hse_finding_inspection  ON hse.inspection_finding(inspection_id);
CREATE INDEX IF NOT EXISTS idx_hse_finding_status      ON hse.inspection_finding(status)    WHERE status IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_hse_finding_severity   ON hse.inspection_finding(severity);
CREATE INDEX IF NOT EXISTS idx_hse_training_active     ON hse.training(is_active)           WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_hse_emp_training_user   ON hse.employee_training(user_code);
CREATE INDEX IF NOT EXISTS idx_hse_emp_training_date   ON hse.employee_training(training_date DESC);
CREATE INDEX IF NOT EXISTS idx_hse_emp_training_exp   ON hse.employee_training(expiry_date) WHERE expiry_date IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_hse_ppe_site            ON hse.ppe_inventory(site_code)       WHERE site_code IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_hse_ppe_category       ON hse.ppe_inventory(category);
CREATE INDEX IF NOT EXISTS idx_hse_ppe_active         ON hse.ppe_inventory(is_active)       WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_hse_ppe_dist_user      ON hse.ppe_distribution(user_code);
CREATE INDEX IF NOT EXISTS idx_hse_ppe_dist_date       ON hse.ppe_distribution(issue_date DESC);
CREATE INDEX IF NOT EXISTS idx_hse_risk_no             ON hse.risk_assessment(assessment_no);
CREATE INDEX IF NOT EXISTS idx_hse_risk_site           ON hse.risk_assessment(site_code)    WHERE site_code IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_hse_risk_level          ON hse.risk_assessment(risk_level);
CREATE INDEX IF NOT EXISTS idx_hse_risk_status         ON hse.risk_assessment(status)       WHERE status IS NOT NULL;

-- 16. REPORTING INDEXES (on materialized views)
CREATE INDEX IF NOT EXISTS idx_reporting_tide_daily_date   ON reporting.tide_read_daily(record_date DESC);
CREATE INDEX IF NOT EXISTS idx_reporting_tide_weekly_date  ON reporting.tide_read_weekly(record_week DESC);
CREATE INDEX IF NOT EXISTS idx_reporting_buoy_daily_date   ON reporting.buoy_read_daily(record_date DESC);
CREATE INDEX IF NOT EXISTS idx_reporting_buoy_weekly_date  ON reporting.buoy_read_weekly(record_week DESC);
CREATE INDEX IF NOT EXISTS idx_reporting_dredging_date    ON reporting.dredging_production(work_date DESC);
CREATE INDEX IF NOT EXISTS idx_reporting_dredging_buyer   ON reporting.dredging_production(buyer_code);
CREATE INDEX IF NOT EXISTS idx_reporting_account_type     ON reporting.account_balance(account_type);
CREATE INDEX IF NOT EXISTS idx_reporting_hse_month        ON reporting.hse_incident_summary(incident_month DESC);
CREATE INDEX IF NOT EXISTS idx_reporting_fleet_active     ON reporting.fleet_utilization(fleet_code);

-- BRIN Indexes for Time-Series Data
CREATE INDEX IF NOT EXISTS brin_env_wq_time  ON enviro.water_quality USING BRIN(record_time);
CREATE INDEX IF NOT EXISTS brin_env_tide_time ON enviro.tide_reading USING BRIN(record_time);
CREATE INDEX IF NOT EXISTS brin_env_buoy_time ON enviro.buoy_reading USING BRIN(record_time);
CREATE INDEX IF NOT EXISTS brin_voyage_time   ON voyage.voyage USING BRIN(record_time);
CREATE INDEX IF NOT EXISTS brin_voyage_hist_time ON voyage.voyage_hist USING BRIN(record_time);
CREATE INDEX IF NOT EXISTS brin_form_meas_time ON form.measurement USING BRIN(created_at);

-- ============================================================
-- END OF SCHEMA
-- ============================================================