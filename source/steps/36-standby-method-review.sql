-- Method configuration review only; no activation of exclusion billing.
BEGIN;
CREATE TABLE IF NOT EXISTS commercial.standby_method_proposal (
 proposal_id bigserial PRIMARY KEY,
 sales_contract_id bigint NOT NULL REFERENCES commercial.sales_contract(sales_contract_id),
 request_key uuid NOT NULL UNIQUE,
 mode text NOT NULL CHECK(mode IN ('NET_THEN_FREE','AFTER_FREE_WINDOW')),
 prepared_by_id bigint NOT NULL CHECK(prepared_by_id>0),
 prepared_by text NOT NULL,
 payload jsonb NOT NULL CHECK(payload @> '{"scope":"METHOD_CONFIGURATION_ONLY","billing_enabled":false}'::jsonb),
 payload_hash text NOT NULL CHECK(payload_hash ~ '^[0-9a-f]{64}$'),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE INDEX IF NOT EXISTS standby_method_contract36_idx ON commercial.standby_method_proposal(sales_contract_id,proposal_id DESC);
CREATE TABLE IF NOT EXISTS commercial.standby_method_event (
 event_id bigserial PRIMARY KEY,
 proposal_id bigint NOT NULL REFERENCES commercial.standby_method_proposal(proposal_id),
 version integer NOT NULL CHECK(version>0),
 action text NOT NULL CHECK(action IN ('SUBMIT','APPROVE1','APPROVE2','REJECT','CANCEL')),
 state text NOT NULL CHECK(state IN ('PENDING_1','PENDING_2','APPROVED_FOR_CONFIGURATION','REJECTED','CANCELLED')),
 actor_id bigint NOT NULL CHECK(actor_id>0), actor_name text NOT NULL,
 snapshot jsonb NOT NULL CHECK(snapshot @> '{"scope":"METHOD_CONFIGURATION_ONLY","billing_enabled":false,"source_verified":false,"human_identity_verified":false}'::jsonb),
 snapshot_hash text NOT NULL CHECK(snapshot_hash ~ '^[0-9a-f]{64}$'),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(proposal_id,version)
);
CREATE OR REPLACE FUNCTION commercial.standby_review_immutable36() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN RAISE EXCEPTION 'Standby method review is append-only: update/delete/truncate forbidden'; END $$;
DROP TRIGGER IF EXISTS standby_method_proposal_immutable36 ON commercial.standby_method_proposal;
CREATE TRIGGER standby_method_proposal_immutable36 BEFORE UPDATE OR DELETE ON commercial.standby_method_proposal FOR EACH ROW EXECUTE FUNCTION commercial.standby_review_immutable36();
DROP TRIGGER IF EXISTS standby_method_proposal_truncate36 ON commercial.standby_method_proposal;
CREATE TRIGGER standby_method_proposal_truncate36 BEFORE TRUNCATE ON commercial.standby_method_proposal FOR EACH STATEMENT EXECUTE FUNCTION commercial.standby_review_immutable36();
DROP TRIGGER IF EXISTS standby_method_event_immutable36 ON commercial.standby_method_event;
CREATE TRIGGER standby_method_event_immutable36 BEFORE UPDATE OR DELETE ON commercial.standby_method_event FOR EACH ROW EXECUTE FUNCTION commercial.standby_review_immutable36();
DROP TRIGGER IF EXISTS standby_method_event_truncate36 ON commercial.standby_method_event;
CREATE TRIGGER standby_method_event_truncate36 BEFORE TRUNCATE ON commercial.standby_method_event FOR EACH STATEMENT EXECUTE FUNCTION commercial.standby_review_immutable36();
CREATE OR REPLACE FUNCTION commercial.standby_review_transition36() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE prep bigint; proposalrow commercial.standby_method_proposal%ROWTYPE; expected_actors jsonb; lastrow commercial.standby_method_event%ROWTYPE; first_actor bigint;
BEGIN
 SELECT * INTO STRICT proposalrow FROM commercial.standby_method_proposal WHERE proposal_id=NEW.proposal_id FOR UPDATE;
 prep := proposalrow.prepared_by_id;
 IF NEW.snapshot->'proposal' IS DISTINCT FROM proposalrow.payload OR NEW.snapshot->>'proposal_hash' IS DISTINCT FROM proposalrow.payload_hash
    OR NEW.snapshot->>'state' IS DISTINCT FROM NEW.state OR (NEW.snapshot->>'version')::integer IS DISTINCT FROM NEW.version
    OR (NEW.snapshot->>'proposal_id')::bigint IS DISTINCT FROM NEW.proposal_id
    OR NEW.snapshot->'event'->>'action' IS DISTINCT FROM NEW.action
    OR (NEW.snapshot->'event'->'actor'->>'id')::bigint IS DISTINCT FROM NEW.actor_id
    OR NEW.snapshot->'event'->'actor'->>'username' IS DISTINCT FROM NEW.actor_name THEN
    RAISE EXCEPTION 'Snapshot does not match immutable source/event';
 END IF;
 SELECT * INTO lastrow FROM commercial.standby_method_event WHERE proposal_id=NEW.proposal_id ORDER BY version DESC LIMIT 1;
 expected_actors := CASE WHEN lastrow.event_id IS NULL THEN jsonb_build_object('preparer',proposalrow.payload->'prepared_by') ELSE lastrow.snapshot->'actors' END;
 IF NEW.action='APPROVE1' THEN expected_actors:=expected_actors||jsonb_build_object('approver_1',NEW.snapshot->'event'->'actor'); END IF;
 IF NEW.action='APPROVE2' THEN expected_actors:=expected_actors||jsonb_build_object('approver_2',NEW.snapshot->'event'->'actor'); END IF;
 IF NEW.snapshot->'actors' IS DISTINCT FROM expected_actors THEN RAISE EXCEPTION 'Actor history cannot be replaced'; END IF;
 IF lastrow.event_id IS NULL THEN
  IF NEW.version<>1 OR NEW.action<>'SUBMIT' OR NEW.state<>'PENDING_1' OR NEW.actor_id<>prep THEN RAISE EXCEPTION 'Invalid initial review'; END IF;
 ELSE
  IF NEW.version<>lastrow.version+1 OR lastrow.state NOT IN ('PENDING_1','PENDING_2') THEN RAISE EXCEPTION 'Final/stale review'; END IF;
  IF NEW.action='CANCEL' AND NEW.state='CANCELLED' AND NEW.actor_id=prep THEN RETURN NEW; END IF;
  IF NEW.actor_id=prep THEN RAISE EXCEPTION 'Preparer cannot approve/reject own review'; END IF;
  IF NEW.action='REJECT' AND NEW.state='REJECTED' THEN RETURN NEW; END IF;
  IF lastrow.state='PENDING_1' AND NEW.action='APPROVE1' AND NEW.state='PENDING_2' THEN RETURN NEW; END IF;
  SELECT actor_id INTO first_actor FROM commercial.standby_method_event WHERE proposal_id=NEW.proposal_id AND action='APPROVE1';
  IF lastrow.state='PENDING_2' AND NEW.action='APPROVE2' AND NEW.state='APPROVED_FOR_CONFIGURATION' AND NEW.actor_id<>first_actor THEN RETURN NEW; END IF;
  RAISE EXCEPTION 'Invalid transition or reused approver';
 END IF;
 RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS standby_method_transition36 ON commercial.standby_method_event;
CREATE TRIGGER standby_method_transition36 BEFORE INSERT ON commercial.standby_method_event FOR EACH ROW EXECUTE FUNCTION commercial.standby_review_transition36();
COMMIT;
