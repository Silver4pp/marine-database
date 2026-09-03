-- ============================================================
-- BASE LAYER / 6: row level security
-- file    : base/06_rls.sql
-- note    : Enables RLS on every tenant-scoped table and adds policies driven by
--           security.user_scope, using security.fn_get_current_tenant_id() and
--           security.fn_is_super_admin().
--
--           Run AFTER base/05_tenant_hardening.sql: RLS on a nullable tenant_id
--           would silently hide every row whose tenant is NULL.
--
--           Policies per table:
--             pol_<t>_select  SELECT  tenant match OR super admin OR VIEWER/SAFETY_OFFICER
--             pol_<t>_modify  ALL     tenant match OR super admin, ADMIN/MANAGER/OPERATOR
--
--           A superuser has BYPASSRLS and skips every policy, so verifying this
--           as `postgres` proves nothing. Test with a non-superuser role.
--
-- usage   : psql "$DB_URL" -v ON_ERROR_STOP=1 -f base/06_rls.sql
--           Pass -v mig.rls_no_force=1 to leave FORCE ROW LEVEL SECURITY off. By
--           default it is ON, because Supabase applications connect as the table
--           owner and table owners bypass RLS otherwise.
-- ============================================================

\set ON_ERROR_STOP on
SET client_min_messages = notice;

DO $$
DECLARE
    r RECORD;
    v_force TEXT := COALESCE(current_setting('mig.rls_no_force', true), '');
BEGIN
    -- DROP POLICY IF EXISTS is noisy on a first run; keep the summary only
    SET LOCAL client_min_messages = warning;

    FOR r IN
        SELECT n.nspname AS sch, c.relname AS tbl
        FROM pg_attribute a
        JOIN pg_class c ON c.oid = a.attrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE a.attname = 'tenant_id' AND a.attnum > 0 AND NOT a.attisdropped
          AND c.relkind IN ('r','p')
          AND n.nspname NOT IN ('pg_catalog','information_schema','security','reporting','auth')
        ORDER BY 1, 2
    LOOP
        EXECUTE format('ALTER TABLE %I.%I ENABLE ROW LEVEL SECURITY', r.sch, r.tbl);
        IF v_force <> '1' THEN
            EXECUTE format('ALTER TABLE %I.%I FORCE ROW LEVEL SECURITY', r.sch, r.tbl);
        END IF;

        EXECUTE format('DROP POLICY IF EXISTS pol_%1$s_select ON %2$I.%1$I', r.tbl, r.sch);
        EXECUTE format('DROP POLICY IF EXISTS pol_%1$s_modify ON %2$I.%1$I', r.tbl, r.sch);

        EXECUTE format($f$
            CREATE POLICY pol_%1$s_select ON %2$I.%1$I
            FOR SELECT
            USING (
                   security.fn_is_super_admin()
                OR tenant_id = security.fn_get_current_tenant_id()
                OR EXISTS (SELECT 1 FROM security.user_scope s
                           WHERE s.auth_user_id = auth.uid() AND s.is_active = TRUE
                             AND s.role_code IN ('VIEWER','SAFETY_OFFICER'))
            )
        $f$, r.tbl, r.sch);

        EXECUTE format($f$
            CREATE POLICY pol_%1$s_modify ON %2$I.%1$I
            FOR ALL
            USING (
                   (security.fn_is_super_admin()
                    OR tenant_id = security.fn_get_current_tenant_id())
                AND (security.fn_is_super_admin()
                     OR EXISTS (SELECT 1 FROM security.user_scope s
                                WHERE s.auth_user_id = auth.uid() AND s.is_active = TRUE
                                  AND s.role_code IN ('ADMIN','MANAGER','OPERATOR')))
            )
            WITH CHECK (
                   (security.fn_is_super_admin()
                    OR tenant_id = security.fn_get_current_tenant_id())
                AND (security.fn_is_super_admin()
                     OR EXISTS (SELECT 1 FROM security.user_scope s
                                WHERE s.auth_user_id = auth.uid() AND s.is_active = TRUE
                                  AND s.role_code IN ('ADMIN','MANAGER','OPERATOR')))
            )
        $f$, r.tbl, r.sch);
    END LOOP;

    RAISE NOTICE 'RLS enabled on % tenant-scoped table(s)',
        (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
          WHERE c.relrowsecurity AND n.nspname NOT IN ('pg_catalog','information_schema'));
