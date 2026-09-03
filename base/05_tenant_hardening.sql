-- ============================================================
-- BASE LAYER / 5: tenant hardening
-- file    : base/05_tenant_hardening.sql
-- note    : Turns the existing `tenant_id UUID` columns into real multi-tenancy.
--           Runs AFTER the feature layer, in phases:
--             A  ensure a default tenant exists
--             B  backfill NULL tenant_id
--             C  foreign key to security.tenant
--             D  NOT NULL on tenant-scoped tables
--             E  index on tenant_id where missing
--             F  composite (tenant_id, code) unique keys on parent tables
--             G  composite foreign keys on the critical child references
--
-- usage   : PGOPTIONS="-c mig.default_tenant_code=DEFAULT -c mig.default_tenant_name=DefaultTenant" \
--               psql "$DB_URL" -v ON_ERROR_STOP=1 -f base/05_tenant_hardening.sql
--
--           The name must be a dotted GUC set server-side; a psql -v variable is
--           client-side only and current_setting() cannot see it.
--
--           Without mig.default_tenant_code the script aborts before touching
--           anything: it will not invent a tenant behind your back.
-- ============================================================

\set ON_ERROR_STOP on
SET client_min_messages = notice;

-- The tenant NAME may contain spaces, and PGOPTIONS cannot carry a value with a
-- space in it (the backend splits its options on whitespace and rejects the
-- remainder: "invalid command-line argument for server process"). So the name is
-- passed as a psql variable and pushed into the GUC here; the code stays in
-- PGOPTIONS because it must be visible to every phase and never contains spaces.
\if :{?mig_name}
SELECT set_config('mig.default_tenant_name', :'mig_name', false) AS default_tenant_name;
\endif

-- ------------------------------------------------------------ A. default tenant
DO $$
DECLARE v_code TEXT;
BEGIN
    BEGIN
        v_code := current_setting('mig.default_tenant_code', true);
    EXCEPTION WHEN OTHERS THEN
        v_code := NULL;
    END;

    IF v_code IS NULL OR v_code = '' THEN
        RAISE EXCEPTION
            'mig.default_tenant_code is not set. Pass it via PGOPTIONS="-c mig.default_tenant_code=CODE" so existing rows have somewhere to belong.';
    END IF;

    INSERT INTO security.tenant (tenant_code, tenant_name, is_active)
    VALUES (v_code, COALESCE(current_setting('mig.default_tenant_name', true), v_code), TRUE)
    ON CONFLICT (tenant_code) DO NOTHING;

    RAISE NOTICE 'phase A: default tenant % ready', v_code;
END;
$$;

-- ------------------------------------------------------------ B. backfill
DO $$
DECLARE
    r RECORD; v_tenant UUID; v_rows BIGINT; v_total BIGINT := 0;
BEGIN
    SELECT tenant_id INTO v_tenant FROM security.tenant
    WHERE tenant_code = current_setting('mig.default_tenant_code', true);

    FOR r IN
        SELECT n.nspname AS sch, c.relname AS tbl
        FROM pg_attribute a
        JOIN pg_class c ON c.oid = a.attrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE a.attname = 'tenant_id' AND a.attnum > 0 AND NOT a.attisdropped
          AND c.relkind IN ('r','p')
          AND NOT c.relispartition   -- partitions inherit from the parent
          AND n.nspname NOT IN ('pg_catalog','information_schema','security','reporting','auth')
        ORDER BY 1, 2
    LOOP
        EXECUTE format('UPDATE %I.%I SET tenant_id = $1 WHERE tenant_id IS NULL', r.sch, r.tbl)
            USING v_tenant;
        GET DIAGNOSTICS v_rows = ROW_COUNT;
        v_total := v_total + v_rows;
        IF v_rows > 0 THEN
            RAISE NOTICE 'phase B: backfilled % row(s) in %.%', v_rows, r.sch, r.tbl;
        END IF;
    END LOOP;
    RAISE NOTICE 'phase B: % row(s) backfilled in total', v_total;
END;
$$;

