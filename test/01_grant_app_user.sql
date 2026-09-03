-- ============================================================
-- Grants for the non-superuser test role -- ONLY for local/offline testing.
--
--   psql "$DB_URL" -f test/01_grant_app_user.sql
--
-- test/21_smoke_test_rls.sql must run as a role WITHOUT BYPASSRLS, otherwise the
-- RLS assertions pass vacuously. On Supabase the equivalent role is `authenticated`
-- and these grants come from the platform instead.
-- Run as the owner of the schemas (postgres) after scripts/deploy.sh.
-- ============================================================
\set ON_ERROR_STOP on

DO $$
DECLARE
    s RECORD;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_user') THEN
        CREATE ROLE app_user LOGIN;
    END IF;

    EXECUTE format('GRANT CONNECT ON DATABASE %I TO app_user', current_database());
    EXECUTE 'GRANT USAGE ON SCHEMA auth TO app_user';
    EXECUTE 'GRANT SELECT ON ALL TABLES IN SCHEMA auth TO app_user';

    FOR s IN
        SELECT nspname FROM pg_namespace
        WHERE nspname IN ('param','site','user','partner','buyer','fleet','form',
                          'laboratory','survey','enviro','commercial','operational',
                          'voyage','financial','hse','security','audit','workflow',
                          'document','telemetry','reporting','compliance')
        ORDER BY 1
    LOOP
        EXECUTE format('GRANT USAGE ON SCHEMA %I TO app_user', s.nspname);
        EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA %I TO app_user', s.nspname);
        EXECUTE format('GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA %I TO app_user', s.nspname);
        EXECUTE format('GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA %I TO app_user', s.nspname);
        EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA %I GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app_user', s.nspname);
        EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA %I GRANT USAGE, SELECT ON SEQUENCES TO app_user', s.nspname);
    END LOOP;

    RAISE NOTICE 'app_user granted on % schemas',
        (SELECT count(*) FROM pg_namespace
          WHERE nspname IN ('param','site','user','partner','buyer','fleet','form',
                            'laboratory','survey','enviro','commercial','operational',
                            'voyage','financial','hse','security','audit','workflow',
                            'document','telemetry','reporting','compliance'));
END;
$$;
