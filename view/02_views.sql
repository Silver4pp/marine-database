-- ============================================================
-- VIEW LAYER / 2: Regular views
-- file    : view/02_views.sql
-- note    : Hand-written, not generated. Runs after view/01_materialized_views.sql
--           and before index/01_indexes.sql.
--
--           These are the monitoring surfaces the new layers expose. Every one of
--           them answers an operational question that previously required an ad-hoc
--           query: what HSE work is late, which obligation is lapsing, which
--           station has gone quiet, and where each environmental number came from.
-- depends : feature/10_enviro.sql, feature/22_enviro.sql, feature/15_hse.sql,
--           feature/23_hse.sql, feature/24_compliance.sql
-- ============================================================

\set ON_ERROR_STOP on

-- ------------------------------------------------------------
-- hse.v_overdue_actions
-- Open corrective actions plus anything that was closed late. days_overdue stops
-- counting once the action is closed, so a closed row never keeps ageing.
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW hse.v_overdue_actions AS
SELECT
    ca.action_id,
    ca.action_no,
    ca.title,
    ca.source_type,
    ca.source_id,
    ca.incident_id,
    ca.finding_id,
    ca.severity,
    ca.owner_user_code,
    u.name AS owner_name,
    ca.site_code,
    ca.status,
    ca.opened_at,
    ca.due_date,
    ca.completed_at,
    ca.verified_by,
    ca.closed_at,
    hse.fn_days_overdue(ca.due_date, ca.closed_at) AS days_overdue,
    CASE
        WHEN ca.closed_at IS NOT NULL AND ca.closed_at::DATE > ca.due_date THEN 'CLOSED_LATE'
        WHEN ca.closed_at IS NOT NULL                                      THEN 'CLOSED'
        WHEN ca.due_date <  CURRENT_DATE                                   THEN 'OVERDUE'
        WHEN ca.due_date =  CURRENT_DATE                                   THEN 'DUE_TODAY'
        ELSE 'OPEN'
    END AS ageing_status,
    ca.tenant_id
FROM hse.corrective_action ca
LEFT JOIN "user".info u ON u.user_code = ca.owner_user_code
WHERE ca.closed_at IS NULL
   OR hse.fn_days_overdue(ca.due_date, ca.closed_at) > 0;

-- ------------------------------------------------------------
-- compliance.v_requirement_status
-- One row per obligation per subject, graded live. `status` is the same grade
-- fn_scan_requirements() writes, so the dashboard and the alert queue can never
-- disagree.
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW compliance.v_requirement_status AS
SELECT
    er.entity_req_id,
    req.requirement_id,
    req.requirement_code,
    req.requirement_name,
    req.category,
    req.applies_to,
    req.severity,
    req.evidence_required,
    er.entity_type,
    er.fleet_code,
    er.site_code,
    er.buyer_code,
    er.partner_code,
    er.person_user_code,
    er.document_id,
    er.reference_no,
    er.effective_from,
    er.expiry_date,
    (er.expiry_date - CURRENT_DATE) AS days_to_expiry,
    (er.document_id IS NOT NULL)    AS has_document,
    d.document_code AS evidence_document_code,
    d.document_name AS evidence_document_name,
    compliance.fn_grade(er.expiry_date, req.warn_days_before,
                        req.evidence_required, er.document_id IS NOT NULL) AS status,
    er.last_verified_at,
    er.responsible_user,
    er.is_active,
    (SELECT a.alert_type
       FROM compliance.alert a
      WHERE a.entity_req_id = er.entity_req_id AND a.is_active = TRUE
      ORDER BY a.created_at DESC LIMIT 1) AS open_alert_type,
    er.tenant_id
FROM compliance.entity_requirement er
JOIN compliance.requirement req ON req.requirement_id = er.requirement_id
LEFT JOIN document.document d      ON d.document_id = er.document_id;

-- ------------------------------------------------------------
-- enviro.v_station_latency
-- Which continuous-sensor station has gone quiet, measured against the cadence
-- the station itself promises. CRITICAL past twice the expected interval.
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW enviro.v_station_latency AS
SELECT
    s.station_code,
    s.name                    AS station_name,
    s.station_type,
    s.site_code,
    s.expected_interval_minutes,
    s.expected_interval_minutes * 2 AS critical_after_minutes,
    latest.last_record_time,
    latest.last_received_at,
    latest.last_source_system,
    latest.last_data_quality,
    latest.last_delay_status,
    ROUND(EXTRACT(EPOCH FROM (now() - latest.last_record_time)) / 60)::INT AS minutes_since_last,
    CASE
        WHEN latest.last_record_time IS NULL THEN 'NO_DATA'
        WHEN (now() - latest.last_record_time)
             > make_interval(mins => s.expected_interval_minutes * 2) THEN 'CRITICAL'
        WHEN (now() - latest.last_record_time)
             > make_interval(mins => s.expected_interval_minutes)     THEN 'WARN'
        ELSE 'ON_TIME'
    END AS latency_status,
    s.tenant_id
FROM enviro.station s
LEFT JOIN LATERAL (
    SELECT r.record_time   AS last_record_time,
           r.received_at   AS last_received_at,
           r.source_system AS last_source_system,
           r.data_quality  AS last_data_quality,
           r.delay_status  AS last_delay_status
    FROM enviro.reading r
    WHERE r.station_code = s.station_code
    ORDER BY r.record_time DESC
    LIMIT 1
) latest ON TRUE;

-- ------------------------------------------------------------
-- enviro.v_reading_provenance
-- The one place a dashboard reads environmental measurements from. It carries the
-- data source, when it was measured, when it arrived, the quality flag and the
-- delay status, and it names the canonical path the row came in on - which is
-- what keeps tide_reading / buoy_reading out of new dashboards.
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW enviro.v_reading_provenance AS
SELECT
    'CONTINUOUS_SENSOR'          AS data_path,
    r.id                         AS reading_id,
    r.station_code,
    r.reading_type               AS subject,
    r.record_time,
    r.received_at,
    r.ingest_latency_seconds,
    r.delay_status,
    r.data_quality,
    r.source_system,
    r.salinity, r.turbidity, r.current_speed, r.current_direction,
    r.dissolved_oxygen, r.water_density, r.tide_level, r.wave_height,
    r.wind_speed, r.wind_direction, r.air_temperature, r.pressure, r.visibility,
    r.recorded_by,
    r.tenant_id
FROM enviro.reading r
UNION ALL
SELECT
    'FIELD_SURVEY'               AS data_path,
    m.id                         AS reading_id,
    ws.site_code                 AS station_code,
    m.parameter_name             AS subject,
    COALESCE(m.measured_at, m.received_at) AS record_time,
    m.received_at,
    GREATEST(0, ROUND(EXTRACT(EPOCH FROM (m.received_at - COALESCE(m.measured_at, m.received_at))))::INT)
                                 AS ingest_latency_seconds,
    CASE WHEN m.received_at - COALESCE(m.measured_at, m.received_at) > INTERVAL '2 hours' THEN 'DELAYED'
         ELSE 'ON_TIME' END      AS delay_status,
    m.data_quality,
    m.source_system,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    ws.recorder_by               AS recorded_by,
    m.tenant_id
FROM survey.measurement m
JOIN survey.water_sampling ws ON ws.form_no = m.form_no;

COMMENT ON VIEW enviro.v_reading_provenance IS
    'Canonical environmental read path. Legacy enviro.tide_reading / enviro.buoy_reading are deliberately absent.';
