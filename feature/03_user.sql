-- ============================================================
-- FEATURE SCHEMA: user
-- file    : feature/03_user.sql
-- objects : 3 statement(s)
-- generated from original/schema_v1_original.sql by tools/split_schema.py
-- ============================================================

-- ============================================================
-- SECTION 6: USER SCHEMA TABLES
-- ============================================================

CREATE TABLE "user".info (
    user_code       VARCHAR(30)     PRIMARY KEY,
    name            VARCHAR(150)    NOT NULL,
    role            VARCHAR(50)     NOT NULL
                        REFERENCES param.role(role_code) ON DELETE RESTRICT,
    employee_id     VARCHAR(30),
    department      VARCHAR(100),
    tenant_id       UUID,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE "user".detail (
    id              BIGSERIAL       PRIMARY KEY,
    user_code       VARCHAR(30)     NOT NULL
                        REFERENCES "user".info(user_code) ON DELETE CASCADE,
    contact_type    VARCHAR(30)     NOT NULL
                        CHECK (contact_type IN ('PHONE','EMAIL','FAX','ADDRESS','EMERGENCY')),
    contact_value   VARCHAR(200)    NOT NULL,
    is_primary      BOOLEAN         NOT NULL DEFAULT FALSE,
    is_verified     BOOLEAN         NOT NULL DEFAULT FALSE,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    CONSTRAINT uq_user_contact UNIQUE (user_code, contact_type, contact_value)
);

CREATE TABLE "user".session_log (
    id              BIGSERIAL       PRIMARY KEY,
    user_code       VARCHAR(30)     NOT NULL
                        REFERENCES "user".info(user_code) ON DELETE CASCADE,
    session_id      VARCHAR(100),
    ip_address      INET,
    user_agent      TEXT,
    login_time      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    logout_time     TIMESTAMPTZ,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE
);
