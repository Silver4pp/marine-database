-- ============================================================
-- STUB Supabase `auth` schema -- ONLY for local/offline testing.
-- Never run this on a real Supabase instance.
-- ============================================================
CREATE SCHEMA IF NOT EXISTS auth;

CREATE TABLE IF NOT EXISTS auth.users (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email              VARCHAR(255) UNIQUE,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- auth.uid() reads the JWT claim 'sub'; the stub reads a session GUC instead.
CREATE OR REPLACE FUNCTION auth.uid() RETURNS UUID AS $$
    SELECT NULLIF(current_setting('request.jwt.claim.sub', true), '')::UUID;
$$ LANGUAGE sql STABLE;

CREATE OR REPLACE FUNCTION auth.role() RETURNS TEXT AS $$
    SELECT NULLIF(current_setting('request.jwt.claim.role', true), '');
$$ LANGUAGE sql STABLE;
