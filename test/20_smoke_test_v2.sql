-- ============================================================
-- SMOKE TEST v2 - the layers added in this round
--   point 2  delivery_trip / trip_event / cargo_manifest / delivery_receipt
--   point 3  partitioned + composite primary keys
--   point 4  extensions
--   point 5  tenant integrity, composite FK, RLS
--   point 6  enviro provenance
--   point 7  hse.corrective_action
--   point 8  compliance registry
-- Run against a database deployed with WITH_HARDENING=1.
-- ============================================================
\set ON_ERROR_STOP off
\pset footer off
SET client_min_messages = warning;

-- make the run repeatable
TRUNCATE compliance.alert, compliance.finding, compliance.evaluation,
         compliance.entity_requirement, compliance.requirement,
         hse.corrective_action, hse.incident_witness, hse.incident,
         operational.delivery_receipt, operational.cargo_manifest,
         operational.delivery_trip_event, operational.delivery_trip,
         operational.shipment_instruction, commercial.delivery_order,
         commercial.purchase_order, enviro.reading, enviro.station,
         security.user_scope, buyer.info, fleet.info, partner.info,
         "user".info, site.info, telemetry.vessel_position_latest,
         telemetry.ais_position CASCADE;
DELETE FROM security.app_user;
DELETE FROM auth.users;

\echo '=== point 4: extensions ==='
SELECT extname FROM pg_extension
WHERE extname IN ('postgis','pgcrypto','btree_gist','pg_cron') ORDER BY 1;

\echo
\echo '=== point 3: primary keys ==='
SELECT c.relname, string_agg(a.attname, ', ' ORDER BY x.ord) AS pk_columns
FROM pg_index i
JOIN pg_class c ON c.oid = i.indrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
JOIN LATERAL unnest(i.indkey) WITH ORDINALITY x(attnum, ord) ON TRUE
JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum = x.attnum
WHERE i.indisprimary AND n.nspname = 'telemetry'
  AND c.relname IN ('ais_position','vessel_position_latest')
GROUP BY c.relname ORDER BY c.relname;

\echo
\echo '=== point 5: tenant integrity summary ==='
SELECT 'tenant_id NOT NULL' AS item, count(*)::TEXT FROM pg_attribute a
  JOIN pg_class c ON c.oid=a.attrelid JOIN pg_namespace n ON n.oid=c.relnamespace
  WHERE a.attname='tenant_id' AND a.attnotnull AND c.relkind IN ('r','p')
    AND NOT c.relispartition AND n.nspname NOT IN ('pg_catalog','information_schema','auth')
UNION ALL SELECT 'fk_tenant constraints', count(*)::TEXT FROM pg_constraint WHERE conname='fk_tenant'
UNION ALL SELECT 'composite tenant FKs',  count(*)::TEXT FROM pg_constraint
  WHERE conname LIKE 'fk\_%\_tenant' AND conname <> 'fk_tenant'
UNION ALL SELECT 'RLS enabled (tables)',  count(*)::TEXT FROM pg_class c
  JOIN pg_namespace n ON n.oid=c.relnamespace
  WHERE c.relrowsecurity AND NOT c.relispartition
    AND n.nspname NOT IN ('pg_catalog','information_schema')
UNION ALL SELECT 'RLS policies',          count(*)::TEXT FROM pg_policy;

-- ---------------------------------------------------------------- fixtures
\echo
\echo '=== fixtures: two tenants with parallel masters ==='
INSERT INTO security.tenant (tenant_code, tenant_name) VALUES ('TA','Tenant A'),('TB','Tenant B')
ON CONFLICT (tenant_code) DO NOTHING;
SELECT tenant_id AS ta FROM security.tenant WHERE tenant_code='TA' \gset
SELECT tenant_id AS tb FROM security.tenant WHERE tenant_code='TB' \gset

-- auth identities so RLS policies have something to resolve
INSERT INTO auth.users (id, email) VALUES
 ('aaaaaaaa-0000-0000-0000-000000000001','a@example.test'),
 ('bbbbbbbb-0000-0000-0000-000000000002','b@example.test')
