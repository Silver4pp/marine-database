-- ============================================================
-- FEATURE SCHEMA: audit
-- file    : feature/17_audit.sql
-- objects : 1 statement(s)
-- generated from original/schema_v1_original.sql by tools/split_schema.py
-- ============================================================

-- ============================================================
-- SECTION 20: AUDIT SCHEMA TABLES
-- ============================================================

CREATE TABLE audit.log (
    log_id              BIGSERIAL       PRIMARY KEY,
    tenant_id          UUID,
    auth_user_id       UUID,
    user_code          VARCHAR(30),
    action             VARCHAR(20)     NOT NULL,
    table_schema        VARCHAR(100)    NOT NULL,
    table_name          VARCHAR(100)    NOT NULL,
    record_pk          TEXT,
    record_pk_name      VARCHAR(100),
    old_data            JSONB,
    new_data            JSONB,
    changed_fields      JSONB,
    request_id          UUID,
    source_ip           INET,
    user_agent          TEXT,
    app_version         VARCHAR(50),
    executed_at         TIMESTAMPTZ     NOT NULL DEFAULT now(),
    execution_time_ms   BIGINT
);
