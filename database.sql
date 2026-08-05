-- ============================================================
-- TASK
-- ============================================================
/*

Penambahan Schema :

1. Financial
2. Reporting
3. HSE


Check Ulang
1. Apakah Schema Lab diperlukan ?

*/

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

CREATE TABLE param.threshold (
    threshold_code  VARCHAR(30)     PRIMARY KEY,
    parameter_name  VARCHAR(100)    NOT NULL,
    parameter_value NUMERIC(18,6)   NOT NULL,
    uom_code        VARCHAR(20)     NOT NULL
                        REFERENCES param.unit_of_measure(uom_code) ON DELETE RESTRICT,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
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
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION buyer.fn_prevent_ledger_update()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Ledger entries are immutable. Create a reversal entry instead.';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_prevent_ledger_update
BEFORE UPDATE OR DELETE ON buyer.ledger_hist
FOR EACH ROW EXECUTE FUNCTION buyer.fn_prevent_ledger_update();

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
    mmsi_number     VARCHAR(20),
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

-- OTOMATIS MENCEGAH JADWAL FLEET YANG OVERLAP
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
    total_sample    INT             NOT NULL DEFAULT 0 CHECK (total_sample >= 0),
    recorder_by     VARCHAR(30)     REFERENCES "user".info(user_code) ON DELETE SET NULL,
    received_by     VARCHAR(30)     REFERENCES "user".info(user_code) ON DELETE SET NULL,
    status          VARCHAR(30)     REFERENCES param.status(status_code) ON DELETE SET NULL,
    location_desc   TEXT,           
    weather         VARCHAR(50),    
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE form.sample (
    sample_id       BIGSERIAL       PRIMARY KEY,
    form_no         VARCHAR(30)     NOT NULL,
    sample_no       INT             NOT NULL,
    type_sample     VARCHAR(50)     NOT NULL,
    description     TEXT,
    status          VARCHAR(30)     REFERENCES param.status(status_code) ON DELETE SET NULL,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    
    CONSTRAINT uq_sample_per_form UNIQUE (form_no, sample_no)
);

CREATE TABLE form.measurement (
    id              BIGSERIAL       PRIMARY KEY,
    form_no         VARCHAR(30)     NOT NULL, 
    sample_id       BIGINT          NOT NULL, 
    parameter_name  VARCHAR(100)    NOT NULL,
    parameter_value NUMERIC(18,6),
    uom_code        VARCHAR(20)     REFERENCES param.unit_of_measure(uom_code) ON DELETE SET NULL,
    method          VARCHAR(100),
    status          VARCHAR(30)     REFERENCES param.status(status_code) ON DELETE SET NULL,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),

    CONSTRAINT uq_form_measurement UNIQUE (form_no, sample_id, parameter_name)
);


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
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT now(),

    CHECK (target_end_date  >= target_start_date),
    CHECK (actual_end_date  >= actual_start_date)
);

CREATE TABLE commercial.delivery_order (
    do_num              VARCHAR(30)     PRIMARY KEY,
    po_num              VARCHAR(30)     NOT NULL
                            REFERENCES commercial.purchase_order(po_num) ON DELETE RESTRICT,
    discharge_site      VARCHAR(30)
                            REFERENCES site.info(site_code) ON DELETE SET NULL,
    uom_code            VARCHAR(20)     NOT NULL
                            REFERENCES param.unit_of_measure(uom_code) ON DELETE RESTRICT,
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


-- ============================================================
-- SCHEMA: operational
-- ============================================================
CREATE SCHEMA IF NOT EXISTS operational;

CREATE TABLE operational.work_area (
    area_code       VARCHAR(30)     PRIMARY KEY,
    name            VARCHAR(150)    NOT NULL,
    geom            GEOMETRY(Polygon, 4326),
    lat             NUMERIC(10,7) GENERATED ALWAYS AS (
                        CASE WHEN geom IS NOT NULL THEN ST_Y(ST_Centroid(geom)) ELSE NULL END
                    ) STORED,
    long            NUMERIC(11,7) GENERATED ALWAYS AS (
                        CASE WHEN geom IS NOT NULL THEN ST_X(ST_Centroid(geom)) ELSE NULL END
                    ) STORED,
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
                            REFERENCES operational.work_area(area_code) ON DELETE SET NULL,
    discharge_site      VARCHAR(30)
                            REFERENCES site.info(site_code) ON DELETE SET NULL,
    status              VARCHAR(30)     REFERENCES param.status(status_code) ON DELETE SET NULL,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT now(),

    CHECK (fleet_assist_code IS NULL
           OR fleet_assist_code <> fleet_main_code)
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
    planned_start   TIMESTAMPTZ,
    planned_end     TIMESTAMPTZ,
    status          VARCHAR(30)
                        REFERENCES param.status(status_code) ON DELETE SET NULL,
    actual_start    TIMESTAMPTZ,
    actual_end      TIMESTAMPTZ,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),

    CHECK (planned_end >= planned_start),
    CHECK (actual_end  >= actual_start),

    CONSTRAINT uq_activity_si UNIQUE (si_num, activity_num)
);

