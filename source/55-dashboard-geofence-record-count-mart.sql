-- DDL55 · Exact all-row count of registered geofence definitions for the module index.
-- Preserves count(*) FROM telemetry.geofence; does not count events or filter type/geometry.
BEGIN;

CREATE OR REPLACE VIEW analytics.v_dashboard_geofence_record_count AS
SELECT count(*) AS geofence_record_count
  FROM telemetry.geofence;

COMMENT ON VIEW analytics.v_dashboard_geofence_record_count IS
  'Scalar read-only count of all telemetry.geofence registry rows, matching the module-index source. Does not count geofence events or filter fence_type, geometry, radius, status, or time.';

COMMIT;
