BEGIN;
CREATE TABLE IF NOT EXISTS operational.weather_snapshot (
 snapshot_id bigserial PRIMARY KEY,
 kind text NOT NULL CHECK(kind IN ('ACQUISITION','DECISION')),
 source_key text NOT NULL,
 fingerprint char(64) NOT NULL UNIQUE CHECK(fingerprint ~ '^[0-9a-f]{64}$'),
 digest char(64) NOT NULL UNIQUE CHECK(digest ~ '^[0-9a-f]{64}$'),
 payload_zlib bytea NOT NULL,
 payload_bytes integer NOT NULL CHECK(payload_bytes>0 AND payload_bytes<=16777216),
 recorded_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE INDEX IF NOT EXISTS weather_snapshot_source_idx ON operational.weather_snapshot(kind,source_key,snapshot_id DESC);
CREATE OR REPLACE FUNCTION operational.weather_snapshot_immutable() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN RAISE EXCEPTION 'Weather snapshots are immutable; update/delete/truncate forbidden'; END $$;
DROP TRIGGER IF EXISTS weather_snapshot_immutable ON operational.weather_snapshot;
CREATE TRIGGER weather_snapshot_immutable BEFORE UPDATE OR DELETE ON operational.weather_snapshot
 FOR EACH ROW EXECUTE FUNCTION operational.weather_snapshot_immutable();
DROP TRIGGER IF EXISTS weather_snapshot_no_truncate ON operational.weather_snapshot;
CREATE TRIGGER weather_snapshot_no_truncate BEFORE TRUNCATE ON operational.weather_snapshot
 FOR EACH STATEMENT EXECUTE FUNCTION operational.weather_snapshot_immutable();
COMMIT;
