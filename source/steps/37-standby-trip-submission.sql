-- References only: no verified attachment, exclusion activation or billing.
BEGIN;
CREATE TABLE IF NOT EXISTS commercial.standby_trip_submission (
 submission_id bigserial PRIMARY KEY,
 trip_id bigint NOT NULL REFERENCES operational.trip(trip_id),
 sales_contract_id bigint NOT NULL REFERENCES commercial.sales_contract(sales_contract_id),
 method_proposal_id bigint NOT NULL REFERENCES commercial.standby_method_proposal(proposal_id),
 revision integer NOT NULL CHECK(revision>0),
 request_key uuid NOT NULL UNIQUE,
 request_hash text NOT NULL CHECK(request_hash ~ '^[0-9a-f]{64}$'),
 prepared_by_id bigint NOT NULL CHECK(prepared_by_id>0),
 payload jsonb NOT NULL CHECK(payload @> '{"state":"SUBMITTED_UNVERIFIED","billing_enabled":false,"evidence_verified":false,"human_identity_verified":false}'::jsonb),
 payload_hash text NOT NULL CHECK(payload_hash ~ '^[0-9a-f]{64}$'),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(trip_id,revision),
 CHECK((payload->'prepared_by'->>'id')::bigint IS NOT DISTINCT FROM prepared_by_id),
 CHECK((payload->>'revision')::integer IS NOT DISTINCT FROM revision),
 CHECK((payload->>'trip_id')::bigint IS NOT DISTINCT FROM trip_id),
 CHECK((payload->>'contract_id')::bigint IS NOT DISTINCT FROM sales_contract_id),
 CHECK((payload->>'method_proposal_id')::bigint IS NOT DISTINCT FROM method_proposal_id)
);
CREATE INDEX IF NOT EXISTS standby_trip_submission_contract37_idx ON commercial.standby_trip_submission(sales_contract_id,submission_id DESC);
DROP TRIGGER IF EXISTS standby_trip_submission_immutable37 ON commercial.standby_trip_submission;
CREATE TRIGGER standby_trip_submission_immutable37 BEFORE UPDATE OR DELETE ON commercial.standby_trip_submission FOR EACH ROW EXECUTE FUNCTION commercial.standby_review_immutable36();
DROP TRIGGER IF EXISTS standby_trip_submission_truncate37 ON commercial.standby_trip_submission;
CREATE TRIGGER standby_trip_submission_truncate37 BEFORE TRUNCATE ON commercial.standby_trip_submission FOR EACH STATEMENT EXECUTE FUNCTION commercial.standby_review_immutable36();
COMMIT;