ON CONFLICT DO NOTHING;
INSERT INTO security.app_user (auth_user_id, user_code, name) VALUES
 ('aaaaaaaa-0000-0000-0000-000000000001','U-A','User A'),
 ('bbbbbbbb-0000-0000-0000-000000000002','U-B','User B')
ON CONFLICT DO NOTHING;

INSERT INTO site.info (site_code, type_code, name, tenant_id) VALUES
 ('A-PORT','PORT','A port',:'ta'::uuid),('B-PORT','PORT','B port',:'tb'::uuid);
-- note: "user".info has no unique key on user_code alone, so no ON CONFLICT here
INSERT INTO "user".info (user_code, name, role, tenant_id) VALUES
 ('U-A','User A','MANAGER',:'ta'::uuid),('U-B','User B','MANAGER',:'tb'::uuid);
INSERT INTO partner.info (partner_code, type_code, name, tenant_id) VALUES
 ('P-A','VENDOR','Partner A',:'ta'::uuid),('P-B','VENDOR','Partner B',:'tb'::uuid);
INSERT INTO fleet.info (fleet_code, partner_code, type_code, name, tenant_id) VALUES
 ('F-A','P-A','TS','Tug A',:'ta'::uuid),('F-B','P-B','TS','Tug B',:'tb'::uuid);
INSERT INTO buyer.info (buyer_code, name, tenant_id) VALUES
 ('BUY-A','Buyer A',:'ta'::uuid),('BUY-B','Buyer B',:'tb'::uuid);

INSERT INTO security.user_scope (auth_user_id, tenant_id, role_code, is_primary) VALUES
 ('aaaaaaaa-0000-0000-0000-000000000001',:'ta'::uuid,'MANAGER', TRUE),
 ('bbbbbbbb-0000-0000-0000-000000000002',:'tb'::uuid,'MANAGER', TRUE);

INSERT INTO commercial.purchase_order
 (po_num, buyer_code, po_date, uom_code, total_volume, unit_price, currency_code, tenant_id)
VALUES ('PO-A1','BUY-A', DATE '2026-05-01','M3', 1000, 50000,'IDR',:'ta'::uuid);
INSERT INTO commercial.delivery_order
 (do_num, po_num, do_date, uom_code, target_volume, tenant_id)
VALUES ('DO-A1','PO-A1', DATE '2026-05-10','M3', 500,:'ta'::uuid);
INSERT INTO operational.shipment_instruction (si_num, do_num, fleet_main_code, tenant_id)
VALUES ('SI-A1','DO-A1','F-A',:'ta'::uuid);

\echo
\echo '=== point 5: composite FK blocks a cross-tenant reference ==='
\echo '  tenant A PO pointing at tenant B buyer - expecting fk_po_buyer_tenant'
INSERT INTO commercial.purchase_order
 (po_num, buyer_code, po_date, uom_code, total_volume, unit_price, currency_code, tenant_id)
VALUES ('PO-X','BUY-B', DATE '2026-05-01','M3', 1000, 50000,'IDR',:'ta'::uuid);

\echo '  tenant B SI using a tenant A vessel - expecting fk_si_fleet_main_tenant'
INSERT INTO operational.shipment_instruction (si_num, do_num, fleet_main_code, tenant_id)
VALUES ('SI-X','DO-A1','F-A',:'tb'::uuid);

\echo
\echo '=== point 2: trip lifecycle, stamped only by milestone events ==='
INSERT INTO operational.delivery_trip
 (trip_no, si_num, do_num, fleet_code, planned_arrive_at, tenant_id)
VALUES ('TRIP-1','SI-A1','DO-A1','F-A', TIMESTAMPTZ '2026-05-11 10:00:00+07',:'ta'::uuid);
SELECT trip_no,
       (actual_load_at IS NULL AND actual_depart_at IS NULL
        AND actual_arrive_at IS NULL AND actual_deliver_at IS NULL) AS nothing_recorded
FROM operational.delivery_trip WHERE trip_no='TRIP-1';