CREATE TABLE operational.dredging_records (
    id               BIGSERIAL      PRIMARY KEY,
    si_num           VARCHAR(30)    NOT NULL
                            REFERENCES operational.shipment_instruction(si_num) ON DELETE RESTRICT,
    activity_num     BIGINT         NOT NULL
                            REFERENCES operational.work_activity(activity_num) ON DELETE RESTRICT,
    record_date      DATE           NOT NULL,
    dredging_volume  NUMERIC(18,4)  NOT NULL CHECK (dredging_volume >= 0),
    uom_code         VARCHAR(20)    NOT NULL DEFAULT 'M3'
                            REFERENCES param.unit_of_measure(uom_code) ON DELETE RESTRICT,
    created_by       VARCHAR(30)
                            REFERENCES "user".info(user_code) ON DELETE SET NULL,
    notes            TEXT,
    created_at       TIMESTAMPTZ    NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ    NOT NULL DEFAULT now(),

    CONSTRAINT fk_dredging_activity
        FOREIGN KEY (si_num, activity_num)
        REFERENCES operational.work_activity(si_num, activity_num)
        ON DELETE CASCADE,

    CONSTRAINT uq_dredging_daily UNIQUE (activity_num, record_date)
);

CREATE OR REPLACE FUNCTION operational.fn_validate_dredging_volume()
RETURNS TRIGGER AS $$
DECLARE
    v_do_num      VARCHAR(30);
    v_target      NUMERIC(18,4);
    v_target_uom  VARCHAR(20);
    v_total       NUMERIC(18,4);
