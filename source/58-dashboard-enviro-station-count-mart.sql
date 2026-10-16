-- DDL58 · Exact all-row count of registered environmental monitoring stations.
-- Preserves count(*) FROM enviro.station; does not count stations with readings.
BEGIN;

CREATE OR REPLACE VIEW analytics.v_dashboard_enviro_station_count AS
SELECT count(*) AS enviro_station_count
  FROM enviro.station;

COMMENT ON VIEW analytics.v_dashboard_enviro_station_count IS
  'Scalar read-only count of all enviro.station registry rows keyed by station_code; no station_type, location, reading, status, date, or time-zone filter.';

COMMIT;
