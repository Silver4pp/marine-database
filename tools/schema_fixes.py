"""Corrections applied to the original single-file schema during the split.

Each entry: (id, exact old text, exact new text, why).
`split_schema.py` applies them while writing and folds them back out during
`--verify`, so the source/output comparison stays honest.
"""

FIXES = [
    (
        "FIX-1",
        "    tenant_id       UUID,\n"
        "    CONSTRAINT uq_ledger_ref_doc UNIQUE (buyer_code, ref_doc, ref_type)\n"
        "                        WHERE ref_doc IS NOT NULL\n"
        ")",
        "    tenant_id       UUID\n"
        "    -- [FIX-1] A WHERE predicate is not allowed on a table-level UNIQUE\n"
        "    -- constraint (PostgreSQL: \"syntax error at or near WHERE\"). The equivalent\n"
        "    -- partial UNIQUE index now lives in index/01_indexes.sql.\n"
        "    -- ORIGINAL (invalid):\n"
        "    --   CONSTRAINT uq_ledger_ref_doc UNIQUE (buyer_code, ref_doc, ref_type)\n"
        "    --       WHERE ref_doc IS NOT NULL\n"
        ")",
        "buyer.ledger_hist: UNIQUE ... WHERE moved to a partial unique index",
    ),
    (
        "FIX-2",
        "    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),\n"
        "    CONSTRAINT uq_fleet_imo   UNIQUE (imo_number)   WHERE imo_number IS NOT NULL,\n"
        "    CONSTRAINT uq_fleet_mmsi  UNIQUE (mmsi_number)  WHERE mmsi_number IS NOT NULL\n"
        ")",
        "    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()\n"
        "    -- [FIX-2] UNIQUE ... WHERE is not valid inside a table body.\n"
        "    -- Re-created as partial UNIQUE indexes in index/01_indexes.sql.\n"
        "    -- ORIGINAL (invalid):\n"
        "    --   CONSTRAINT uq_fleet_imo  UNIQUE (imo_number)  WHERE imo_number IS NOT NULL,\n"
        "    --   CONSTRAINT uq_fleet_mmsi UNIQUE (mmsi_number) WHERE mmsi_number IS NOT NULL\n"
        ")",
        "fleet.info: two UNIQUE ... WHERE moved to partial unique indexes",
    ),
    (
        "FIX-3",
        "    CONSTRAINT uq_document_version UNIQUE (document_id, version_no),\n"
        "    CONSTRAINT uq_current_version UNIQUE (document_id) WHERE is_current = TRUE\n"
        ")",
        "    CONSTRAINT uq_document_version UNIQUE (document_id, version_no)\n"
        "    -- [FIX-3] UNIQUE ... WHERE is not valid inside a table body.\n"
        "    -- Re-created as a partial UNIQUE index in index/01_indexes.sql.\n"
        "    -- ORIGINAL (invalid):\n"
        "    --   CONSTRAINT uq_current_version UNIQUE (document_id) WHERE is_current = TRUE\n"
        ")",
        "document.version: UNIQUE ... WHERE moved to a partial unique index",
    ),
    (
        "FIX-4a",
        "    position_id     BIGSERIAL       PRIMARY KEY,",
        "    -- [FIX-4] A PRIMARY KEY on a partitioned table must include every\n"
        "    -- partitioning column (\"unique constraint on partitioned table must\n"
        "    -- include all partitioning columns\"). PK moved to (position_id, reported_at).\n"
        "    -- ORIGINAL (invalid): position_id BIGSERIAL PRIMARY KEY,\n"
        "    position_id     BIGSERIAL       NOT NULL,",
        "telemetry.ais_position: PK must include the partition key",
    ),
    (
        "FIX-4b",
        "    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now()\n"
        ") PARTITION BY RANGE (reported_at)",
        "    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),\n"
        "    PRIMARY KEY (position_id, reported_at)\n"
        ") PARTITION BY RANGE (reported_at)",
        "telemetry.ais_position: composite PK declared",
    ),
    (
        "FIX-5",
        "INSERT INTO param.unit_conversion (uom_code, uom_from, uom_to, conv_value) VALUES",
        "-- [FIX-5] The original column list used `uom_code`, which is not a column of\n"
        "-- param.unit_conversion (its PK column is `uc_code`) ->\n"
        "--   column \"uom_code\" of relation \"unit_conversion\" does not exist\n"
        "INSERT INTO param.unit_conversion (uc_code, uom_from, uom_to, conv_value) VALUES",
        "seed: unit_conversion column list referenced a non-existent column",
    ),
    (
        "FIX-6",
        "          AND n.nspname NOT IN ('pg_catalog','information_schema','extensions','graphql','graphql_public','realtime','supabase_functions','supabase_migrations','net','cron','pgsodium','pgbouncer')",
        "          -- [FIX-6] 'auth' added: without it this block would try to attach\n"
        "          -- trg_updated_at to Supabase-owned auth.* tables on every deploy.\n"
        "          AND n.nspname NOT IN ('pg_catalog','information_schema','extensions','graphql','graphql_public','realtime','supabase_functions','supabase_migrations','net','cron','pgsodium','pgbouncer','auth')",
        "global updated_at trigger: exclude the Supabase auth schema",
    ),
    (
        "FIX-7",
        "CREATE EXTENSION IF NOT EXISTS btree_gist",
        "-- pgcrypto: gen_random_uuid() (security.tenant) and digest()/hmac() for\n"
        "-- checksums and signatures.\n"
        "CREATE EXTENSION IF NOT EXISTS pgcrypto;\n\n"
        "CREATE EXTENSION IF NOT EXISTS btree_gist",
        "add pgcrypto alongside postgis and btree_gist",
    ),
    (
        "FIX-8",
        "    PRIMARY KEY (position_id, reported_at)",
        "    -- partition key first, so the leading column is the one every\n"
        "    -- time-range query filters on\n"
        "    PRIMARY KEY (reported_at, position_id)",
        "ais_position PK column order: (reported_at, position_id)",
    ),
    (
        "FIX-9a",
        "CREATE TABLE telemetry.vessel_position_latest (\n"
        "    fleet_code      VARCHAR(30)     PRIMARY KEY,\n"
        "    tenant_id       UUID            NOT NULL,",
        "CREATE TABLE telemetry.vessel_position_latest (\n"
        "    -- a fleet_code is only unique inside a tenant, so the key is composite\n"
        "    tenant_id       UUID            NOT NULL,\n"
        "    fleet_code      VARCHAR(30)     NOT NULL,",
        "vessel_position_latest: composite key part 1",
    ),
    (
        "FIX-9b",
        "    last_update     TIMESTAMPTZ     NOT NULL,\n"
        "    data_quality    VARCHAR(20),\n"
        "    source_system   VARCHAR(50),\n"
        "    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),\n"
        "    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()\n"
        ")",
        "    last_update     TIMESTAMPTZ     NOT NULL,\n"
        "    data_quality    VARCHAR(20),\n"
        "    source_system   VARCHAR(50),\n"
        "    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),\n"
        "    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),\n"
        "    PRIMARY KEY (tenant_id, fleet_code)\n"
        ")",
        "vessel_position_latest: PRIMARY KEY (tenant_id, fleet_code)",
    ),
    (
        "FIX-9c",
        "    ON CONFLICT (fleet_code) DO UPDATE SET",
        "    -- the conflict target must match the new composite key\n"
        "    ON CONFLICT (tenant_id, fleet_code) DO UPDATE SET",
        "fn_update_latest_position: conflict target follows the new PK",
    ),
]

