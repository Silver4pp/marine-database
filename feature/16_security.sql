-- ============================================================
-- FEATURE SCHEMA: security
-- file    : feature/16_security.sql
-- objects : 7 statement(s)
-- generated from original/schema_v1_original.sql by tools/split_schema.py
-- ============================================================

-- ============================================================
-- SECTION 19: SECURITY SCHEMA TABLES (Supabase Integration)
-- ============================================================

CREATE TABLE security.app_user (
    auth_user_id    UUID            PRIMARY KEY
                        REFERENCES auth.users(id) ON DELETE CASCADE,
    user_code       VARCHAR(30)     NOT NULL UNIQUE,
    name            VARCHAR(150)    NOT NULL,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    is_super_admin  BOOLEAN         NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE security.tenant (
    tenant_id       UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_code     VARCHAR(30)     NOT NULL UNIQUE,
    tenant_name     VARCHAR(200)    NOT NULL,
    site_code       VARCHAR(30)
                        REFERENCES site.info(site_code) ON DELETE SET NULL,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE security.user_scope (
    scope_id        BIGSERIAL       PRIMARY KEY,
    auth_user_id    UUID            NOT NULL
                        REFERENCES security.app_user(auth_user_id) ON DELETE CASCADE,
    tenant_id       UUID            NOT NULL
                        REFERENCES security.tenant(tenant_id) ON DELETE RESTRICT,
    partner_code    VARCHAR(30),
    buyer_code      VARCHAR(30),
    role_code       VARCHAR(50)      NOT NULL,
    is_primary      BOOLEAN         NOT NULL DEFAULT FALSE,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    valid_from      TIMESTAMPTZ,
    valid_until     TIMESTAMPTZ,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    CONSTRAINT uq_user_tenant UNIQUE (auth_user_id, tenant_id)
);

CREATE TABLE security.permission (
    permission_id   BIGSERIAL       PRIMARY KEY,
    permission_code VARCHAR(100)    NOT NULL UNIQUE,
    permission_name VARCHAR(200)     NOT NULL,
    module          VARCHAR(50)     NOT NULL,
    description     TEXT,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE security.role_permission (
    id              BIGSERIAL       PRIMARY KEY,
    role_code       VARCHAR(50)     NOT NULL,
    permission_code VARCHAR(100)    NOT NULL
                        REFERENCES security.permission(permission_code) ON DELETE CASCADE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    CONSTRAINT uq_role_permission UNIQUE (role_code, permission_code)
);

-- Security: Get current tenant ID
CREATE OR REPLACE FUNCTION security.fn_get_current_tenant_id()
RETURNS UUID AS $$
BEGIN RETURN (
    SELECT tenant_id FROM security.user_scope
    WHERE auth_user_id = auth.uid() AND is_active = TRUE
    ORDER BY is_primary DESC LIMIT 1
);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Security: Check if super admin
CREATE OR REPLACE FUNCTION security.fn_is_super_admin()
RETURNS BOOLEAN AS $$
BEGIN RETURN (
    SELECT is_super_admin FROM security.app_user WHERE auth_user_id = auth.uid()
);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
