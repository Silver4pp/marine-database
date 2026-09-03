-- ============================================================
-- BASE LAYER / 1: PostgreSQL extensions
-- file    : base/01_extensions.sql
-- objects : 3 statement(s)
-- note    : Run first. Requires superuser or a role with CREATE on the database.
-- generated from original/schema_v1_original.sql by tools/split_schema.py
-- ============================================================

-- ============================================================
-- DATABASE SCHEMA - COMPLETE & PRODUCTION READY
-- Single File - Organized Structure
-- Last Updated: 2026-09-03
-- ============================================================

-- ============================================================
-- SECTION 1: EXTENSIONS
-- ============================================================
CREATE EXTENSION IF NOT EXISTS postgis;

-- pgcrypto: gen_random_uuid() (security.tenant) and digest()/hmac() for
-- checksums and signatures.
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE EXTENSION IF NOT EXISTS pg_cron;
