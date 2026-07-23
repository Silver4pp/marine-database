-- =============================================================================
-- DATABASE.MD (FIXED)
-- =============================================================================
-- International-Grade Mining & Maritime Operations Database
-- Conforms to:
--   ISO 3166-1:2020  (Country)
--   ISO 4217         (Currency)
--   ISO 639-1        (Language)
--   ISO 8601         (Date/Time — PostgreSQL timestamptz)
--   ISO 19111:2019   (Spatial referencing via PostGIS SRID)
--   ISO/IEC 27001:2022 (Security — RBAC, RLS, Audit)
--   IANA Time Zone Database (Timezone)
--   IMO / MMSI / UN/LOCODE (Maritime identifiers)
-- =============================================================================

-- =============================================================================
-- 1. EXTENSIONS
-- =============================================================================
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- =============================================================================
-- 2. SCHEMAS
-- =============================================================================

-- Core master data & global reference
CREATE SCHEMA IF NOT EXISTS core;
CREATE SCHEMA IF NOT EXISTS ref;    

-- Maritime & Fleet
CREATE SCHEMA IF NOT EXISTS fleet;
CREATE SCHEMA IF NOT EXISTS port;

-- Commercial & Logistics
CREATE SCHEMA IF NOT EXISTS commercial;
CREATE SCHEMA IF NOT EXISTS logistics;
CREATE SCHEMA IF NOT EXISTS voyage;

-- Regulatory & Compliance
CREATE SCHEMA IF NOT EXISTS regulatory;

-- Operations
CREATE SCHEMA IF NOT EXISTS operations;

-- Cargo & Quantity
CREATE SCHEMA IF NOT EXISTS cargo;

-- Survey & Sampling
CREATE SCHEMA IF NOT EXISTS survey;

-- Tracking & Environment
CREATE SCHEMA IF NOT EXISTS tracking;
CREATE SCHEMA IF NOT EXISTS environment;

-- Finance
CREATE SCHEMA IF NOT EXISTS finance;

-- Documents
CREATE SCHEMA IF NOT EXISTS documents;

-- Security & Audit
CREATE SCHEMA IF NOT EXISTS security;
CREATE SCHEMA IF NOT EXISTS audit;

-- Integration
CREATE SCHEMA IF NOT EXISTS integration;

-- Reporting (Read-only views / materialized views)
CREATE SCHEMA IF NOT EXISTS reporting;

-- Internal automation (partition management, etc.)
CREATE SCHEMA IF NOT EXISTS internal;

-- =============================================================================
-- 3. GLOBAL REFERENCE DATA (ISO Standards)
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 3.1 Country — ISO 3166-1:2020
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ref.country (
    country_id          smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    iso_alpha2          char(2) NOT NULL UNIQUE,
    iso_alpha3          char(3) NOT NULL UNIQUE,
    iso_numeric         char(3) NOT NULL UNIQUE,
    name                varchar(100) NOT NULL,
    official_name       varchar(200),
    status              varchar(20) NOT NULL DEFAULT 'ACTIVE',
    valid_from          date NOT NULL DEFAULT CURRENT_DATE,
    valid_to            date,
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz,
    CONSTRAINT chk_country_status CHECK (status IN ('ACTIVE','INACTIVE','RESERVED')),
    CONSTRAINT chk_country_valid CHECK (valid_to IS NULL OR valid_to >= valid_from)
);

COMMENT ON TABLE ref.country IS 'ISO 3166-1:2020 — Country codes';

