-- ============================================================
-- BASE LAYER / 8: Global updated_at trigger
-- file    : base/08_global_updated_at.sql
-- objects : 1 statement(s)
-- note    : MUST run after every table exists, so it comes after the feature layer.
-- generated from original/schema_v1_original.sql by tools/split_schema.py
-- ============================================================

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
          -- [FIX-6] 'auth' added: without it this block would try to attach
          -- trg_updated_at to Supabase-owned auth.* tables on every deploy.
          AND n.nspname NOT IN ('pg_catalog','information_schema','extensions','graphql','graphql_public','realtime','supabase_functions','supabase_migrations','net','cron','pgsodium','pgbouncer','auth')
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
