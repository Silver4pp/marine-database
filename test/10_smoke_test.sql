-- ============================================================
-- SMOKE TEST - proves the split schema actually enforces its rules.
-- Run against a database built by scripts/deploy.sh.
-- Each block is expected to raise; \set ON_ERROR_STOP off lets us continue.
-- ============================================================
\set ON_ERROR_STOP off
\pset footer off
SET client_min_messages = warning;

-- make the run repeatable
TRUNCATE telemetry.geofence_event, telemetry.ais_position, telemetry.vessel_position_latest,
         telemetry.geofence, workflow.history, workflow.approval, workflow.instance_step,
         workflow.instance, form.measurement, form.sample, form.water_sampling,
         buyer.ledger_hist, buyer.info, fleet.info, fleet.assignment_leg, fleet.maintenance,
         partner.info, "user".detail, "user".info, site.info CASCADE;

-- after migration/01 tenant_id is NOT NULL and references security.tenant,
-- so every fixture below needs one
INSERT INTO security.tenant (tenant_code, tenant_name) VALUES ('TST','Smoke Test Tenant')
ON CONFLICT (tenant_code) DO NOTHING;
SELECT tenant_id AS tst FROM security.tenant WHERE tenant_code='TST' \gset

\echo '--- 1. object inventory ---'
SELECT n.nspname AS schema,
       count(*) FILTER (WHERE c.relkind = 'r')  AS tables,
       count(*) FILTER (WHERE c.relkind = 'p')  AS partitioned,
       count(*) FILTER (WHERE c.relkind = 'm')  AS matviews
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname NOT LIKE 'pg_%'
  AND n.nspname NOT IN ('information_schema','auth','cron','public','topology')
GROUP BY 1 ORDER BY 1;

SELECT count(*) AS total_indexes   FROM pg_indexes WHERE schemaname NOT IN ('pg_catalog','information_schema','cron','auth','public');
SELECT count(*) AS matview_indexes FROM pg_indexes WHERE schemaname = 'reporting';
SELECT count(*) AS triggers        FROM information_schema.triggers
 WHERE trigger_schema NOT IN ('pg_catalog','information_schema');
-- schema-owned functions only (public.* is dominated by PostGIS, so exclude it)
SELECT n.nspname AS schema, count(*) AS functions
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname IN ('param','site','user','partner','buyer','fleet','form','laboratory','survey',
                    'enviro','commercial','operational','voyage','financial','hse','security',
                    'audit','workflow','document','telemetry')
GROUP BY 1 ORDER BY 1;
SELECT count(*) AS public_helper_functions FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public' AND p.proname LIKE 'fn\_%';

\echo
\echo '--- 2. seed row counts ---'
SELECT 'param.country' t, count(*) FROM param.country
UNION ALL SELECT 'param.currency',        count(*) FROM param.currency
UNION ALL SELECT 'param.unit_of_measure', count(*) FROM param.unit_of_measure
UNION ALL SELECT 'param.unit_conversion', count(*) FROM param.unit_conversion
UNION ALL SELECT 'param.status',          count(*) FROM param.status
UNION ALL SELECT 'param.role',            count(*) FROM param.role
UNION ALL SELECT 'fleet.type',            count(*) FROM fleet.type
UNION ALL SELECT 'site.type',             count(*) FROM site.type
UNION ALL SELECT 'partner.type',          count(*) FROM partner.type
UNION ALL SELECT 'enviro.reading_type',   count(*) FROM enviro.reading_type
UNION ALL SELECT 'hse.incident_type',     count(*) FROM hse.incident_type
UNION ALL SELECT 'document.type',         count(*) FROM document.type
UNION ALL SELECT 'survey.type',           count(*) FROM survey.type
UNION ALL SELECT 'security.permission',   count(*) FROM security.permission
UNION ALL SELECT 'workflow.definition',   count(*) FROM workflow.definition
UNION ALL SELECT 'workflow.step',         count(*) FROM workflow.step
ORDER BY 1;

\echo
\echo '--- 3. FIX-1 partial unique index actually rejects a duplicate ledger ref ---'
INSERT INTO site.info (site_code, type_code, name, tenant_id) VALUES ('S1','PORT','Site 1',:'tst'::uuid);
INSERT INTO buyer.info (buyer_code, name, tenant_id) VALUES ('B1','Buyer 1',:'tst'::uuid);
INSERT INTO buyer.ledger_hist (buyer_code, transaction_date, transaction_type, amount, currency_code, ref_doc, ref_type, tenant_id)
VALUES ('B1', DATE '2026-01-01','CREDIT', 100,'IDR','INV-1','INVOICE',:'tst'::uuid);
\echo '  expecting: duplicate key value violates unique constraint "uq_ledger_ref_doc"'
INSERT INTO buyer.ledger_hist (buyer_code, transaction_date, transaction_type, amount, currency_code, ref_doc, ref_type, tenant_id)
VALUES ('B1', DATE '2026-01-02','DEBIT', 100,'IDR','INV-1','INVOICE',:'tst'::uuid);

\echo
\echo '--- 4. buyer ledger immutability trigger blocks UPDATE ---'
\echo '  expecting: Ledger entries are immutable'
UPDATE buyer.ledger_hist SET amount = 999 WHERE buyer_code = 'B1';

