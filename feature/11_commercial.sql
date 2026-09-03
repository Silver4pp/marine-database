-- ============================================================
-- FEATURE SCHEMA: commercial
-- file    : feature/11_commercial.sql
-- objects : 2 statement(s)
-- generated from original/schema_v1_original.sql by tools/split_schema.py
-- ============================================================

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
