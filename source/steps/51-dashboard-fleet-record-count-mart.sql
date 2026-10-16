-- DDL51 · Exact all-row fleet registry count for the module index.
-- Matches the existing count(*) FROM fleet.info; no trip/status/time filter.
BEGIN;

CREATE OR REPLACE VIEW analytics.v_dashboard_fleet_record_count AS
SELECT count(*) AS fleet_record_count
  FROM fleet.info;

COMMENT ON VIEW analytics.v_dashboard_fleet_record_count IS
  'Scalar read-only count of every registered fleet.info row, matching the module-index count(*) source. No status, trip, maintenance, position, or time filter; not a count of active/in-operation vessels.';

COMMIT;