INSERT INTO operational.delivery_trip_event (trip_id, event_type, event_time, tenant_id)
SELECT trip_id,'LOADING',  TIMESTAMPTZ '2026-05-10 06:00:00+07',:'ta'::uuid FROM operational.delivery_trip WHERE trip_no='TRIP-1'
UNION ALL SELECT trip_id,'DEPARTED', TIMESTAMPTZ '2026-05-10 08:00:00+07',:'ta'::uuid FROM operational.delivery_trip WHERE trip_no='TRIP-1'
UNION ALL SELECT trip_id,'ARRIVED',  TIMESTAMPTZ '2026-05-11 12:30:00+07',:'ta'::uuid FROM operational.delivery_trip WHERE trip_no='TRIP-1';

SELECT trip_no,
       to_char(actual_load_at,'MM-DD HH24:MI')   AS loaded,
       to_char(actual_depart_at,'MM-DD HH24:MI') AS departed,
       to_char(actual_arrive_at,'MM-DD HH24:MI') AS arrived,
       '  stamped by trg_sync_trip_from_event' AS note
FROM operational.delivery_trip WHERE trip_no='TRIP-1';

\echo '  a milestone cannot be recorded twice - expecting uq_trip_event_once'
INSERT INTO operational.delivery_trip_event (trip_id, event_type, event_time, tenant_id)
SELECT trip_id,'ARRIVED', TIMESTAMPTZ '2026-05-11 13:00:00+07',:'ta'::uuid FROM operational.delivery_trip WHERE trip_no='TRIP-1';

\echo '  a DELAYED event moves the ETA and the derived delay_minutes'
INSERT INTO operational.delivery_trip_event (trip_id, event_type, event_time, delay_minutes, delay_reason, tenant_id)
SELECT trip_id,'DELAYED', TIMESTAMPTZ '2026-05-11 09:00:00+07', 150,'weather',:'ta'::uuid
FROM operational.delivery_trip WHERE trip_no='TRIP-1';
SELECT trip_no, to_char(eta,'MM-DD HH24:MI') AS eta, delay_minutes
FROM operational.delivery_trip WHERE trip_no='TRIP-1';

\echo
\echo '=== point 2: manifest (measured) and receipt (accepted) ==='
INSERT INTO operational.cargo_manifest
 (manifest_no, trip_id, uom_code, loaded_volume, discharged_volume, measurement_method, is_valid, tenant_id)
SELECT 'MAN-1', trip_id,'M3', 480, 470,'DRAFT_SURVEY', TRUE,:'ta'::uuid
FROM operational.delivery_trip WHERE trip_no='TRIP-1';
SELECT manifest_no, loaded_volume, discharged_volume, loss_volume,
       '  loss_volume derived' AS note
FROM operational.cargo_manifest WHERE manifest_no='MAN-1';

INSERT INTO operational.delivery_receipt
 (receipt_no, trip_id, manifest_id, buyer_code, received_at, uom_code, received_volume,
  receiver_name, status, tenant_id)
SELECT 'RCPT-1', t.trip_id, m.manifest_id,'BUY-A', TIMESTAMPTZ '2026-05-11 14:00:00+07','M3', 465,
       'Site Receiver','APPROVED',:'ta'::uuid
FROM operational.delivery_trip t JOIN operational.cargo_manifest m ON m.trip_id=t.trip_id
WHERE t.trip_no='TRIP-1';

\echo
\echo '=== point 2: fulfillment from manifest + receipt, not from the DO ==='
SELECT * FROM operational.fn_do_fulfilled_volume('DO-A1');
SELECT target_volume AS do_target,
       operational.fn_do_fulfillment_pct('DO-A1') AS fulfilled_pct,
       '  465 / 500 = 93.00' AS note
FROM commercial.delivery_order WHERE do_num='DO-A1';

\echo '  invalidating the manifest drops it out of fulfillment'
UPDATE operational.cargo_manifest SET is_valid = FALSE WHERE manifest_no='MAN-1';
SELECT operational.fn_do_fulfillment_pct('DO-A1') AS pct_after_invalidating, '  expecting 0.00' AS note;
UPDATE operational.cargo_manifest SET is_valid = TRUE  WHERE manifest_no='MAN-1';

\echo
\echo '=== point 7: corrective action as a monitored entity ==='
INSERT INTO hse.incident (incident_no, incident_type, severity, incident_date, title, description, tenant_id)
VALUES ('INC-A1','INJURY','HIGH', TIMESTAMPTZ '2026-05-12 09:00:00+07','Fall','Desc',:'ta'::uuid);
INSERT INTO hse.corrective_action
 (action_no, source_type, source_id, incident_id, title, owner_user_code, due_date, tenant_id)
