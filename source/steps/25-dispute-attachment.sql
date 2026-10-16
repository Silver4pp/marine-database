BEGIN;
CREATE TABLE IF NOT EXISTS partner.dispute_attachment (
 attachment_id bigserial PRIMARY KEY,
 message_id bigint NOT NULL UNIQUE REFERENCES partner.dispute_message(message_id),
 original_name varchar(160) NOT NULL,
 mime text NOT NULL CHECK(mime IN ('application/pdf','image/jpeg','image/png')),
 extension text NOT NULL CHECK(extension IN ('pdf','jpg','png')),
 source_sha256 text NOT NULL CHECK(source_sha256 ~ '^[0-9a-f]{64}$'),
 sha256 text NOT NULL CHECK(sha256 ~ '^[0-9a-f]{64}$'),
 source_data bytea NOT NULL CHECK(octet_length(source_data) BETWEEN 1 AND 5242880),
 data bytea NOT NULL CHECK(octet_length(data) BETWEEN 1 AND 5242880),
 metadata jsonb NOT NULL CHECK(jsonb_typeof(metadata)='object'),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
COMMENT ON TABLE partner.dispute_attachment IS 'Private evidence: original bytes archived, normalized copy downloadable only through ACL+digest verification. Not malware certification. No cascade deletion.';
COMMIT;
