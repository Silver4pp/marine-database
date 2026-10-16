-- DDL49 · Exact all-row HSE incident-count projection for the module index.
-- Includes soft-deleted rows, matching the existing count(*) consumer predicate.
BEGIN;

CREATE OR REPLACE VIEW analytics.v_dashboard_hse_incident_count AS
SELECT count(*) AS incident_record_count
  FROM hse.incident;

COMMENT ON VIEW analytics.v_dashboard_hse_incident_count IS
  'One-row count of all persisted hse.incident rows, including soft-deleted rows, preserving the module-index count(*) predicate. Not an active-incident, severity, or safety-performance measure.';

COMMIT;
