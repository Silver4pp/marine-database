BEGIN;
CREATE TABLE IF NOT EXISTS partner.statement_receipt (
 statement_line_id bigint NOT NULL REFERENCES partner.statement_line(statement_line_id),
 partner_code varchar(30) NOT NULL REFERENCES partner.info(partner_code),
 snapshot_hash text NOT NULL CHECK(snapshot_hash ~ '^[0-9a-f]{64}$'),
 snapshot jsonb NOT NULL CHECK(jsonb_typeof(snapshot)='object'),
 received_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 received_by varchar(150) NOT NULL,
 auth_user_id bigint NOT NULL,
 PRIMARY KEY(statement_line_id,partner_code,snapshot_hash)
);
COMMENT ON TABLE partner.statement_receipt IS 'Partner receipt of a specific statement version, not approval or payment. No cascade deletion; preserve receipt and audit history.';
COMMIT;
