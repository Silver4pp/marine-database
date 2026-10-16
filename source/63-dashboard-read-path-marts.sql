-- DDL63 · Exact-grain analytics readers for W4 map, PWA, and operational health.
-- These views preserve the existing source keys, joins, predicates and output grain;
-- they do not materialize, filter by user, or mutate business/workflow rows.
BEGIN;

CREATE OR REPLACE VIEW analytics.v_dashboard_station_map AS
SELECT DISTINCT s.station_code, s.station_name,
       ST_X(s.location::geometry) AS lon,
       ST_Y(s.location::geometry) AS lat,
       (SELECT count(*) FROM enviro.ews_event e
         WHERE e.station_code=s.station_code AND e.closed_at IS NULL) AS ews_aktif
  FROM enviro.station s;
COMMENT ON VIEW analytics.v_dashboard_station_map IS
  'One row per enviro.station; coordinates are the stored PostGIS location and ews_aktif counts every unclosed EWS event for the same station_code.';

CREATE OR REPLACE VIEW analytics.v_dashboard_work_area_map AS
SELECT w.area_code, w.permit_no, z.zone_code, z.quota_m3, z.quota_used_m3,
       round(z.quota_used_m3/z.quota_m3*100,0) AS pct,
       ST_AsGeoJSON(w.geom) AS geo
  FROM operational.work_area w
  JOIN operational.work_zone z USING (zone_code)
 WHERE w.status='AKTIF';
COMMENT ON VIEW analytics.v_dashboard_work_area_map IS
  'Active work areas inner-joined to work_zone by zone_code; preserves the map reader quota percentage and stored work_area geometry.';

CREATE OR REPLACE VIEW analytics.v_dashboard_work_zone_map AS
SELECT DISTINCT zone_code, zone_name, ST_AsGeoJSON(geom) AS geo
  FROM operational.work_zone
 WHERE geom IS NOT NULL;
COMMENT ON VIEW analytics.v_dashboard_work_zone_map IS
  'All work-zone rows with stored geometry; intentionally has no status filter, matching the map reader.';

CREATE OR REPLACE VIEW analytics.v_dashboard_site_map AS
SELECT DISTINCT buyer_site_id, site_code, note
  FROM buyer.site;
COMMENT ON VIEW analytics.v_dashboard_site_map IS
  'One row per buyer.site primary key; ordering remains the caller responsibility.';

CREATE OR REPLACE VIEW analytics.v_dashboard_trip_map_context AS
SELECT t.trip_id, t.trip_no, t.fleet_code, t.status, t.work_area_code,
       d.vessel_name, sc.site_code,
       (t.ts_closed IS NOT NULL) AS selesai,
       (t.ts_bap_signed IS NOT NULL) AS bap,
       (t.ts_discharge_end IS NOT NULL) AS bongkar_end,
       (t.ts_discharge_start IS NOT NULL) AS bongkar,
       (t.ts_arrived IS NOT NULL) AS tiba,
       (t.ts_departed IS NOT NULL) AS brgkt,
       (t.ts_loading_start IS NOT NULL) AS muat
  FROM operational.trip t
  LEFT JOIN operational.shipment_instruction si ON si.si_num=t.si_num
  LEFT JOIN commercial.delivery_order d ON d.do_id=si.do_id
  LEFT JOIN commercial.purchase_order po ON po.po_id=d.po_id
  LEFT JOIN commercial.sales_contract sc ON sc.sales_contract_id=po.sales_contract_id;
COMMENT ON VIEW analytics.v_dashboard_trip_map_context IS
  'One row per operational.trip with the map reader’s LEFT JOIN chain trip→SI→DO→PO→sales_contract and unchanged phase flags.';

CREATE OR REPLACE VIEW analytics.v_dashboard_pwa_device_rows AS
SELECT h.*, t.trip_no, t.status AS trip_status
  FROM operational.pwa_device_health h
  LEFT JOIN operational.trip t USING (trip_id);
COMMENT ON VIEW analytics.v_dashboard_pwa_device_rows IS
  'PWA heartbeat rows with the existing optional trip context; user/ACL filtering, stale-hours parameter, order and limit remain in the application.';

CREATE OR REPLACE VIEW analytics.v_dashboard_pwa_report_detail AS
SELECT v.report_id, v.perangkat, v.latensi_menit, m.created_at
  FROM analytics.v_pwa_sinkron v
  JOIN operational.manual_report m USING (report_id);
COMMENT ON VIEW analytics.v_dashboard_pwa_report_detail IS
  'PWA report mart joined to the original manual_report creation timestamp; one row per report_id, used only for the reporter latest-latency ordering.';

CREATE OR REPLACE VIEW analytics.v_dashboard_health_weather AS
SELECT max(diperbarui) AS newest_weather_at
  FROM operational.cuaca_grid;
COMMENT ON VIEW analytics.v_dashboard_health_weather IS
  'Scalar maximum cuaca_grid.diperbarui used only for cache age; does not assert forecast coverage or snapshot completeness.';

CREATE OR REPLACE VIEW analytics.v_dashboard_health_email AS
SELECT min(created_at) FILTER (WHERE status IN ('QUEUED','WAITING_SMTP','RETRY')) AS oldest_queued_at,
       count(*) FILTER (WHERE status IN ('FAILED','PARTIAL','UNKNOWN','BLOCKED')
          OR (status='SENDING' AND alarm_id IS NULL AND attachment_sha256 IS NOT NULL
              AND (delivery_claimed_at IS NULL
                   OR delivery_claimed_at < now()-interval '15 minutes'))) AS failed_count
  FROM notification.email_outbox;
COMMENT ON VIEW analytics.v_dashboard_health_email IS
  'Exact operational_health.collect email predicate: oldest QUEUED/WAITING_SMTP/RETRY and FAILED/PARTIAL/UNKNOWN/BLOCKED plus qualifying stale SENDING; not the all-row outbox count.';

CREATE OR REPLACE VIEW analytics.v_dashboard_health_bi AS
SELECT EXISTS (SELECT 1 FROM param.system_parameter
                WHERE param_key='BI_TOKEN' AND length(trim(nilai))>0) AS token_available;
COMMENT ON VIEW analytics.v_dashboard_health_bi IS
  'Boolean BI token-presence signal only; never exposes the token value and does not prove BI use.';

CREATE OR REPLACE VIEW analytics.v_dashboard_health_job_run AS
SELECT DISTINCT ON (job_name)
       job_name, status, started_at, finished_at, result, error_code, slot_at, trigger_kind
  FROM param.job_run
 WHERE status<>'SKIPPED'
 ORDER BY job_name, started_at DESC, run_id DESC;
COMMENT ON VIEW analytics.v_dashboard_health_job_run IS
  'One latest non-SKIPPED run per job_name, using the original started_at DESC, run_id DESC ordering; job allowlist and freshness limits remain in the application.';

COMMIT;
