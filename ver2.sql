-- ============================================================
-- EXTENSIONS
-- ============================================================
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS btree_gist;

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
-- SCHEMA: param
-- ============================================================
CREATE SCHEMA IF NOT EXISTS param;

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
    CONSTRAINT chk_diff_uom       CHECK  (uom_from <> uom_to)
);

CREATE TABLE param.status (
    status_code     VARCHAR(30)     PRIMARY KEY,
    status_group    VARCHAR(50)     NOT NULL,
    description     TEXT,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_status_group ON param.status(status_group);

CREATE TABLE param.threshold (
    threshold_code  VARCHAR(30)     PRIMARY KEY,
    parameter_name  VARCHAR(100)    NOT NULL,
    parameter_value NUMERIC(18,6)   NOT NULL,
    uom_code        VARCHAR(20)     NOT NULL
                        REFERENCES param.unit_of_measure(uom_code) ON DELETE RESTRICT,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),

    CONSTRAINT uq_threshold_param UNIQUE (parameter_name, threshold_code)
);

-- ============================================================
-- SCHEMA: site
-- ============================================================
CREATE SCHEMA IF NOT EXISTS site;

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
    lat             NUMERIC(10,7),
    long            NUMERIC(11,7),
    geom            GEOMETRY(Point, 4326),
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_site_info_geom ON site.info USING GIST(geom);
CREATE INDEX IF NOT EXISTS idx_site_info_type ON site.info(type_code);

-- Auto-generate geom from lat/long
CREATE OR REPLACE FUNCTION site.fn_set_geom()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.lat IS NOT NULL AND NEW.long IS NOT NULL THEN
        NEW.geom := ST_SetSRID(ST_MakePoint(NEW.long, NEW.lat), 4326);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_site_info_geom
    BEFORE INSERT OR UPDATE OF lat, long ON site.info
    FOR EACH ROW EXECUTE FUNCTION site.fn_set_geom();

-- ============================================================
-- SCHEMA: "user"
-- ============================================================
CREATE SCHEMA IF NOT EXISTS "user";

CREATE TABLE "user".info (
    user_code       VARCHAR(30)     PRIMARY KEY,
    name            VARCHAR(150)    NOT NULL,
    role            VARCHAR(50)     NOT NULL,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE "user".detail (
    id              BIGSERIAL       PRIMARY KEY,
    user_code       VARCHAR(30)     NOT NULL
                        REFERENCES "user".info(user_code) ON DELETE CASCADE,
    contact_type    VARCHAR(30)     NOT NULL,
    contact_value   VARCHAR(200)    NOT NULL,
    is_primary      BOOLEAN         NOT NULL DEFAULT FALSE,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),

    CONSTRAINT uq_user_contact UNIQUE (user_code, contact_type, contact_value)
);
CREATE INDEX IF NOT EXISTS idx_user_detail_user ON "user".detail(user_code);

-- HANYA BOLEH 1 PRIMARY CONTACT PER USER
CREATE UNIQUE INDEX IF NOT EXISTS uq_user_one_primary
    ON "user".detail(user_code)
    WHERE is_primary = TRUE AND is_active = TRUE;

-- ============================================================
-- SCHEMA: partner
-- ============================================================
CREATE SCHEMA IF NOT EXISTS partner;

