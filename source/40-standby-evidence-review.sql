-- Human review of one immutable technical copy and its linked interval; never contractual acceptance.
BEGIN;
CREATE TABLE IF NOT EXISTS commercial.standby_evidence_review (
 event_id bigserial PRIMARY KEY,
 evidence_id bigint NOT NULL REFERENCES commercial.standby_evidence(evidence_id),
 submission_id bigint NOT NULL REFERENCES commercial.standby_trip_submission(submission_id),
 interval_no integer NOT NULL CHECK(interval_no BETWEEN 1 AND 100),
 version integer NOT NULL CHECK(version BETWEEN 1 AND 4),
 action text NOT NULL CHECK(action IN ('APPROVE1','APPROVE2','REJECT','CANCEL','REVOKE')),
 state text NOT NULL CHECK(state IN ('PENDING_2','TECHNICAL_REVIEWED','REJECTED','CANCELLED','REVOKED')),
 actor_id bigint NOT NULL CHECK(actor_id>0), actor_name text NOT NULL,
 snapshot jsonb NOT NULL CHECK(snapshot @> '{"scope":"PER_RANGE_TECHNICAL_FILE_REVIEW","authenticity_verified":false,"malware_scanned":false,"contractual_acceptance":false,"billing_enabled":false,"human_identity_verified":false}'::jsonb),
 snapshot_hash text NOT NULL CHECK(snapshot_hash ~ '^[0-9a-f]{64}$'),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(evidence_id,version)
);
CREATE OR REPLACE FUNCTION commercial.standby_evidence_review_insert40() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE file commercial.standby_evidence%ROWTYPE; parent commercial.standby_trip_submission%ROWTYPE; prev commercial.standby_evidence_review%ROWTYPE; refstate text; maxfile bigint; delivery_id bigint; delivery_at timestamptz; expected jsonb; a1 bigint; actor_in_snapshot bigint;
BEGIN
 SELECT * INTO STRICT file FROM commercial.standby_evidence WHERE evidence_id=NEW.evidence_id;
 SELECT * INTO STRICT parent FROM commercial.standby_trip_submission WHERE submission_id=NEW.submission_id;
 PERFORM 1 FROM operational.trip WHERE trip_id=parent.trip_id FOR UPDATE;
 PERFORM 1 FROM commercial.standby_trip_submission WHERE submission_id=NEW.submission_id FOR UPDATE;
 IF file.submission_id<>NEW.submission_id OR file.interval_no<>NEW.interval_no OR NEW.interval_no>jsonb_array_length(parent.payload->'intervals') THEN RAISE EXCEPTION 'Evidence submission/range mismatch'; END IF;
 IF file.manifest->>'submission_hash' IS DISTINCT FROM parent.payload_hash OR file.manifest->'interval' IS DISTINCT FROM parent.payload->'intervals'->(NEW.interval_no-1) OR file.manifest_hash<>NEW.snapshot->>'manifest_hash' THEN RAISE EXCEPTION 'Evidence manifest/range mismatch'; END IF;
 IF encode(sha256(file.source_data),'hex')<>file.source_sha256 OR encode(sha256(file.data),'hex')<>file.sha256 THEN RAISE EXCEPTION 'Evidence byte digest mismatch'; END IF;
 SELECT evidence_id INTO maxfile FROM commercial.standby_evidence WHERE submission_id=NEW.submission_id AND interval_no=NEW.interval_no ORDER BY version DESC LIMIT 1;
 IF maxfile<>NEW.evidence_id THEN RAISE EXCEPTION 'Only latest file version can be reviewed'; END IF;
 SELECT * INTO prev FROM commercial.standby_evidence_review WHERE evidence_id=NEW.evidence_id ORDER BY version DESC LIMIT 1;
 SELECT state INTO refstate FROM commercial.standby_trip_review WHERE submission_id=NEW.submission_id ORDER BY version DESC LIMIT 1;
 IF NEW.action IN ('APPROVE1','APPROVE2') OR (NEW.action='REJECT' AND prev.event_id IS NULL) THEN
   IF refstate IS DISTINCT FROM 'REFERENCES_REVIEWED' THEN RAISE EXCEPTION 'Reference review must remain final'; END IF;
 END IF;
 IF NEW.action IN ('APPROVE1','APPROVE2','REJECT','REVOKE') THEN
   SELECT audit_id,diubah_pada INTO delivery_id,delivery_at FROM param.audit_log
    WHERE tabel='commercial.standby_evidence' AND record_key=file.evidence_id::text AND kolom='download'
      AND nilai_baru='normalized:'||file.sha256 AND diubah_oleh=NEW.actor_name AND diubah_pada>=file.created_at
    ORDER BY diubah_pada DESC,audit_id DESC LIMIT 1;
   IF delivery_id IS NULL OR (NEW.snapshot->'reviewer_delivery'->>'audit_id')::bigint IS DISTINCT FROM delivery_id
      OR (NEW.snapshot->'reviewer_delivery'->>'actor_id')::bigint IS DISTINCT FROM NEW.actor_id
      OR NEW.snapshot->'reviewer_delivery'->>'username' IS DISTINCT FROM NEW.actor_name
      OR NEW.snapshot->'reviewer_delivery'->>'file_sha256' IS DISTINCT FROM file.sha256
      OR (NEW.snapshot->'reviewer_delivery'->>'at')::timestamptz IS DISTINCT FROM delivery_at THEN RAISE EXCEPTION 'Reviewer must download the exact normalized copy before deciding'; END IF;
 END IF;
 IF NEW.version<>coalesce(prev.version,0)+1 THEN RAISE EXCEPTION 'Stale evidence-review version'; END IF;
 actor_in_snapshot:=(NEW.snapshot->'event'->'actor'->>'id')::bigint;
 IF NEW.snapshot->>'scope'<>'PER_RANGE_TECHNICAL_FILE_REVIEW'
   OR NEW.snapshot->>'state' IS DISTINCT FROM NEW.state OR NEW.snapshot->>'submission_hash' IS DISTINCT FROM parent.payload_hash
   OR (NEW.snapshot->>'submission_id')::bigint IS DISTINCT FROM NEW.submission_id
   OR (NEW.snapshot->>'interval_no')::integer IS DISTINCT FROM NEW.interval_no
   OR (NEW.snapshot->>'evidence_id')::bigint IS DISTINCT FROM NEW.evidence_id
   OR NEW.snapshot->>'manifest_hash' IS DISTINCT FROM file.manifest_hash
   OR NEW.snapshot->'interval' IS DISTINCT FROM parent.payload->'intervals'->(NEW.interval_no-1)
   OR NEW.snapshot->'manifest' IS DISTINCT FROM file.manifest
   OR NEW.snapshot->>'file_sha256' IS DISTINCT FROM file.sha256 OR NEW.snapshot->>'source_sha256' IS DISTINCT FROM file.source_sha256
   OR (NEW.snapshot->>'version')::integer IS DISTINCT FROM NEW.version
   OR NEW.snapshot->'event'->>'action' IS DISTINCT FROM NEW.action
   OR actor_in_snapshot IS DISTINCT FROM NEW.actor_id OR NEW.snapshot->'event'->'actor'->>'username' IS DISTINCT FROM NEW.actor_name
   OR NEW.snapshot->'application_hashes_verified' IS DISTINCT FROM 'true'::jsonb
   OR NEW.snapshot->'range_binding_checked' IS DISTINCT FROM 'true'::jsonb
   OR NEW.snapshot->'event'->'confirmed' IS DISTINCT FROM 'true'::jsonb
   OR NEW.snapshot->'authenticity_verified' IS DISTINCT FROM 'false'::jsonb
   OR NEW.snapshot->'malware_scanned' IS DISTINCT FROM 'false'::jsonb
   OR NEW.snapshot->'contractual_acceptance' IS DISTINCT FROM 'false'::jsonb
   OR NEW.snapshot->'billing_enabled' IS DISTINCT FROM 'false'::jsonb
   OR NEW.snapshot->'human_identity_verified' IS DISTINCT FROM 'false'::jsonb THEN RAISE EXCEPTION 'Evidence-review snapshot mismatch'; END IF;
 expected:=CASE WHEN prev.event_id IS NULL THEN jsonb_build_object('preparer',parent.payload->'prepared_by') ELSE prev.snapshot->'actors' END;
 IF NEW.action='APPROVE1' THEN expected:=expected||jsonb_build_object('approver_1',NEW.snapshot->'event'->'actor'); END IF;
 IF NEW.action='APPROVE2' THEN expected:=expected||jsonb_build_object('approver_2',NEW.snapshot->'event'->'actor'); END IF;
 IF NEW.snapshot->'actors' IS DISTINCT FROM expected THEN RAISE EXCEPTION 'Evidence reviewer history mismatch'; END IF;
 IF NEW.action IN ('APPROVE1','APPROVE2') AND parent.revision<>(SELECT max(revision) FROM commercial.standby_trip_submission WHERE trip_id=parent.trip_id) THEN RAISE EXCEPTION 'Submission superseded'; END IF;
 IF NEW.action='APPROVE1' AND prev.event_id IS NULL AND NEW.state='PENDING_2' AND NEW.actor_id<>parent.prepared_by_id THEN RETURN NEW; END IF;
 IF NEW.action='REJECT' AND NEW.state='REJECTED' AND NEW.actor_id<>parent.prepared_by_id AND (prev.event_id IS NULL OR prev.state='PENDING_2') THEN RETURN NEW; END IF;
 IF prev.state='PENDING_2' AND NEW.action='CANCEL' AND NEW.state='CANCELLED' AND NEW.actor_id=parent.prepared_by_id THEN RETURN NEW; END IF;
 IF prev.state='PENDING_2' AND NEW.action='APPROVE2' AND NEW.state='TECHNICAL_REVIEWED' AND NEW.actor_id<>parent.prepared_by_id THEN
   a1:=(prev.snapshot->'actors'->'approver_1'->>'id')::bigint;
   IF NEW.actor_id<>a1 THEN RETURN NEW; END IF;
 END IF;
 IF prev.state='TECHNICAL_REVIEWED' AND NEW.action='REVOKE' AND NEW.state='REVOKED' AND NEW.actor_id<>parent.prepared_by_id THEN RETURN NEW; END IF;
 RAISE EXCEPTION 'Invalid evidence-review transition';
END $$;
DROP TRIGGER IF EXISTS standby_evidence_review_insert40 ON commercial.standby_evidence_review;
CREATE TRIGGER standby_evidence_review_insert40 BEFORE INSERT ON commercial.standby_evidence_review FOR EACH ROW EXECUTE FUNCTION commercial.standby_evidence_review_insert40();
DROP TRIGGER IF EXISTS standby_evidence_review_immutable40 ON commercial.standby_evidence_review;
CREATE TRIGGER standby_evidence_review_immutable40 BEFORE UPDATE OR DELETE ON commercial.standby_evidence_review FOR EACH ROW EXECUTE FUNCTION commercial.standby_review_immutable36();
DROP TRIGGER IF EXISTS standby_evidence_review_truncate40 ON commercial.standby_evidence_review;
CREATE TRIGGER standby_evidence_review_truncate40 BEFORE TRUNCATE ON commercial.standby_evidence_review FOR EACH STATEMENT EXECUTE FUNCTION commercial.standby_review_immutable36();
COMMIT;
