-- W3: additive, re-runnable. Historical demo SENT is left untouched, never replayed.
BEGIN;
ALTER TABLE notification.report_schedule ADD COLUMN IF NOT EXISTS export_format text NOT NULL DEFAULT 'pdf';
ALTER TABLE notification.report_schedule ADD COLUMN IF NOT EXISTS owner_user_id bigint;
ALTER TABLE notification.report_schedule ADD COLUMN IF NOT EXISTS last_generated_at timestamptz;
ALTER TABLE notification.email_outbox ADD COLUMN IF NOT EXISTS export_format text NOT NULL DEFAULT 'pdf';
ALTER TABLE notification.email_outbox ADD COLUMN IF NOT EXISTS attachment_sha256 text;
ALTER TABLE notification.email_outbox ADD COLUMN IF NOT EXISTS report_snapshot jsonb;
CREATE INDEX IF NOT EXISTS report_outbox_pending_idx ON notification.email_outbox(schedule_id,created_at) WHERE alarm_id IS NULL AND attachment_sha256 IS NOT NULL AND status IN ('QUEUED','WAITING_SMTP');
COMMIT;
ALTER TABLE notification.email_outbox ADD COLUMN IF NOT EXISTS report_request_key text;
CREATE UNIQUE INDEX IF NOT EXISTS report_request_unique ON notification.email_outbox(schedule_id,report_request_key) WHERE report_request_key IS NOT NULL;