CREATE TABLE partner.type (
    type_code       VARCHAR(20)     PRIMARY KEY,
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
    site_code       VARCHAR(30)
                        REFERENCES site.info(site_code) ON DELETE SET NULL,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

-- ============================================================
-- SCHEMA: buyer
-- ============================================================
CREATE SCHEMA IF NOT EXISTS buyer;

CREATE TABLE buyer.info (
    buyer_code      VARCHAR(30)     PRIMARY KEY,
    name            VARCHAR(150)    NOT NULL,
    site_code       VARCHAR(30)
                        REFERENCES site.info(site_code) ON DELETE SET NULL,
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
    ref_doc         VARCHAR(100),
    description     TEXT,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_buyer_ledger_buyer
    ON buyer.ledger_hist(buyer_code, transaction_date DESC);

CREATE OR REPLACE VIEW buyer.v_info_with_ledger AS
SELECT
    bi.*,
    COALESCE(agg.balance, 0) AS amount_ledger
FROM buyer.info bi
LEFT JOIN (
    SELECT
        buyer_code,
        SUM(CASE
            WHEN transaction_type = 'CREDIT' THEN  amount
            WHEN transaction_type = 'DEBIT'  THEN -amount
        END) AS balance
    FROM buyer.ledger_hist
    GROUP BY buyer_code
) agg ON agg.buyer_code = bi.buyer_code;

-- ============================================================
-- SCHEMA: fleet
-- ============================================================
CREATE SCHEMA IF NOT EXISTS fleet;

CREATE TABLE fleet.type (
    type_code       VARCHAR(20)     PRIMARY KEY,
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
    call_sign       VARCHAR(20),
    flag_country_id INT
                        REFERENCES param.country(country_id) ON DELETE SET NULL,
    grt             NUMERIC(12,2),
    dwt             NUMERIC(12,2),
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE fleet.assignment_leg (
    id              BIGSERIAL       PRIMARY KEY,
    fleet_code      VARCHAR(30)     NOT NULL
                        REFERENCES fleet.info(fleet_code) ON DELETE RESTRICT,
    site_code       VARCHAR(30)     NOT NULL
                        REFERENCES site.info(site_code) ON DELETE RESTRICT,
    est_start_date  DATE,
    est_end_date    DATE,
    act_start_date  DATE,
    act_end_date    DATE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),

    CHECK (est_end_date >= est_start_date),
    CHECK (act_end_date >= act_start_date)
);
CREATE INDEX IF NOT EXISTS idx_fleet_assign_fleet
    ON fleet.assignment_leg(fleet_code);

-- OTOMATIS MENCEGAH JADWAL FLEET YANG OVERLAP
ALTER TABLE fleet.assignment_leg
ADD CONSTRAINT chk_no_overlapping_assignment
EXCLUDE USING GIST (
    fleet_code WITH =,
    daterange(est_end_date, COALESCE(act_end_date, CURRENT_DATE + INTERVAL '100 years'), '[]') WITH &&
);

CREATE TABLE fleet.maintenance (
    id              BIGSERIAL       PRIMARY KEY,
    fleet_code      VARCHAR(30)     NOT NULL
                        REFERENCES fleet.info(fleet_code) ON DELETE CASCADE,
    description     TEXT,
    start_date      DATE            NOT NULL,
    end_date        DATE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),

    CHECK (end_date >= start_date)
);
CREATE INDEX IF NOT EXISTS idx_fleet_mtc_fleet
    ON fleet.maintenance(fleet_code, start_date DESC);

CREATE OR REPLACE VIEW fleet.v_info_with_maintenance AS
SELECT
    fi.*,
    lm.last_mtc_start,
    lm.last_mtc_end
FROM fleet.info fi
LEFT JOIN LATERAL (
    SELECT fm.start_date AS last_mtc_start,
           fm.end_date   AS last_mtc_end
    FROM   fleet.maintenance fm
    WHERE  fm.fleet_code = fi.fleet_code
    ORDER  BY fm.start_date DESC
    LIMIT  1
) lm ON TRUE;

-- ============================================================
-- SCHEMA: form
-- ============================================================
CREATE SCHEMA IF NOT EXISTS form;

CREATE TABLE form.water_sampling (
    form_no         VARCHAR(30)     PRIMARY KEY,
    sampling_date   DATE            NOT NULL,
    total_sample    INT             NOT NULL DEFAULT 0
                        CHECK (total_sample >= 0),
    recorder_by     VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE SET NULL,
    received_by     VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE SET NULL,
    status          VARCHAR(30)
                        REFERENCES param.status(status_code) ON DELETE SET NULL,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE form.sample (
    sample_id       BIGSERIAL       PRIMARY KEY,
    form_no         VARCHAR(30)     NOT NULL
                        REFERENCES form.water_sampling(form_no) ON DELETE CASCADE,
    sample_no       INT             NOT NULL,
    type_sample     VARCHAR(50)     NOT NULL,
    description     TEXT,
    status          VARCHAR(30)
                        REFERENCES param.status(status_code) ON DELETE SET NULL,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),

    CONSTRAINT uq_sample_per_form UNIQUE (form_no, sample_no)
);

CREATE TABLE form.measurement (
    id              BIGSERIAL       PRIMARY KEY,
    sample_id       BIGINT          NOT NULL
                        REFERENCES form.sample(sample_id) ON DELETE CASCADE,
    parameter_name  VARCHAR(100)    NOT NULL,
    parameter_value NUMERIC(18,6),
    uom_code        VARCHAR(20)
                        REFERENCES param.unit_of_measure(uom_code) ON DELETE SET NULL,
    method          VARCHAR(100),
    status          VARCHAR(30)
                        REFERENCES param.status(status_code) ON DELETE SET NULL,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_measurement_sample
    ON form.measurement(sample_id);

-- ============================================================
-- SCHEMA: laboratory
-- ============================================================
CREATE SCHEMA IF NOT EXISTS laboratory;

CREATE TABLE laboratory.info (
    lab_code        VARCHAR(30)     PRIMARY KEY,
    site_code       VARCHAR(30)
                        REFERENCES site.info(site_code) ON DELETE SET NULL,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE laboratory.result (
    id              BIGSERIAL       PRIMARY KEY,
    doc_no          VARCHAR(50)     NOT NULL,
    lab_code        VARCHAR(30)
                        REFERENCES laboratory.info(lab_code) ON DELETE SET NULL,
    sample_id       BIGINT
                        REFERENCES form.sample(sample_id) ON DELETE SET NULL,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

-- ============================================================
-- SCHEMA: survey
-- ============================================================
CREATE SCHEMA IF NOT EXISTS survey;

CREATE TABLE survey.water_sampling (
    form_no         VARCHAR(30)     PRIMARY KEY,
    sampling_date   DATE            NOT NULL,
    total_sample    INT             NOT NULL DEFAULT 0,
    recorder_by     VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE SET NULL,
    received_by     VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE SET NULL,
    status          VARCHAR(30)
                        REFERENCES param.status(status_code) ON DELETE SET NULL,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE survey.measurement (
    id              BIGSERIAL       PRIMARY KEY,
    form_no         VARCHAR(30)     NOT NULL
                        REFERENCES survey.water_sampling(form_no) ON DELETE CASCADE,
    parameter_name  VARCHAR(100)    NOT NULL,
    parameter_value NUMERIC(18,6),
    uom_code        VARCHAR(20)
                        REFERENCES param.unit_of_measure(uom_code) ON DELETE SET NULL,
    method          VARCHAR(100),
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

-- ============================================================
-- SCHEMA: enviro
-- ============================================================
CREATE SCHEMA IF NOT EXISTS enviro;

CREATE TABLE enviro.station (
    station_code    VARCHAR(30)     PRIMARY KEY,
    site_code       VARCHAR(30)
                        REFERENCES site.info(site_code) ON DELETE SET NULL,
    station_type    VARCHAR(50)     NOT NULL,
    status          VARCHAR(30)
                        REFERENCES param.status(status_code) ON DELETE SET NULL,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE enviro.water_quality (
    id              BIGSERIAL       PRIMARY KEY,
    station_code    VARCHAR(30)     NOT NULL
                        REFERENCES enviro.station(station_code) ON DELETE CASCADE,
    record_time     TIMESTAMPTZ     NOT NULL,
    depth           NUMERIC(10,2),
    brightness      NUMERIC(10,2),
    temperature     NUMERIC(8,2),
    turbidity       NUMERIC(10,2),
    dissolved_oxygen NUMERIC(8,2),
    ph_level        NUMERIC(5,2),
    salt            NUMERIC(8,2),
    condition       VARCHAR(50),
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),

    CONSTRAINT uq_wq_station_time UNIQUE (station_code, record_time)
);
CREATE INDEX IF NOT EXISTS idx_wq_station_time
    ON enviro.water_quality(station_code, record_time DESC);

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
CREATE INDEX IF NOT EXISTS idx_tide_reading_ts
    ON enviro.tide_reading(station_code, record_time DESC);

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
CREATE INDEX IF NOT EXISTS idx_buoy_reading_ts
    ON enviro.buoy_reading(station_code, record_time DESC);

CREATE TABLE enviro.maintenance (
    id              BIGSERIAL       PRIMARY KEY,
    station_code    VARCHAR(30)     NOT NULL
                        REFERENCES enviro.station(station_code) ON DELETE CASCADE,
    description     TEXT,
    start_date      DATE            NOT NULL,
    end_date        DATE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),

    CHECK (end_date >= start_date)
);
CREATE INDEX IF NOT EXISTS idx_enviro_mtc_station
    ON enviro.maintenance(station_code, start_date DESC);

CREATE OR REPLACE VIEW enviro.v_station_with_maintenance AS
SELECT
    es.*,
    lm.last_mtc_start,
    lm.last_mtc_end
FROM enviro.station es
LEFT JOIN LATERAL (
    SELECT em.start_date AS last_mtc_start,
           em.end_date   AS last_mtc_end
    FROM   enviro.maintenance em
    WHERE  em.station_code = es.station_code
    ORDER  BY em.start_date DESC
    LIMIT  1
) lm ON TRUE;

-- ============================================================
-- SCHEMA: commercial
-- ============================================================
CREATE SCHEMA IF NOT EXISTS commercial;

CREATE TABLE commercial.purchase_order (
    po_num              VARCHAR(30)     PRIMARY KEY,
    buyer_code          VARCHAR(30)     NOT NULL
                            REFERENCES buyer.info(buyer_code) ON DELETE RESTRICT,
    contact_number      VARCHAR(50),
    po_date             DATE            NOT NULL,
    uom_code            VARCHAR(20)     NOT NULL
                            REFERENCES param.unit_of_measure(uom_code) ON DELETE RESTRICT,
    total_volume        NUMERIC(18,4)   NOT NULL CHECK (total_volume >= 0),
    unit_price          NUMERIC(18,4)   NOT NULL CHECK (unit_price >= 0),
    currency_code       CHAR(3)         NOT NULL
                            REFERENCES param.currency(currency_code) ON DELETE RESTRICT,
    total_amount        NUMERIC(18,2)   NOT NULL CHECK (total_amount >= 0),
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
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT now(),

    CHECK (target_end_date  >= target_start_date),
    CHECK (actual_end_date  >= actual_start_date)
);
CREATE INDEX IF NOT EXISTS idx_po_buyer   ON commercial.purchase_order(buyer_code);
CREATE INDEX IF NOT EXISTS idx_po_status  ON commercial.purchase_order(status);

CREATE TABLE commercial.delivery_order (
    do_num              VARCHAR(30)     PRIMARY KEY,
    po_num              VARCHAR(30)     NOT NULL
                            REFERENCES commercial.purchase_order(po_num) ON DELETE RESTRICT,
    discharge_site      VARCHAR(30)
                            REFERENCES site.info(site_code) ON DELETE SET NULL,
    target_volume       NUMERIC(18,4)   CHECK (target_volume >= 0),
    target_start_date   DATE,
    target_end_date     DATE,
    status              VARCHAR(30)
                            REFERENCES param.status(status_code) ON DELETE SET NULL,
    actual_start_date   DATE,
    actual_end_date     DATE,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT now(),

    CHECK (target_end_date >= target_start_date),
    CHECK (actual_end_date >= actual_start_date)
);
CREATE INDEX IF NOT EXISTS idx_do_po     ON commercial.delivery_order(po_num);
CREATE INDEX IF NOT EXISTS idx_do_status ON commercial.delivery_order(status);

-- ============================================================
-- SCHEMA: operational
-- ============================================================
CREATE SCHEMA IF NOT EXISTS operational;

CREATE TABLE operational.work_area (
    area_code       VARCHAR(30)     PRIMARY KEY,
    name            VARCHAR(150)    NOT NULL,
    lat             NUMERIC(10,7),
    long            NUMERIC(11,7),
    geom            GEOMETRY(Polygon, 4326),
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_work_area_geom
    ON operational.work_area USING GIST(geom);

CREATE OR REPLACE FUNCTION operational.fn_set_geom()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.lat IS NOT NULL AND NEW.long IS NOT NULL THEN
        NEW.geom := ST_SetSRID(ST_MakePoint(NEW.long, NEW.lat), 4326);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_work_area_geom
    BEFORE INSERT OR UPDATE OF lat, long ON operational.work_area
    FOR EACH ROW EXECUTE FUNCTION operational.fn_set_geom();

CREATE TABLE operational.shipment_instruction (
    si_num              VARCHAR(30)     PRIMARY KEY,
    do_num              VARCHAR(30)     NOT NULL
                            REFERENCES commercial.delivery_order(do_num) ON DELETE RESTRICT,
    fleet_main_code     VARCHAR(30)     NOT NULL
                            REFERENCES fleet.info(fleet_code) ON DELETE RESTRICT,
    fleet_assist_code   VARCHAR(30)
                            REFERENCES fleet.info(fleet_code) ON DELETE SET NULL,
    working_site        VARCHAR(30)
                            REFERENCES operational.work_area(area_code) ON DELETE SET NULL,
    discharge_site      VARCHAR(30)
                            REFERENCES site.info(site_code) ON DELETE SET NULL,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT now(),

    CHECK (fleet_assist_code IS NULL
           OR fleet_assist_code <> fleet_main_code)
);

CREATE TABLE operational.work_activity (
    id              BIGSERIAL       PRIMARY KEY,
    si_num          VARCHAR(30)     NOT NULL
                        REFERENCES operational.shipment_instruction(si_num) ON DELETE CASCADE,
    fleet_code      VARCHAR(30)     NOT NULL
                        REFERENCES fleet.info(fleet_code) ON DELETE RESTRICT,
    area_code       VARCHAR(30)
                        REFERENCES operational.work_area(area_code) ON DELETE SET NULL,
    activity_type   VARCHAR(50)     NOT NULL,
    planned_start   TIMESTAMPTZ,
    planned_end     TIMESTAMPTZ,
    status          VARCHAR(30)
                        REFERENCES param.status(status_code) ON DELETE SET NULL,
    actual_start    TIMESTAMPTZ,
    actual_end      TIMESTAMPTZ,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),

    CHECK (planned_end >= planned_start),
    CHECK (actual_end  >= actual_start)
);
CREATE INDEX IF NOT EXISTS idx_work_activity_si
    ON operational.work_activity(si_num);
CREATE INDEX IF NOT EXISTS idx_work_activity_fleet
    ON operational.work_activity(fleet_code);

-- ============================================================
-- SCHEMA: voyage
-- ============================================================
CREATE SCHEMA IF NOT EXISTS voyage;

CREATE TABLE voyage.voyage (
    id              BIGSERIAL       PRIMARY KEY,
    fleet_code      VARCHAR(30)     NOT NULL
                        REFERENCES fleet.info(fleet_code) ON DELETE RESTRICT,
    do_num          VARCHAR(30)
                        REFERENCES commercial.delivery_order(do_num) ON DELETE SET NULL,
    lat             NUMERIC(10,7),
    long            NUMERIC(11,7),
    geom            GEOMETRY(Point, 4326),
    record_time     TIMESTAMPTZ     NOT NULL,
    status          VARCHAR(30)
                        REFERENCES param.status(status_code) ON DELETE SET NULL,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_voyage_fleet_time
    ON voyage.voyage(fleet_code, record_time DESC);
CREATE INDEX IF NOT EXISTS idx_voyage_geom
    ON voyage.voyage USING GIST(geom);

CREATE TABLE voyage.voyage_hist (
    id              BIGSERIAL       PRIMARY KEY,
    fleet_code      VARCHAR(30)     NOT NULL
                        REFERENCES fleet.info(fleet_code) ON DELETE RESTRICT,
    lat             NUMERIC(10,7),
    long            NUMERIC(11,7),
    geom            GEOMETRY(Point, 4326),
    record_time     TIMESTAMPTZ     NOT NULL,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),

    CONSTRAINT uq_voyage_hist_fleet_time
        UNIQUE (fleet_code, record_time)
);
CREATE INDEX IF NOT EXISTS idx_voyage_hist_fleet_time
    ON voyage.voyage_hist(fleet_code, record_time DESC);
CREATE INDEX IF NOT EXISTS idx_voyage_hist_geom
    ON voyage.voyage_hist USING GIST(geom);

-- ============================================================
-- SCHEMA: reporting (Materialized Views)
-- ============================================================
CREATE SCHEMA IF NOT EXISTS reporting;

-- TIDE: DAILY
CREATE MATERIALIZED VIEW reporting.tide_read_daily AS
SELECT
    station_code,
    DATE(record_time)                   AS read_date,
    AVG(salinity)                       AS avg_salinity,
    AVG(turbidity)                      AS avg_turbidity,
    AVG(current_speed)                  AS avg_current_speed,
    AVG(dissolved_oxygen)               AS avg_dissolved_oxygen,
    AVG(water_density)                  AS avg_water_density,
    AVG(tide_level)                     AS avg_tide_level,
    MIN(tide_level)                     AS min_tide_level,
    MAX(tide_level)                     AS max_tide_level,
    COUNT(*)                            AS reading_count
FROM enviro.tide_reading
GROUP BY station_code, DATE(record_time)
WITH NO DATA;

CREATE UNIQUE INDEX IF NOT EXISTS idx_tide_daily_pk
    ON reporting.tide_read_daily(station_code, read_date);

-- TIDE: WEEKLY
CREATE MATERIALIZED VIEW reporting.tide_read_weekly AS
SELECT
    station_code,
    DATE_TRUNC('week', record_time)::DATE   AS week_start,
    EXTRACT(ISOYEAR FROM record_time)::INT  AS iso_year,
    EXTRACT(WEEK    FROM record_time)::INT  AS iso_week,
    AVG(salinity)                           AS avg_salinity,
    AVG(turbidity)                          AS avg_turbidity,
    AVG(current_speed)                      AS avg_current_speed,
    AVG(dissolved_oxygen)                   AS avg_dissolved_oxygen,
    AVG(water_density)                      AS avg_water_density,
    AVG(tide_level)                         AS avg_tide_level,
    MIN(tide_level)                         AS min_tide_level,
    MAX(tide_level)                         AS max_tide_level,
    COUNT(*)                                AS reading_count
FROM enviro.tide_reading
GROUP BY station_code,
         DATE_TRUNC('week', record_time)::DATE,
         EXTRACT(ISOYEAR FROM record_time),
         EXTRACT(WEEK    FROM record_time)
WITH NO DATA;

CREATE UNIQUE INDEX IF NOT EXISTS idx_tide_weekly_pk
    ON reporting.tide_read_weekly(station_code, week_start);

-- TIDE: YEARLY
CREATE MATERIALIZED VIEW reporting.tide_read_yearly AS
SELECT
    station_code,
    EXTRACT(YEAR FROM record_time)::INT     AS read_year,
    AVG(salinity)                           AS avg_salinity,
    AVG(turbidity)                          AS avg_turbidity,
    AVG(current_speed)                      AS avg_current_speed,
    AVG(dissolved_oxygen)                   AS avg_dissolved_oxygen,
    AVG(water_density)                      AS avg_water_density,
    AVG(tide_level)                         AS avg_tide_level,
    MIN(tide_level)                         AS min_tide_level,
    MAX(tide_level)                         AS max_tide_level,
    COUNT(*)                                AS reading_count
FROM enviro.tide_reading
GROUP BY station_code, EXTRACT(YEAR FROM record_time)
WITH NO DATA;

CREATE UNIQUE INDEX IF NOT EXISTS idx_tide_yearly_pk
    ON reporting.tide_read_yearly(station_code, read_year);

-- BUOY: DAILY
CREATE MATERIALIZED VIEW reporting.buoy_read_daily AS
SELECT
    station_code,
    DATE(record_time)                   AS read_date,
    AVG(salinity)                       AS avg_salinity,
    AVG(turbidity)                      AS avg_turbidity,
    AVG(current_speed)                  AS avg_current_speed,
    AVG(dissolved_oxygen)               AS avg_dissolved_oxygen,
    AVG(water_density)                  AS avg_water_density,
    AVG(tide_level)                     AS avg_tide_level,
    MIN(tide_level)                     AS min_tide_level,
    MAX(tide_level)                     AS max_tide_level,
    COUNT(*)                            AS reading_count
FROM enviro.buoy_reading
GROUP BY station_code, DATE(record_time)
WITH NO DATA;

CREATE UNIQUE INDEX IF NOT EXISTS idx_buoy_daily_pk
    ON reporting.buoy_read_daily(station_code, read_date);

-- BUOY: WEEKLY
CREATE MATERIALIZED VIEW reporting.buoy_read_weekly AS
SELECT
    station_code,
    DATE_TRUNC('week', record_time)::DATE   AS week_start,
    EXTRACT(ISOYEAR FROM record_time)::INT  AS iso_year,
    EXTRACT(WEEK    FROM record_time)::INT  AS iso_week,
    AVG(salinity)                           AS avg_salinity,
    AVG(turbidity)                          AS avg_turbidity,
    AVG(current_speed)                      AS avg_current_speed,
    AVG(dissolved_oxygen)                   AS avg_dissolved_oxygen,
    AVG(water_density)                      AS avg_water_density,
    AVG(tide_level)                         AS avg_tide_level,
    MIN(tide_level)                         AS min_tide_level,
    MAX(tide_level)                         AS max_tide_level,
    COUNT(*)                                AS reading_count
FROM enviro.buoy_reading
GROUP BY station_code,
         DATE_TRUNC('week', record_time)::DATE,
         EXTRACT(ISOYEAR FROM record_time),
         EXTRACT(WEEK    FROM record_time)
WITH NO DATA;

CREATE UNIQUE INDEX IF NOT EXISTS idx_buoy_weekly_pk
    ON reporting.buoy_read_weekly(station_code, week_start);

-- BUOY: YEARLY
CREATE MATERIALIZED VIEW reporting.buoy_read_yearly AS
SELECT
    station_code,
    EXTRACT(YEAR FROM record_time)::INT     AS read_year,
    AVG(salinity)                           AS avg_salinity,
    AVG(turbidity)                          AS avg_turbidity,
    AVG(current_speed)                      AS avg_current_speed,
    AVG(dissolved_oxygen)                   AS avg_dissolved_oxygen,
    AVG(water_density)                      AS avg_water_density,
    AVG(tide_level)                         AS avg_tide_level,
    MIN(tide_level)                         AS min_tide_level,
    MAX(tide_level)                         AS max_tide_level,
    COUNT(*)                                AS reading_count
FROM enviro.buoy_reading
GROUP BY station_code, EXTRACT(YEAR FROM record_time)
WITH NO DATA;

CREATE UNIQUE INDEX IF NOT EXISTS idx_buoy_yearly_pk
    ON reporting.buoy_read_yearly(station_code, read_year);

-- ============================================================
-- GLOBAL AUTO updated_at TRIGGER
-- VERSI IDEMPOTENT: bisa dijalankan berulang kali tanpa error
-- ============================================================

DO $$
DECLARE
    r RECORD;
    trigger_exists BOOLEAN;
BEGIN
    FOR r IN
        SELECT table_schema, table_name
        FROM information_schema.columns
        WHERE column_name = 'updated_at'
          AND table_schema NOT IN ('pg_catalog','information_schema','reporting')
          AND table_schema NOT LIKE 'pg_%'
    LOOP
        -- Cek apakah trigger sudah ada
        SELECT EXISTS (
            SELECT 1 
            FROM information_schema.triggers 
            WHERE trigger_name = 'trg_updated_at'
              AND event_object_schema = r.table_schema
              AND event_object_table = r.table_name
        ) INTO trigger_exists;
        
        -- Hanya buat trigger jika belum ada
        IF NOT trigger_exists THEN
            EXECUTE format(
                'CREATE TRIGGER trg_updated_at
                 BEFORE UPDATE ON %I.%I
                 FOR EACH ROW
                 EXECUTE FUNCTION public.fn_set_updated_at()',
                r.table_schema, r.table_name
            );
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