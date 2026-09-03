-- ============================================================
-- BASE LAYER / 2: Schema creation
-- file    : base/02_schemas.sql
-- objects : 21 statement(s)
-- note    : All 21 application schemas.
-- generated from original/schema_v1_original.sql by tools/split_schema.py
-- ============================================================

-- ============================================================
-- SECTION 3: SCHEMA CREATION
-- ============================================================
CREATE SCHEMA IF NOT EXISTS param;

CREATE SCHEMA IF NOT EXISTS site;

CREATE SCHEMA IF NOT EXISTS "user";

CREATE SCHEMA IF NOT EXISTS partner;

CREATE SCHEMA IF NOT EXISTS buyer;

CREATE SCHEMA IF NOT EXISTS fleet;

CREATE SCHEMA IF NOT EXISTS form;

CREATE SCHEMA IF NOT EXISTS laboratory;

CREATE SCHEMA IF NOT EXISTS survey;

CREATE SCHEMA IF NOT EXISTS enviro;

CREATE SCHEMA IF NOT EXISTS commercial;

CREATE SCHEMA IF NOT EXISTS operational;

CREATE SCHEMA IF NOT EXISTS voyage;

CREATE SCHEMA IF NOT EXISTS financial;

CREATE SCHEMA IF NOT EXISTS hse;

CREATE SCHEMA IF NOT EXISTS reporting;

CREATE SCHEMA IF NOT EXISTS security;

CREATE SCHEMA IF NOT EXISTS audit;

CREATE SCHEMA IF NOT EXISTS workflow;

CREATE SCHEMA IF NOT EXISTS document;

CREATE SCHEMA IF NOT EXISTS telemetry;