SELECT 'CA-1','INCIDENT', incident_id, incident_id,'Install guard rail','U-A',
       CURRENT_DATE - 3,:'ta'::uuid
FROM hse.incident WHERE incident_no='INC-A1';
SELECT action_no, days_overdue, '  overdue work surfaces on its own' AS note
FROM hse.v_overdue_actions;

\echo '  closing without verification must be refused - expecting chk_ca_close_requires_verify'
UPDATE hse.corrective_action SET closed_at = now() WHERE action_no='CA-1';

\echo
\echo '=== point 8: compliance registry ==='
INSERT INTO compliance.requirement
 (requirement_code, requirement_name, category, applies_to, valid_for_days, warn_days_before) VALUES
 ('VESSEL_SEACERT','Seaworthiness Certificate','VESSEL_CERTIFICATE','FLEET', 365, 45),
 ('CREW_BST','Basic Safety Training','CREW_CERTIFICATE','PERSON', 1825, 60);
-- one expired obligation
INSERT INTO compliance.entity_requirement
 (requirement_id, entity_type, fleet_code, reference_no, expiry_date, tenant_id)
SELECT requirement_id,'FLEET','F-A','SC-001', CURRENT_DATE - 1,:'ta'::uuid
FROM compliance.requirement WHERE requirement_code='VESSEL_SEACERT';
-- one expiring soon (inside its own 60-day warning window)
INSERT INTO compliance.entity_requirement
 (requirement_id, entity_type, person_user_code, reference_no, expiry_date, tenant_id)
SELECT requirement_id,'PERSON','U-A','BST-001', CURRENT_DATE + 10,:'ta'::uuid
FROM compliance.requirement WHERE requirement_code='CREW_BST';

SELECT requirement_code, COALESCE(fleet_code, person_user_code) AS subject,
       days_to_expiry, has_document, status
FROM compliance.v_requirement_status ORDER BY expiry_date;

SELECT compliance.fn_scan_requirements() AS alerts_raised;
SELECT alert_type, count(*) FROM compliance.alert GROUP BY 1 ORDER BY 1;
\echo '  re-running the scan must not duplicate live alerts:'
SELECT compliance.fn_scan_requirements() AS second_run,
       (SELECT count(*) FROM compliance.alert WHERE NOT is_acknowledged) AS live_alerts,
       '  expecting 0 new, 2 live' AS note;

\echo '  one requirement per subject - expecting uq_entity_requirement_subject'
INSERT INTO compliance.entity_requirement
 (requirement_id, entity_type, fleet_code, reference_no, expiry_date, tenant_id)
SELECT requirement_id,'FLEET','F-A','SC-999', CURRENT_DATE + 100,:'ta'::uuid
FROM compliance.requirement WHERE requirement_code='VESSEL_SEACERT';

\echo '  a row must name exactly one subject - expecting chk_entity_one_subject'
INSERT INTO compliance.entity_requirement
 (requirement_id, entity_type, fleet_code, site_code, expiry_date, tenant_id)
SELECT requirement_id,'FLEET','F-A','A-PORT', CURRENT_DATE + 100,:'ta'::uuid
FROM compliance.requirement WHERE requirement_code='VESSEL_SEACERT';

\echo
\echo '=== point 6: enviro provenance ==='
INSERT INTO enviro.station (station_code, name, station_type, expected_interval_minutes, tenant_id)
VALUES ('ST-A1','Station A1','BUOY', 15,:'ta'::uuid);
INSERT INTO enviro.reading (station_code, reading_type, record_time, received_at, data_quality, source_system, tenant_id)
VALUES ('ST-A1','BUOY', now() - INTERVAL '40 minutes', now() - INTERVAL '38 minutes','GOOD','AIS_FEED',:'ta'::uuid);
SELECT ingest_latency_seconds, data_quality, source_system FROM enviro.reading WHERE station_code='ST-A1';
SELECT station_code, expected_interval_minutes, minutes_since_last, latency_status,
       '  40 min late against a 15 min promise' AS note
FROM enviro.v_station_latency WHERE station_code='ST-A1';