-- ---------------------------------------------------------------------------
-- 3.2 Currency — ISO 4217
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ref.currency (
    currency_code       char(3) PRIMARY KEY,
    currency_name       varchar(100) NOT NULL,
    currency_symbol     varchar(10),
    minor_unit          smallint NOT NULL DEFAULT 2,
    is_active           boolean NOT NULL DEFAULT true,
    created_at          timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE ref.currency IS 'ISO 4217 — Currency codes';

-- ---------------------------------------------------------------------------
-- 3.3 Language — ISO 639-1
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ref.language (
    language_code       char(2) PRIMARY KEY,
    language_name       varchar(100) NOT NULL,
    native_name         varchar(100),
    is_active           boolean NOT NULL DEFAULT true,
    created_at          timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE ref.language IS 'ISO 639-1 — Language codes';

-- ---------------------------------------------------------------------------
-- 3.4 Timezone — IANA Time Zone Database
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ref.timezone (
    timezone_id         varchar(50) PRIMARY KEY,
    iana_name           varchar(100) NOT NULL UNIQUE,
    utc_offset          varchar(6),
    is_active           boolean NOT NULL DEFAULT true,
    created_at          timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE ref.timezone IS 'IANA Time Zone Database';

-- ---------------------------------------------------------------------------
-- 3.5 Unit of Measure
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ref.unit_of_measure (
    uom_code            varchar(10) PRIMARY KEY,
    name                varchar(100) NOT NULL,
    category            varchar(50) NOT NULL,  -- volume, weight, length, etc.
    symbol              varchar(10),
    si_unit             boolean NOT NULL DEFAULT false,
    is_active           boolean NOT NULL DEFAULT true,
    created_at          timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE ref.unit_of_measure IS 'Unit of measure master — Metric, Imperial, Maritime';

CREATE TABLE IF NOT EXISTS ref.unit_conversion (
    id                  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    uom_from            varchar(10) NOT NULL REFERENCES ref.unit_of_measure(uom_code),
    uom_to              varchar(10) NOT NULL REFERENCES ref.unit_of_measure(uom_code),
    conversion_factor   numeric(20,10) NOT NULL,
    conversion_formula  varchar(200),
    valid_from          date NOT NULL DEFAULT CURRENT_DATE,
    valid_to            date,
    created_at          timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT chk_conversion_valid CHECK (valid_to IS NULL OR valid_to >= valid_from),
    CONSTRAINT uq_conversion UNIQUE (uom_from, uom_to, valid_from)
);

COMMENT ON TABLE ref.unit_conversion IS 'Unit conversion factors with temporal validity';

-- ---------------------------------------------------------------------------
-- 3.6 Status Vocabulary (controlled vocabulary)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ref.status (
    status_group        varchar(50) NOT NULL,
    status_code         varchar(50) NOT NULL,
    description         text,
    is_active           boolean NOT NULL DEFAULT true,
    sort_order          integer DEFAULT 0,
    created_at          timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (status_group, status_code)
);

COMMENT ON TABLE ref.status IS 'Controlled status vocabulary for all entities';

-- ---------------------------------------------------------------------------
-- 3.7 Seed Data — ISO reference data
-- ---------------------------------------------------------------------------
INSERT INTO ref.country (iso_alpha2, iso_alpha3, iso_numeric, name, official_name) VALUES
    ('ID', 'IDN', '360', 'Indonesia', 'Republic of Indonesia'),
    ('SG', 'SGP', '702', 'Singapore', 'Republic of Singapore'),
    ('MY', 'MYS', '458', 'Malaysia', 'Malaysia'),
    ('CN', 'CHN', '156', 'China', 'People''s Republic of China'),
    ('JP', 'JPN', '392', 'Japan', 'Japan'),
    ('KR', 'KOR', '410', 'South Korea', 'Republic of Korea'),
    ('IN', 'IND', '356', 'India', 'Republic of India'),
    ('AU', 'AUS', '036', 'Australia', 'Commonwealth of Australia'),
    ('US', 'USA', '840', 'United States', 'United States of America'),
    ('GB', 'GBR', '826', 'United Kingdom', 'United Kingdom of Great Britain and Northern Ireland'),
    ('NL', 'NLD', '528', 'Netherlands', 'Kingdom of the Netherlands'),
    ('PH', 'PHL', '608', 'Philippines', 'Republic of the Philippines'),
    ('TH', 'THA', '764', 'Thailand', 'Kingdom of Thailand'),
    ('VN', 'VNM', '704', 'Vietnam', 'Socialist Republic of Vietnam'),
    ('HK', 'HKG', '344', 'Hong Kong', 'Hong Kong Special Administrative Region of China')
ON CONFLICT (iso_alpha2) DO NOTHING;

INSERT INTO ref.currency (currency_code, currency_name, currency_symbol, minor_unit) VALUES
    ('IDR', 'Indonesian Rupiah', 'Rp', 2),
    ('USD', 'US Dollar', '$', 2),
    ('SGD', 'Singapore Dollar', 'S$', 2),
    ('CNY', 'Chinese Yuan', '¥', 2),
    ('JPY', 'Japanese Yen', '¥', 0),
    ('KRW', 'South Korean Won', '₩', 0),
    ('INR', 'Indian Rupee', '₹', 2),
    ('EUR', 'Euro', '€', 2),
    ('GBP', 'British Pound', '£', 2),
    ('AUD', 'Australian Dollar', 'A$', 2),
    ('HKD', 'Hong Kong Dollar', 'HK$', 2),
    ('MYR', 'Malaysian Ringgit', 'RM', 2),
    ('PHP', 'Philippine Peso', '₱', 2),
    ('THB', 'Thai Baht', '฿', 2),
    ('VND', 'Vietnamese Đồng', '₫', 0)
ON CONFLICT (currency_code) DO NOTHING;

INSERT INTO ref.language (language_code, language_name) VALUES
    ('id', 'Indonesian'),
    ('en', 'English'),
    ('zh', 'Chinese'),
    ('ja', 'Japanese'),
    ('ko', 'Korean'),
    ('hi', 'Hindi'),
    ('ms', 'Malay'),
    ('th', 'Thai'),
    ('vi', 'Vietnamese'),
    ('nl', 'Dutch'),
    ('ar', 'Arabic')
ON CONFLICT (language_code) DO NOTHING;

INSERT INTO ref.timezone (timezone_id, iana_name, utc_offset) VALUES
    ('TZ-JKT', 'Asia/Jakarta', '+07:00'),
    ('TZ-MKS', 'Asia/Makassar', '+08:00'),
    ('TZ-JAY', 'Asia/Jayapura', '+09:00'),
    ('TZ-SIN', 'Asia/Singapore', '+08:00'),
    ('TZ-KUL', 'Asia/Kuala_Lumpur', '+08:00'),
    ('TZ-BEJ', 'Asia/Shanghai', '+08:00'),
    ('TZ-TOK', 'Asia/Tokyo', '+09:00'),
    ('TZ-SEL', 'Asia/Seoul', '+09:00'),
    ('TZ-DEL', 'Asia/Kolkata', '+05:30'),
    ('TZ-LON', 'Europe/London', '+00:00'),
    ('TZ-UTC', 'UTC', '+00:00')
ON CONFLICT (iana_name) DO NOTHING;

INSERT INTO ref.unit_of_measure (uom_code, name, category, symbol, si_unit) VALUES
    ('MT',   'Metric Ton',       'weight', 't',    true),
    ('KG',   'Kilogram',         'weight', 'kg',   true),
    ('M3',   'Cubic Meter',      'volume', 'm³',   true),
    ('L',    'Liter',            'volume', 'L',    false),
    ('BBL',  'Barrel',           'volume', 'bbl',  false),
    ('TON',  'Long Ton',         'weight', 'ton',  false),
    ('LB',   'Pound',            'weight', 'lb',   false),
    ('FT',   'Foot',             'length', 'ft',   false),
    ('M',    'Meter',            'length', 'm',    true),
    ('NM',   'Nautical Mile',    'length', 'nmi',  false),
    ('KT',   'Knot',             'speed',  'kn',   false),
    ('PCT',  'Percentage',       'ratio',  '%',    false)
ON CONFLICT (uom_code) DO NOTHING;

INSERT INTO ref.unit_conversion (uom_from, uom_to, conversion_factor) VALUES
    ('MT', 'KG',  1000.0),
    ('MT', 'LB',  2204.62),
    ('TON', 'MT', 1.01604691),
    ('M3', 'L',   1000.0),
    ('FT', 'M',   0.3048),
    ('NM', 'M',   1852.0)
ON CONFLICT (uom_from, uom_to, valid_from) DO NOTHING;

-- =============================================================================
-- 4. CORE MASTER DATA
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 4.1 Organization
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS core.organization (
    org_code            varchar(20) PRIMARY KEY,
    name                varchar(200) NOT NULL,
    business_type       varchar(50),
    country_id          smallint REFERENCES ref.country(country_id),
    is_active           boolean NOT NULL DEFAULT true,
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz
);

-- ---------------------------------------------------------------------------
-- 4.2 Business Unit
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS core.business_unit (
    bu_code             varchar(20) PRIMARY KEY,
    org_code            varchar(20) NOT NULL REFERENCES core.organization(org_code),
    name                varchar(200) NOT NULL,
    is_active           boolean NOT NULL DEFAULT true,
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz
);

-- ---------------------------------------------------------------------------
-- 4.3 Partner (unified — replaces partner.info and buyer.info)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS core.partner (
    partner_id          varchar(20) PRIMARY KEY,
    name                varchar(200) NOT NULL,
    legal_name          varchar(200),
    tax_id              varchar(50),
    registration_number varchar(50),
    country_id          smallint REFERENCES ref.country(country_id),
    is_active           boolean NOT NULL DEFAULT true,
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz
);

COMMENT ON TABLE core.partner IS 'Unified partner entity — Owner, Operator, Charterer, Buyer, Seller, Agent, Surveyor, Laboratory, etc.';

CREATE TABLE IF NOT EXISTS core.partner_role (
    id                  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    partner_id          varchar(20) NOT NULL REFERENCES core.partner(partner_id),
    role_code           varchar(30) NOT NULL,
    valid_from          date NOT NULL DEFAULT CURRENT_DATE,
    valid_to            date,
    is_current          boolean NOT NULL DEFAULT true,
    created_at          timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT chk_partner_role CHECK (role_code IN (
        'OWNER','OPERATOR','CHARTERER','AGENT','BUYER','SELLER',
        'SURVEYOR','LABORATORY','PORT_AGENT','CUSTOMS_AGENT','STEVEDORE',
        'SHIPPER','CONSIGNEE','NOTIFY_PARTY','BROKER','FORWARDER'
    )),
    CONSTRAINT uq_partner_role UNIQUE (partner_id, role_code, valid_from)
);

COMMENT ON TABLE core.partner_role IS 'Temporal partner roles — supports role history';

CREATE TABLE IF NOT EXISTS core.partner_address (
    id                  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    partner_id          varchar(20) NOT NULL REFERENCES core.partner(partner_id),
    address_type        varchar(20) NOT NULL DEFAULT 'BUSINESS',
    address_line1       varchar(200) NOT NULL,
    address_line2       varchar(200),
    city                varchar(100),
    state_province      varchar(100),
    postal_code         varchar(20),
    country_id          smallint REFERENCES ref.country(country_id),
    is_primary          boolean NOT NULL DEFAULT false,
    latitude            numeric(10,7),
    longitude           numeric(10,7),
    geom                geometry(Point, 4326) GENERATED ALWAYS AS (
        CASE WHEN latitude IS NOT NULL AND longitude IS NOT NULL
             THEN ST_SetSRID(ST_MakePoint(longitude::float8, latitude::float8), 4326)
             ELSE NULL END
    ) STORED,
    valid_from          date NOT NULL DEFAULT CURRENT_DATE,
    valid_to            date,
    created_at          timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT chk_address_type CHECK (address_type IN ('BUSINESS','BILLING','SHIPPING','REGISTERED','CORRESPONDENCE'))
);

CREATE TABLE IF NOT EXISTS core.partner_contact (
    id                  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    partner_id          varchar(20) NOT NULL REFERENCES core.partner(partner_id),
    contact_name        varchar(100),
    contact_type        varchar(20) NOT NULL,
    contact_value       varchar(200) NOT NULL,
    is_primary          boolean NOT NULL DEFAULT false,
    is_active           boolean NOT NULL DEFAULT true,
    created_at          timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT chk_contact_type CHECK (contact_type IN ('EMAIL','PHONE','MOBILE','FAX','WEBSITE','TELEX'))
);

-- ---------------------------------------------------------------------------
-- 4.4 Port — with UN/LOCODE reference
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS port.port (
    port_id             varchar(10) PRIMARY KEY,
    un_locode           varchar(5) UNIQUE,
    name                varchar(200) NOT NULL,
    country_id          smallint NOT NULL REFERENCES ref.country(country_id),
    longitude           numeric(10,7),
    latitude            numeric(10,7),
    geom                geometry(Point, 4326) GENERATED ALWAYS AS (
        CASE WHEN latitude IS NOT NULL AND longitude IS NOT NULL
             THEN ST_SetSRID(ST_MakePoint(longitude::float8, latitude::float8), 4326)
             ELSE NULL END
    ) STORED,
    timezone_id         varchar(50) REFERENCES ref.timezone(timezone_id),
    port_type           varchar(30) NOT NULL DEFAULT 'SEAPORT',
    is_active           boolean NOT NULL DEFAULT true,
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz,
    CONSTRAINT chk_port_type CHECK (port_type IN ('SEAPORT','RIVER_PORT','INLAND_PORT','FISHING_PORT','MILITARY_PORT'))
);

COMMENT ON TABLE port.port IS 'Port master with UN/LOCODE — covers all countries';

CREATE TABLE IF NOT EXISTS port.terminal (
    terminal_id         varchar(20) PRIMARY KEY,
    port_id             varchar(10) NOT NULL REFERENCES port.port(port_id),
    name                varchar(200) NOT NULL,
    operator_partner_id varchar(20) REFERENCES core.partner(partner_id),
    cargo_type          varchar(50),
    is_active           boolean NOT NULL DEFAULT true,
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz
);

-- ---------------------------------------------------------------------------
-- 4.5 Site (Mining/Operations Site — linked to Work Area)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS operations.site (
    site_code           varchar(20) PRIMARY KEY,
    name                varchar(200) NOT NULL,
    org_code            varchar(20) REFERENCES core.organization(org_code),
    country_id          smallint REFERENCES ref.country(country_id),
    latitude            numeric(10,7),
    longitude           numeric(10,7),
    geom                geometry(Point, 4326) GENERATED ALWAYS AS (
        CASE WHEN latitude IS NOT NULL AND longitude IS NOT NULL
             THEN ST_SetSRID(ST_MakePoint(longitude::float8, latitude::float8), 4326)
             ELSE NULL END
    ) STORED,
    timezone_id         varchar(50) REFERENCES ref.timezone(timezone_id),
    is_active           boolean NOT NULL DEFAULT true,
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz
);

-- =============================================================================
-- 5. FLEET & VESSEL
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 5.1 Vessel Type (IMO ship type classification)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS fleet.vessel_type (
    vessel_type_code    varchar(20) PRIMARY KEY,
    name                varchar(100) NOT NULL,
    description         text,
    is_active           boolean NOT NULL DEFAULT true
);

INSERT INTO fleet.vessel_type (vessel_type_code, name) VALUES
    ('BULK_CARRIER', 'Bulk Carrier'),
    ('TANKER', 'Tanker'),
    ('CONTAINER', 'Container Ship'),
    ('GENERAL_CARGO', 'General Cargo'),
    ('BARGE', 'Barge'),
    ('TUG', 'Tugboat'),
    ('FPSO', 'Floating Production Storage Offloading'),
    ('OSV', 'Offshore Support Vessel'),
    ('DREDGER', 'Dredger'),
    ('LNG', 'LNG Carrier')
ON CONFLICT (vessel_type_code) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 5.2 Vessel
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS fleet.vessel (
    vessel_id           varchar(20) PRIMARY KEY,
    imo_number          varchar(10) UNIQUE,
    mmsi                varchar(9) UNIQUE,
    call_sign           varchar(20) UNIQUE,
    name                varchar(200) NOT NULL,
    former_name         varchar(200),
    vessel_type_code    varchar(20) REFERENCES fleet.vessel_type(vessel_type_code),
    flag_country_id     smallint REFERENCES ref.country(country_id),
    year_built          smallint,
    grt                 numeric(12,2),   -- Gross Registered Tonnage
    nrt                 numeric(12,2),   -- Net Registered Tonnage
    dwt                 numeric(12,2),   -- Deadweight Tonnage
    loa                 numeric(10,2),   -- Length Overall (meters)
    beam                numeric(10,2),   -- Breadth (meters)
    draft_max           numeric(10,2),   -- Maximum Draft (meters)
    is_active           boolean NOT NULL DEFAULT true,
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz
);

COMMENT ON TABLE fleet.vessel IS 'Vessel master — IMO Number is the primary global identifier. MMSI for AIS tracking.';

-- ---------------------------------------------------------------------------
-- 5.3 Vessel Partner Relationship (temporal)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS fleet.vessel_partner (
    id                  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    vessel_id           varchar(20) NOT NULL REFERENCES fleet.vessel(vessel_id),
    partner_id          varchar(20) NOT NULL REFERENCES core.partner(partner_id),
    role_code           varchar(30) NOT NULL,
    valid_from          date NOT NULL DEFAULT CURRENT_DATE,
    valid_to            date,
    is_current          boolean NOT NULL DEFAULT true,
    created_at          timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT chk_vp_role CHECK (role_code IN ('OWNER','OPERATOR','CHARTERER','MANAGER','TECHNICAL_MANAGER')),
    CONSTRAINT uq_vessel_partner UNIQUE (vessel_id, partner_id, role_code, valid_from)
);

COMMENT ON TABLE fleet.vessel_partner IS 'Temporal vessel-partner relationship — never store owner/operator as columns on vessel.';

-- ---------------------------------------------------------------------------
-- 5.4 Vessel Certificate
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS fleet.vessel_certificate (
    id                  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    vessel_id           varchar(20) NOT NULL REFERENCES fleet.vessel(vessel_id),
    certificate_type    varchar(50) NOT NULL,
    certificate_number  varchar(100),
    issuing_authority   varchar(200),
    issued_date         date NOT NULL,
    expiry_date         date NOT NULL,
    status              varchar(20) NOT NULL DEFAULT 'ACTIVE',
    document_id         bigint,
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz,
    CONSTRAINT chk_cert_status CHECK (status IN ('ACTIVE','EXPIRED','REVOKED','SUSPENDED')),
    CONSTRAINT chk_cert_dates CHECK (expiry_date >= issued_date)
);

-- =============================================================================
-- 6. COMMERCIAL
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 6.1 Purchase Order
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS commercial.purchase_order (
    po_number           varchar(50) PRIMARY KEY,
    buyer_partner_id    varchar(20) NOT NULL REFERENCES core.partner(partner_id),
    seller_partner_id   varchar(20) NOT NULL REFERENCES core.partner(partner_id),
    contract_number     varchar(50),
    po_date             date NOT NULL,
    commodity           varchar(100) NOT NULL,
    uom_code            varchar(10) NOT NULL REFERENCES ref.unit_of_measure(uom_code),
    total_volume        numeric(20,6) NOT NULL,
    unit_price          numeric(18,4) NOT NULL,
    currency_code       char(3) NOT NULL REFERENCES ref.currency(currency_code),
    total_amount        numeric(18,4) NOT NULL,
    incoterm            varchar(10),
    port_of_loading     varchar(10) REFERENCES port.port(port_id),
    port_of_discharge   varchar(10) REFERENCES port.port(port_id),
    target_start_date   date,
    target_end_date     date,
    status              varchar(30) NOT NULL DEFAULT 'DRAFT',
    description         text,
    created_by          varchar(20),
    approved_by         varchar(20),
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz,
    CONSTRAINT chk_po_status CHECK (status IN ('DRAFT','SUBMITTED','APPROVED','IN_PROGRESS','COMPLETED','CANCELLED','CLOSED'))
);

CREATE TABLE IF NOT EXISTS commercial.purchase_order_line (
    id                  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    po_number           varchar(50) NOT NULL REFERENCES commercial.purchase_order(po_number),
    line_number         smallint NOT NULL,
    commodity           varchar(100),
    uom_code            varchar(10) REFERENCES ref.unit_of_measure(uom_code),
    volume              numeric(20,6) NOT NULL,
    unit_price          numeric(18,4),
    total_price         numeric(20,4),
    description         text,
    created_at          timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_po_line UNIQUE (po_number, line_number)
);

-- ---------------------------------------------------------------------------
-- 6.2 Shipment Projection
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS commercial.shipment_projection (
    projection_id       varchar(30) PRIMARY KEY,
    po_number           varchar(50) NOT NULL REFERENCES commercial.purchase_order(po_number),
    vessel_id           varchar(20) REFERENCES fleet.vessel(vessel_id),
    projected_volume    numeric(20,6) NOT NULL,
    uom_code            varchar(10) REFERENCES ref.unit_of_measure(uom_code),
    projected_loading_date date,
    projected_arrival_date  date,
    status              varchar(30) NOT NULL DEFAULT 'PLANNED',
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz,
    CONSTRAINT chk_proj_status CHECK (status IN ('PLANNED','CONFIRMED','CANCELLED','COMPLETED'))
);

-- =============================================================================
-- 7. LOGISTICS & SHIPMENT
-- =============================================================================

CREATE TABLE IF NOT EXISTS logistics.shipment (
    shipment_id         varchar(30) PRIMARY KEY,
    po_number           varchar(50) REFERENCES commercial.purchase_order(po_number),
    projection_id       varchar(30) REFERENCES commercial.shipment_projection(projection_id),
    vessel_id           varchar(20) NOT NULL REFERENCES fleet.vessel(vessel_id),
    shipment_type       varchar(20) NOT NULL DEFAULT 'MARITIME',
    cargo_description   text,
    status              varchar(30) NOT NULL DEFAULT 'PLANNED',
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz,
    CONSTRAINT chk_shipment_status CHECK (status IN ('PLANNED','CONFIRMED','LOADING','SAILING','ARRIVED','DISCHARGING','COMPLETED','CANCELLED'))
);

CREATE TABLE IF NOT EXISTS logistics.shipment_party (
    id                  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    shipment_id         varchar(30) NOT NULL REFERENCES logistics.shipment(shipment_id),
    partner_id          varchar(20) NOT NULL REFERENCES core.partner(partner_id),
    party_role          varchar(30) NOT NULL,
    created_at          timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT chk_shipment_party_role CHECK (party_role IN ('SHIPPER','CONSIGNEE','NOTIFY_PARTY','BROKER','FORWARDER','AGENT'))
);

-- =============================================================================
-- 8. VOYAGE ARCHITECTURE
-- =============================================================================

CREATE TABLE IF NOT EXISTS voyage.voyage (
    voyage_id           varchar(30) PRIMARY KEY,
    shipment_id         varchar(30) REFERENCES logistics.shipment(shipment_id),
    vessel_id           varchar(20) NOT NULL REFERENCES fleet.vessel(vessel_id),
    voyage_number       varchar(30) NOT NULL,
    voyage_type         varchar(20) NOT NULL DEFAULT 'INTERNATIONAL',
    status              varchar(30) NOT NULL DEFAULT 'PLANNED',
    planned_departure   timestamptz,
    planned_arrival     timestamptz,
    actual_departure    timestamptz,
    actual_arrival      timestamptz,
    departure_timezone  varchar(50) REFERENCES ref.timezone(timezone_id),
    arrival_timezone    varchar(50) REFERENCES ref.timezone(timezone_id),
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz,
    CONSTRAINT chk_voyage_status CHECK (status IN ('PLANNED','CONFIRMED','IN_PROGRESS','COMPLETED','CANCELLED')),
    CONSTRAINT uq_vessel_voyage UNIQUE (vessel_id, voyage_number)
);

COMMENT ON TABLE voyage.voyage IS 'Voyage — core entity linking shipment to vessel movements';

CREATE TABLE IF NOT EXISTS voyage.voyage_leg (
    leg_id              varchar(30) PRIMARY KEY,
    voyage_id           varchar(30) NOT NULL REFERENCES voyage.voyage(voyage_id),
    leg_sequence        smallint NOT NULL,
    origin_port_id      varchar(10) NOT NULL REFERENCES port.port(port_id),
    destination_port_id varchar(10) NOT NULL REFERENCES port.port(port_id),
    distance_nm         numeric(10,2),
    status              varchar(30) NOT NULL DEFAULT 'PLANNED',
    planned_start       timestamptz,
    planned_end         timestamptz,
    actual_start        timestamptz,
    actual_end          timestamptz,
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz,
    CONSTRAINT chk_leg_status CHECK (status IN ('PLANNED','CONFIRMED','IN_PROGRESS','COMPLETED','CANCELLED')),
    CONSTRAINT uq_leg_sequence UNIQUE (voyage_id, leg_sequence)
);

CREATE TABLE IF NOT EXISTS voyage.port_call (
    port_call_id        varchar(30) PRIMARY KEY,
    voyage_id           varchar(30) NOT NULL REFERENCES voyage.voyage(voyage_id),
    leg_id              varchar(30) REFERENCES voyage.voyage_leg(leg_id),
    port_id             varchar(10) NOT NULL REFERENCES port.port(port_id),
    terminal_id         varchar(20) REFERENCES port.terminal(terminal_id),
    call_sequence       smallint NOT NULL,
    call_purpose        varchar(30) NOT NULL DEFAULT 'LOADING',
    status              varchar(30) NOT NULL DEFAULT 'PLANNED',
    planned_arrival     timestamptz,
    planned_departure   timestamptz,
    actual_arrival      timestamptz,
    actual_departure    timestamptz,
    timezone_id         varchar(50) REFERENCES ref.timezone(timezone_id),
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz,
    CONSTRAINT chk_port_call_purpose CHECK (call_purpose IN ('LOADING','DISCHARGE','ANCHORAGE','BUNKERING','REPAIR','CUSTOMS','BOTH')),
    CONSTRAINT chk_port_call_status CHECK (status IN ('PLANNED','CONFIRMED','ARRIVED','BERTHED','LOADING','DISCHARGING','DEPARTED','COMPLETED','CANCELLED')),
    CONSTRAINT uq_port_call_seq UNIQUE (voyage_id, call_sequence)
);

CREATE TABLE IF NOT EXISTS voyage.port_call_event (
    id                  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    port_call_id        varchar(30) NOT NULL REFERENCES voyage.port_call(port_call_id),
    event_type          varchar(30) NOT NULL,
    planned_at          timestamptz,
    estimated_at        timestamptz,
    actual_at           timestamptz NOT NULL,
    timezone_id         varchar(50) REFERENCES ref.timezone(timezone_id),
    location            geometry(Point, 4326),
    source              varchar(50) DEFAULT 'MANUAL',
    remarks             text,
    created_at          timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT chk_event_type CHECK (event_type IN (
        'ARRIVAL','ANCHORAGE','BERTHING','MOORING','LOADING_START','LOADING_END',
        'DISCHARGE_START','DISCHARGE_END','UNMOORING','DEPARTURE','PILOT_ONBOARD',
        'PILOT_OFF','TUG_ASSIST','CUSTOMS_CLEARANCE','SURVEY'
    ))
);

-- =============================================================================
-- 9. REGULATORY & CLEARANCE (Generic multi-country)
-- =============================================================================

CREATE TABLE IF NOT EXISTS regulatory.clearance (
    clearance_id        varchar(30) PRIMARY KEY,
    country_id          smallint NOT NULL REFERENCES ref.country(country_id),
    clearance_type      varchar(30) NOT NULL,
    direction           varchar(10) NOT NULL,
    shipment_id         varchar(30) REFERENCES logistics.shipment(shipment_id),
    voyage_id           varchar(30) REFERENCES voyage.voyage(voyage_id),
    vessel_id           varchar(20) REFERENCES fleet.vessel(vessel_id),
    port_call_id        varchar(30) REFERENCES voyage.port_call(port_call_id),
    status              varchar(30) NOT NULL DEFAULT 'DRAFT',
    submitted_at        timestamptz,
    approved_at         timestamptz,
    approved_by_partner varchar(20) REFERENCES core.partner(partner_id),
    valid_until         timestamptz,
    reference_number    varchar(100),
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz,
    CONSTRAINT chk_clearance_direction CHECK (direction IN ('IN','OUT','TRANSIT')),
    CONSTRAINT chk_clearance_type CHECK (clearance_type IN (
        'CUSTOMS','IMMIGRATION','PORT_HEALTH','HARBOR_MASTER','MPA','ICA',
        'SECURITY','ENVIRONMENTAL','PORT_ENTRY','PORT_EXIT'
    )),
    CONSTRAINT chk_clearance_status CHECK (status IN (
        'DRAFT','SUBMITTED','UNDER_REVIEW','APPROVED','REJECTED','RESUBMITTED','CANCELLED','EXPIRED'
    ))
);

COMMENT ON TABLE regulatory.clearance IS 'Generic multi-country clearance — never make separate tables per country. Supports IDN/IN, IDN/OUT, SGP/IN, SGP/OUT, etc.';

CREATE TABLE IF NOT EXISTS regulatory.clearance_event (
    id                  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    clearance_id        varchar(30) NOT NULL REFERENCES regulatory.clearance(clearance_id),
    event_type          varchar(30) NOT NULL,
    event_status        varchar(30) NOT NULL,
    event_at            timestamptz NOT NULL DEFAULT now(),
    actor_partner_id    varchar(20) REFERENCES core.partner(partner_id),
    remarks             text,
    created_at          timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT chk_clearance_event_type CHECK (event_type IN (
        'SUBMISSION','REVIEW','APPROVAL','REJECTION','RESUBMISSION','CANCELLATION','EXPIRY'
    ))
);

CREATE TABLE IF NOT EXISTS regulatory.clearance_document (
    id                  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    clearance_id        varchar(30) NOT NULL REFERENCES regulatory.clearance(clearance_id),
    document_type       varchar(50) NOT NULL,
    document_number     varchar(100),
    document_url        text,
    issued_date         date,
    expiry_date         date,
    status              varchar(20) NOT NULL DEFAULT 'ACTIVE',
    created_at          timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT chk_clr_doc_status CHECK (status IN ('ACTIVE','EXPIRED','REVOKED'))
);

-- =============================================================================
-- 10. OPERATIONS — MINING
-- =============================================================================

CREATE TABLE IF NOT EXISTS operations.project (
    project_code        varchar(20) PRIMARY KEY,
    name                varchar(200) NOT NULL,
    org_code            varchar(20) REFERENCES core.organization(org_code),
    country_id          smallint REFERENCES ref.country(country_id),
    start_date          date,
    end_date            date,
    status              varchar(30) NOT NULL DEFAULT 'ACTIVE',
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz,
    CONSTRAINT chk_project_status CHECK (status IN ('PLANNED','ACTIVE','SUSPENDED','COMPLETED','CANCELLED'))
);

CREATE TABLE IF NOT EXISTS operations.work_area (
    work_area_code      varchar(20) PRIMARY KEY,
    project_code        varchar(20) REFERENCES operations.project(project_code),
    site_code           varchar(20) REFERENCES operations.site(site_code),
    name                varchar(200) NOT NULL,
    area_type           varchar(30) NOT NULL DEFAULT 'MINING',
    geom                geometry(Polygon, 4326),
    centroid            geometry(Point, 4326),
    is_active           boolean NOT NULL DEFAULT true,
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz,
    CONSTRAINT chk_work_area_type CHECK (area_type IN ('MINING','STOCKPILE','LOADING_POINT','DISPOSAL','BUFFER'))
);

CREATE TABLE IF NOT EXISTS operations.work_activity (
    activity_id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    work_area_code      varchar(20) REFERENCES operations.work_area(work_area_code),
    vessel_id           varchar(20) REFERENCES fleet.vessel(vessel_id),
    activity_type       varchar(30) NOT NULL,
    planned_start       timestamptz,
    planned_end         timestamptz,
    actual_start        timestamptz,
    actual_end          timestamptz,
    status              varchar(30) NOT NULL DEFAULT 'SCHEDULED',
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz,
    CONSTRAINT chk_activity_type CHECK (activity_type IN ('MINING','LOADING','STOCKPILING','MAINTENANCE','SURVEY','BLASTING','TRANSFER')),
    CONSTRAINT chk_activity_status CHECK (status IN ('SCHEDULED','IN_PROGRESS','PAUSED','COMPLETED','CANCELLED'))
);

CREATE TABLE IF NOT EXISTS operations.work_activity_event (
    id                  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    activity_id         bigint NOT NULL REFERENCES operations.work_activity(activity_id),
    event_type          varchar(30) NOT NULL,
    event_at            timestamptz NOT NULL DEFAULT now(),
    remarks             text,
    created_by          varchar(20),
    created_at          timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT chk_activity_event CHECK (event_type IN ('START','PAUSE','RESUME','COMPLETE','CANCEL'))
);

-- =============================================================================
-- 11. CARGO & QUANTITY CONTROL
-- =============================================================================

CREATE TABLE IF NOT EXISTS cargo.cargo (
    cargo_id            varchar(30) PRIMARY KEY,
    shipment_id         varchar(30) REFERENCES logistics.shipment(shipment_id),
    cargo_type          varchar(100) NOT NULL,
    commodity           varchar(100),
    uom_code            varchar(10) NOT NULL REFERENCES ref.unit_of_measure(uom_code),
    total_quantity      numeric(20,6),
    description         text,
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz
);

CREATE TABLE IF NOT EXISTS cargo.cargo_lot (
    lot_id              varchar(30) PRIMARY KEY,
    cargo_id            varchar(30) NOT NULL REFERENCES cargo.cargo(cargo_id),
    lot_number          varchar(50) NOT NULL,
    source_work_area    varchar(20) REFERENCES operations.work_area(work_area_code),
    quantity            numeric(20,6) NOT NULL,
    uom_code            varchar(10) REFERENCES ref.unit_of_measure(uom_code),
    grade               varchar(50),
    created_at          timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_cargo_lot UNIQUE (cargo_id, lot_number)
);

CREATE TABLE IF NOT EXISTS cargo.voyage_cargo (
    id                  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    voyage_id           varchar(30) NOT NULL REFERENCES voyage.voyage(voyage_id),
    cargo_id            varchar(30) NOT NULL REFERENCES cargo.cargo(cargo_id),
    loaded_quantity     numeric(20,6),
    discharged_quantity numeric(20,6),
    uom_code            varchar(10) REFERENCES ref.unit_of_measure(uom_code),
    created_at          timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_voyage_cargo UNIQUE (voyage_id, cargo_id)
);

CREATE TABLE IF NOT EXISTS cargo.cargo_movement (
    movement_id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    cargo_id            varchar(30) NOT NULL REFERENCES cargo.cargo(cargo_id),
    lot_id              varchar(30) REFERENCES cargo.cargo_lot(lot_id),
    movement_type       varchar(30) NOT NULL,
    quantity            numeric(20,6) NOT NULL,
    uom_code            varchar(10) REFERENCES ref.unit_of_measure(uom_code),
    from_location       varchar(100),
    to_location         varchar(100),
    from_port_call_id   varchar(30) REFERENCES voyage.port_call(port_call_id),
    to_port_call_id     varchar(30) REFERENCES voyage.port_call(port_call_id),
    movement_time       timestamptz NOT NULL DEFAULT now(),
    source              varchar(50) DEFAULT 'MANUAL',
    created_at          timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT chk_movement_type CHECK (movement_type IN (
        'LOADING','TRANSFER','TRANSIT','DISCHARGE','RETURN','ADJUSTMENT','SHIFTING'
    ))
);

COMMENT ON TABLE cargo.cargo_movement IS 'End-to-end cargo movement tracking — initial volume → loading → transit → discharge → final volume';

CREATE TABLE IF NOT EXISTS cargo.quantity_measurement (
    measurement_id      bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    cargo_id            varchar(30) REFERENCES cargo.cargo(cargo_id),
    movement_id         bigint REFERENCES cargo.cargo_movement(movement_id),
    port_call_id        varchar(30) REFERENCES voyage.port_call(port_call_id),
    measurement_type    varchar(30) NOT NULL,
    measurement_method  varchar(50),
    quantity            numeric(20,6) NOT NULL,
    uom_code            varchar(10) NOT NULL REFERENCES ref.unit_of_measure(uom_code),
    moisture_pct        numeric(7,4),
    net_quantity        numeric(20,6),
    measurement_location geometry(Point, 4326),
    measured_at         timestamptz NOT NULL DEFAULT now(),
    measured_by_partner varchar(20) REFERENCES core.partner(partner_id),
    source              varchar(50) DEFAULT 'MANUAL',
    created_at          timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT chk_meas_type CHECK (measurement_type IN (
        'INITIAL_VOLUME','LOADING_SURVEY','ONBOARD_SURVEY','DISCHARGE_SURVEY',
        'FINAL_VOLUME','DRAFT_SURVEY','WEIGHING','FLOW_METER'
    ))
);

COMMENT ON TABLE cargo.quantity_measurement IS 'Every quantity measurement — enables reconciliation from initial to final volume';

-- =============================================================================
-- 12. SURVEY & SAMPLING
-- =============================================================================

CREATE TABLE IF NOT EXISTS survey.survey (
    survey_id           varchar(30) PRIMARY KEY,
    voyage_id           varchar(30) REFERENCES voyage.voyage(voyage_id),
    port_call_id        varchar(30) REFERENCES voyage.port_call(port_call_id),
    cargo_id            varchar(30) REFERENCES cargo.cargo(cargo_id),
    survey_type         varchar(30) NOT NULL,
    survey_date         timestamptz NOT NULL,
    surveyor_partner_id varchar(20) REFERENCES core.partner(partner_id),
    status              varchar(30) NOT NULL DEFAULT 'PENDING',
    report_number       varchar(100),
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz,
    CONSTRAINT chk_survey_type CHECK (survey_type IN (
        'INITIAL','DRAFT','FINAL','VERIFICATION','LOADING','DISCHARGE','INTERMEDIATE'
    )),
    CONSTRAINT chk_survey_status CHECK (status IN ('PENDING','IN_PROGRESS','COMPLETED','VERIFIED','REJECTED'))
);

CREATE TABLE IF NOT EXISTS survey.survey_measurement (
    id                  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    survey_id           varchar(30) NOT NULL REFERENCES survey.survey(survey_id),
    measurement_type    varchar(50) NOT NULL,
    value               numeric(20,6) NOT NULL,
    uom_code            varchar(10) REFERENCES ref.unit_of_measure(uom_code),
    created_at          timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS survey.sample (
    sample_id           varchar(30) PRIMARY KEY,
    survey_id           varchar(30) REFERENCES survey.survey(survey_id),
    cargo_id            varchar(30) REFERENCES cargo.cargo(cargo_id),
    lot_id              varchar(30) REFERENCES cargo.cargo_lot(lot_id),
    sample_number       varchar(50) NOT NULL,
    sample_type         varchar(30) NOT NULL,
    collection_point    geometry(Point, 4326),
    collected_at        timestamptz NOT NULL,
    collected_by_partner varchar(20) REFERENCES core.partner(partner_id),
    status              varchar(30) NOT NULL DEFAULT 'COLLECTED',
    created_at          timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT chk_sample_status CHECK (status IN ('COLLECTED','SUBMITTED','IN_TESTING','COMPLETED','REJECTED')),
    CONSTRAINT chk_sample_type CHECK (sample_type IN ('CARGO','WATER','SOIL','AIR','SEDIMENT'))
);

CREATE TABLE IF NOT EXISTS survey.sample_test (
    test_id             bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    sample_id           varchar(30) NOT NULL REFERENCES survey.sample(sample_id),
    laboratory_partner_id varchar(20) REFERENCES core.partner(partner_id),
    test_type           varchar(50) NOT NULL,
    test_method         varchar(100),
    test_started_at     timestamptz,
    test_completed_at   timestamptz,
    status              varchar(30) NOT NULL DEFAULT 'PENDING',
    created_at          timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT chk_test_status CHECK (status IN ('PENDING','IN_PROGRESS','COMPLETED','CANCELLED'))
);

CREATE TABLE IF NOT EXISTS survey.sample_result (
    result_id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    test_id             bigint NOT NULL REFERENCES survey.sample_test(test_id),
    parameter           varchar(100) NOT NULL,
    value               numeric(20,6) NOT NULL,
    uom_code            varchar(10) REFERENCES ref.unit_of_measure(uom_code),
    min_threshold       numeric(20,6),
    max_threshold       numeric(20,6),
    is_pass             boolean,
    result_at           timestamptz NOT NULL DEFAULT now(),
    created_at          timestamptz NOT NULL DEFAULT now()
);

-- =============================================================================
-- 13. TRACKING — AIS & VESSEL TRACK
-- =============================================================================

CREATE TABLE IF NOT EXISTS tracking.ais_position (
    id                  bigint GENERATED ALWAYS AS IDENTITY,
    vessel_id           varchar(20) NOT NULL REFERENCES fleet.vessel(vessel_id),
    voyage_id           varchar(30) REFERENCES voyage.voyage(voyage_id),
    record_time         timestamptz NOT NULL,
    latitude            numeric(10,7) NOT NULL,
    longitude           numeric(10,7) NOT NULL,
    geom                geometry(Point, 4326) GENERATED ALWAYS AS (
        ST_SetSRID(ST_MakePoint(longitude::float8, latitude::float8), 4326)
    ) STORED,
    speed_over_ground   numeric(6,2),
    course_over_ground  numeric(5,2),
    heading             numeric(5,2),
    navigation_status   varchar(50),
    source_mmsi         varchar(9),
    created_at          timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (id, record_time)
) PARTITION BY RANGE (record_time);

COMMENT ON TABLE tracking.ais_position IS 'AIS position data — partitioned by time for performance';

CREATE TABLE IF NOT EXISTS tracking.ais_position_default
    PARTITION OF tracking.ais_position DEFAULT;

CREATE TABLE IF NOT EXISTS tracking.vessel_track (
    id                  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    vessel_id           varchar(20) NOT NULL REFERENCES fleet.vessel(vessel_id),
    voyage_id           varchar(30) REFERENCES voyage.voyage(voyage_id),
    voyage_leg_id       varchar(30) REFERENCES voyage.voyage_leg(leg_id),
    track_segment       geometry(Linestring, 4326),
    start_time          timestamptz NOT NULL,
    end_time            timestamptz,
    distance_nm         numeric(10,2),
    created_at          timestamptz NOT NULL DEFAULT now()
);

-- =============================================================================
-- 14. ENVIRONMENTAL MONITORING
-- =============================================================================

CREATE TABLE IF NOT EXISTS environment.station (
    station_id          varchar(20) PRIMARY KEY,
    site_code           varchar(20) REFERENCES operations.site(site_code),
    work_area_code      varchar(20) REFERENCES operations.work_area(work_area_code),
    station_type        varchar(30) NOT NULL,
    latitude            numeric(10,7) NOT NULL,
    longitude           numeric(10,7) NOT NULL,
    geom                geometry(Point, 4326) GENERATED ALWAYS AS (
        ST_SetSRID(ST_MakePoint(longitude::float8, latitude::float8), 4326)
    ) STORED,
    depth_m             numeric(8,2),
    battery_level       numeric(5,2),
    last_maintenance    date,
    status              varchar(20) NOT NULL DEFAULT 'ACTIVE',
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz,
    CONSTRAINT chk_env_station_status CHECK (status IN ('ACTIVE','INACTIVE','MAINTENANCE','DECOMMISSIONED')),
    CONSTRAINT chk_battery CHECK (battery_level IS NULL OR (battery_level >= 0 AND battery_level <= 100))
);

CREATE TABLE IF NOT EXISTS environment.observation (
    observation_id      bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    station_id          varchar(20) NOT NULL REFERENCES environment.station(station_id),
    voyage_id           varchar(30) REFERENCES voyage.voyage(voyage_id),
    port_call_id        varchar(30) REFERENCES voyage.port_call(port_call_id),
    observed_at         timestamptz NOT NULL,
    weather_condition   varchar(50),
    wind_speed_kt       numeric(6,2),
    wave_height_m       numeric(6,2),
    current_speed_kt    numeric(6,2),
    remarks             text,
    created_at          timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS environment.measurement (
    id                  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    observation_id      bigint NOT NULL REFERENCES environment.observation(observation_id),
    parameter           varchar(50) NOT NULL,
    value               numeric(12,4) NOT NULL,
    uom_code            varchar(10) REFERENCES ref.unit_of_measure(uom_code),
    created_at          timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS environment.alert (
    alert_id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    station_id          varchar(20) REFERENCES environment.station(station_id),
    observation_id      bigint REFERENCES environment.observation(observation_id),
    alert_type          varchar(50) NOT NULL,
    severity            varchar(20) NOT NULL DEFAULT 'WARNING',
    parameter           varchar(50),
    threshold_value     numeric(12,4),
    actual_value        numeric(12,4),
    triggered_at        timestamptz NOT NULL DEFAULT now(),
    acknowledged_at     timestamptz,
    acknowledged_by     varchar(20),
    status              varchar(20) NOT NULL DEFAULT 'ACTIVE',
    created_at          timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT chk_env_alert_severity CHECK (severity IN ('INFO','WARNING','CRITICAL','EMERGENCY')),
    CONSTRAINT chk_env_alert_status CHECK (status IN ('ACTIVE','ACKNOWLEDGED','RESOLVED','DISMISSED'))
);

-- =============================================================================
-- 15. FINANCE
-- =============================================================================

CREATE TABLE IF NOT EXISTS finance.exchange_rate (
    id                  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    currency_from       char(3) NOT NULL REFERENCES ref.currency(currency_code),
    currency_to         char(3) NOT NULL REFERENCES ref.currency(currency_code),
    rate_date           date NOT NULL,
    rate_type           varchar(20) NOT NULL DEFAULT 'SPOT',
    rate_buy            numeric(18,6),
    rate_sell           numeric(18,6),
    rate_mid            numeric(18,6) NOT NULL,
    source              varchar(50),
    created_at          timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_exchange_rate UNIQUE (currency_from, currency_to, rate_date, rate_type)
);

CREATE TABLE IF NOT EXISTS finance.proforma_invoice (
    proforma_number     varchar(50) PRIMARY KEY,
    shipment_id         varchar(30) REFERENCES logistics.shipment(shipment_id),
    buyer_partner_id    varchar(20) NOT NULL REFERENCES core.partner(partner_id),
    issue_date          date NOT NULL,
    estimated_volume    numeric(20,6),
    uom_code            varchar(10) REFERENCES ref.unit_of_measure(uom_code),
    unit_price          numeric(18,4),
    currency_code       char(3) REFERENCES ref.currency(currency_code),
    estimated_amount    numeric(20,4),
    status              varchar(30) NOT NULL DEFAULT 'DRAFT',
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz,
    CONSTRAINT chk_proforma_status CHECK (status IN ('DRAFT','ISSUED','ACCEPTED','INVOICED','CANCELLED'))
);

CREATE TABLE IF NOT EXISTS finance.invoice (
    invoice_number      varchar(50) PRIMARY KEY,
    invoice_type        varchar(20) NOT NULL,
    invoice_category    varchar(20) NOT NULL DEFAULT 'FINAL',
    parent_invoice      varchar(50) REFERENCES finance.invoice(invoice_number),
    buyer_partner_id    varchar(20) REFERENCES core.partner(partner_id),
    seller_partner_id   varchar(20) REFERENCES core.partner(partner_id),
    proforma_number     varchar(50) REFERENCES finance.proforma_invoice(proforma_number),
    shipment_id         varchar(30) REFERENCES logistics.shipment(shipment_id),
    po_number           varchar(50) REFERENCES commercial.purchase_order(po_number),
    issue_date          date NOT NULL,
    due_date            date NOT NULL,
    currency_code       char(3) NOT NULL REFERENCES ref.currency(currency_code),
    exchange_rate_id    bigint REFERENCES finance.exchange_rate(id),
    subtotal            numeric(20,4) NOT NULL DEFAULT 0,
    tax_total           numeric(20,4) NOT NULL DEFAULT 0,
    discount_total      numeric(20,4) NOT NULL DEFAULT 0,
    total_amount        numeric(20,4) NOT NULL DEFAULT 0,
    total_amount_idr    numeric(20,4),
    status              varchar(30) NOT NULL DEFAULT 'DRAFT',
    description         text,
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz,
    CONSTRAINT chk_invoice_type CHECK (invoice_type IN ('SALES','PURCHASE','CREDIT_NOTE','DEBIT_NOTE')),
    CONSTRAINT chk_invoice_category CHECK (invoice_category IN ('PROFORMA','FINAL','PROVISIONAL')),
    CONSTRAINT chk_invoice_status CHECK (status IN ('DRAFT','ISSUED','CONFIRMED','PARTIAL','PAID','OVERDUE','CANCELLED','CREDITED'))
);

CREATE TABLE IF NOT EXISTS finance.invoice_line (
    id                  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    invoice_number      varchar(50) NOT NULL REFERENCES finance.invoice(invoice_number),
    line_number         smallint NOT NULL,
    description         varchar(255) NOT NULL,
    quantity            numeric(20,6) NOT NULL,
    uom_code            varchar(10) REFERENCES ref.unit_of_measure(uom_code),
    unit_price          numeric(18,4) NOT NULL,
    total_price         numeric(20,4) NOT NULL,
    created_at          timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_invoice_line UNIQUE (invoice_number, line_number)
);

CREATE TABLE IF NOT EXISTS finance.invoice_tax (
    id                  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    invoice_number      varchar(50) NOT NULL REFERENCES finance.invoice(invoice_number),
    tax_type            varchar(30) NOT NULL,
    tax_rate_pct        numeric(5,2) NOT NULL,
    tax_base_amount     numeric(20,4) NOT NULL,
    tax_amount          numeric(20,4) NOT NULL,
    tax_amount_idr      numeric(20,4),
    tax_doc_number      varchar(50),
    created_at          timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS finance.payment (
    payment_number      varchar(50) PRIMARY KEY,
    invoice_number      varchar(50) NOT NULL REFERENCES finance.invoice(invoice_number),
    buyer_partner_id    varchar(20) REFERENCES core.partner(partner_id),
    payment_date        date NOT NULL,
    payment_method      varchar(30) NOT NULL,
    currency_code       char(3) NOT NULL REFERENCES ref.currency(currency_code),
    exchange_rate_id    bigint REFERENCES finance.exchange_rate(id),
    amount              numeric(20,4) NOT NULL,
    amount_idr          numeric(20,4),
    reference_code      varchar(100),
    notes               text,
    status              varchar(30) NOT NULL DEFAULT 'PENDING',
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz,
    CONSTRAINT chk_payment_method CHECK (payment_method IN ('BANK_TRANSFER','LC','TELEGRAPHIC','CHECK','CASH','CARD')),
    CONSTRAINT chk_payment_status CHECK (status IN ('PENDING','CONFIRMED','COMPLETED','FAILED','REFUNDED','CANCELLED'))
);

-- =============================================================================
-- 16. DOCUMENTS
-- =============================================================================

CREATE TABLE IF NOT EXISTS documents.document_category (
    category_code       varchar(30) PRIMARY KEY,
    name                varchar(100) NOT NULL,
    description         text,
    is_active           boolean NOT NULL DEFAULT true
);

CREATE TABLE IF NOT EXISTS documents.document (
    document_id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    category_code       varchar(30) REFERENCES documents.document_category(category_code),
    document_number     varchar(100),
    title               varchar(255) NOT NULL,
    description         text,
    classification      varchar(20) NOT NULL DEFAULT 'INTERNAL',
    created_by          varchar(20),
    created_at          timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT chk_doc_classification CHECK (classification IN ('PUBLIC','INTERNAL','CONFIDENTIAL','RESTRICTED'))
);

CREATE TABLE IF NOT EXISTS documents.document_version (
    version_id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    document_id         bigint NOT NULL REFERENCES documents.document(document_id),
    version_number      integer NOT NULL,
    file_name           varchar(255) NOT NULL,
    storage_url         text NOT NULL,
    file_hash           varchar(64) NOT NULL,
    file_size_bytes     bigint,
    mime_type           varchar(50),
    uploaded_by         varchar(20),
    is_current          boolean NOT NULL DEFAULT true,
    created_at          timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_doc_version UNIQUE (document_id, version_number)
);

CREATE TABLE IF NOT EXISTS documents.document_relation (
    id                  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    document_id         bigint NOT NULL REFERENCES documents.document(document_id),
    entity_type         varchar(50) NOT NULL,
    entity_id           varchar(50) NOT NULL,
    relation_type       varchar(30) NOT NULL DEFAULT 'ATTACHMENT',
    created_at          timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE documents.document_relation IS 'Polymorphic relation — links documents to any entity (PO, Clearance, Survey, Voyage, Invoice, etc.)';

CREATE TABLE IF NOT EXISTS documents.document_approval (
    id                  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    document_id         bigint NOT NULL REFERENCES documents.document(document_id),
    version_id          bigint REFERENCES documents.document_version(version_id),
    approval_status     varchar(20) NOT NULL DEFAULT 'PENDING',
    approved_by         varchar(20),
    approved_at         timestamptz,
    remarks             text,
    created_at          timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT chk_doc_approval_status CHECK (approval_status IN ('PENDING','APPROVED','REJECTED','REVOKED'))
);

-- =============================================================================
-- 17. SECURITY — RBAC
-- =============================================================================

CREATE TABLE IF NOT EXISTS security.role (
    role_code           varchar(30) PRIMARY KEY,
    name                varchar(100) NOT NULL,
    description         text,
    is_active           boolean NOT NULL DEFAULT true,
    created_at          timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS security.permission (
    permission_code     varchar(50) PRIMARY KEY,
    module              varchar(50) NOT NULL,
    action              varchar(30) NOT NULL,
    description         text,
    created_at          timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS security.role_permission (
    role_code           varchar(30) NOT NULL REFERENCES security.role(role_code),
    permission_code     varchar(50) NOT NULL REFERENCES security.permission(permission_code),
    created_at          timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (role_code, permission_code)
);

CREATE TABLE IF NOT EXISTS security.user_account (
    code_user           varchar(30) PRIMARY KEY,
    username            varchar(50) NOT NULL UNIQUE,
    password_hash       varchar(255) NOT NULL,
    name                varchar(100) NOT NULL,
    email               varchar(100) UNIQUE,
    role_code           varchar(30) REFERENCES security.role(role_code),
    org_code            varchar(20) REFERENCES core.organization(org_code),
    partner_id          varchar(20) REFERENCES core.partner(partner_id),
    is_active           boolean NOT NULL DEFAULT true,
    last_login          timestamptz,
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz,
    deleted_at          timestamptz
);

CREATE TABLE IF NOT EXISTS security.user_contact (
    id                  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code_user           varchar(30) NOT NULL REFERENCES security.user_account(code_user),
    contact_type        varchar(20) NOT NULL,
    contact_value       varchar(200) NOT NULL,
    is_primary          boolean NOT NULL DEFAULT false,
    created_at          timestamptz NOT NULL DEFAULT now()
);

-- =============================================================================
-- 18. AUDIT — Immutable Audit Trail
-- =============================================================================

CREATE TABLE IF NOT EXISTS audit.audit_event (
    event_id            uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    code_user           varchar(30),
    action_type         varchar(20) NOT NULL,
    schema_name         varchar(50) NOT NULL,
    table_name          varchar(50) NOT NULL,
    record_id           varchar(100),
    old_data            jsonb,
    new_data            jsonb,
    correlation_id      uuid,
    request_id          uuid,
    client_ip           inet,
    user_agent          text,
    data_classification varchar(20),
    created_at          timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE audit.audit_event IS 'Immutable audit trail — no UPDATE or DELETE allowed. No FK to user_account to preserve audit when users are deleted.';

CREATE TABLE IF NOT EXISTS audit.audit_change (
    change_id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    event_id            uuid NOT NULL REFERENCES audit.audit_event(event_id),
    field_name          varchar(100) NOT NULL,
    old_value           text,
    new_value           text,
    created_at          timestamptz NOT NULL DEFAULT now()
);

-- =============================================================================
-- 19. INTEGRATION
-- =============================================================================

CREATE TABLE IF NOT EXISTS integration.inbox (
    message_id          uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    source_system       varchar(50) NOT NULL,
    source_record_id    varchar(100),
    source_country      char(2),
    message_type        varchar(50) NOT NULL,
    message_body        jsonb NOT NULL,
    status              varchar(30) NOT NULL DEFAULT 'RECEIVED',
    error_message       text,
    received_at         timestamptz NOT NULL DEFAULT now(),
    processed_at        timestamptz,
    CONSTRAINT chk_inbox_status CHECK (status IN ('RECEIVED','VALIDATED','PROCESSED','FAILED','DUPLICATE'))
);

CREATE TABLE IF NOT EXISTS integration.outbox (
    message_id          uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    target_system       varchar(50) NOT NULL,
    message_type        varchar(50) NOT NULL,
    message_body        jsonb NOT NULL,
    status              varchar(30) NOT NULL DEFAULT 'PENDING',
    error_message       text,
    created_at          timestamptz NOT NULL DEFAULT now(),
    sent_at             timestamptz,
    CONSTRAINT chk_outbox_status CHECK (status IN ('PENDING','SENT','FAILED','RETRY'))
);

-- =============================================================================
-- 20. HELPER FUNCTIONS
-- =============================================================================

-- Auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION internal.update_updated_at()
RETURNS trigger
SET search_path = ''
AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Generic audit trigger function
CREATE OR REPLACE FUNCTION internal.audit_trigger()
RETURNS trigger
SET search_path = ''
AS $$
DECLARE
    v_record_id TEXT;
    v_data JSONB;
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_data := to_jsonb(OLD);
    ELSE
        v_data := to_jsonb(NEW);
    END IF;

    v_record_id := v_data ->> TG_ARGV[0];
    IF v_record_id IS NULL THEN
        v_record_id := v_data->>'id';
    END IF;
    IF v_record_id IS NULL THEN
        v_record_id := 'UNKNOWN';
    END IF;

    INSERT INTO audit.audit_event (
        code_user, action_type, schema_name, table_name,
        record_id, old_data, new_data,
        correlation_id, request_id, client_ip, user_agent, created_at
    ) VALUES (
        COALESCE(current_setting('app.current_user', true), 'SYSTEM'),
        TG_OP,
        TG_TABLE_SCHEMA,
        TG_TABLE_NAME,
        v_record_id,
        CASE WHEN TG_OP IN ('UPDATE','DELETE') THEN to_jsonb(OLD) ELSE NULL END,
        CASE WHEN TG_OP IN ('INSERT','UPDATE') THEN to_jsonb(NEW) ELSE NULL END,
        NULLIF(current_setting('app.correlation_id', true), '')::uuid,
        NULLIF(current_setting('app.request_id', true), '')::uuid,
        NULLIF(current_setting('app.client_ip', true), '')::inet,
        NULLIF(current_setting('app.user_agent', true), ''),
        now()
    );

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Auto-partition management
CREATE OR REPLACE FUNCTION internal.create_monthly_partitions()
RETURNS void
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_parents TEXT[] := ARRAY[
        'tracking.ais_position'
    ];
    v_parent TEXT;
    v_schema TEXT;
    v_table TEXT;
    v_partition_name TEXT;
    v_target DATE;
    v_start DATE;
    v_end DATE;
BEGIN
    FOR i IN 0..2 LOOP
        v_target := date_trunc('month', CURRENT_DATE + (i || ' month')::interval)::date;
        v_start := v_target;
        v_end := v_target + interval '1 month';
        FOREACH v_parent IN ARRAY v_parents LOOP
            v_schema := split_part(v_parent, '.', 1);
            v_table := split_part(v_parent, '.', 2);
            v_partition_name := v_table || '_' || to_char(v_target, 'YYYYMM');
            IF NOT EXISTS (
                SELECT 1 FROM pg_catalog.pg_class c
                JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
                WHERE n.nspname = v_schema AND c.relname = v_partition_name
            ) THEN
                EXECUTE format(
                    'CREATE TABLE %I.%I PARTITION OF %I.%I FOR VALUES FROM (%L) TO (%L);',
                    v_schema, v_partition_name, v_schema, v_table, v_start, v_end
                );
            END IF;
        END LOOP;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- 21. TRIGGERS
-- =============================================================================

-- updated_at triggers on key tables
CREATE TRIGGER trg_core_partner_updated BEFORE UPDATE ON core.partner
    FOR EACH ROW EXECUTE FUNCTION internal.update_updated_at();
CREATE TRIGGER trg_fleet_vessel_updated BEFORE UPDATE ON fleet.vessel
    FOR EACH ROW EXECUTE FUNCTION internal.update_updated_at();
CREATE TRIGGER trg_commercial_po_updated BEFORE UPDATE ON commercial.purchase_order
    FOR EACH ROW EXECUTE FUNCTION internal.update_updated_at();
CREATE TRIGGER trg_logistics_shipment_updated BEFORE UPDATE ON logistics.shipment
    FOR EACH ROW EXECUTE FUNCTION internal.update_updated_at();
CREATE TRIGGER trg_voyage_updated BEFORE UPDATE ON voyage.voyage
    FOR EACH ROW EXECUTE FUNCTION internal.update_updated_at();
CREATE TRIGGER trg_finance_invoice_updated BEFORE UPDATE ON finance.invoice
    FOR EACH ROW EXECUTE FUNCTION internal.update_updated_at();
CREATE TRIGGER trg_finance_payment_updated BEFORE UPDATE ON finance.payment
    FOR EACH ROW EXECUTE FUNCTION internal.update_updated_at();
CREATE TRIGGER trg_security_user_updated BEFORE UPDATE ON security.user_account
    FOR EACH ROW EXECUTE FUNCTION internal.update_updated_at();

-- Audit triggers on critical tables
CREATE TRIGGER trg_audit_partner AFTER INSERT OR UPDATE OR DELETE ON core.partner
    FOR EACH ROW EXECUTE FUNCTION internal.audit_trigger('partner_id');
CREATE TRIGGER trg_audit_vessel AFTER INSERT OR UPDATE OR DELETE ON fleet.vessel
    FOR EACH ROW EXECUTE FUNCTION internal.audit_trigger('vessel_id');
CREATE TRIGGER trg_audit_po AFTER INSERT OR UPDATE OR DELETE ON commercial.purchase_order
    FOR EACH ROW EXECUTE FUNCTION internal.audit_trigger('po_number');
CREATE TRIGGER trg_audit_shipment AFTER INSERT OR UPDATE OR DELETE ON logistics.shipment
    FOR EACH ROW EXECUTE FUNCTION internal.audit_trigger('shipment_id');
CREATE TRIGGER trg_audit_voyage AFTER INSERT OR UPDATE OR DELETE ON voyage.voyage
    FOR EACH ROW EXECUTE FUNCTION internal.audit_trigger('voyage_id');
CREATE TRIGGER trg_audit_clearance AFTER INSERT OR UPDATE OR DELETE ON regulatory.clearance
    FOR EACH ROW EXECUTE FUNCTION internal.audit_trigger('clearance_id');
CREATE TRIGGER trg_audit_invoice AFTER INSERT OR UPDATE OR DELETE ON finance.invoice
    FOR EACH ROW EXECUTE FUNCTION internal.audit_trigger('invoice_number');
CREATE TRIGGER trg_audit_payment AFTER INSERT OR UPDATE OR DELETE ON finance.payment
    FOR EACH ROW EXECUTE FUNCTION internal.audit_trigger('payment_number');
CREATE TRIGGER trg_audit_cargo AFTER INSERT OR UPDATE OR DELETE ON cargo.cargo
    FOR EACH ROW EXECUTE FUNCTION internal.audit_trigger('cargo_id');
CREATE TRIGGER trg_audit_survey AFTER INSERT OR UPDATE OR DELETE ON survey.survey
    FOR EACH ROW EXECUTE FUNCTION internal.audit_trigger('survey_id');
CREATE TRIGGER trg_audit_user AFTER INSERT OR UPDATE OR DELETE ON security.user_account
    FOR EACH ROW EXECUTE FUNCTION internal.audit_trigger('code_user');

-- =============================================================================
-- 22. INDEXES
-- =============================================================================

-- Reference Data
CREATE INDEX IF NOT EXISTS idx_ref_country_iso ON ref.country (iso_alpha2, iso_alpha3);

-- Core
CREATE INDEX IF NOT EXISTS idx_core_partner_name ON core.partner (name);
CREATE INDEX IF NOT EXISTS idx_core_partner_country ON core.partner (country_id);
CREATE INDEX IF NOT EXISTS idx_core_partner_role ON core.partner_role (partner_id, role_code, is_current);
CREATE INDEX IF NOT EXISTS idx_core_partner_address_geo ON core.partner_address USING GIST (geom);

-- Port
CREATE INDEX IF NOT EXISTS idx_port_unlocode ON port.port (un_locode);
CREATE INDEX IF NOT EXISTS idx_port_country ON port.port (country_id);
CREATE INDEX IF NOT EXISTS idx_port_geom ON port.port USING GIST (geom);

-- Fleet
CREATE INDEX IF NOT EXISTS idx_fleet_vessel_imo ON fleet.vessel (imo_number);
CREATE INDEX IF NOT EXISTS idx_fleet_vessel_mmsi ON fleet.vessel (mmsi);
CREATE INDEX IF NOT EXISTS idx_fleet_vessel_flag ON fleet.vessel (flag_country_id);
CREATE INDEX IF NOT EXISTS idx_fleet_vessel_partner ON fleet.vessel_partner (vessel_id, partner_id, is_current);

-- Commercial
CREATE INDEX IF NOT EXISTS idx_commercial_po_buyer ON commercial.purchase_order (buyer_partner_id);
CREATE INDEX IF NOT EXISTS idx_commercial_po_status ON commercial.purchase_order (status);

-- Logistics
CREATE INDEX IF NOT EXISTS idx_logistics_shipment_vessel ON logistics.shipment (vessel_id);
CREATE INDEX IF NOT EXISTS idx_logistics_shipment_po ON logistics.shipment (po_number);

-- Voyage
CREATE INDEX IF NOT EXISTS idx_voyage_vessel ON voyage.voyage (vessel_id);
CREATE INDEX IF NOT EXISTS idx_voyage_status ON voyage.voyage (status);
CREATE INDEX IF NOT EXISTS idx_voyage_leg_route ON voyage.voyage_leg (origin_port_id, destination_port_id);
CREATE INDEX IF NOT EXISTS idx_port_call_voyage ON voyage.port_call (voyage_id);
CREATE INDEX IF NOT EXISTS idx_port_call_port ON voyage.port_call (port_id);
CREATE INDEX IF NOT EXISTS idx_port_call_event_type ON voyage.port_call_event (port_call_id, event_type);

-- Regulatory
CREATE INDEX IF NOT EXISTS idx_clearance_country ON regulatory.clearance (country_id);
CREATE INDEX IF NOT EXISTS idx_clearance_shipment ON regulatory.clearance (shipment_id);
CREATE INDEX IF NOT EXISTS idx_clearance_status ON regulatory.clearance (status);

-- Cargo
CREATE INDEX IF NOT EXISTS idx_cargo_shipment ON cargo.cargo (shipment_id);
CREATE INDEX IF NOT EXISTS idx_cargo_movement_cargo ON cargo.cargo_movement (cargo_id);
CREATE INDEX IF NOT EXISTS idx_cargo_movement_time ON cargo.cargo_movement (movement_time);
CREATE INDEX IF NOT EXISTS idx_quantity_measurement_cargo ON cargo.quantity_measurement (cargo_id);

-- Survey
CREATE INDEX IF NOT EXISTS idx_survey_voyage ON survey.survey (voyage_id);
CREATE INDEX IF NOT EXISTS idx_survey_sample_cargo ON survey.sample (cargo_id);
CREATE INDEX IF NOT EXISTS idx_survey_sample_status ON survey.sample (status);

-- Tracking
CREATE INDEX IF NOT EXISTS idx_ais_vessel_time ON tracking.ais_position (vessel_id, record_time DESC);
CREATE INDEX IF NOT EXISTS idx_ais_geom ON tracking.ais_position USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_vessel_track_voyage ON tracking.vessel_track (vessel_id, voyage_id);

-- Environment
CREATE INDEX IF NOT EXISTS idx_env_station_site ON environment.station (site_code);
CREATE INDEX IF NOT EXISTS idx_env_observation_time ON environment.observation (station_id, observed_at DESC);

-- Finance
CREATE INDEX IF NOT EXISTS idx_finance_invoice_buyer ON finance.invoice (buyer_partner_id);
CREATE INDEX IF NOT EXISTS idx_finance_invoice_status ON finance.invoice (status);
CREATE INDEX IF NOT EXISTS idx_finance_payment_invoice ON finance.payment (invoice_number);
CREATE INDEX IF NOT EXISTS idx_finance_exchange_rate ON finance.exchange_rate (currency_from, currency_to, rate_date);

-- Documents
CREATE INDEX IF NOT EXISTS idx_document_relation_entity ON documents.document_relation (entity_type, entity_id);

-- Audit
CREATE INDEX IF NOT EXISTS idx_audit_event_time ON audit.audit_event (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_event_table ON audit.audit_event (schema_name, table_name);
CREATE INDEX IF NOT EXISTS idx_audit_event_user ON audit.audit_event (code_user);

-- Integration
CREATE INDEX IF NOT EXISTS idx_inbox_status ON integration.inbox (status, received_at);
CREATE INDEX IF NOT EXISTS idx_outbox_status ON integration.outbox (status, created_at);

-- =============================================================================
-- 23. COORDINATE VALIDATION CONSTRAINTS
-- =============================================================================
DO $$
DECLARE
    v_checks TEXT[][] := ARRAY[
        ARRAY['core.partner_address', 'chk_partner_addr_coords'],
        ARRAY['port.port', 'chk_port_coords'],
        ARRAY['operations.site', 'chk_site_coords'],
        ARRAY['environment.station', 'chk_env_station_coords'],
        ARRAY['tracking.ais_position', 'chk_ais_coords']
    ];
    v_row TEXT[];
BEGIN
    FOREACH v_row SLICE 1 IN ARRAY v_checks LOOP
        IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = v_row[2]) THEN
            EXECUTE format(
                'ALTER TABLE %s ADD CONSTRAINT %I CHECK (
                    (latitude IS NULL OR latitude BETWEEN -90 AND 90)
                    AND (longitude IS NULL OR longitude BETWEEN -180 AND 180)
                );',
                v_row[1], v_row[2]
            );
        END IF;
    END LOOP;
END $$;

-- =============================================================================
-- 24. AUDIT IMMUTABILITY
-- =============================================================================
-- Audit tables are append-only. No updates or deletes allowed.
REVOKE UPDATE, DELETE ON audit.audit_event, audit.audit_change FROM PUBLIC;
REVOKE UPDATE, DELETE ON audit.audit_event, audit.audit_change FROM app_service;

-- =============================================================================
-- 25. ROW LEVEL SECURITY (RLS)
-- =============================================================================
ALTER TABLE finance.invoice ENABLE ROW LEVEL SECURITY;
ALTER TABLE finance.payment ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.partner ENABLE ROW LEVEL SECURITY;
ALTER TABLE security.user_account ENABLE ROW LEVEL SECURITY;
ALTER TABLE documents.document ENABLE ROW LEVEL SECURITY;

-- Note: Implement granular RLS policies per application role as needed.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='finance' AND tablename='invoice' AND policyname='invoice_read_authenticated') THEN
        CREATE POLICY invoice_read_authenticated ON finance.invoice
            FOR SELECT TO authenticated USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='finance' AND tablename='payment' AND policyname='payment_read_authenticated') THEN
        CREATE POLICY payment_read_authenticated ON finance.payment
            FOR SELECT TO authenticated USING (true);
    END IF;
END $$;

-- =============================================================================
-- 26. CRON JOB — Monthly Partition Maintenance
-- =============================================================================
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'create_monthly_partitions') THEN
        PERFORM cron.unschedule(jobid) FROM cron.job WHERE jobname = 'create_monthly_partitions';
    END IF;
END $$;

SELECT cron.schedule(
    'create_monthly_partitions',
    '0 0 25 * *',
    $$ SELECT internal.create_monthly_partitions(); $$
);

-- =============================================================================
-- 27. VIEWS — Reporting Layer
-- =============================================================================

-- Voyage summary
CREATE OR REPLACE VIEW reporting.voyage_summary AS
SELECT
    v.voyage_id,
    v.voyage_number,
    v.vessel_id,
    fv.name AS vessel_name,
    fv.imo_number,
    s.shipment_id,
    v.status,
    v.planned_departure,
    v.actual_departure,
    v.planned_arrival,
    v.actual_arrival,
    (SELECT COUNT(*) FROM voyage.port_call pc WHERE pc.voyage_id = v.voyage_id) AS port_call_count,
    v.created_at
FROM voyage.voyage v
LEFT JOIN fleet.vessel fv ON v.vessel_id = fv.vessel_id
LEFT JOIN logistics.shipment s ON v.shipment_id = s.shipment_id;

-- Cargo summary per voyage
CREATE OR REPLACE VIEW reporting.cargo_summary AS
SELECT
    vc.voyage_id,
    v.voyage_number,
    vc.cargo_id,
    c.cargo_type,
    c.commodity,
    vc.loaded_quantity,
    vc.discharged_quantity,
    vc.uom_code,
    (vc.loaded_quantity - vc.discharged_quantity) AS quantity_difference
FROM cargo.voyage_cargo vc
JOIN voyage.voyage v ON vc.voyage_id = v.voyage_id
JOIN cargo.cargo c ON vc.cargo_id = c.cargo_id;

-- Quantity reconciliation (initial vs final)
CREATE OR REPLACE VIEW reporting.quantity_reconciliation AS
SELECT
    qm.cargo_id,
    c.cargo_type,
    qm.measurement_type,
    qm.quantity,
    qm.uom_code,
    qm.moisture_pct,
    qm.net_quantity,
    qm.measured_at,
    qm.measured_by_partner,
    qm.source
FROM cargo.quantity_measurement qm
JOIN cargo.cargo c ON qm.cargo_id = c.cargo_id
ORDER BY qm.cargo_id, qm.measured_at;

-- Sales summary (reporting layer, not source of truth)
CREATE OR REPLACE VIEW reporting.sales_summary AS
SELECT
    i.invoice_number,
    i.invoice_type,
    i.buyer_partner_id,
    cp.name AS buyer_name,
    i.issue_date,
    i.due_date,
    i.currency_code,
    i.subtotal,
    i.tax_total,
    i.total_amount,
    i.total_amount_idr,
    i.status,
    COALESCE(p.paid_amount, 0) AS paid_amount,
    (i.total_amount - COALESCE(p.paid_amount, 0)) AS outstanding_amount,
    i.created_at
FROM finance.invoice i
LEFT JOIN core.partner cp ON i.buyer_partner_id = cp.partner_id
LEFT JOIN (
    SELECT invoice_number, SUM(amount) AS paid_amount
    FROM finance.payment
    WHERE status IN ('CONFIRMED','COMPLETED')
    GROUP BY invoice_number
) p ON i.invoice_number = p.invoice_number;

-- =============================================================================
-- 28. DATA LINEAGE & CLASSIFICATION
-- =============================================================================

COMMENT ON COLUMN integration.inbox.source_system IS 'Source system name — for data lineage tracking';
COMMENT ON COLUMN integration.inbox.source_record_id IS 'Record ID in the source system';
COMMENT ON COLUMN integration.inbox.source_country IS 'Country of origin (ISO 3166-1 alpha-2)';