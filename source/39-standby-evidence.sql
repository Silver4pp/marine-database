-- Technical file custody only; no claim of authenticity, malware clearance or billing.
BEGIN;
CREATE TABLE IF NOT EXISTS commercial.standby_evidence (
 evidence_id bigserial PRIMARY KEY,
 submission_id bigint NOT NULL REFERENCES commercial.standby_trip_submission(submission_id),
 interval_no integer NOT NULL CHECK(interval_no BETWEEN 1 AND 100),
 version integer NOT NULL CHECK(version BETWEEN 1 AND 5),
 request_key uuid NOT NULL UNIQUE,
 request_hash text NOT NULL CHECK(request_hash ~ '^[0-9a-f]{64}$'),
 uploader_id bigint NOT NULL CHECK(uploader_id>0),
 original_name varchar(160) NOT NULL,
 mime text NOT NULL CHECK(mime IN ('application/pdf','image/jpeg','image/png')),
 extension text NOT NULL CHECK(extension IN ('pdf','jpg','png')),
 source_sha256 text NOT NULL CHECK(source_sha256 ~ '^[0-9a-f]{64}$'),
 sha256 text NOT NULL CHECK(sha256 ~ '^[0-9a-f]{64}$'),
 source_data bytea NOT NULL CHECK(octet_length(source_data) BETWEEN 1 AND 5242880),
 data bytea NOT NULL CHECK(octet_length(data) BETWEEN 1 AND 5242880),
 manifest jsonb NOT NULL CHECK(manifest @> '{"state":"TECHNICAL_COPY_ONLY","authenticity_verified":false,"malware_scanned":false,"billing_enabled":false}'::jsonb),
 manifest_hash text NOT NULL CHECK(manifest_hash ~ '^[0-9a-f]{64}$'),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(submission_id,interval_no,version),
 CHECK((manifest->>'interval_no')::integer IS NOT DISTINCT FROM interval_no),
 CHECK((manifest->>'version')::integer IS NOT DISTINCT FROM version),
 CHECK(manifest->>'source_sha256' IS NOT DISTINCT FROM source_sha256),
 CHECK(manifest->>'sha256' IS NOT DISTINCT FROM sha256),
 CHECK((manifest->>'submission_id')::bigint IS NOT DISTINCT FROM submission_id)
);
CREATE OR REPLACE FUNCTION commercial.standby_evidence_insert39() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE parent commercial.standby_trip_submission%ROWTYPE; last_version integer; num_files bigint; stored_bytes bigint;
BEGIN
 SELECT * INTO STRICT parent FROM commercial.standby_trip_submission WHERE submission_id=NEW.submission_id;
 PERFORM 1 FROM operational.trip WHERE trip_id=parent.trip_id FOR UPDATE;
 IF NEW.uploader_id<>parent.prepared_by_id OR NEW.interval_no>jsonb_array_length(parent.payload->'intervals') THEN RAISE EXCEPTION 'Invalid uploader or interval'; END IF;
 IF parent.revision<>(SELECT max(revision) FROM commercial.standby_trip_submission WHERE trip_id=parent.trip_id)
    OR EXISTS(SELECT 1 FROM commercial.standby_trip_review WHERE submission_id=NEW.submission_id) THEN RAISE EXCEPTION 'Submission superseded or review already started'; END IF;
 IF NEW.manifest->>'submission_hash' IS DISTINCT FROM parent.payload_hash
    OR NEW.manifest->'interval' IS DISTINCT FROM parent.payload->'intervals'->(NEW.interval_no-1)
    OR (NEW.manifest->'uploader'->>'id')::bigint IS DISTINCT FROM NEW.uploader_id THEN RAISE EXCEPTION 'Manifest binding mismatch'; END IF;
 SELECT coalesce(max(version),0) INTO last_version FROM commercial.standby_evidence WHERE submission_id=NEW.submission_id AND interval_no=NEW.interval_no;
 IF NEW.version<>last_version+1 THEN RAISE EXCEPTION 'Stale evidence version'; END IF;
 SELECT count(*),coalesce(sum(octet_length(source_data)::bigint+octet_length(data)::bigint),0) INTO num_files,stored_bytes FROM commercial.standby_evidence WHERE submission_id=NEW.submission_id;
 IF num_files>=100 OR stored_bytes+octet_length(NEW.source_data)+octet_length(NEW.data)>52428800 THEN RAISE EXCEPTION 'Submission evidence quota exceeded'; END IF;
 RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS standby_evidence_insert39 ON commercial.standby_evidence;
CREATE TRIGGER standby_evidence_insert39 BEFORE INSERT ON commercial.standby_evidence FOR EACH ROW EXECUTE FUNCTION commercial.standby_evidence_insert39();
DROP TRIGGER IF EXISTS standby_evidence_immutable39 ON commercial.standby_evidence;
CREATE TRIGGER standby_evidence_immutable39 BEFORE UPDATE OR DELETE ON commercial.standby_evidence FOR EACH ROW EXECUTE FUNCTION commercial.standby_review_immutable36();
DROP TRIGGER IF EXISTS standby_evidence_truncate39 ON commercial.standby_evidence;
CREATE TRIGGER standby_evidence_truncate39 BEFORE TRUNCATE ON commercial.standby_evidence FOR EACH STATEMENT EXECUTE FUNCTION commercial.standby_review_immutable36();
COMMIT;
