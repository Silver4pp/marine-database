-- DDL46 · Exact read-only executive-dashboard summary of open EWS events.
-- Preserves the existing dashboard predicate: every ews_event with closed_at IS NULL.
BEGIN;

CREATE OR REPLACE VIEW analytics.v_dashboard_ews_open AS
SELECT count(*)::bigint AS ews_terbuka
  FROM enviro.ews_event
 WHERE closed_at IS NULL;

COMMENT ON VIEW analytics.v_dashboard_ews_open IS
  'One-row read-only dashboard metric: exact count of all enviro.ews_event rows with closed_at IS NULL. No level, source, age, owner, or severity filter is applied.';

COMMIT;
