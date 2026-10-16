-- Reviews of references only: never verification of file content or billing.
BEGIN;
CREATE TABLE IF NOT EXISTS commercial.standby_trip_review (
 event_id bigserial PRIMARY KEY,
 submission_id bigint NOT NULL REFERENCES commercial.standby_trip_submission(submission_id),
 version integer NOT NULL CHECK(version>0),
 action text NOT NULL CHECK(action IN ('APPROVE1','APPROVE2','CANCEL','REJECT','REVOKE')),
 state text NOT NULL CHECK(state IN ('PENDING_2','REFERENCES_REVIEWED','CANCELLED','REJECTED','REVOKED')),
 actor_id bigint NOT NULL CHECK(actor_id>0),
 actor_name text NOT NULL,
 snapshot jsonb NOT NULL CHECK(snapshot @> '{"scope":"REFERENCES_ONLY","billing_enabled":false,"evidence_verified":false,"human_identity_verified":false}'::jsonb),
 snapshot_hash text NOT NULL CHECK(snapshot_hash ~ '^[0-9a-f]{64}$'),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(submission_id,version)
);
CREATE OR REPLACE FUNCTION commercial.standby_trip_transition38() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE parent commercial.standby_trip_submission%ROWTYPE; prev commercial.standby_trip_review%ROWTYPE; expected jsonb;
BEGIN
 SELECT * INTO STRICT parent FROM commercial.standby_trip_submission WHERE submission_id=NEW.submission_id;
 PERFORM 1 FROM operational.trip WHERE trip_id=parent.trip_id FOR UPDATE;
 PERFORM 1 FROM commercial.standby_trip_submission WHERE submission_id=NEW.submission_id FOR UPDATE;
 SELECT * INTO prev FROM commercial.standby_trip_review WHERE submission_id=NEW.submission_id ORDER BY version DESC LIMIT 1;
 IF NEW.version<>coalesce(prev.version,0)+1 THEN RAISE EXCEPTION 'Stale review version'; END IF;
 IF NEW.snapshot->'submission' IS DISTINCT FROM parent.payload
    OR NEW.snapshot->>'submission_hash' IS DISTINCT FROM parent.payload_hash
    OR (NEW.snapshot->>'submission_id')::bigint IS DISTINCT FROM NEW.submission_id
    OR (NEW.snapshot->>'version')::integer IS DISTINCT FROM NEW.version
    OR NEW.snapshot->>'state' IS DISTINCT FROM NEW.state
    OR NEW.snapshot->'event'->>'action' IS DISTINCT FROM NEW.action
    OR (NEW.snapshot->'event'->'actor'->>'id')::bigint IS DISTINCT FROM NEW.actor_id
    OR NEW.snapshot->'event'->'actor'->>'username' IS DISTINCT FROM NEW.actor_name THEN RAISE EXCEPTION 'Review snapshot mismatch'; END IF;
 IF NEW.action IN ('APPROVE1','APPROVE2','REVOKE') AND NEW.snapshot->'event'->'confirmed' IS DISTINCT FROM 'true'::jsonb THEN RAISE EXCEPTION 'Explicit confirmation required'; END IF;
 expected:=CASE WHEN prev.event_id IS NULL THEN jsonb_build_object('preparer',parent.payload->'prepared_by') ELSE prev.snapshot->'actors' END;
 IF NEW.action='APPROVE1' THEN expected:=expected||jsonb_build_object('approver_1',NEW.snapshot->'event'->'actor'); END IF;
 IF NEW.action='APPROVE2' THEN expected:=expected||jsonb_build_object('approver_2',NEW.snapshot->'event'->'actor'); END IF;
 IF NEW.snapshot->'actors' IS DISTINCT FROM expected THEN RAISE EXCEPTION 'Actor history mismatch'; END IF;
 IF prev.state='REFERENCES_REVIEWED' AND NEW.action='REVOKE' AND NEW.state='REVOKED' AND NEW.actor_id<>parent.prepared_by_id THEN RETURN NEW; END IF;
 IF prev.event_id IS NOT NULL AND prev.state<>'PENDING_2' THEN RAISE EXCEPTION 'Final review'; END IF;
 IF NEW.action='CANCEL' AND NEW.state='CANCELLED' AND NEW.actor_id=parent.prepared_by_id THEN RETURN NEW; END IF;
 IF NEW.actor_id=parent.prepared_by_id THEN RAISE EXCEPTION 'Preparer cannot review own submission'; END IF;
 IF NEW.action='REJECT' AND NEW.state='REJECTED' THEN RETURN NEW; END IF;
 IF parent.revision<>(SELECT max(revision) FROM commercial.standby_trip_submission WHERE trip_id=parent.trip_id) THEN RAISE EXCEPTION 'Superseded submission'; END IF;
 IF prev.event_id IS NULL AND NEW.action='APPROVE1' AND NEW.state='PENDING_2' THEN RETURN NEW; END IF;
 IF prev.state='PENDING_2' AND NEW.action='APPROVE2' AND NEW.state='REFERENCES_REVIEWED'
    AND NEW.actor_id<>(prev.snapshot->'actors'->'approver_1'->>'id')::bigint THEN RETURN NEW; END IF;
 RAISE EXCEPTION 'Invalid transition or reused reviewer';
END $$;
DROP TRIGGER IF EXISTS standby_trip_review_transition38 ON commercial.standby_trip_review;
CREATE TRIGGER standby_trip_review_transition38 BEFORE INSERT ON commercial.standby_trip_review FOR EACH ROW EXECUTE FUNCTION commercial.standby_trip_transition38();
DROP TRIGGER IF EXISTS standby_trip_review_immutable38 ON commercial.standby_trip_review;
CREATE TRIGGER standby_trip_review_immutable38 BEFORE UPDATE OR DELETE ON commercial.standby_trip_review FOR EACH ROW EXECUTE FUNCTION commercial.standby_review_immutable36();
DROP TRIGGER IF EXISTS standby_trip_review_truncate38 ON commercial.standby_trip_review;
CREATE TRIGGER standby_trip_review_truncate38 BEFORE TRUNCATE ON commercial.standby_trip_review FOR EACH STATEMENT EXECUTE FUNCTION commercial.standby_review_immutable36();
COMMIT;