# Indexes that restore the uniqueness the removed table constraints intended.
EXTRA_INDEXES = {
    "index/01_indexes.sql": """
-- ============================================================
-- PARTIAL UNIQUE INDEXES (restore FIX-1 .. FIX-3)
-- A UNIQUE constraint inside CREATE TABLE cannot carry a WHERE predicate;
-- these indexes enforce exactly the rule the original constraints intended.
-- ============================================================

-- [FIX-1] was: CONSTRAINT uq_ledger_ref_doc UNIQUE (buyer_code, ref_doc, ref_type) WHERE ref_doc IS NOT NULL
CREATE UNIQUE INDEX IF NOT EXISTS uq_ledger_ref_doc
    ON buyer.ledger_hist(buyer_code, ref_doc, ref_type)
    WHERE ref_doc IS NOT NULL;

-- [FIX-2] were: CONSTRAINT uq_fleet_imo / uq_fleet_mmsi
CREATE UNIQUE INDEX IF NOT EXISTS uq_fleet_imo
    ON fleet.info(imo_number)
    WHERE imo_number IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_fleet_mmsi
    ON fleet.info(mmsi_number)
    WHERE mmsi_number IS NOT NULL;

-- [FIX-3] was: CONSTRAINT uq_current_version UNIQUE (document_id) WHERE is_current = TRUE
CREATE UNIQUE INDEX IF NOT EXISTS uq_current_version
    ON document.version(document_id)
    WHERE is_current = TRUE;
""",
}


# Whole statements added during the split (not replacements).
EXTRA_STATEMENTS = {
    "base/01_extensions.sql": "CREATE EXTENSION IF NOT EXISTS pgcrypto",
}
