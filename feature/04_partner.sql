-- ============================================================
-- FEATURE SCHEMA: partner
-- file    : feature/04_partner.sql
-- objects : 2 statement(s)
-- generated from original/schema_v1_original.sql by tools/split_schema.py
-- ============================================================

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
