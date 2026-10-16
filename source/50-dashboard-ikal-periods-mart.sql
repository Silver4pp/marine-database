-- DDL50 · Exact distinct IKAL period tokens carried by IKAL EWS events.
-- Mirrors COUNT(DISTINCT value_snapshot->>'periode') semantics: NULL is ignored;
-- no closed/status/date/time-zone filter or normalization is added.
BEGIN;

CREATE OR REPLACE VIEW analytics.v_dashboard_ikal_periods AS
SELECT DISTINCT value_snapshot->>'periode' AS periode
  FROM enviro.ews_event
 WHERE parameter_code='IKAL'
   AND value_snapshot->>'periode' IS NOT NULL;

COMMENT ON VIEW analytics.v_dashboard_ikal_periods IS
  'Distinct non-null period text tokens from enviro.ews_event rows with parameter_code IKAL. Preserves the module-index COUNT(DISTINCT value_snapshot->>periode) source; no status, age, date, time-zone, or normalization filter.';

COMMIT;
