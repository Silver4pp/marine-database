BEGIN;
CREATE TABLE IF NOT EXISTS partner.statement_dispute (
 dispute_id bigserial PRIMARY KEY,
 statement_line_id bigint NOT NULL REFERENCES partner.statement_line(statement_line_id),
 partner_code varchar(30) NOT NULL REFERENCES partner.info(partner_code),
 snapshot_hash text NOT NULL CHECK(snapshot_hash ~ '^[0-9a-f]{64}$'),
 snapshot jsonb NOT NULL CHECK(jsonb_typeof(snapshot)='object'),
 state text NOT NULL DEFAULT 'BARU' CHECK(state IN ('BARU','DIPROSES','SELESAI')),
 version integer NOT NULL DEFAULT 1 CHECK(version>0),
 created_by varchar(150) NOT NULL, auth_user_id bigint NOT NULL,
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(statement_line_id,partner_code)
);
CREATE TABLE IF NOT EXISTS partner.dispute_message (
 message_id bigserial PRIMARY KEY,
 dispute_id bigint NOT NULL REFERENCES partner.statement_dispute(dispute_id),
 version integer NOT NULL CHECK(version>0),
 author varchar(150) NOT NULL, auth_user_id bigint NOT NULL,
 author_role varchar(20) NOT NULL CHECK(author_role IN ('PARTNER','OPS','KEU')),
 body text NOT NULL CHECK(char_length(body) BETWEEN 1 AND 2000),
 state_before text, state_after text NOT NULL CHECK(state_after IN ('BARU','DIPROSES','SELESAI')),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(dispute_id,version)
);
COMMENT ON TABLE partner.statement_dispute IS 'One persistent case per statement line and partner. Opening snapshot retained; no amount/payment mutations; no cascade deletion.';
COMMIT;
