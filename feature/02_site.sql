-- ============================================================
-- FEATURE SCHEMA: site
-- file    : feature/02_site.sql
-- objects : 2 statement(s)
-- generated from original/schema_v1_original.sql by tools/split_schema.py
-- ============================================================

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