BEGIN
    SELECT
        si.do_num,
        d_o.target_volume,
        po.uom_code
    INTO
        v_do_num,
        v_target,
        v_target_uom
    FROM operational.shipment_instruction si
    JOIN commercial.delivery_order d_o
      ON d_o.do_num = si.do_num
    JOIN commercial.purchase_order po
      ON po.po_num = d_o.po_num
    WHERE si.si_num = NEW.si_num;

    IF v_do_num IS NULL THEN
        RAISE EXCEPTION 'Shipment instruction % not found', NEW.si_num;
    END IF;

    IF v_target IS NULL THEN
        RETURN NEW;
    END IF;

    IF NEW.uom_code <> v_target_uom THEN
        RAISE EXCEPTION
            'Dredging UOM (%) must match PO UOM (%) for DO %',
            NEW.uom_code, v_target_uom, v_do_num;
    END IF;

    SELECT COALESCE(SUM(dr.dredging_volume), 0)
    INTO v_total
    FROM operational.dredging_records dr
    JOIN operational.shipment_instruction si2
      ON si2.si_num = dr.si_num
    WHERE si2.do_num = v_do_num
      AND dr.id IS DISTINCT FROM NEW.id;

    IF (v_total + NEW.dredging_volume) > v_target THEN
        RAISE EXCEPTION
            'Total dredging volume (%) exceeds DO target volume (%) for DO %',
            v_total + NEW.dredging_volume,
            v_target,
            v_do_num;
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
    geom            GEOMETRY(Point, 4326) GENERATED ALWAYS AS (
                        CASE
                            WHEN lat IS NOT NULL AND long IS NOT NULL
                            THEN ST_SetSRID(ST_MakePoint(long, lat), 4326)
                            ELSE NULL
                        END
                    ) STORED,
    record_time     TIMESTAMPTZ     NOT NULL,
    status          VARCHAR(30)
                        REFERENCES param.status(status_code) ON DELETE SET NULL,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE voyage.voyage_hist (
    id              BIGSERIAL       PRIMARY KEY,
    fleet_code      VARCHAR(30)     NOT NULL
                        REFERENCES fleet.info(fleet_code) ON DELETE RESTRICT,
    lat             NUMERIC(10,7),
    long            NUMERIC(11,7),
    geom            GEOMETRY(Point, 4326) GENERATED ALWAYS AS (
                        CASE
                            WHEN lat IS NOT NULL AND long IS NOT NULL
                            THEN ST_SetSRID(ST_MakePoint(long, lat), 4326)
                            ELSE NULL
                        END
                    ) STORED,
    record_time     TIMESTAMPTZ     NOT NULL,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),

    CONSTRAINT uq_voyage_hist_fleet_time
        UNIQUE (fleet_code, record_time)
);

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
               c.relname AS table_name
        FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        JOIN pg_attribute a ON a.attrelid = c.oid
        WHERE a.attname = 'updated_at'
          AND a.attnum > 0
          AND NOT a.attisdropped
          AND c.relkind = 'r'                         
          AND n.nspname NOT IN ('pg_catalog','information_schema','reporting')
          AND n.nspname NOT LIKE 'pg_%'
    LOOP
        SELECT EXISTS (
            SELECT 1
            FROM information_schema.triggers
            WHERE trigger_name = 'trg_updated_at'
              AND event_object_schema = r.table_schema
              AND event_object_table  = r.table_name
        ) INTO trigger_exists;

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

-- ============================================================
-- INDEXING
-- ============================================================

-- 1. PARAM INDEXES
CREATE INDEX IF NOT EXISTS idx_status_group
    ON param.status(status_group);

CREATE INDEX IF NOT EXISTS idx_unit_conversion_uom_to
    ON param.unit_conversion(uom_to);

CREATE INDEX IF NOT EXISTS idx_threshold_uom_code
    ON param.threshold(uom_code);

CREATE INDEX IF NOT EXISTS idx_threshold_parameter_name
    ON param.threshold(parameter_name);

-- 2. SITE INDEXES
CREATE INDEX IF NOT EXISTS idx_site_info_type
    ON site.info(type_code);

CREATE INDEX IF NOT EXISTS idx_site_info_geom
    ON site.info USING GIST(geom)
    WHERE geom IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_site_info_city
    ON site.info(city)
    WHERE city IS NOT NULL;

-- 3. USER INDEXES
CREATE UNIQUE INDEX IF NOT EXISTS uq_user_one_primary
    ON "user".detail(user_code)
    WHERE is_primary = TRUE
      AND is_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_user_detail_contact_type
    ON "user".detail(contact_type);

CREATE INDEX IF NOT EXISTS idx_user_info_role
    ON "user".info(role);

-- 4. PARTNER INDEXES
CREATE INDEX IF NOT EXISTS idx_partner_info_type
    ON partner.info(type_code);

CREATE INDEX IF NOT EXISTS idx_partner_info_site
    ON partner.info(site_code)
    WHERE site_code IS NOT NULL;

-- 5. BUYER INDEXES
CREATE INDEX IF NOT EXISTS idx_buyer_info_site
    ON buyer.info(site_code)
    WHERE site_code IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_buyer_site_site
    ON buyer.site(site_code);

CREATE INDEX IF NOT EXISTS idx_buyer_ledger_buyer_date_id
    ON buyer.ledger_hist(buyer_code, transaction_date DESC, id DESC);

CREATE INDEX IF NOT EXISTS idx_buyer_ledger_ref_doc
    ON buyer.ledger_hist(ref_doc)
    WHERE ref_doc IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_buyer_ledger_transaction_type
    ON buyer.ledger_hist(transaction_type);

