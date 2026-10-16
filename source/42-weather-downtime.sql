-- Reviewed, evidence-linked operational downtime; never proves weather causation or force majeure.
BEGIN;

CREATE OR REPLACE FUNCTION operational.weather_downtime_trip_snapshot42(p_trip_id bigint)
RETURNS jsonb LANGUAGE sql STABLE AS $$
 SELECT jsonb_build_object(
   'trip_id',t.trip_id,'trip_no',t.trip_no,'fleet_code',t.fleet_code,'status',t.status,
   'ts_loading_start',CASE WHEN t.ts_loading_start IS NULL THEN NULL ELSE to_char(t.ts_loading_start AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"') END,
   'ts_departed',CASE WHEN t.ts_departed IS NULL THEN NULL ELSE to_char(t.ts_departed AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"') END,
   'ts_arrived',CASE WHEN t.ts_arrived IS NULL THEN NULL ELSE to_char(t.ts_arrived AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"') END,
   'ts_discharge_start',CASE WHEN t.ts_discharge_start IS NULL THEN NULL ELSE to_char(t.ts_discharge_start AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"') END,
   'ts_discharge_end',CASE WHEN t.ts_discharge_end IS NULL THEN NULL ELSE to_char(t.ts_discharge_end AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"') END,
   'ts_closed',CASE WHEN t.ts_closed IS NULL THEN NULL ELSE to_char(t.ts_closed AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"') END
 ) FROM operational.trip t WHERE t.trip_id=p_trip_id
$$;

CREATE TABLE IF NOT EXISTS operational.weather_downtime (
 record_id bigserial PRIMARY KEY,
 trip_id bigint NOT NULL REFERENCES operational.trip(trip_id),
 request_key uuid NOT NULL UNIQUE,
 request_hash char(64) NOT NULL CHECK(request_hash ~ '^[0-9a-f]{64}$'),
 prepared_by_id bigint NOT NULL CHECK(prepared_by_id>0),
 prepared_by text NOT NULL CHECK(length(btrim(prepared_by)) BETWEEN 1 AND 150),
 started_at timestamptz NOT NULL,
 stopped_at timestamptz NOT NULL CHECK(stopped_at>started_at),
 category text NOT NULL CHECK(category IN ('WEATHER','EQUIPMENT','PORT','OPERATIONAL','OTHER')),
 reason text NOT NULL CHECK(length(btrim(reason)) BETWEEN 10 AND 1000),
 evidence_reference text NOT NULL CHECK(length(btrim(evidence_reference)) BETWEEN 3 AND 300),
 weather_snapshot_id bigint REFERENCES operational.weather_snapshot(snapshot_id),
 weather_context_reference text NOT NULL DEFAULT '' CHECK(length(btrim(weather_context_reference))<=300),
 trip_source jsonb NOT NULL,
 trip_source_hash char(64) NOT NULL CHECK(trip_source_hash ~ '^[0-9a-f]{64}$'),
 original_name text NOT NULL CHECK(length(original_name) BETWEEN 1 AND 160),
 mime text NOT NULL CHECK(mime IN ('image/jpeg','image/png','application/pdf')),
 extension text NOT NULL CHECK(extension IN ('jpg','png','pdf')),
 source_sha256 char(64) NOT NULL CHECK(source_sha256 ~ '^[0-9a-f]{64}$'),
 sha256 char(64) NOT NULL CHECK(sha256 ~ '^[0-9a-f]{64}$'),
 source_data bytea NOT NULL CHECK(octet_length(source_data) BETWEEN 1 AND 5242880),
 data bytea NOT NULL CHECK(octet_length(data) BETWEEN 1 AND 5242880),
 parser_metadata jsonb NOT NULL,
 manifest jsonb NOT NULL,
 manifest_hash char(64) NOT NULL CHECK(manifest_hash ~ '^[0-9a-f]{64}$'),
 payload jsonb NOT NULL CHECK(payload @> '{"scope":"WEATHER_DOWNTIME_CAPTURE","source_authenticity_verified":false,"evidence_verified":false,"malware_scanned":false,"causality_verified":false,"force_majeure_confirmed":false,"human_identity_verified":false,"billing_enabled":false}'::jsonb),
 payload_hash char(64) NOT NULL CHECK(payload_hash ~ '^[0-9a-f]{64}$'),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 CHECK(payload->>'trip_id'=trip_id::text),
 CHECK(payload->>'started_at' IS NOT DISTINCT FROM to_char(started_at AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"')),
 CHECK(payload->>'stopped_at' IS NOT DISTINCT FROM to_char(stopped_at AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"')),
 CHECK(payload->>'category' IS NOT DISTINCT FROM category),
 CHECK(payload->>'reason' IS NOT DISTINCT FROM reason),
 CHECK(payload->>'evidence_reference' IS NOT DISTINCT FROM evidence_reference),
 CHECK(payload->>'weather_context_reference' IS NOT DISTINCT FROM weather_context_reference),
 CHECK(payload->>'submit_confirmation' IS NOT DISTINCT FROM 'true'),
 CHECK(payload->'weather_snapshot_id' IS NOT DISTINCT FROM coalesce(to_jsonb(weather_snapshot_id),'null'::jsonb)),
 CHECK(payload->>'trip_source_hash' IS NOT DISTINCT FROM trip_source_hash),
 CHECK(payload->>'source_sha256' IS NOT DISTINCT FROM source_sha256),
 CHECK(payload->>'sha256' IS NOT DISTINCT FROM sha256),
 CHECK(manifest->>'source_sha256' IS NOT DISTINCT FROM source_sha256),
 CHECK(manifest->>'sha256' IS NOT DISTINCT FROM sha256),
 CHECK(manifest->>'original_name' IS NOT DISTINCT FROM original_name)
);
CREATE INDEX IF NOT EXISTS weather_downtime_trip_time42_idx
 ON operational.weather_downtime(trip_id,started_at,record_id DESC);
CREATE INDEX IF NOT EXISTS weather_downtime_time42_idx
 ON operational.weather_downtime(started_at DESC,record_id DESC);

CREATE OR REPLACE FUNCTION operational.weather_downtime_record_guard42() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE t operational.trip%ROWTYPE; lo timestamptz; hi timestamptz; current_source jsonb; weather_kind text;
BEGIN
 SELECT * INTO STRICT t FROM operational.trip WHERE trip_id=NEW.trip_id FOR UPDATE;
 current_source:=operational.weather_downtime_trip_snapshot42(NEW.trip_id);
 IF current_source IS DISTINCT FROM NEW.trip_source THEN RAISE EXCEPTION 'Trip source changed; refresh downtime capture'; END IF;
 IF t.status='CANCELLED' THEN RAISE EXCEPTION 'Cancelled trip cannot receive a downtime record'; END IF;
 lo:=LEAST(t.ts_loading_start,t.ts_departed,t.ts_arrived,t.ts_discharge_start);
 hi:=coalesce(t.ts_closed,clock_timestamp());
 IF lo IS NULL OR NEW.started_at<lo OR NEW.stopped_at>hi OR NEW.stopped_at>clock_timestamp() THEN
   RAISE EXCEPTION 'Downtime interval is outside the recorded trip window';
 END IF;
 IF NEW.weather_snapshot_id IS NOT NULL THEN
   SELECT kind INTO weather_kind FROM operational.weather_snapshot WHERE snapshot_id=NEW.weather_snapshot_id;
   IF weather_kind IS DISTINCT FROM 'ACQUISITION' THEN RAISE EXCEPTION 'Only an acquisition snapshot may be linked as forecast context'; END IF;
   IF length(btrim(NEW.weather_context_reference))<3 THEN RAISE EXCEPTION 'Weather context reference required'; END IF;
 ELSIF length(btrim(NEW.weather_context_reference))>0 THEN
   RAISE EXCEPTION 'Weather context reference requires a linked acquisition snapshot';
 END IF;
 IF octet_length(NEW.source_data)>5242880 OR octet_length(NEW.data)>5242880
    OR encode(sha256(NEW.source_data),'hex')<>NEW.source_sha256
    OR encode(sha256(NEW.data),'hex')<>NEW.sha256 THEN
   RAISE EXCEPTION 'Downtime evidence bytes/digests do not match';
 END IF;
 IF NEW.payload->'trip_source' IS DISTINCT FROM NEW.trip_source
    OR NEW.payload->>'trip_source_hash' IS DISTINCT FROM NEW.trip_source_hash
    OR NEW.payload->'manifest' IS DISTINCT FROM NEW.manifest
    OR NEW.payload->>'manifest_hash' IS DISTINCT FROM NEW.manifest_hash
    OR NEW.payload->'parser_metadata' IS DISTINCT FROM NEW.parser_metadata
    OR NEW.payload->'prepared_by'->>'username' IS DISTINCT FROM NEW.prepared_by
    OR (NEW.payload->'prepared_by'->>'id')::bigint IS DISTINCT FROM NEW.prepared_by_id
    OR NEW.manifest->'prepared_by'->>'username' IS DISTINCT FROM NEW.prepared_by
    OR (NEW.manifest->'prepared_by'->>'id')::bigint IS DISTINCT FROM NEW.prepared_by_id
    OR NEW.manifest_hash !~ '^[0-9a-f]{64}$'
    OR NEW.manifest->>'trip_source_hash' IS DISTINCT FROM NEW.trip_source_hash
    OR NEW.payload->>'source_authenticity_verified'<>'false'
    OR NEW.payload->>'evidence_verified'<>'false'
    OR NEW.payload->>'malware_scanned'<>'false'
    OR NEW.payload->>'causality_verified'<>'false'
    OR NEW.payload->>'force_majeure_confirmed'<>'false'
    OR NEW.payload->>'human_identity_verified'<>'false'
    OR NEW.payload->>'billing_enabled'<>'false' THEN
   RAISE EXCEPTION 'Downtime capture snapshot mismatch';
 END IF;
 RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS weather_downtime_record_guard42 ON operational.weather_downtime;
CREATE TRIGGER weather_downtime_record_guard42 BEFORE INSERT ON operational.weather_downtime
 FOR EACH ROW EXECUTE FUNCTION operational.weather_downtime_record_guard42();

CREATE TABLE IF NOT EXISTS operational.weather_downtime_review (
 event_id bigserial PRIMARY KEY,
 record_id bigint NOT NULL REFERENCES operational.weather_downtime(record_id),
 version integer NOT NULL CHECK(version>0),
 request_key uuid NOT NULL UNIQUE,
 request_hash char(64) NOT NULL CHECK(request_hash ~ '^[0-9a-f]{64}$'),
 action text NOT NULL CHECK(action IN ('SUBMIT','APPROVE1','APPROVE2','REJECT','CANCEL','REVOKE')),
 state text NOT NULL CHECK(state IN ('PENDING_1','PENDING_2','REVIEWED_BY_TWO_ACCOUNTS','REJECTED','CANCELLED','REVOKED')),
 actor_id bigint NOT NULL CHECK(actor_id>0),
 actor_name text NOT NULL CHECK(length(btrim(actor_name)) BETWEEN 1 AND 150),
 snapshot jsonb NOT NULL CHECK(snapshot @> '{"scope":"WEATHER_DOWNTIME_REVIEW","source_authenticity_verified":false,"evidence_verified":false,"malware_scanned":false,"causality_verified":false,"force_majeure_confirmed":false,"human_identity_verified":false,"billing_enabled":false}'::jsonb),
 snapshot_hash char(64) NOT NULL CHECK(snapshot_hash ~ '^[0-9a-f]{64}$'),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(record_id,version),
 CHECK(snapshot->>'record_id'=record_id::text),
 CHECK(snapshot->>'version'=version::text),
 CHECK(snapshot->>'request_hash'=request_hash),
 CHECK(snapshot->>'action'=action),
 CHECK(snapshot->>'state'=state),
 CHECK(snapshot->'source_authenticity_verified'='false'::jsonb),
 CHECK(snapshot->'evidence_verified'='false'::jsonb),
 CHECK(snapshot->'malware_scanned'='false'::jsonb),
 CHECK(snapshot->'causality_verified'='false'::jsonb),
 CHECK(snapshot->'force_majeure_confirmed'='false'::jsonb),
 CHECK(snapshot->'human_identity_verified'='false'::jsonb),
 CHECK(snapshot->'billing_enabled'='false'::jsonb)
);
CREATE INDEX IF NOT EXISTS weather_downtime_review_latest42_idx
 ON operational.weather_downtime_review(record_id,version DESC);

CREATE OR REPLACE FUNCTION operational.weather_downtime_review_transition42() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE d operational.weather_downtime%ROWTYPE; previous operational.weather_downtime_review%ROWTYPE;
 current_source jsonb; expected_actors jsonb; delivery_id bigint; delivery_at timestamptz;
BEGIN
 SELECT * INTO STRICT d FROM operational.weather_downtime WHERE record_id=NEW.record_id;
 PERFORM 1 FROM operational.trip WHERE trip_id=d.trip_id FOR UPDATE;
 PERFORM 1 FROM operational.weather_downtime WHERE record_id=NEW.record_id FOR UPDATE;
 SELECT * INTO previous FROM operational.weather_downtime_review WHERE record_id=NEW.record_id ORDER BY version DESC LIMIT 1;
 IF NEW.version<>coalesce(previous.version,0)+1 THEN RAISE EXCEPTION 'Stale downtime review version'; END IF;
 IF NEW.snapshot->'payload' IS DISTINCT FROM d.payload
    OR NEW.snapshot->>'payload_hash' IS DISTINCT FROM d.payload_hash
    OR NEW.snapshot->>'file_sha256' IS DISTINCT FROM d.sha256
    OR NEW.snapshot->>'source_sha256' IS DISTINCT FROM d.source_sha256
    OR NEW.snapshot->>'trip_source_hash' IS DISTINCT FROM d.trip_source_hash
    OR (NEW.snapshot->>'weather_snapshot_id') IS DISTINCT FROM (d.weather_snapshot_id::text)
    OR NEW.snapshot->'actors' IS NULL
    OR NEW.snapshot->'event'->>'action' IS DISTINCT FROM NEW.action
    OR NEW.snapshot->'event'->'actor'->>'username' IS DISTINCT FROM NEW.actor_name
    OR (NEW.snapshot->'event'->'actor'->>'id')::bigint IS DISTINCT FROM NEW.actor_id
    OR NEW.snapshot->'event'->'confirmed' IS DISTINCT FROM 'true'::jsonb THEN
   RAISE EXCEPTION 'Downtime review snapshot mismatch';
 END IF;
 IF NEW.action IN ('APPROVE1','APPROVE2','REJECT','REVOKE') THEN
   SELECT audit_id,diubah_pada INTO delivery_id,delivery_at FROM param.audit_log
    WHERE tabel='operational.weather_downtime' AND record_key=d.record_id::text
      AND kolom='download' AND nilai_baru='normalized:'||d.sha256
      AND diubah_oleh=NEW.actor_name AND diubah_pada>=d.created_at AND diubah_pada<=NEW.created_at
    ORDER BY diubah_pada DESC,audit_id DESC LIMIT 1;
   IF delivery_id IS NULL
      OR (NEW.snapshot->'reviewer_delivery'->>'audit_id')::bigint IS DISTINCT FROM delivery_id
      OR NEW.snapshot->'reviewer_delivery'->>'username' IS DISTINCT FROM NEW.actor_name
      OR NEW.snapshot->'reviewer_delivery'->>'file_sha256' IS DISTINCT FROM d.sha256
      OR (NEW.snapshot->'reviewer_delivery'->>'at')::timestamptz IS DISTINCT FROM delivery_at THEN
     RAISE EXCEPTION 'Decision maker must download this exact evidence copy first';
   END IF;
 END IF;
 IF NEW.action='SUBMIT' THEN
   IF previous.event_id IS NOT NULL OR NEW.version<>1 OR NEW.actor_id<>d.prepared_by_id OR NEW.actor_name<>d.prepared_by OR NEW.state<>'PENDING_1'
      OR NEW.snapshot->'actors' IS DISTINCT FROM jsonb_build_object('preparer',NEW.snapshot->'event'->'actor') THEN
     RAISE EXCEPTION 'Invalid downtime submission event';
   END IF;
   RETURN NEW;
 END IF;
 IF previous.event_id IS NULL OR NEW.snapshot->'payload' IS DISTINCT FROM previous.snapshot->'payload'
    OR NEW.snapshot->'payload_hash' IS DISTINCT FROM previous.snapshot->'payload_hash' THEN
   RAISE EXCEPTION 'Downtime history has no stable parent snapshot';
 END IF;
 IF NEW.action='APPROVE1' THEN
   SELECT operational.weather_downtime_trip_snapshot42(d.trip_id) INTO current_source;
   IF current_source IS DISTINCT FROM d.trip_source THEN RAISE EXCEPTION 'Trip source changed; positive review is blocked'; END IF;
   expected_actors:=previous.snapshot->'actors'||jsonb_build_object('approver_1',NEW.snapshot->'event'->'actor');
   IF previous.state<>'PENDING_1' OR NEW.state<>'PENDING_2' OR NEW.actor_id=d.prepared_by_id
      OR NEW.snapshot->'actors' IS DISTINCT FROM expected_actors THEN RAISE EXCEPTION 'Invalid first downtime approval'; END IF;
   RETURN NEW;
 END IF;
 IF NEW.action='APPROVE2' THEN
   SELECT operational.weather_downtime_trip_snapshot42(d.trip_id) INTO current_source;
   IF current_source IS DISTINCT FROM d.trip_source THEN RAISE EXCEPTION 'Trip source changed; positive review is blocked'; END IF;
   expected_actors:=previous.snapshot->'actors'||jsonb_build_object('approver_2',NEW.snapshot->'event'->'actor');
   IF previous.state<>'PENDING_2' OR NEW.state<>'REVIEWED_BY_TWO_ACCOUNTS'
      OR NEW.actor_id=d.prepared_by_id
      OR NEW.actor_id IS NOT DISTINCT FROM (previous.snapshot->'actors'->'approver_1'->>'id')::bigint
      OR NEW.snapshot->'actors' IS DISTINCT FROM expected_actors THEN RAISE EXCEPTION 'Invalid second downtime approval'; END IF;
   IF EXISTS(SELECT 1 FROM operational.weather_downtime other
      JOIN LATERAL (SELECT state FROM operational.weather_downtime_review r WHERE r.record_id=other.record_id ORDER BY version DESC LIMIT 1) last ON true
      WHERE other.trip_id=d.trip_id AND other.record_id<>d.record_id AND last.state='REVIEWED_BY_TWO_ACCOUNTS'
        AND other.started_at<d.stopped_at AND other.stopped_at>d.started_at) THEN
     RAISE EXCEPTION 'Reviewed downtime intervals cannot overlap on the same trip';
   END IF;
   RETURN NEW;
 END IF;
 IF NEW.snapshot->'actors' IS DISTINCT FROM previous.snapshot->'actors' THEN RAISE EXCEPTION 'Downtime actor history changed'; END IF;
 IF NEW.action='CANCEL' AND NEW.state='CANCELLED' AND NEW.actor_id=d.prepared_by_id AND previous.state IN ('PENDING_1','PENDING_2') THEN RETURN NEW; END IF;
 IF NEW.action='REJECT' AND NEW.state='REJECTED' AND NEW.actor_id<>d.prepared_by_id AND previous.state IN ('PENDING_1','PENDING_2') THEN RETURN NEW; END IF;
 IF NEW.action='REVOKE' AND NEW.state='REVOKED' AND NEW.actor_id<>d.prepared_by_id AND previous.state='REVIEWED_BY_TWO_ACCOUNTS' THEN RETURN NEW; END IF;
 RAISE EXCEPTION 'Invalid downtime review transition';
END $$;
DROP TRIGGER IF EXISTS weather_downtime_review_transition42 ON operational.weather_downtime_review;
CREATE TRIGGER weather_downtime_review_transition42 BEFORE INSERT ON operational.weather_downtime_review
 FOR EACH ROW EXECUTE FUNCTION operational.weather_downtime_review_transition42();

CREATE OR REPLACE FUNCTION operational.weather_downtime_immutable42() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN RAISE EXCEPTION 'Weather downtime records/reviews are append-only; mutation forbidden'; END $$;
DROP TRIGGER IF EXISTS weather_downtime_record_immutable42 ON operational.weather_downtime;
CREATE TRIGGER weather_downtime_record_immutable42 BEFORE UPDATE OR DELETE ON operational.weather_downtime
 FOR EACH ROW EXECUTE FUNCTION operational.weather_downtime_immutable42();
DROP TRIGGER IF EXISTS weather_downtime_record_truncate42 ON operational.weather_downtime;
CREATE TRIGGER weather_downtime_record_truncate42 BEFORE TRUNCATE ON operational.weather_downtime
 FOR EACH STATEMENT EXECUTE FUNCTION operational.weather_downtime_immutable42();
DROP TRIGGER IF EXISTS weather_downtime_review_immutable42 ON operational.weather_downtime_review;
CREATE TRIGGER weather_downtime_review_immutable42 BEFORE UPDATE OR DELETE ON operational.weather_downtime_review
 FOR EACH ROW EXECUTE FUNCTION operational.weather_downtime_immutable42();
DROP TRIGGER IF EXISTS weather_downtime_review_truncate42 ON operational.weather_downtime_review;
CREATE TRIGGER weather_downtime_review_truncate42 BEFORE TRUNCATE ON operational.weather_downtime_review
 FOR EACH STATEMENT EXECUTE FUNCTION operational.weather_downtime_immutable42();

CREATE OR REPLACE VIEW analytics.v_weather_downtime AS
SELECT d.record_id,d.trip_id,t.trip_no,t.fleet_code,d.started_at,d.stopped_at,
       round((extract(epoch FROM d.stopped_at-d.started_at)/3600)::numeric,3) AS duration_hours,
       d.category,d.reason,d.evidence_reference,d.weather_snapshot_id,
       CASE WHEN d.weather_snapshot_id IS NULL THEN 'NO_SNAPSHOT_LINKED' ELSE 'FORECAST_CONTEXT_ONLY' END AS weather_context_state,
       d.prepared_by,d.created_at,
       last.snapshot->'actors'->'approver_1'->>'username' AS reviewer_1,
       last.snapshot->'actors'->'approver_2'->>'username' AS reviewer_2,
       last.created_at AS reviewed_at
FROM operational.weather_downtime d
JOIN operational.trip t USING(trip_id)
JOIN LATERAL (SELECT state,snapshot,created_at FROM operational.weather_downtime_review r
              WHERE r.record_id=d.record_id ORDER BY version DESC LIMIT 1) last ON last.state='REVIEWED_BY_TWO_ACCOUNTS';

COMMIT;
