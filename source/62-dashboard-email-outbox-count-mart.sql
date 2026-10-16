-- DDL62 · Exact all-row count of currently stored shared email outbox rows.
-- Includes scheduled-report and alarm-email rows regardless of status, schedule,
-- attachment, SMTP configuration, or timestamp; this is not an SMTP health metric.
BEGIN;

CREATE OR REPLACE VIEW analytics.v_dashboard_email_outbox_count AS
SELECT count(*) AS email_outbox_count
  FROM notification.email_outbox;

COMMENT ON VIEW analytics.v_dashboard_email_outbox_count IS
  'Scalar read-only count of all currently stored notification.email_outbox rows (scheduled reports and alarm emails), independent of status, schedule, attachment, SMTP state, or time; not an SMTP health indicator.';

COMMIT;
