-- ============================================================
-- VIEW LAYER / 1: Materialized views
-- file    : view/01_materialized_views.sql
-- objects : 5 statement(s)
-- note    : Built WITH DATA, so it must run after every source table is populated.
-- generated from original/schema_v1_original.sql by tools/split_schema.py
-- ============================================================

-- ============================================================
-- SECTION 24: REPORTING MATERIALIZED VIEWS
-- ============================================================

CREATE MATERIALIZED VIEW reporting.tide_read_daily (
    tenant_id, station_code, station_name, site_code, record_date,
    reading_count, avg_tide_level, min_tide_level, max_tide_level,
    avg_salinity, avg_dissolved_oxygen, last_reading_time
) AS
SELECT
    COALESCE(s.tenant_id, '00000000-0000-0000-0000-000000000000'::UUID),
    s.station_code, s.name, s.site_code,
    DATE_TRUNC('day', tr.record_time),
    COUNT(*)::INT, AVG(tr.tide_level), MIN(tr.tide_level), MAX(tr.tide_level),
    AVG(tr.salinity), AVG(tr.dissolved_oxygen), MAX(tr.record_time)
FROM enviro.tide_reading tr
JOIN enviro.station s ON s.station_code = tr.station_code
GROUP BY s.tenant_id, s.station_code, s.name, s.site_code, DATE_TRUNC('day', tr.record_time)
WITH DATA;

CREATE MATERIALIZED VIEW reporting.buoy_read_daily (
    tenant_id, station_code, station_name, site_code, record_date,
    reading_count, avg_tide_level, avg_salinity, avg_current_speed
) AS
SELECT
    COALESCE(s.tenant_id, '00000000-0000-0000-0000-000000000000'::UUID),
    s.station_code, s.name, s.site_code,
    DATE_TRUNC('day', br.record_time),
    COUNT(*)::INT, AVG(br.tide_level), AVG(br.salinity), AVG(br.current_speed)
FROM enviro.buoy_reading br
JOIN enviro.station s ON s.station_code = br.station_code
GROUP BY s.tenant_id, s.station_code, s.name, s.site_code, DATE_TRUNC('day', br.record_time)
WITH DATA;

CREATE MATERIALIZED VIEW reporting.dredging_production (
    tenant_id, si_num, do_num, po_num, buyer_code, buyer_name,
    fleet_code, fleet_name, work_date, daily_volume, uom_code, record_count
) AS
SELECT
    COALESCE(si.tenant_id, '00000000-0000-0000-0000-000000000000'::UUID),
    si.si_num, si.do_num, p.po_num, p.buyer_code, b.name,
    fa.fleet_code, fa.name,
    DATE_TRUNC('day', dr.record_date),
    SUM(dr.dredging_volume), dr.uom_code, COUNT(dr.id)::INT
FROM operational.dredging_records dr
JOIN operational.shipment_instruction si ON si.si_num = dr.si_num
JOIN commercial.delivery_order d_o ON d_o.do_num = si.do_num
JOIN commercial.purchase_order p ON p.po_num = d_o.po_num
JOIN buyer.info b ON b.buyer_code = p.buyer_code
JOIN fleet.info fa ON fa.fleet_code = si.fleet_main_code
GROUP BY si.tenant_id, si.si_num, si.do_num, p.po_num, p.buyer_code, b.name,
         fa.fleet_code, fa.name, DATE_TRUNC('day', dr.record_date), dr.uom_code
WITH DATA;

CREATE MATERIALIZED VIEW reporting.account_balance (
    account_code, account_name, account_type, tenant_id,
    total_debit, total_credit, balance, currency_code
) AS
SELECT
    fa.account_code, fa.account_name, fa.account_type,
    COALESCE(fjl.tenant_id, '00000000-0000-0000-0000-000000000000'::UUID),
    COALESCE(SUM(fjl.debit), 0), COALESCE(SUM(fjl.credit), 0),
    COALESCE(SUM(fjl.debit), 0) - COALESCE(SUM(fjl.credit), 0),
    fjl.currency_code
FROM financial.account fa
LEFT JOIN financial.journal_line fjl ON fjl.account_code = fa.account_code
LEFT JOIN financial.journal fj ON fj.journal_id = fjl.journal_id AND fj.is_posted = TRUE
GROUP BY fa.account_code, fa.account_name, fa.account_type, fjl.tenant_id, fjl.currency_code
WITH DATA;

CREATE MATERIALIZED VIEW reporting.hse_incident_summary (
    tenant_id, incident_type, type_name, severity, incident_month,
    incident_count, closed_count, open_count
) AS
SELECT
    COALESCE(hi.tenant_id, '00000000-0000-0000-0000-000000000000'::UUID),
    hi.incident_type, hit.type_name, hi.severity,
    DATE_TRUNC('month', hi.incident_date),
    COUNT(*)::INT,
    COUNT(CASE WHEN hi.status = 'CLOSED' THEN 1 END)::INT,
    COUNT(CASE WHEN hi.status != 'CLOSED' THEN 1 END)::INT
FROM hse.incident hi
JOIN hse.incident_type hit ON hit.type_code = hi.incident_type
GROUP BY hi.tenant_id, hi.incident_type, hit.type_name, hi.severity,
         DATE_TRUNC('month', hi.incident_date)
WITH DATA;
