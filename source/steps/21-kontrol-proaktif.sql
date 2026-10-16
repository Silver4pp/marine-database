-- Patch55: additive, idempotent; no existing decisions or issued numbers rewritten.
BEGIN;
CREATE TABLE IF NOT EXISTS param.job_run (
 run_id bigserial PRIMARY KEY, job_name text NOT NULL,
 started_at timestamptz NOT NULL DEFAULT now(), finished_at timestamptz,
 status text NOT NULL CHECK(status IN ('RUNNING','OK','FAILED','ABANDONED')),
 result jsonb NOT NULL DEFAULT '{}', error_code text
);
CREATE INDEX IF NOT EXISTS job_run_latest ON param.job_run(job_name,started_at DESC);
CREATE TABLE IF NOT EXISTS notification.alarm (
 alarm_id bigserial PRIMARY KEY, rule text NOT NULL, entity_key text NOT NULL,
 module_key text NOT NULL, allowed_roles text[] NOT NULL,
 title varchar(200) NOT NULL, detail text NOT NULL,
 severity text NOT NULL CHECK(severity IN ('WARNING','CRITICAL')),
 state text NOT NULL DEFAULT 'OPEN' CHECK(state IN ('OPEN','ACK','CLOSED')),
 opened_at timestamptz NOT NULL DEFAULT now(), last_seen_at timestamptz NOT NULL DEFAULT now(),
 acknowledged_at timestamptz, acknowledged_by varchar(150),
 closed_at timestamptz, close_reason text, last_notified_at timestamptz,
 notification_pending boolean NOT NULL DEFAULT true,
 cycle integer NOT NULL DEFAULT 0, version integer NOT NULL DEFAULT 1,
 UNIQUE(rule,entity_key)
);
ALTER TABLE notification.alarm ADD COLUMN IF NOT EXISTS notification_pending boolean NOT NULL DEFAULT true;
ALTER TABLE notification.email_outbox ADD COLUMN IF NOT EXISTS alarm_id bigint REFERENCES notification.alarm(alarm_id);
ALTER TABLE notification.email_outbox ADD COLUMN IF NOT EXISTS alarm_delivery_key text;
ALTER TABLE notification.email_outbox ADD COLUMN IF NOT EXISTS recipient_username varchar(150);
ALTER TABLE notification.email_outbox ADD COLUMN IF NOT EXISTS attempts integer NOT NULL DEFAULT 0;
ALTER TABLE notification.email_outbox ADD COLUMN IF NOT EXISTS next_attempt_at timestamptz NOT NULL DEFAULT now();
ALTER TABLE notification.email_outbox ADD COLUMN IF NOT EXISTS body_text text;
CREATE UNIQUE INDEX IF NOT EXISTS email_alarm_delivery_uq ON notification.email_outbox(alarm_delivery_key) WHERE alarm_delivery_key IS NOT NULL;
CREATE INDEX IF NOT EXISTS email_alarm_due ON notification.email_outbox(next_attempt_at) WHERE alarm_id IS NOT NULL AND status='QUEUED';
CREATE TABLE IF NOT EXISTS commercial.standby_policy (
 sales_contract_id bigint PRIMARY KEY REFERENCES commercial.sales_contract(sales_contract_id),
 enabled boolean NOT NULL DEFAULT false,
 basis text NOT NULL CHECK(basis IN ('NOR','ARRIVAL')),
 rounding text NOT NULL CHECK(rounding IN ('CEIL_MINUTE','FLOOR_MINUTE')),
 approved_by varchar(150) NOT NULL, approved_at timestamptz NOT NULL DEFAULT now(),
 note text NOT NULL, version integer NOT NULL DEFAULT 1
);
ALTER TABLE commercial.standby_policy ADD COLUMN IF NOT EXISTS effective_from timestamptz NOT NULL DEFAULT now();
CREATE TABLE IF NOT EXISTS commercial.standby_policy_revision (
 sales_contract_id bigint NOT NULL REFERENCES commercial.sales_contract(sales_contract_id),
 version integer NOT NULL, snapshot jsonb NOT NULL, recorded_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(sales_contract_id,version)
);
-- Imported seed IDs must not collide with new candidates/master entries. Never rewind.
LOCK TABLE commercial.standby_claim, commercial.sales_contract IN SHARE ROW EXCLUSIVE MODE;
SELECT setval('commercial.standby_claim_standby_claim_id_seq',GREATEST(
 (SELECT last_value FROM commercial.standby_claim_standby_claim_id_seq),
 COALESCE((SELECT max(standby_claim_id) FROM commercial.standby_claim),1)),true);
SELECT setval('commercial.sales_contract_sales_contract_id_seq',GREATEST(
 (SELECT last_value FROM commercial.sales_contract_sales_contract_id_seq),
 COALESCE((SELECT max(sales_contract_id) FROM commercial.sales_contract),1)),true);
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='commercial'
   AND table_name='standby_claim' AND column_name='disposed_by' AND character_maximum_length<150) THEN
   DROP VIEW IF EXISTS analytics.v_standby_review;
   ALTER TABLE commercial.standby_claim ALTER COLUMN disposed_by TYPE varchar(150);
 END IF;
END $$;
ALTER TABLE commercial.standby_claim ADD COLUMN IF NOT EXISTS auto_source text;
ALTER TABLE commercial.standby_claim ADD COLUMN IF NOT EXISTS calculation_snapshot jsonb;
ALTER TABLE commercial.standby_claim ADD COLUMN IF NOT EXISTS disposal_reason text;
ALTER TABLE commercial.standby_claim ADD COLUMN IF NOT EXISTS decision_version integer NOT NULL DEFAULT 1;
INSERT INTO param.system_parameter(param_key,label,nilai,satuan,keterangan,updated_by) VALUES
 ('alarm_quota_warning','Alarm kuota peringatan','80','persen','Terpakai lebih dari ambang','patch55'),
 ('alarm_quota_critical','Alarm kuota kritis','95','persen','Terpakai lebih dari ambang','patch55'),
 ('alarm_quota_days','Proyeksi kuota habis','60','hari','Proyeksi, bukan realisasi','patch55'),
 ('alarm_cooldown_minutes','Masa tenang alarm','30','menit','Reopen/escalation; bukan kirim ulang terus-menerus','patch55'),
 ('contract_reminder_days','Pengingat kontrak','90,30','hari','Evaluasi harian, catch-up tahap terdekat','patch55')
 ON CONFLICT(param_key) DO NOTHING;
CREATE OR REPLACE VIEW analytics.v_standby_review AS
 SELECT s.*,t.trip_no,c.contract_no,c.currency_code AS contract_currency,
 c.sales_contract_id FROM commercial.standby_claim s
 JOIN operational.trip t USING(trip_id)
 JOIN operational.shipment_instruction si ON si.si_num=t.si_num
 JOIN commercial.delivery_order d USING(do_id)
 JOIN commercial.purchase_order po USING(po_id)
 JOIN commercial.sales_contract c USING(sales_contract_id);
COMMIT;