-- ------------------------------------------------------------ C. foreign key
DO $$
DECLARE r RECORD;
BEGIN
    FOR r IN
        SELECT n.nspname AS sch, c.relname AS tbl
        FROM pg_attribute a
        JOIN pg_class c ON c.oid = a.attrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE a.attname = 'tenant_id' AND a.attnum > 0 AND NOT a.attisdropped
          AND c.relkind IN ('r','p')
          AND NOT c.relispartition
          AND n.nspname NOT IN ('pg_catalog','information_schema','security','reporting','auth')
          AND NOT EXISTS (SELECT 1 FROM pg_constraint con
                          WHERE con.conrelid = c.oid AND con.conname = 'fk_tenant')
        ORDER BY 1, 2
    LOOP
        EXECUTE format(
            'ALTER TABLE %I.%I ADD CONSTRAINT fk_tenant
                 FOREIGN KEY (tenant_id) REFERENCES security.tenant(tenant_id) ON DELETE RESTRICT',
            r.sch, r.tbl);
        RAISE NOTICE 'phase C: fk_tenant on %.%', r.sch, r.tbl;
    END LOOP;
END;
$$;

-- ------------------------------------------------------------ D. NOT NULL
DO $$
DECLARE r RECORD;
BEGIN
    FOR r IN
        SELECT n.nspname AS sch, c.relname AS tbl
        FROM pg_attribute a
        JOIN pg_class c ON c.oid = a.attrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE a.attname = 'tenant_id' AND a.attnum > 0 AND NOT a.attisdropped
          AND NOT a.attnotnull
          AND c.relkind IN ('r','p')
          AND NOT c.relispartition
          AND n.nspname NOT IN ('pg_catalog','information_schema','security','reporting','auth')
        ORDER BY 1, 2
    LOOP
        EXECUTE format('ALTER TABLE %I.%I ALTER COLUMN tenant_id SET NOT NULL', r.sch, r.tbl);
        RAISE NOTICE 'phase D: tenant_id NOT NULL on %.%', r.sch, r.tbl;
    END LOOP;
END;
$$;

-- ------------------------------------------------------------ E. index
DO $$
DECLARE r RECORD;
BEGIN
    FOR r IN
        SELECT n.nspname AS sch, c.relname AS tbl
        FROM pg_attribute a
        JOIN pg_class c ON c.oid = a.attrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE a.attname = 'tenant_id' AND a.attnum > 0 AND NOT a.attisdropped
          AND c.relkind IN ('r','p')
          AND NOT c.relispartition
          AND n.nspname NOT IN ('pg_catalog','information_schema','security','reporting','auth')
          AND NOT EXISTS (
                SELECT 1 FROM pg_index i
                JOIN pg_attribute k ON k.attrelid = i.indrelid AND k.attnum = i.indkey[0]
                WHERE i.indrelid = c.oid AND k.attname = 'tenant_id')
        ORDER BY 1, 2
    LOOP
        EXECUTE format('CREATE INDEX IF NOT EXISTS idx_%s_tenant ON %I.%I(tenant_id)',
                       replace(r.tbl, '.', '_'), r.sch, r.tbl);
        RAISE NOTICE 'phase E: index on %.%(tenant_id)', r.sch, r.tbl;
    END LOOP;
END;
$$;

