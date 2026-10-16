-- Contract-clause acceptance capture for one technically reviewed file/range.
-- This is NOT a legal-effect, authority, identity, authenticity, malware, or billing assertion.
BEGIN;
CREATE TABLE IF NOT EXISTS commercial.standby_contract_acceptance (
 event_id bigserial PRIMARY KEY,
 evidence_id bigint NOT NULL REFERENCES commercial.standby_evidence(evidence_id),
 submission_id bigint NOT NULL REFERENCES commercial.standby_trip_submission(submission_id),
 interval_no integer NOT NULL CHECK(interval_no BETWEEN 1 AND 100),
 version integer NOT NULL CHECK(version>0),
 request_key uuid NOT NULL UNIQUE,
 request_hash text NOT NULL CHECK(request_hash ~ '^[0-9a-f]{64}$'),
 action text NOT NULL CHECK(action IN ('SUBMIT','APPROVE1','APPROVE2','REJECT','CANCEL','REVOKE')),
 state text NOT NULL CHECK(state IN ('PENDING_1','PENDING_2','ACCEPTANCE_RECORDED_UNVERIFIED','REJECTED','CANCELLED','REVOKED')),
 actor_id bigint NOT NULL CHECK(actor_id>0),
 actor_name text NOT NULL,
 basis jsonb NOT NULL CHECK(
   basis->>'scope'='CONTRACT_CLAUSE_INPUT_ONLY'
   AND length(btrim(coalesce(basis->>'clause_reference',''))) BETWEEN 3 AND 300
   AND length(btrim(coalesce(basis->>'contract_document_reference',''))) BETWEEN 3 AND 300
   AND length(btrim(coalesce(basis->>'authority_reference',''))) BETWEEN 3 AND 300
   AND basis->>'legal_applicability_status'='UNASSESSED'
   AND basis->'authority_verified'='false'::jsonb
   AND basis->'legal_reviewed'='false'::jsonb
 ),
 basis_hash text NOT NULL CHECK(basis_hash ~ '^[0-9a-f]{64}$'),
 snapshot jsonb NOT NULL CHECK(snapshot @> '{"scope":"CONTRACTUAL_ACCEPTANCE_CAPTURE","contractual_acceptance":false,"legal_effect_confirmed":false,"legal_applicability_status":"UNASSESSED","authority_verified":false,"human_identity_verified":false,"evidence_verified":false,"malware_scanned":false,"billing_enabled":false}'::jsonb),
 snapshot_hash text NOT NULL CHECK(snapshot_hash ~ '^[0-9a-f]{64}$'),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(evidence_id,version),
 CHECK(snapshot->'basis' IS NOT DISTINCT FROM basis),
 CHECK(snapshot->>'basis_hash' IS NOT DISTINCT FROM basis_hash),
 CHECK(snapshot->>'request_hash' IS NOT DISTINCT FROM request_hash),
 CHECK(snapshot->>'state' IS NOT DISTINCT FROM state),
 CHECK((snapshot->>'evidence_id')::bigint IS NOT DISTINCT FROM evidence_id),
 CHECK((snapshot->>'submission_id')::bigint IS NOT DISTINCT FROM submission_id),
 CHECK((snapshot->>'interval_no')::integer IS NOT DISTINCT FROM interval_no),
 CHECK((snapshot->>'version')::integer IS NOT DISTINCT FROM version)
);
CREATE INDEX IF NOT EXISTS standby_contract_acceptance_submission41_idx
 ON commercial.standby_contract_acceptance(submission_id,interval_no,version DESC);

CREATE OR REPLACE FUNCTION commercial.standby_contract_acceptance_transition41() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
 file commercial.standby_evidence%ROWTYPE;
 parent commercial.standby_trip_submission%ROWTYPE;
 previous commercial.standby_contract_acceptance%ROWTYPE;
 tech_event_id bigint; tech_hash text; tech_state text;
 ref_event_id bigint; ref_hash text; ref_state text;
 contract_number text;
 maximum_file bigint; delivery_id bigint; delivery_at timestamptz;
 expected_actors jsonb; preparer_id bigint; first_approver_id bigint;
