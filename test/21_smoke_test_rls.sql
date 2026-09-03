-- ============================================================
-- SMOKE TEST v2b - RLS tenant isolation
-- Run AFTER test/20_smoke_test_v2.sql (it creates the TA/TB fixtures).
--
-- MUST be run as a non-superuser role. A superuser has BYPASSRLS and skips
-- every policy, so running this as `postgres` proves nothing.
--
--   psql "$DB_URL" -U app_user -f test/21_smoke_test_rls.sql
--
-- FORCE ROW LEVEL SECURITY is on, so even the table owner is filtered. The
-- policies resolve the caller through auth.uid(), which the local stub reads
-- from the request.jwt.claim.sub session GUC.
-- ============================================================

-- refuse to produce a meaningless result
DO $$
BEGIN
    IF current_setting('is_superuser') = 'on' THEN
        RAISE EXCEPTION 'run this as a non-superuser role; superusers bypass RLS and the test would pass vacuously';
    END IF;
END;
$$;
\set ON_ERROR_STOP off
\pset footer off
SET client_min_messages = warning;

SELECT tenant_code, tenant_id FROM security.tenant WHERE tenant_code IN ('TA','TB') ORDER BY 1;

\echo
\echo '=== 0. no identity at all -> nothing is visible (safe default) ==='
SELECT reset_config AS ignored FROM (SELECT set_config('request.jwt.claim.sub','',false)) r(reset_config);
SELECT count(*) AS buyers_visible, '  expecting 0' AS note FROM buyer.info;
SELECT count(*) AS fleets_visible, '  expecting 0' AS note FROM fleet.info;

\echo
\echo '=== 1. caller is User A (tenant TA) ==='
SELECT set_config('request.jwt.claim.sub','aaaaaaaa-0000-0000-0000-000000000001',false) AS who;
SELECT security.fn_get_current_tenant_id() = (SELECT tenant_id FROM security.tenant WHERE tenant_code='TA')
       AS resolves_to_tenant_a;
SELECT buyer_code, name FROM buyer.info ORDER BY buyer_code;
SELECT fleet_code, name FROM fleet.info ORDER BY fleet_code;
SELECT count(*) AS po_visible, '  expecting 1 (PO-A1 only)' AS note FROM commercial.purchase_order;

\echo
\echo '=== 2. caller is User B (tenant TB) - the same query, different rows ==='
SELECT set_config('request.jwt.claim.sub','bbbbbbbb-0000-0000-0000-000000000002',false) AS who;
SELECT buyer_code, name FROM buyer.info ORDER BY buyer_code;
SELECT fleet_code, name FROM fleet.info ORDER BY fleet_code;

\echo
\echo '=== 3. User B cannot read tenant A trip data ==='
SELECT count(*) AS trips_visible_to_b, '  expecting 0' AS note FROM operational.delivery_trip;
SELECT count(*) AS manifests_visible_to_b, '  expecting 0' AS note FROM operational.cargo_manifest;
SELECT count(*) AS receipts_visible_to_b, '  expecting 0' AS note FROM operational.delivery_receipt;
SELECT count(*) AS corrective_actions_visible_to_b, '  expecting 0' AS note FROM hse.corrective_action;
SELECT count(*) AS compliance_rows_visible_to_b, '  expecting 0' AS note FROM compliance.entity_requirement;
SELECT count(*) AS enviro_readings_visible_to_b, '  expecting 0' AS note FROM enviro.reading;

\echo
\echo '=== 4. child tables with no tenant_id are filtered through the parent ==='
SELECT set_config('request.jwt.claim.sub','aaaaaaaa-0000-0000-0000-000000000001',false) AS who;
INSERT INTO hse.incident_witness (incident_id, witness_name)
SELECT incident_id,'Witness A1' FROM hse.incident WHERE incident_no='INC-A1';
SELECT count(*) AS witnesses_visible_to_a, '  expecting 1' AS note FROM hse.incident_witness;
SELECT set_config('request.jwt.claim.sub','bbbbbbbb-0000-0000-0000-000000000002',false) AS who;
SELECT count(*) AS witnesses_visible_to_b, '  expecting 0 - filtered via hse.incident' AS note
FROM hse.incident_witness;

\echo
\echo '=== 5. writes are checked too (WITH CHECK), not just reads ==='
SELECT set_config('request.jwt.claim.sub','bbbbbbbb-0000-0000-0000-000000000002',false) AS who;
\echo '  User B tries to insert a buyer carrying tenant A id - expecting a policy violation'
INSERT INTO buyer.info (buyer_code, name, tenant_id)
SELECT 'BUY-SMUGGLE','Smuggled', tenant_id FROM security.tenant WHERE tenant_code='TA';
SELECT count(*) AS rows_inserted, '  expecting 0' AS note FROM buyer.info WHERE buyer_code='BUY-SMUGGLE';

\echo
\echo '=== 6. a super admin sees every tenant ==='
UPDATE security.app_user SET is_super_admin = TRUE
WHERE auth_user_id = 'bbbbbbbb-0000-0000-0000-000000000002';
SELECT count(*) AS buyers_visible_to_superadmin,
       '  expecting 2 (BUY-A and BUY-B)' AS note
FROM buyer.info;
UPDATE security.app_user SET is_super_admin = FALSE
WHERE auth_user_id = 'bbbbbbbb-0000-0000-0000-000000000002';

SELECT set_config('request.jwt.claim.sub','',false) AS reset;
