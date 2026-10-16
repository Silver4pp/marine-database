-- DDL48 · Aggregate recorded toolbox plans/outcomes at unit/week grain.
-- Keeps the existing rows and semantics; no meeting data or target is created.
BEGIN;

CREATE OR REPLACE VIEW analytics.v_hse_toolbox_weekly AS
SELECT unit_kode,
       period_week,
       count(*) AS planned,
       count(*) FILTER (WHERE held) AS held
  FROM hse.toolbox_meeting
 GROUP BY unit_kode, period_week;

COMMENT ON VIEW analytics.v_hse_toolbox_weekly IS
  'Read-only unit/week summary of recorded hse.toolbox_meeting rows. planned counts stored rows; held counts rows marked held. Not evidence of attendance or completeness of the plan.';

COMMIT;