BEGIN
 SELECT * INTO STRICT file FROM commercial.standby_evidence WHERE evidence_id=NEW.evidence_id;
 SELECT * INTO STRICT parent FROM commercial.standby_trip_submission WHERE submission_id=NEW.submission_id;
 PERFORM 1 FROM operational.trip WHERE trip_id=parent.trip_id FOR UPDATE;
 PERFORM 1 FROM commercial.standby_trip_submission WHERE submission_id=NEW.submission_id FOR UPDATE;
 PERFORM 1 FROM commercial.standby_evidence WHERE evidence_id=NEW.evidence_id FOR UPDATE;
 IF file.submission_id<>NEW.submission_id OR file.interval_no<>NEW.interval_no
    OR NEW.interval_no>jsonb_array_length(parent.payload->'intervals') THEN RAISE EXCEPTION 'Acceptance submission/range mismatch'; END IF;
 IF file.manifest->>'submission_hash' IS DISTINCT FROM parent.payload_hash
    OR file.manifest->'interval' IS DISTINCT FROM parent.payload->'intervals'->(NEW.interval_no-1)
    OR file.manifest_hash<>NEW.snapshot->>'manifest_hash' THEN RAISE EXCEPTION 'Acceptance manifest/range mismatch'; END IF;
 IF encode(sha256(file.source_data),'hex')<>file.source_sha256 OR encode(sha256(file.data),'hex')<>file.sha256 THEN RAISE EXCEPTION 'Acceptance file digest mismatch'; END IF;
 SELECT evidence_id INTO maximum_file FROM commercial.standby_evidence
  WHERE submission_id=NEW.submission_id AND interval_no=NEW.interval_no ORDER BY version DESC LIMIT 1;
 IF maximum_file IS DISTINCT FROM NEW.evidence_id THEN RAISE EXCEPTION 'Only the latest file version can enter acceptance capture'; END IF;
 SELECT * INTO previous FROM commercial.standby_contract_acceptance
  WHERE evidence_id=NEW.evidence_id ORDER BY version DESC LIMIT 1;
 IF NEW.version<>coalesce(previous.version,0)+1 THEN RAISE EXCEPTION 'Stale contract-acceptance version'; END IF;
 SELECT event_id,snapshot_hash,state INTO tech_event_id,tech_hash,tech_state
  FROM commercial.standby_evidence_review WHERE evidence_id=NEW.evidence_id ORDER BY version DESC LIMIT 1;
 SELECT r.event_id,r.snapshot_hash,r.state INTO ref_event_id,ref_hash,ref_state
  FROM commercial.standby_trip_review r WHERE r.submission_id=NEW.submission_id ORDER BY version DESC LIMIT 1;
 SELECT contract_no INTO contract_number FROM commercial.sales_contract WHERE sales_contract_id=parent.sales_contract_id;
 IF NEW.basis->>'contract_no' IS DISTINCT FROM contract_number
    OR (NEW.basis->>'contract_id')::bigint IS DISTINCT FROM parent.sales_contract_id THEN RAISE EXCEPTION 'Acceptance basis contract mismatch'; END IF;
 IF NEW.snapshot->>'scope'<>'CONTRACTUAL_ACCEPTANCE_CAPTURE'
    OR NEW.snapshot->>'state' IS DISTINCT FROM NEW.state
    OR NEW.snapshot->>'action' IS DISTINCT FROM NEW.action
    OR NEW.snapshot->>'request_hash' IS DISTINCT FROM NEW.request_hash
    OR NEW.snapshot->>'submission_hash' IS DISTINCT FROM parent.payload_hash
    OR NEW.snapshot->>'file_sha256' IS DISTINCT FROM file.sha256
    OR NEW.snapshot->>'source_sha256' IS DISTINCT FROM file.source_sha256
    OR NEW.snapshot->>'manifest_hash' IS DISTINCT FROM file.manifest_hash
    OR NEW.snapshot->'manifest' IS DISTINCT FROM file.manifest
    OR NEW.snapshot->'interval' IS DISTINCT FROM parent.payload->'intervals'->(NEW.interval_no-1)
    OR (NEW.snapshot->>'submission_id')::bigint IS DISTINCT FROM NEW.submission_id
    OR (NEW.snapshot->>'evidence_id')::bigint IS DISTINCT FROM NEW.evidence_id
    OR (NEW.snapshot->>'interval_no')::integer IS DISTINCT FROM NEW.interval_no
    OR (NEW.snapshot->>'version')::integer IS DISTINCT FROM NEW.version
    OR NEW.snapshot->>'basis_hash' IS DISTINCT FROM NEW.basis_hash
    OR NEW.snapshot->'basis' IS DISTINCT FROM NEW.basis
    OR (NEW.snapshot->>'technical_review_event_id')::bigint IS DISTINCT FROM tech_event_id
    OR NEW.snapshot->>'technical_review_hash' IS DISTINCT FROM tech_hash
    OR NEW.snapshot->>'technical_review_state' IS DISTINCT FROM tech_state
    OR (NEW.snapshot->>'reference_review_event_id')::bigint IS DISTINCT FROM ref_event_id
    OR NEW.snapshot->>'reference_review_hash' IS DISTINCT FROM ref_hash
    OR NEW.snapshot->>'reference_review_state' IS DISTINCT FROM ref_state
    OR NEW.snapshot->'acceptance_capture_complete' IS DISTINCT FROM to_jsonb(NEW.state='ACCEPTANCE_RECORDED_UNVERIFIED')
    OR NEW.snapshot->'contractual_acceptance' IS DISTINCT FROM 'false'::jsonb
    OR NEW.snapshot->'legal_effect_confirmed' IS DISTINCT FROM 'false'::jsonb
    OR NEW.snapshot->>'legal_applicability_status'<>'UNASSESSED'
    OR NEW.snapshot->'authority_verified' IS DISTINCT FROM 'false'::jsonb
    OR NEW.snapshot->'human_identity_verified' IS DISTINCT FROM 'false'::jsonb
    OR NEW.snapshot->'evidence_verified' IS DISTINCT FROM 'false'::jsonb
    OR NEW.snapshot->'malware_scanned' IS DISTINCT FROM 'false'::jsonb
    OR NEW.snapshot->'billing_enabled' IS DISTINCT FROM 'false'::jsonb
    OR NEW.snapshot->'event'->>'action' IS DISTINCT FROM NEW.action
    OR (NEW.snapshot->'event'->'actor'->>'id')::bigint IS DISTINCT FROM NEW.actor_id
    OR NEW.snapshot->'event'->'actor'->>'username' IS DISTINCT FROM NEW.actor_name
    OR NEW.snapshot->'event'->'confirmed' IS DISTINCT FROM to_jsonb(NEW.action<>'SUBMIT') THEN
   RAISE EXCEPTION 'Contract-acceptance snapshot mismatch';
 END IF;
 IF NEW.action IN ('APPROVE1','APPROVE2','REJECT','REVOKE') THEN
   SELECT audit_id,diubah_pada INTO delivery_id,delivery_at FROM param.audit_log
    WHERE tabel='commercial.standby_evidence' AND record_key=file.evidence_id::text
      AND kolom='download' AND nilai_baru='normalized:'||file.sha256
      AND diubah_oleh=NEW.actor_name AND diubah_pada>=file.created_at AND diubah_pada<=NEW.created_at
    ORDER BY diubah_pada DESC,audit_id DESC LIMIT 1;
   IF delivery_id IS NULL
      OR (NEW.snapshot->'reviewer_delivery'->>'audit_id')::bigint IS DISTINCT FROM delivery_id
      OR (NEW.snapshot->'reviewer_delivery'->>'actor_id')::bigint IS DISTINCT FROM NEW.actor_id
      OR NEW.snapshot->'reviewer_delivery'->>'username' IS DISTINCT FROM NEW.actor_name
      OR NEW.snapshot->'reviewer_delivery'->>'file_sha256' IS DISTINCT FROM file.sha256
      OR (NEW.snapshot->'reviewer_delivery'->>'at')::timestamptz IS DISTINCT FROM delivery_at THEN
     RAISE EXCEPTION 'Decision maker must download this exact normalized file first';
   END IF;
 END IF;
 preparer_id:=parent.prepared_by_id;
 IF NEW.action IN ('SUBMIT','APPROVE1','APPROVE2') THEN
   IF tech_state IS DISTINCT FROM 'TECHNICAL_REVIEWED' OR ref_state IS DISTINCT FROM 'REFERENCES_REVIEWED' THEN
     RAISE EXCEPTION 'Current technical and reference reviews are required';
   END IF;
   IF parent.revision<>(SELECT max(revision) FROM commercial.standby_trip_submission WHERE trip_id=parent.trip_id) THEN
     RAISE EXCEPTION 'Submission superseded';
   END IF;
 END IF;
 IF NEW.action='SUBMIT' THEN
   IF NEW.state<>'PENDING_1' OR NEW.actor_id<>preparer_id
      OR (previous.event_id IS NOT NULL AND previous.state NOT IN ('REJECTED','CANCELLED','REVOKED')) THEN
     RAISE EXCEPTION 'Invalid acceptance submission';
   END IF;
   expected_actors:=jsonb_build_object('preparer',parent.payload->'prepared_by');
   IF NEW.snapshot->'actors' IS DISTINCT FROM expected_actors THEN RAISE EXCEPTION 'Acceptance preparer snapshot mismatch'; END IF;
   RETURN NEW;
 END IF;
 IF previous.event_id IS NULL OR NEW.basis IS DISTINCT FROM previous.basis
    OR NEW.basis_hash IS DISTINCT FROM previous.basis_hash
    OR NEW.snapshot->'actors' IS DISTINCT FROM previous.snapshot->'actors' THEN
   expected_actors:=CASE WHEN previous.event_id IS NULL THEN jsonb_build_object('preparer',parent.payload->'prepared_by') ELSE previous.snapshot->'actors' END;
   -- The event-specific approver is appended below; preparer and earlier decisions remain immutable.
   IF NEW.action NOT IN ('APPROVE1','APPROVE2') OR NEW.snapshot->'actors'->'preparer' IS DISTINCT FROM expected_actors->'preparer' THEN
     RAISE EXCEPTION 'Acceptance basis/actor history mismatch';
   END IF;
 END IF;
 IF NEW.action='APPROVE1' THEN
   expected_actors:=previous.snapshot->'actors'||jsonb_build_object('approver_1',NEW.snapshot->'event'->'actor');
   IF previous.state<>'PENDING_1' OR NEW.state<>'PENDING_2' OR NEW.actor_id=preparer_id
      OR NEW.snapshot->'actors' IS DISTINCT FROM expected_actors THEN RAISE EXCEPTION 'Invalid first acceptance approval'; END IF;
   RETURN NEW;
 END IF;
 IF NEW.action='APPROVE2' THEN
   expected_actors:=previous.snapshot->'actors'||jsonb_build_object('approver_2',NEW.snapshot->'event'->'actor');
   first_approver_id:=(previous.snapshot->'actors'->'approver_1'->>'id')::bigint;
   IF previous.state<>'PENDING_2' OR NEW.state<>'ACCEPTANCE_RECORDED_UNVERIFIED'
      OR NEW.actor_id=preparer_id OR NEW.actor_id=first_approver_id
      OR NEW.snapshot->'actors' IS DISTINCT FROM expected_actors THEN RAISE EXCEPTION 'Invalid second acceptance approval'; END IF;
   RETURN NEW;
 END IF;
 IF NEW.snapshot->'actors' IS DISTINCT FROM previous.snapshot->'actors' THEN RAISE EXCEPTION 'Acceptance actor history changed'; END IF;
 IF NEW.action='CANCEL' AND NEW.state='CANCELLED' AND NEW.actor_id=preparer_id
    AND previous.state IN ('PENDING_1','PENDING_2') THEN RETURN NEW; END IF;
 IF NEW.action='REJECT' AND NEW.state='REJECTED' AND NEW.actor_id<>preparer_id
    AND previous.state IN ('PENDING_1','PENDING_2') THEN RETURN NEW; END IF;
 IF NEW.action='REVOKE' AND NEW.state='REVOKED' AND NEW.actor_id<>preparer_id
    AND previous.state='ACCEPTANCE_RECORDED_UNVERIFIED' THEN RETURN NEW; END IF;
 RAISE EXCEPTION 'Invalid contract-acceptance transition';
END $$;
DROP TRIGGER IF EXISTS standby_contract_acceptance_transition41 ON commercial.standby_contract_acceptance;
CREATE TRIGGER standby_contract_acceptance_transition41 BEFORE INSERT ON commercial.standby_contract_acceptance
 FOR EACH ROW EXECUTE FUNCTION commercial.standby_contract_acceptance_transition41();
DROP TRIGGER IF EXISTS standby_contract_acceptance_immutable41 ON commercial.standby_contract_acceptance;
CREATE TRIGGER standby_contract_acceptance_immutable41 BEFORE UPDATE OR DELETE ON commercial.standby_contract_acceptance
 FOR EACH ROW EXECUTE FUNCTION commercial.standby_review_immutable36();
DROP TRIGGER IF EXISTS standby_contract_acceptance_truncate41 ON commercial.standby_contract_acceptance;
CREATE TRIGGER standby_contract_acceptance_truncate41 BEFORE TRUNCATE ON commercial.standby_contract_acceptance
 FOR EACH STATEMENT EXECUTE FUNCTION commercial.standby_review_immutable36();
COMMIT;
