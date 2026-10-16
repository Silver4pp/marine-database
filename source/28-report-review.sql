-- Additive/idempotent; report fields only, no rewrite of historical delivery states.
BEGIN;
ALTER TABLE notification.email_outbox ADD COLUMN IF NOT EXISTS delivery_claimed_at timestamptz;
ALTER TABLE notification.email_outbox ADD COLUMN IF NOT EXISTS report_review jsonb;
ALTER TABLE notification.email_outbox ADD COLUMN IF NOT EXISTS refused_recipients jsonb;
COMMIT;