CREATE UNIQUE INDEX IF NOT EXISTS uq_ledger_ref_doc
    ON buyer.ledger_hist (buyer_code, ref_doc)
    WHERE ref_doc IS NOT NULL;

-- 6. FLEET INDEXES
CREATE INDEX IF NOT EXISTS idx_fleet_info_partner
    ON fleet.info(partner_code);

CREATE INDEX IF NOT EXISTS idx_fleet_info_type
    ON fleet.info(type_code);

CREATE INDEX IF NOT EXISTS idx_fleet_info_flag_country
    ON fleet.info(flag_country_id)
    WHERE flag_country_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_fleet_imo_number
    ON fleet.info(imo_number)
    WHERE imo_number IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_fleet_mmsi_number
    ON fleet.info(mmsi_number)
    WHERE mmsi_number IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_fleet_assignment_site
    ON fleet.assignment_leg(site_code);

CREATE INDEX IF NOT EXISTS idx_fleet_assignment_active
    ON fleet.assignment_leg(fleet_code, est_start_date, est_end_date)
    WHERE act_end_date IS NULL;

CREATE INDEX IF NOT EXISTS idx_fleet_assignment_all
    ON fleet.assignment_leg(fleet_code, est_start_date, est_end_date);

CREATE INDEX IF NOT EXISTS idx_fleet_mtc_fleet_start_id
    ON fleet.maintenance(fleet_code, start_date DESC, id DESC);


-- 7. FORM INDEXES
CREATE INDEX IF NOT EXISTS idx_form_sample_form_no
    ON form.sample(form_no);

CREATE INDEX IF NOT EXISTS idx_form_measurement_form_no
    ON form.measurement(form_no);

CREATE INDEX IF NOT EXISTS idx_form_measurement_sample_id
    ON form.measurement(sample_id);

-- 8. SURVEY INDEXES
CREATE INDEX IF NOT EXISTS idx_survey_water_sampling_sampling_date
    ON survey.water_sampling(sampling_date DESC);

CREATE INDEX IF NOT EXISTS idx_survey_water_sampling_recorder
    ON survey.water_sampling(recorder_by)
    WHERE recorder_by IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_survey_water_sampling_received
    ON survey.water_sampling(received_by)
    WHERE received_by IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_survey_water_sampling_status
    ON survey.water_sampling(status)
    WHERE status IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_survey_measurement_form
    ON survey.measurement(form_no);

CREATE INDEX IF NOT EXISTS idx_survey_measurement_uom
    ON survey.measurement(uom_code)
    WHERE uom_code IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_survey_measurement_parameter
    ON survey.measurement(parameter_name);

-- 9. ENVIRO INDEXES
CREATE INDEX IF NOT EXISTS idx_enviro_station_site
    ON enviro.station(site_code)
    WHERE site_code IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_enviro_station_status
    ON enviro.station(status)
    WHERE status IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_enviro_station_type
    ON enviro.station(station_type);

CREATE INDEX IF NOT EXISTS brin_water_quality_record_time
    ON enviro.water_quality USING BRIN(record_time);

CREATE INDEX IF NOT EXISTS brin_tide_reading_record_time
    ON enviro.tide_reading USING BRIN(record_time);

CREATE INDEX IF NOT EXISTS brin_buoy_reading_record_time
    ON enviro.buoy_reading USING BRIN(record_time);

CREATE INDEX IF NOT EXISTS idx_enviro_mtc_station_start_id
    ON enviro.maintenance(station_code, start_date DESC, id DESC);

-- 10. COMMERCIAL INDEXES
CREATE INDEX IF NOT EXISTS idx_po_buyer_date
    ON commercial.purchase_order(buyer_code, po_date DESC);

CREATE INDEX IF NOT EXISTS idx_po_status_date
    ON commercial.purchase_order(status, po_date DESC)
    WHERE status IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_po_uom
    ON commercial.purchase_order(uom_code);

CREATE INDEX IF NOT EXISTS idx_po_currency
    ON commercial.purchase_order(currency_code);