END;
$$;

-- ------------------------------------------------------------
-- Child tables carrying no tenant_id of their own: the policy proves the tenant
-- through the parent row.
-- ------------------------------------------------------------

ALTER TABLE hse.incident_witness ENABLE ROW LEVEL SECURITY;
ALTER TABLE hse.incident_witness FORCE ROW LEVEL SECURITY;
CREATE POLICY pol_incident_witness_select ON hse.incident_witness
FOR SELECT USING (
       security.fn_is_super_admin()
    OR EXISTS (SELECT 1 FROM hse.incident i
               WHERE i.incident_id = incident_witness.incident_id
                 AND i.tenant_id = security.fn_get_current_tenant_id()));
CREATE POLICY pol_incident_witness_modify ON hse.incident_witness
FOR ALL USING (
       security.fn_is_super_admin()
    OR EXISTS (SELECT 1 FROM hse.incident i
               WHERE i.incident_id = incident_witness.incident_id
                 AND i.tenant_id = security.fn_get_current_tenant_id())
) WITH CHECK (
       security.fn_is_super_admin()
    OR EXISTS (SELECT 1 FROM hse.incident i
               WHERE i.incident_id = incident_witness.incident_id
                 AND i.tenant_id = security.fn_get_current_tenant_id()));

ALTER TABLE hse.permit_approval ENABLE ROW LEVEL SECURITY;
ALTER TABLE hse.permit_approval FORCE ROW LEVEL SECURITY;
CREATE POLICY pol_permit_approval_select ON hse.permit_approval
FOR SELECT USING (
       security.fn_is_super_admin()
    OR EXISTS (SELECT 1 FROM hse.permit p
               WHERE p.permit_id = permit_approval.permit_id
                 AND p.tenant_id = security.fn_get_current_tenant_id()));
CREATE POLICY pol_permit_approval_modify ON hse.permit_approval
FOR ALL USING (
       security.fn_is_super_admin()
    OR EXISTS (SELECT 1 FROM hse.permit p
               WHERE p.permit_id = permit_approval.permit_id
                 AND p.tenant_id = security.fn_get_current_tenant_id())
) WITH CHECK (
       security.fn_is_super_admin()
    OR EXISTS (SELECT 1 FROM hse.permit p
               WHERE p.permit_id = permit_approval.permit_id
                 AND p.tenant_id = security.fn_get_current_tenant_id()));

DO $$
DECLARE r RECORD;
BEGIN
    SET LOCAL client_min_messages = warning;
    FOR r IN SELECT unnest(ARRAY['version','permission','signature','audit']) AS tbl
    LOOP
        EXECUTE format('ALTER TABLE document.%I ENABLE ROW LEVEL SECURITY', r.tbl);
        EXECUTE format('ALTER TABLE document.%I FORCE ROW LEVEL SECURITY', r.tbl);
        EXECUTE format($f$
            CREATE POLICY pol_%1$s_select ON document.%1$I FOR SELECT USING (
                   security.fn_is_super_admin()
                OR EXISTS (SELECT 1 FROM document.document d
                           WHERE d.document_id = %1$I.document_id
                             AND d.tenant_id = security.fn_get_current_tenant_id())
            )$f$, r.tbl);
        EXECUTE format($f$
            CREATE POLICY pol_%1$s_modify ON document.%1$I FOR ALL USING (
                   security.fn_is_super_admin()
                OR EXISTS (SELECT 1 FROM document.document d
                           WHERE d.document_id = %1$I.document_id
                             AND d.tenant_id = security.fn_get_current_tenant_id())
            ) WITH CHECK (
                   security.fn_is_super_admin()
                OR EXISTS (SELECT 1 FROM document.document d
                           WHERE d.document_id = %1$I.document_id
                             AND d.tenant_id = security.fn_get_current_tenant_id())
            )$f$, r.tbl);
    END LOOP;
END;
$$;

-- ------------------------------------------------------------ report
SELECT 'tables with RLS enabled' AS check_item, count(*)::TEXT AS value
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relrowsecurity AND n.nspname NOT IN ('pg_catalog','information_schema')
UNION ALL
SELECT 'tables with RLS forced', count(*)::TEXT
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relforcerowsecurity AND n.nspname NOT IN ('pg_catalog','information_schema')
UNION ALL
SELECT 'policies created', count(*)::TEXT FROM pg_policy;