\echo
\echo '--- 5. FIX-2 partial unique index on fleet.info.imo_number ---'
INSERT INTO partner.info (partner_code, type_code, name, tenant_id) VALUES ('P1','VENDOR','Partner 1',:'tst'::uuid);
INSERT INTO fleet.info (fleet_code, partner_code, type_code, name, imo_number, tenant_id)
VALUES ('F1','P1','TS','Tug 1','IMO123',:'tst'::uuid);
\echo '  expecting: duplicate key value violates unique constraint "uq_fleet_imo"'
INSERT INTO fleet.info (fleet_code, partner_code, type_code, name, imo_number, tenant_id)
VALUES ('F2','P1','TS','Tug 2','IMO123',:'tst'::uuid);

\echo
\echo '--- 6. form sample-count trigger keeps form.water_sampling.total_sample in sync ---'
INSERT INTO "user".info (user_code, name, role, tenant_id)
VALUES ('U1','User 1','OPERATOR',:'tst'::uuid)
ON CONFLICT DO NOTHING;
INSERT INTO form.water_sampling (form_no, sampling_date, tenant_id) VALUES ('FRM-1', DATE '2026-01-05',:'tst'::uuid);
INSERT INTO form.sample (form_no, sample_no, type_sample, tenant_id) VALUES ('FRM-1',1,'WATER',:'tst'::uuid),('FRM-1',2,'WATER',:'tst'::uuid);
SELECT form_no, total_sample, '  expecting total_sample = 2' AS note FROM form.water_sampling WHERE form_no='FRM-1';
DELETE FROM form.sample WHERE form_no='FRM-1' AND sample_no=2;
SELECT form_no, total_sample, '  expecting total_sample = 1' AS note FROM form.water_sampling WHERE form_no='FRM-1';

\echo
\echo '--- 7. global updated_at trigger fires ---'
SELECT form_no, (updated_at > created_at) AS updated_at_advanced,
       '  expecting t' AS note
FROM form.water_sampling WHERE form_no='FRM-1';

\echo
\echo '--- 8. telemetry partition routing + PK on (position_id, reported_at) ---'
INSERT INTO telemetry.ais_position
  (tenant_id, partner_code, fleet_code, mmsi, latitude, longitude, reported_at, received_at)
VALUES (:'tst'::uuid,'P1','F1','525000123', -6.2, 106.8,
        TIMESTAMPTZ '2026-06-01 08:00:00+07', now());
SELECT tableoid::regclass AS routed_to_partition, '  expecting telemetry.ais_position_2026' AS note
FROM telemetry.ais_position;

\echo
\echo '--- 9. telemetry triggers: latest position + geofence ENTRY/EXIT ---'
SELECT fleet_code, latitude, longitude, last_update IS NOT NULL AS has_position,
       '  expecting one row for F1' AS note
FROM telemetry.vessel_position_latest;

INSERT INTO telemetry.geofence (tenant_id, geofence_code, name, geofence_type, geom, site_code)
VALUES (:'tst'::uuid,'GF1','Jakarta Bay','AREA',
        ST_SetSRID(ST_Buffer(ST_MakePoint(106.8,-6.2)::geography, 5000)::geometry, 4326), 'S1');

-- report from ~5 degrees away (outside), then from the centre (inside)
INSERT INTO telemetry.ais_position
  (tenant_id, partner_code, fleet_code, mmsi, latitude, longitude, reported_at, received_at)
VALUES (:'tst'::uuid,'P1','F1','525000123', -1.0, 106.8,
        TIMESTAMPTZ '2026-06-01 10:00:00+07', now());
INSERT INTO telemetry.ais_position
  (tenant_id, partner_code, fleet_code, mmsi, latitude, longitude, reported_at, received_at)
VALUES (:'tst'::uuid,'P1','F1','525000123', -6.2, 106.8,
        TIMESTAMPTZ '2026-06-01 11:00:00+07', now());
SELECT event_type, count(*), '  expecting exactly 1 ENTRY' AS note
FROM telemetry.geofence_event GROUP BY 1;

\echo '--- 10. reporting matviews refresh CONCURRENTLY (needs the unique indexes) ---'
REFRESH MATERIALIZED VIEW CONCURRENTLY reporting.tide_read_daily;
REFRESH MATERIALIZED VIEW CONCURRENTLY reporting.buoy_read_daily;
REFRESH MATERIALIZED VIEW CONCURRENTLY reporting.dredging_production;
REFRESH MATERIALIZED VIEW CONCURRENTLY reporting.account_balance;
REFRESH MATERIALIZED VIEW CONCURRENTLY reporting.hse_incident_summary;
SELECT 'all 5 refreshed CONCURRENTLY' AS result;

\echo
\echo '--- 11. workflow engine end-to-end ---'
-- migration/04 added p_tenant_id; pass it explicitly because this session has
-- no security.user_scope for security.fn_get_current_tenant_id() to resolve
SELECT workflow.fn_start_instance('WF_PO_APPROVAL','PURCHASE_ORDER','PO-999','U1','NORMAL',:'tst'::uuid) AS instance_id \gset
SELECT status, current_step_order, '  expecting IN_PROGRESS / 1' AS note
FROM workflow.instance WHERE instance_id = :instance_id;
SELECT workflow.fn_process_step(:instance_id,'U1','APPROVED','ok') AS processed;
SELECT status, current_step_order,
       '  expecting IN_PROGRESS / 2 -- step 2 is the END step and is never auto-closed' AS note
FROM workflow.instance WHERE instance_id = :instance_id;

\echo
\echo '--- 12. cron jobs registered ---'
SELECT jobname, schedule, active FROM cron.job ORDER BY jobname;

\echo
\echo '--- 13. extension inventory ---'
SELECT extname FROM pg_extension ORDER BY 1;
