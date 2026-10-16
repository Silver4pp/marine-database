-- DDL65 · Exact-grain W4 Kokpit readers.
-- The views are additive, idempotent, non-updatable projections. Dynamic ACL,
-- status, ordering, limit, and latest-run selection stay in control_views.cockpit.
-- Stateful details/actions/locks continue to read and update their source tables.
BEGIN;

CREATE OR REPLACE VIEW analytics.v_dashboard_cockpit_alarm_records AS
SELECT a.*
  FROM notification.alarm AS a
 CROSS JOIN (VALUES (1)) AS read_only_guard(singleton);
COMMENT ON VIEW analytics.v_dashboard_cockpit_alarm_records IS
  'One-to-one pass-through of notification.alarm at alarm_id grain. Role-array, module ACL, non-CLOSED predicate, severity/opened_at ordering and limit stay in control_views.cockpit; detail, workflow, history and FOR UPDATE operations remain source-backed.';

CREATE OR REPLACE VIEW analytics.v_dashboard_cockpit_contract_policy_rows AS
SELECT c.sales_contract_id, c.contract_no, c.date_end, c.currency_code,
       c.free_time_hours, c.standby_rate_per_hour, c.is_active,
       p.enabled, p.approved_by, p.basis, p.rounding
  FROM commercial.sales_contract AS c
  LEFT JOIN commercial.standby_policy AS p USING (sales_contract_id)
 CROSS JOIN (VALUES (1)) AS read_only_guard(singleton);
COMMENT ON VIEW analytics.v_dashboard_cockpit_contract_policy_rows IS
  'One row per sales_contract_id, preserving the cockpit LEFT JOIN to the optional unique standby_policy row. The is_active predicate, date_end NULLS LAST order, 100-row limit and finance/deposit ACL stay in control_views.cockpit; policy edits continue to lock/read the source tables.';

CREATE OR REPLACE VIEW analytics.v_dashboard_cockpit_job_run_records AS
SELECT j.*
  FROM param.job_run AS j
 CROSS JOIN (VALUES (1)) AS read_only_guard(singleton);
COMMENT ON VIEW analytics.v_dashboard_cockpit_job_run_records IS
  'One-to-one pass-through of param.job_run at run_id grain, including SKIPPED and all other recorded statuses. The cockpit job allowlist and DISTINCT ON latest-run ordering remain in control_views.cockpit; this is not the latest-non-SKIPPED health summary.';

COMMIT;