-- ------------------------------------------------------------ F. parent keys
-- These are the targets the composite foreign keys in phase G point at.
-- They must NOT be DEFERRABLE: PostgreSQL rejects a deferrable unique constraint
-- as an FK target ("cannot use a deferrable unique constraint for referenced
-- table").
-- param.country / currency / unit_of_measure are global reference tables with no
-- tenant_id column and must stay global, so they get no key here.
ALTER TABLE site.info            ADD CONSTRAINT uq_site_tenant           UNIQUE (tenant_id, site_code);
ALTER TABLE "user".info          ADD CONSTRAINT uq_user_tenant           UNIQUE (tenant_id, user_code);
ALTER TABLE partner.info         ADD CONSTRAINT uq_partner_tenant        UNIQUE (tenant_id, partner_code);
ALTER TABLE buyer.info           ADD CONSTRAINT uq_buyer_tenant          UNIQUE (tenant_id, buyer_code);
ALTER TABLE fleet.info           ADD CONSTRAINT uq_fleet_tenant          UNIQUE (tenant_id, fleet_code);
ALTER TABLE enviro.station       ADD CONSTRAINT uq_enviro_station_tenant UNIQUE (tenant_id, station_code);
ALTER TABLE laboratory.info      ADD CONSTRAINT uq_lab_tenant            UNIQUE (tenant_id, lab_code);
ALTER TABLE telemetry.geofence   ADD CONSTRAINT uq_geofence_tenant       UNIQUE (tenant_id, geofence_id);

-- ------------------------------------------------------------ G. composite FKs
-- A row can now only reference a parent carrying the same tenant_id, which is
-- what stops "PO tenant A referencing buyer tenant B". The original
-- single-column FKs are kept: they give better error messages, and the composite
-- key adds the tenant check on top.
ALTER TABLE commercial.purchase_order
    ADD CONSTRAINT fk_po_buyer_tenant
    FOREIGN KEY (tenant_id, buyer_code) REFERENCES buyer.info(tenant_id, buyer_code);

ALTER TABLE operational.shipment_instruction
    ADD CONSTRAINT fk_si_fleet_main_tenant
    FOREIGN KEY (tenant_id, fleet_main_code) REFERENCES fleet.info(tenant_id, fleet_code);

ALTER TABLE operational.shipment_instruction
    ADD CONSTRAINT fk_si_fleet_assist_tenant
    FOREIGN KEY (tenant_id, fleet_assist_code) REFERENCES fleet.info(tenant_id, fleet_code);

ALTER TABLE operational.work_activity
    ADD CONSTRAINT fk_activity_fleet_tenant
    FOREIGN KEY (tenant_id, fleet_code) REFERENCES fleet.info(tenant_id, fleet_code);

ALTER TABLE operational.delivery_trip
    ADD CONSTRAINT fk_trip_fleet_tenant
    FOREIGN KEY (tenant_id, fleet_code) REFERENCES fleet.info(tenant_id, fleet_code);

ALTER TABLE operational.delivery_receipt
    ADD CONSTRAINT fk_receipt_buyer_tenant
    FOREIGN KEY (tenant_id, buyer_code) REFERENCES buyer.info(tenant_id, buyer_code);

ALTER TABLE financial.journal_line
    ADD CONSTRAINT fk_journal_line_partner_tenant
    FOREIGN KEY (tenant_id, partner_code) REFERENCES partner.info(tenant_id, partner_code);

ALTER TABLE telemetry.raw_message
    ADD CONSTRAINT fk_raw_partner_tenant
    FOREIGN KEY (tenant_id, partner_code) REFERENCES partner.info(tenant_id, partner_code);

ALTER TABLE telemetry.vessel_position_latest
    ADD CONSTRAINT fk_latest_partner_tenant
    FOREIGN KEY (tenant_id, partner_code) REFERENCES partner.info(tenant_id, partner_code);

ALTER TABLE telemetry.geofence_event
    ADD CONSTRAINT fk_geofence_event_tenant
    FOREIGN KEY (tenant_id, geofence_id) REFERENCES telemetry.geofence(tenant_id, geofence_id);

-- Deliberately NO composite FK from telemetry.ais_position.fleet_code to
-- fleet.info. Raw AIS arrives for vessels that are not registered yet, and a
-- referential constraint here would reject the ingest instead of letting the
-- message land and be matched later. Isolation there comes from RLS.

-- compliance.alert.tenant_id gets no composite FK: compliance.entity_requirement
-- has no (tenant_id, entity_req_id) unique key, and entity_req_id is already a
-- global surrogate, so the key would be ceremony without a check.

-- ------------------------------------------------------------ report
SELECT 'tables with tenant_id NOT NULL' AS check_item, count(*) AS value
FROM pg_attribute a
JOIN pg_class c ON c.oid = a.attrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE a.attname = 'tenant_id' AND a.attnotnull AND c.relkind IN ('r','p')
  AND NOT c.relispartition
  AND n.nspname NOT IN ('pg_catalog','information_schema','auth')
UNION ALL
SELECT 'fk_tenant constraints', count(*) FROM pg_constraint WHERE conname = 'fk_tenant'
UNION ALL
SELECT 'composite tenant FKs', count(*)
FROM pg_constraint WHERE conname LIKE 'fk\_%\_tenant' AND conname <> 'fk_tenant';
