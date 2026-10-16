BEGIN;
ALTER TABLE enviro.ews_event ADD COLUMN IF NOT EXISTS acknowledged_at timestamptz;
ALTER TABLE enviro.ews_event ADD COLUMN IF NOT EXISTS acknowledged_by text;
ALTER TABLE enviro.ews_event ADD COLUMN IF NOT EXISTS owner_user_id bigint;
ALTER TABLE enviro.ews_event ADD COLUMN IF NOT EXISTS owner_username text;
ALTER TABLE enviro.ews_event ADD COLUMN IF NOT EXISTS response_minutes integer;
ALTER TABLE enviro.ews_event ADD COLUMN IF NOT EXISTS resolution_minutes integer;
ALTER TABLE enviro.ews_event ADD COLUMN IF NOT EXISTS policy_captured_at timestamptz;
ALTER TABLE enviro.ews_event ADD COLUMN IF NOT EXISTS closed_by text;
ALTER TABLE enviro.ews_event ADD COLUMN IF NOT EXISTS closure_source text;
ALTER TABLE enviro.ews_event ADD COLUMN IF NOT EXISTS resolution_evidence text;
ALTER TABLE enviro.ews_event ADD COLUMN IF NOT EXISTS workflow_version bigint NOT NULL DEFAULT 1;
ALTER TABLE notification.alarm ADD COLUMN IF NOT EXISTS owner_user_id bigint;
ALTER TABLE notification.alarm ADD COLUMN IF NOT EXISTS owner_username text;
ALTER TABLE notification.alarm ADD COLUMN IF NOT EXISTS due_at timestamptz;
ALTER TABLE notification.alarm ADD COLUMN IF NOT EXISTS closed_by text;
ALTER TABLE notification.alarm ADD COLUMN IF NOT EXISTS resolution_evidence text;
CREATE TABLE IF NOT EXISTS notification.control_history (
 history_id bigserial PRIMARY KEY, entity_type text NOT NULL CHECK(entity_type IN ('EWS','ALARM')),
 entity_id bigint NOT NULL, recorded_at timestamptz NOT NULL DEFAULT now(),
 actor text NOT NULL, operation text NOT NULL, snapshot jsonb NOT NULL
);
CREATE INDEX IF NOT EXISTS control_history_entity_idx ON notification.control_history(entity_type,entity_id,history_id DESC);
CREATE OR REPLACE FUNCTION enviro.bump_ews_workflow() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF (to_jsonb(NEW)-'updated_at'-'workflow_version') IS DISTINCT FROM (to_jsonb(OLD)-'updated_at'-'workflow_version') THEN
   NEW.workflow_version := OLD.workflow_version+1;
 ELSE NEW.workflow_version := OLD.workflow_version; END IF;
 RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS ews_workflow_version ON enviro.ews_event;
CREATE TRIGGER ews_workflow_version BEFORE UPDATE ON enviro.ews_event FOR EACH ROW EXECUTE FUNCTION enviro.bump_ews_workflow();
CREATE OR REPLACE FUNCTION notification.record_control_history() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE body jsonb; kind text; key bigint;
BEGIN
 IF TG_TABLE_SCHEMA='enviro' THEN
  IF TG_OP='UPDATE' AND NEW.workflow_version=OLD.workflow_version THEN RETURN NEW; END IF;
  kind:='EWS';key:=NEW.ews_event_id;
  body:=jsonb_build_object('version',NEW.workflow_version,'station',NEW.station_code,'parameter',NEW.parameter_code,
   'level',NEW.level,'created_at',NEW.created_at,'acknowledged_at',NEW.acknowledged_at,'acknowledged_by',NEW.acknowledged_by,
   'owner',NEW.owner_username,'owner_id',NEW.owner_user_id,'closed_at',NEW.closed_at,'closed_by',NEW.closed_by,
   'closure_source',NEW.closure_source,'outcome',NEW.outcome,'evidence',NEW.resolution_evidence,
   'response_minutes',NEW.response_minutes,'resolution_minutes',NEW.resolution_minutes,'policy_captured_at',NEW.policy_captured_at);
 ELSE
  IF TG_OP='UPDATE' AND ROW(NEW.state,NEW.severity,NEW.owner_user_id,NEW.owner_username,NEW.due_at,NEW.close_reason,NEW.resolution_evidence,NEW.acknowledged_by)
   IS NOT DISTINCT FROM ROW(OLD.state,OLD.severity,OLD.owner_user_id,OLD.owner_username,OLD.due_at,OLD.close_reason,OLD.resolution_evidence,OLD.acknowledged_by) THEN RETURN NEW; END IF;
  kind:='ALARM';key:=NEW.alarm_id;
  body:=jsonb_build_object('version',NEW.version,'state',NEW.state,'severity',NEW.severity,'owner',NEW.owner_username,
   'owner_id',NEW.owner_user_id,'due_at',NEW.due_at,'acknowledged_by',NEW.acknowledged_by,'closed_at',NEW.closed_at,
   'closed_by',NEW.closed_by,'close_reason',NEW.close_reason,'evidence',NEW.resolution_evidence);
 END IF;
 INSERT INTO notification.control_history(entity_type,entity_id,actor,operation,snapshot)
 VALUES(kind,key,coalesce(nullif(current_setting('erp.workflow_actor',true),''),'source/scheduler'),TG_OP,body);
 RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS ews_workflow_history ON enviro.ews_event;
CREATE TRIGGER ews_workflow_history AFTER INSERT OR UPDATE ON enviro.ews_event FOR EACH ROW EXECUTE FUNCTION notification.record_control_history();
DROP TRIGGER IF EXISTS alarm_workflow_history ON notification.alarm;
CREATE TRIGGER alarm_workflow_history AFTER INSERT OR UPDATE ON notification.alarm FOR EACH ROW EXECUTE FUNCTION notification.record_control_history();
INSERT INTO param.system_parameter(param_key,label,nilai,satuan,keterangan,updated_by) VALUES
 ('ews_response_minutes','Target respons EWS','60','menit','FR-9-03: created_at sampai acknowledged_at. Snapshot per kasus; perubahan tidak otomatis menulis ulang kasus lama.','migrasi'),
 ('ews_resolution_minutes','Target resolusi EWS','','menit','Kosong sampai pemilik menetapkan; created_at sampai closed_at, bukan durasi setelah ACK.','migrasi')
ON CONFLICT(param_key) DO NOTHING;
COMMIT;
