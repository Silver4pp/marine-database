-- Fix ownership DB uat_pasir_laut ke user aplikasi `erp`
-- (dijalankan bila setelah restart sandbox muncul "permission denied for schema ...")
-- Pemakaian: sudo -u postgres psql -d uat_pasir_laut -q -f /tmp/fix-owner.sql
DO $$ DECLARE r record; BEGIN
  FOR r IN SELECT schemaname, tablename FROM pg_tables WHERE schemaname NOT IN ('pg_catalog','information_schema') LOOP
    EXECUTE format('ALTER TABLE %I.%I OWNER TO erp', r.schemaname, r.tablename); END LOOP;
  FOR r IN SELECT schemaname, sequencename FROM pg_sequences WHERE schemaname NOT IN ('pg_catalog') LOOP
    EXECUTE format('ALTER SEQUENCE %I.%I OWNER TO erp', r.schemaname, r.sequencename); END LOOP;
  FOR r IN SELECT nspname FROM pg_namespace WHERE nspname NOT LIKE 'pg_%' AND nspname <> 'information_schema' LOOP
    EXECUTE format('ALTER SCHEMA %I OWNER TO erp', r.nspname); END LOOP;
  FOR r IN SELECT n.nspname AS s, p.proname AS f, p.oid AS o
            FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid
            WHERE n.nspname NOT LIKE 'pg_%' AND pg_get_userbyid(p.proowner) = 'postgres' LOOP
    EXECUTE format('ALTER FUNCTION %I.%I(%s) OWNER TO erp', r.s, r.f,
                   pg_get_function_identity_arguments(r.o)); END LOOP;
END $$;
GRANT ALL ON SCHEMA public, telemetry, voyage, financial, document, param, commercial,
  operational, fleet, buyer, site, partner, enviro, notification, survey, hse TO erp;
CHECKPOINT;  -- flush ke disk agar tidak hilang oleh snapshot VM / crash recovery