CREATE INDEX IF NOT EXISTS idx_po_created_by
    ON commercial.purchase_order(created_by)
    WHERE created_by IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_po_approved_by
    ON commercial.purchase_order(approved_by)
    WHERE approved_by IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_po_target_date
    ON commercial.purchase_order(target_start_date, target_end_date);

CREATE INDEX IF NOT EXISTS idx_do_po_num
    ON commercial.delivery_order(po_num);

CREATE INDEX IF NOT EXISTS idx_do_status_target_date
    ON commercial.delivery_order(status, target_start_date, target_end_date)
    WHERE status IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_do_discharge_site
    ON commercial.delivery_order(discharge_site)
    WHERE discharge_site IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_do_target_date
    ON commercial.delivery_order(target_start_date, target_end_date);

-- 11. OPERATIONAL INDEXES
CREATE INDEX IF NOT EXISTS idx_work_area_geom
    ON operational.work_area USING GIST(geom)
    WHERE geom IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_si_do
    ON operational.shipment_instruction(do_num);

CREATE INDEX IF NOT EXISTS idx_si_fleet_main
    ON operational.shipment_instruction(fleet_main_code);

CREATE INDEX IF NOT EXISTS idx_si_fleet_assist
    ON operational.shipment_instruction(fleet_assist_code)
    WHERE fleet_assist_code IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_si_working_site
    ON operational.shipment_instruction(working_site)
    WHERE working_site IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_si_discharge_site
    ON operational.shipment_instruction(discharge_site)
    WHERE discharge_site IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_work_activity_si_planned
    ON operational.work_activity(si_num, planned_start DESC);

CREATE INDEX IF NOT EXISTS idx_work_activity_fleet_planned
    ON operational.work_activity(fleet_code, planned_start DESC);

CREATE INDEX IF NOT EXISTS idx_work_activity_area
    ON operational.work_activity(area_code)
    WHERE area_code IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_work_activity_status
    ON operational.work_activity(status)
    WHERE status IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_work_activity_type
    ON operational.work_activity(activity_type);

CREATE INDEX IF NOT EXISTS idx_si_status
    ON operational.shipment_instruction(status)
    WHERE status IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_dredging_si_activity
    ON operational.dredging_records(si_num, activity_num);

CREATE INDEX IF NOT EXISTS idx_dredging_record_date
    ON operational.dredging_records(record_date DESC);

CREATE INDEX IF NOT EXISTS idx_dredging_form_no
    ON operational.dredging_records(form_no);

CREATE INDEX IF NOT EXISTS idx_dredging_uom
    ON operational.dredging_records(uom_code);

CREATE INDEX IF NOT EXISTS idx_dredging_created_by
    ON operational.dredging_records(created_by)
    WHERE created_by IS NOT NULL;

-- 12. VOYAGE INDEXES
CREATE INDEX IF NOT EXISTS idx_voyage_fleet_time_id
    ON voyage.voyage(fleet_code, record_time DESC, id DESC);

CREATE INDEX IF NOT EXISTS idx_voyage_do_num
    ON voyage.voyage(do_num)
    WHERE do_num IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_voyage_status
    ON voyage.voyage(status)
    WHERE status IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_voyage_geom
    ON voyage.voyage USING GIST(geom)
    WHERE geom IS NOT NULL;

CREATE INDEX IF NOT EXISTS brin_voyage_record_time
    ON voyage.voyage USING BRIN(record_time);

CREATE INDEX IF NOT EXISTS idx_voyage_hist_geom
    ON voyage.voyage_hist USING GIST(geom)
    WHERE geom IS NOT NULL;

CREATE INDEX IF NOT EXISTS brin_voyage_hist_record_time
    ON voyage.voyage_hist USING BRIN(record_time);

-- 13. LABORATORY INDEXES
CREATE INDEX IF NOT EXISTS idx_lab_result_lab
    ON laboratory.result(lab_code) WHERE lab_code IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_lab_result_sample
    ON laboratory.result(sample_id) WHERE sample_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_lab_result_doc_no
    ON laboratory.result(doc_no);

CREATE INDEX IF NOT EXISTS idx_lab_info_site
    ON laboratory.info(site_code) WHERE site_code IS NOT NULL;