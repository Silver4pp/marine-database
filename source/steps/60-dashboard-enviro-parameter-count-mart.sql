-- DDL60 · Exact all-row count of environmental monitoring parameter master records.
-- Preserves count(*) FROM enviro.mon_parameter; do not filter is_active or standards.
BEGIN;

CREATE OR REPLACE VIEW analytics.v_dashboard_enviro_parameter_count AS
SELECT count(*) AS enviro_parameter_count
  FROM enviro.mon_parameter;

COMMENT ON VIEW analytics.v_dashboard_enviro_parameter_count IS
  'Scalar read-only count of all enviro.mon_parameter master rows keyed by parameter_code; includes inactive or incomplete standards and applies no group/date/time-zone filter.';

COMMIT;
