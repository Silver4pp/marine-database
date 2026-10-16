-- DDL44 · Read-only analytics projection for explicit fleet maintenance windows.
-- One row per existing window; active_now is a current-time flag, not an idle/readiness decision.
BEGIN;

CREATE OR REPLACE VIEW analytics.v_fleet_maintenance_window AS
SELECT m.maintenance_id,
       m.fleet_code,
       f.fleet_name,
       m.jenis,
       m.window_start,
       m.window_end,
       (m.window_start <= now() AND m.window_end > now()) AS active_now
  FROM fleet.vessel_maintenance m
  JOIN fleet.info f ON f.fleet_code=m.fleet_code;

COMMENT ON VIEW analytics.v_fleet_maintenance_window IS
  'Read-only projection, one row per fleet.vessel_maintenance window. active_now means window_start <= database now < window_end; this is not vessel idle/readiness, a maintenance approval, or proof of field conditions.';

COMMIT;
