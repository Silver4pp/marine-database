-- -----------------------------------------------------------------------------
-- CREATING SCHEMAS
-- -----------------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS "param";
CREATE SCHEMA IF NOT EXISTS "usr";
CREATE SCHEMA IF NOT EXISTS "site";
CREATE SCHEMA IF NOT EXISTS "vessel";
CREATE SCHEMA IF NOT EXISTS "partner";
CREATE SCHEMA IF NOT EXISTS "buyer";
CREATE SCHEMA IF NOT EXISTS "operational";
CREATE SCHEMA IF NOT EXISTS "enviro";
CREATE SCHEMA IF NOT EXISTS "finance";
CREATE SCHEMA IF NOT EXISTS "document";
CREATE SCHEMA IF NOT EXISTS "audit";
CREATE SCHEMA IF NOT EXISTS "form";
CREATE SCHEMA IF NOT EXISTS "internal";
CREATE SCHEMA IF NOT EXISTS "ref";
CREATE SCHEMA IF NOT EXISTS "integration";
CREATE SCHEMA IF NOT EXISTS "reporting";

-- -----------------------------------------------------------------------------
-- CREATING EXTENSION
-- -----------------------------------------------------------------------------
SET search_path = public, extensions;
CREATE EXTENSION IF NOT EXISTS postgis SCHEMA extensions;
ALTER DATABASE postgres SET search_path TO "$user", "", public, extensions;

CREATE EXTENSION IF NOT EXISTS pg_cron SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS pgcrypto SCHEMA extensions;

-- -----------------------------------------------------------------------------
-- SCHEMA: PARAM
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS param.system_config (
    code_config varchar(50) PRIMARY KEY,
    config_value text NOT NULL,
    description text,
    is_secure boolean DEFAULT false,
    updated_by varchar(20),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS param.dropdown_list (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    category varchar(50) NOT NULL,
    code_value varchar(50) NOT NULL,
    display_label varchar(100) NOT NULL,
    sort_order integer DEFAULT 0,
    is_active boolean DEFAULT true,
    CONSTRAINT uq_dropdown UNIQUE (category, code_value)
);

CREATE TABLE IF NOT EXISTS param.notification_template (
    code_template varchar(50) PRIMARY KEY,
    platform varchar(20) NOT NULL,
    message_body text NOT NULL,
    is_active boolean DEFAULT true,
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS param.notification_log (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code_template varchar(50) REFERENCES param.notification_template(code_template),
    recipient varchar(100) NOT NULL,
    sent_at timestamptz NOT NULL DEFAULT now(),
    status varchar(20) DEFAULT 'SENT',
    error_message text,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS param.abbreviation (
    code_abbr varchar(50) PRIMARY KEY,
    full_name varchar(255) NOT NULL,
    category varchar(50),
    description text,
    is_active boolean DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz
);

CREATE TABLE IF NOT EXISTS param.uom (
    code_uom varchar(10) PRIMARY KEY,
    name varchar(50) NOT NULL,
    description text,
    is_active boolean DEFAULT true
);

CREATE TABLE IF NOT EXISTS param.organization (
    code_org varchar(20) PRIMARY KEY,
    name varchar(100) NOT NULL,
    is_active boolean DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz
);

CREATE TABLE IF NOT EXISTS param.threshold (
    code_threshold varchar(20) PRIMARY KEY,
    description text,
    code_uom varchar(10) REFERENCES param.uom(code_uom),
    nominal_limit numeric(20,6) NOT NULL,
    is_active boolean DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz
);

-- -----------------------------------------------------------------------------
-- SCHEMA: REF (international reference data — ISO standards)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ref.country (
    country_code char(2) PRIMARY KEY,      -- ISO 3166-1 alpha-2
    country_name text NOT NULL,
    iso3_code char(3),
    numeric_code char(3),
    is_active boolean NOT NULL DEFAULT true
);

CREATE TABLE IF NOT EXISTS ref.currency (
    currency_code char(3) PRIMARY KEY,     -- ISO 4217
    currency_name text NOT NULL,
    minor_unit smallint NOT NULL DEFAULT 2,
    is_active boolean NOT NULL DEFAULT true
);

CREATE TABLE IF NOT EXISTS ref.language (
    language_code char(2) PRIMARY KEY,     -- ISO 639-1
    language_name text NOT NULL,
    is_active boolean NOT NULL DEFAULT true
);

-- Reference table for controlled status vocabularies (Section 24). This is
-- documentation/validation metadata, NOT a replacement for the existing
-- varchar + CHECK constraint pattern already used across the schema (that
-- pattern is simple, fast, and adequate for this system's scale). Use this
-- table if the application needs to look up allowed statuses + descriptions
-- dynamically (e.g. for UI dropdowns) rather than hardcoding them.
CREATE TABLE IF NOT EXISTS ref.status (
    status_group varchar(50) NOT NULL,
    status_code varchar(50) NOT NULL,
    description text,
    is_active boolean NOT NULL DEFAULT true,
    PRIMARY KEY (status_group, status_code)
);

-- Seed: only the currencies/countries this business actually operates with.
-- Extend as needed — do not blindly seed the full ISO list if unused.
INSERT INTO ref.currency (currency_code, currency_name, minor_unit) VALUES
    ('IDR', 'Indonesian Rupiah', 2),
    ('USD', 'US Dollar', 2),
    ('SGD', 'Singapore Dollar', 2)
ON CONFLICT (currency_code) DO NOTHING;

INSERT INTO ref.country (country_code, country_name, iso3_code, numeric_code) VALUES
    ('ID', 'Indonesia', 'IDN', '360'),
    ('SG', 'Singapore', 'SGP', '702'),
    ('MY', 'Malaysia', 'MYS', '458')
ON CONFLICT (country_code) DO NOTHING;

-- -----------------------------------------------------------------------------
-- SCHEMA: USR
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS usr.role (
    code_role varchar(20) PRIMARY KEY,
    description text,
    is_active boolean DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz
);

CREATE TABLE IF NOT EXISTS usr.permission (
    code_permission varchar(50) PRIMARY KEY,
    module varchar(50) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS usr.role_permission (
    code_role varchar(20) REFERENCES usr.role(code_role) ON DELETE CASCADE,
    code_permission varchar(50) REFERENCES usr.permission(code_permission) ON DELETE CASCADE,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (code_role, code_permission)
);

CREATE TABLE IF NOT EXISTS usr.info (
    code_user varchar(20) PRIMARY KEY,
    password_hash varchar(255) NOT NULL,
    name varchar(100) NOT NULL,
    citizen varchar(20) NOT NULL,
    role varchar(20) REFERENCES usr.role(code_role),
    organization varchar(20) REFERENCES param.organization(code_org),
    is_active boolean DEFAULT true,
    last_login timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz,
    deleted_at timestamptz
);

CREATE TABLE IF NOT EXISTS usr.contact (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code_user varchar(20) REFERENCES usr.info(code_user) ON DELETE CASCADE,
    contact_type varchar(30) NOT NULL,
    contact_value varchar(100) NOT NULL,
    is_primary boolean DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz
);

-- -----------------------------------------------------------------------------
-- SCHEMA: SITE
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS site.type (
    code_type varchar(20) PRIMARY KEY,
    description text,
    is_active boolean DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS site.info (
    code_site varchar(20) PRIMARY KEY,
    code_type varchar(20) REFERENCES site.type(code_type),
    name varchar(100) NOT NULL,
    address text,
    city varchar(100),
    latitude numeric(10,7) NOT NULL,
    longitude numeric(10,7) NOT NULL,
    geom geometry(Point, 4326) GENERATED ALWAYS AS (
        ST_SetSRID(ST_MakePoint(longitude::float8, latitude::float8), 4326)
    ) STORED,
    is_active boolean DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz
);

CREATE TABLE IF NOT EXISTS site.roster (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code_site varchar(20) REFERENCES site.info(code_site) ON DELETE CASCADE,
    code_user varchar(20) REFERENCES usr.info(code_user) ON DELETE CASCADE,
    work_date date NOT NULL,
    is_pic boolean DEFAULT false,
    shift varchar(20) NOT NULL,
    status varchar(20) DEFAULT 'SCHEDULED',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz,
    CONSTRAINT roster_prevent_double_booking UNIQUE (code_user, work_date, shift)
);

-- -----------------------------------------------------------------------------
-- SCHEMA: PARTNER
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS partner.type (
    code_type varchar(20) PRIMARY KEY,
    description text,
    is_active boolean DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS partner.info (
    code_partner varchar(20) PRIMARY KEY,
    code_type varchar(20) REFERENCES partner.type(code_type),
    name varchar(100) NOT NULL,
    address text,
    city varchar(50),
    country char(2) REFERENCES ref.country(country_code),
    is_active boolean DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz
);

CREATE TABLE IF NOT EXISTS partner.contact (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code_partner varchar(20) REFERENCES partner.info(code_partner) ON DELETE CASCADE,
    pic_name varchar(100),
    contact_type varchar(30) NOT NULL,
    contact_value varchar(100) NOT NULL,
    is_primary boolean DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz
);

-- -----------------------------------------------------------------------------
-- SCHEMA: VESSEL
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS vessel.type (
    code_type varchar(20) PRIMARY KEY,
    description text,
    is_active boolean DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS vessel.info (
    code_vessel varchar(20) PRIMARY KEY,
    code_partner varchar(20) REFERENCES partner.info(code_partner),
    code_type varchar(20) REFERENCES vessel.type(code_type),
    name varchar(100) NOT NULL,
    imo_number varchar(20) UNIQUE,
    call_sign varchar(20) UNIQUE,
    flag char(2) REFERENCES ref.country(country_code),
    grt numeric(20,6),
    dwt numeric(20,6),
    is_active boolean DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz
);

CREATE TABLE IF NOT EXISTS vessel.site_assignment (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code_vessel varchar(20) REFERENCES vessel.info(code_vessel) ON DELETE CASCADE,
    code_site varchar(20) REFERENCES site.info(code_site),
    start_date date NOT NULL,
    end_date date,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz,
    CONSTRAINT chk_site_assignment_dates CHECK (end_date IS NULL OR end_date >= start_date)
);

CREATE TABLE IF NOT EXISTS vessel.certificate (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code_vessel varchar(20) REFERENCES vessel.info(code_vessel) ON DELETE CASCADE,
    name varchar(100) NOT NULL,
    issuer varchar(100) NOT NULL,
    issued_date date NOT NULL,
    expiry_date date NOT NULL,
    is_active boolean DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz
);

CREATE TABLE IF NOT EXISTS vessel.crew_history (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code_vessel varchar(20) REFERENCES vessel.info(code_vessel) ON DELETE CASCADE,
    code_user varchar(20) REFERENCES usr.info(code_user) ON DELETE CASCADE,
    position varchar(50) NOT NULL,
    sign_on_date date NOT NULL,
    sign_off_date date,
    status varchar(20) DEFAULT,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz
);

CREATE TABLE IF NOT EXISTS vessel.maintenance (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code_vessel varchar(20) REFERENCES vessel.info(code_vessel) ON DELETE CASCADE,
    code_partner varchar(20) REFERENCES partner.info(code_partner) ON DELETE SET NULL,
    description text NOT NULL,
    start_date date NOT NULL,
    end_date date,
    status varchar(20) DEFAULT 'SCHEDULED',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz
);

-- -----------------------------------------------------------------------------
-- SCHEMA: BUYER
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS buyer.type (
    code_type varchar(20) PRIMARY KEY,
    description text,
    is_active boolean DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS buyer.info (
    code_buyer varchar(20) PRIMARY KEY,
    code_type varchar(20) REFERENCES buyer.type(code_type),
    name varchar(100) NOT NULL,
    address text,
    city varchar(50),
    country char(2) REFERENCES ref.country(country_code),
    deposit_balance numeric(15,2) DEFAULT 0.00,
    is_active boolean DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz
);

CREATE TABLE IF NOT EXISTS buyer.discharge_location (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code_buyer varchar(20) REFERENCES buyer.info(code_buyer) ON DELETE CASCADE,
    name varchar(100) NOT NULL,
    latitude numeric(10,7) NOT NULL,
    longitude numeric(10,7) NOT NULL,
    is_active boolean DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz
);

CREATE TABLE IF NOT EXISTS buyer.deposit_ledger (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code_buyer varchar(20) REFERENCES buyer.info(code_buyer) ON DELETE CASCADE,
    transaction_date timestamptz NOT NULL DEFAULT now(),
    transaction_type varchar(30) NOT NULL,
    amount numeric(15,2) NOT NULL,
    reference_doc varchar(50),
    description text,
    created_by varchar(20) REFERENCES usr.info(code_user),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz
);

-- -----------------------------------------------------------------------------
-- SCHEMA: OPERATIONAL
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS operational.purchase_order (
    po_number varchar(50) PRIMARY KEY,
    code_buyer varchar(20) REFERENCES buyer.info(code_buyer),
    po_date date NOT NULL,
    target_completion_date date,
    uom varchar(10) REFERENCES param.uom(code_uom),
    total_volume numeric(20,6) NOT NULL,
    unit_price numeric(15,2) NOT NULL,
    total_amount numeric(15,2) NOT NULL,
    created_by varchar(20) REFERENCES usr.info(code_user),
    approved_by varchar(20) REFERENCES usr.info(code_user),
    status varchar(20) DEFAULT 'DRAFT',
    description text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz,
    CONSTRAINT chk_po_status CHECK (status IN ('DRAFT','SUBMITTED','APPROVED','IN PROGRESS','COMPLETED','CANCELLED'))
);

CREATE TABLE IF NOT EXISTS operational.approval_log (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ref_table varchar(50) NOT NULL,
    ref_id varchar(50) NOT NULL,
    action varchar(20) NOT NULL,
    -- Ditambahkan (Section 35): jejak transisi status eksplisit, terpisah
    -- dari 'action' (mis. action='APPROVE', previous_status='SUBMITTED',
    -- new_status='APPROVED'), supaya riwayat approval bisa direkonstruksi
    -- tanpa perlu menebak dari tabel bisnis aslinya.
    previous_status varchar(30),
    new_status varchar(30),
    approved_by varchar(20) REFERENCES usr.info(code_user),
    approved_at timestamptz NOT NULL DEFAULT now(),
    remarks text,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS operational.stock_ledger (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code_site varchar(20) NOT NULL REFERENCES site.info(code_site),
    transaction_time timestamptz NOT NULL DEFAULT now(),
    transaction_type varchar(30) NOT NULL,
    reference_type varchar(50),
    reference_id varchar(100),
    quantity numeric(20,6) NOT NULL,
    unit_code varchar(20) NOT NULL DEFAULT 'M3' REFERENCES param.uom(code_uom),
    direction smallint NOT NULL,
    quantity_delta numeric(20,6) GENERATED ALWAYS AS (quantity * direction) STORED,
    remarks text,
    created_by varchar(20) REFERENCES usr.info(code_user) ON DELETE SET NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT chk_stock_direction CHECK (direction IN (-1, 1)),
    CONSTRAINT chk_stock_quantity CHECK (quantity > 0),
    CONSTRAINT chk_stock_txn_type CHECK (transaction_type IN (
        'INITIAL_BALANCE','PRODUCTION','SHIPMENT','TRANSFER_IN','TRANSFER_OUT','ADJUSTMENT','CORRECTION'
    ))
);

CREATE TABLE IF NOT EXISTS operational.daily_production (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code_site varchar(20) REFERENCES site.info(code_site),
    code_vessel varchar(20) REFERENCES vessel.info(code_vessel),
    production_date date NOT NULL,
    volume_mined numeric(20,6) NOT NULL,
    operating_hours numeric(6,2) NOT NULL,
    reported_by varchar(20) REFERENCES usr.info(code_user) ON DELETE SET NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_daily_production UNIQUE (code_site, code_vessel, production_date)
);

CREATE TABLE IF NOT EXISTS operational.delivery_order (
    do_number varchar(50) PRIMARY KEY,
    po_number varchar(50) REFERENCES operational.purchase_order(po_number),
    code_vessel_main varchar(20) REFERENCES vessel.info(code_vessel),
    code_vessel_assist varchar(20) REFERENCES vessel.info(code_vessel) ON DELETE SET NULL,
    loading_site varchar(20) REFERENCES site.info(code_site),
    discharge_location_id bigint REFERENCES buyer.discharge_location(id),
    target_volume numeric(20,6) NOT NULL,
    status varchar(20) DEFAULT 'ISSUED',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz,
    CONSTRAINT chk_do_status CHECK (status IN ('ISSUED','LOADING','SAILING','DELIVERED','CANCELLED'))
);

CREATE TABLE IF NOT EXISTS operational.cargo_survey (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    do_number varchar(50) REFERENCES operational.delivery_order(do_number) ON DELETE CASCADE,
    code_partner varchar(20) REFERENCES partner.info(code_partner),
    survey_type varchar(30) NOT NULL,
    survey_date timestamptz NOT NULL,
    gross_volume numeric(20,6) NOT NULL,
    moisture_pct numeric(7,4),
    net_volume numeric(20,6) NOT NULL,
    report_doc_number varchar(100),
    status varchar(20),
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT chk_survey_status CHECK (status IN ('PENDING','VERIFIED','REJECTED'))
);

CREATE TABLE IF NOT EXISTS operational.bill_of_lading (
    bl_number varchar(50) PRIMARY KEY,
    do_number varchar(50) REFERENCES operational.delivery_order(do_number) ON DELETE CASCADE,
    issue_date date NOT NULL,
    port_of_loading varchar(100) NOT NULL,
    port_of_discharge varchar(100) NOT NULL,
    shipped_volume numeric(20,6) NOT NULL,
    status varchar(20) DEFAULT 'ISSUED',
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT chk_bl_status CHECK (status IN ('ISSUED','RELEASED','SURRENDERED'))
);

CREATE TABLE IF NOT EXISTS operational.statement_of_fact (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    do_number varchar(50) REFERENCES operational.delivery_order(do_number) ON DELETE CASCADE,
    event_time timestamptz NOT NULL,
    event_type varchar(50) NOT NULL,
    remarks text,
    recorded_by varchar(20) REFERENCES usr.info(code_user) ON DELETE SET NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);

-- -----------------------------------------------------------------------------
-- VESSEL MOVEMENT_LOG
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS vessel.movement_log (
    id bigint GENERATED ALWAYS AS IDENTITY,
    code_vessel varchar(20) REFERENCES vessel.info(code_vessel) ON DELETE CASCADE,
    code_site varchar(20) REFERENCES site.info(code_site) ON DELETE SET NULL,
    do_number varchar(50) REFERENCES operational.delivery_order(do_number) ON DELETE SET NULL,
    status varchar(30) NOT NULL,
    latitude numeric(10,7),
    longitude numeric(10,7),
    geom geometry(Point, 4326) GENERATED ALWAYS AS (
        ST_SetSRID(ST_MakePoint(longitude::float8, latitude::float8), 4326)
    ) STORED,
    log_time timestamptz NOT NULL DEFAULT now(),
    description text,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (id, log_time)
) PARTITION BY RANGE (log_time);

-- Partisi default sebagai jaring pengaman jika ada log_time di luar
-- rentang yang sudah dibuat oleh cron bulanan.
CREATE TABLE IF NOT EXISTS vessel.movement_log_default
    PARTITION OF vessel.movement_log DEFAULT;

-- -----------------------------------------------------------------------------
-- SCHEMA: FINANCE
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS finance.exchange_rate (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    currency_from varchar(3) NOT NULL REFERENCES ref.currency(currency_code),
    currency_to varchar(3) REFERENCES ref.currency(currency_code),
    rate_date date NOT NULL,
    rate_type varchar(30) NOT NULL,
    exchange_rate numeric(15,4) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_exchange_rate UNIQUE (currency_from, currency_to, rate_date, rate_type)
);

CREATE TABLE IF NOT EXISTS finance.invoice (
    invoice_number varchar(50) PRIMARY KEY,
    invoice_type varchar(20) NOT NULL,
    invoice_category varchar(20) DEFAULT 'FINAL',
    parent_invoice_number varchar(50) REFERENCES finance.invoice(invoice_number) ON DELETE SET NULL,
    code_buyer varchar(20) REFERENCES buyer.info(code_buyer),
    code_partner varchar(20) REFERENCES partner.info(code_partner),
    po_number varchar(50) REFERENCES operational.purchase_order(po_number) ON DELETE SET NULL,
    do_number varchar(50) REFERENCES operational.delivery_order(do_number) ON DELETE SET NULL,
    issue_date date NOT NULL,
    due_date date NOT NULL,
    currency_code varchar(3) REFERENCES ref.currency(currency_code),
    exchange_rate_id bigint REFERENCES finance.exchange_rate(id) ON DELETE SET NULL,
    subtotal numeric(15,2) DEFAULT 0.00,
    total_amount numeric(15,2) DEFAULT 0.00,
    subtotal_idr numeric(15,2) DEFAULT 0.00,
    total_amount_idr numeric(15,2) DEFAULT 0.00,
    status varchar(20) DEFAULT 'DRAFT',
    description text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz,
    CONSTRAINT chk_invoice_entity CHECK (
        (invoice_type = 'SALES' AND code_buyer IS NOT NULL AND code_partner IS NULL) OR
        (invoice_type = 'PURCHASE' AND code_partner IS NOT NULL AND code_buyer IS NULL)
    ),
    CONSTRAINT chk_invoice_status CHECK (status IN ('DRAFT','ISSUED','PAID','PARTIAL','CANCELLED')),
    CONSTRAINT chk_invoice_category CHECK (invoice_category IN ('FINAL','PROFORMA'))
);

CREATE TABLE IF NOT EXISTS finance.invoice_delivery_order (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    invoice_number varchar(50) REFERENCES finance.invoice(invoice_number) ON DELETE CASCADE,
    do_number varchar(50) REFERENCES operational.delivery_order(do_number) ON DELETE CASCADE,
    allocated_volume numeric(20,6),
    description text,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_invoice_do UNIQUE (invoice_number, do_number)
);

CREATE TABLE IF NOT EXISTS finance.invoice_item (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    invoice_number varchar(50) REFERENCES finance.invoice(invoice_number) ON DELETE CASCADE,
    description varchar(255) NOT NULL,
    quantity numeric(20,6) NOT NULL,
    uom varchar(20) NOT NULL,
    unit_price numeric(15,2) NOT NULL,
    total_price numeric(15,2) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS finance.invoice_tax (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    invoice_number varchar(50) REFERENCES finance.invoice(invoice_number) ON DELETE CASCADE,
    tax_type varchar(30) NOT NULL,
    tax_rate_pct numeric(5,2) NOT NULL,
    tax_amount numeric(15,2) NOT NULL,
    tax_amount_idr numeric(15,2) NOT NULL,
    tax_doc_number varchar(50),
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS finance.payment (
    payment_number varchar(50) PRIMARY KEY,
    invoice_number varchar(50) REFERENCES finance.invoice(invoice_number),
    payment_date timestamptz NOT NULL DEFAULT now(),
    payment_method varchar(30) NOT NULL,
    currency_code varchar(3) REFERENCES ref.currency(currency_code),
    exchange_rate_id bigint REFERENCES finance.exchange_rate(id) ON DELETE SET NULL,
    amount numeric(15,2) NOT NULL,
    amount_idr numeric(15,2) NOT NULL,
    reference_code varchar(100),
    status varchar(20) DEFAULT 'PENDING',
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT chk_payment_status CHECK (status IN ('PENDING','COMPLETED','FAILED'))
);

CREATE TABLE IF NOT EXISTS finance.government_dues (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    do_number varchar(50) REFERENCES operational.delivery_order(do_number) ON DELETE SET NULL,
    tax_type varchar(50) NOT NULL,
    volume_basis numeric(20,6) NOT NULL,
    tariff_rate numeric(15,2) NOT NULL,
    total_amount_idr numeric(15,2) NOT NULL,
    billing_code varchar(50),
    payment_date date,
    status varchar(20) DEFAULT 'UNPAID',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz,
    CONSTRAINT chk_govdues_status CHECK (status IN ('UNPAID','PAID'))
);

-- -----------------------------------------------------------------------------
-- SCHEMA: DOCUMENT
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS document.category (
    code_category varchar(30) PRIMARY KEY,
    description varchar(255) NOT NULL,
    is_active boolean DEFAULT true
);

CREATE TABLE IF NOT EXISTS document.file_registry (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code_category varchar(30) REFERENCES document.category(code_category),
    file_name varchar(255) NOT NULL,
    storage_url text NOT NULL,
    file_hash char(64) NOT NULL,
    storage_provider varchar(50) NOT NULL,
    storage_object_key text NOT NULL,
    version_number integer NOT NULL DEFAULT 1,
    mime_type varchar(50) NOT NULL,
    size_kb numeric(15,3) NOT NULL,
    is_confidential boolean DEFAULT false,
    uploaded_by varchar(20) REFERENCES usr.info(code_user) ON DELETE SET NULL,
    uploaded_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS document.entity_link (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    document_id bigint REFERENCES document.file_registry(id) ON DELETE CASCADE,
    reference_document varchar(100) NOT NULL,
    linked_at timestamptz NOT NULL DEFAULT now()
);

-- -----------------------------------------------------------------------------
-- SCHEMA: ENVIRO
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS enviro.station_info (
    code_station varchar(20) PRIMARY KEY,
    code_site varchar(20) REFERENCES site.info(code_site),
    station_type varchar(50) NOT NULL,
    latitude numeric(10,7) NOT NULL,
    longitude numeric(10,7) NOT NULL,
    battery_level double precision,
    last_maintenance date,
    status varchar(20) DEFAULT 'ACTIVE',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz,
    CONSTRAINT chk_station_status CHECK (status IN ('ACTIVE','INACTIVE','MAINTENANCE'))
);

CREATE TABLE IF NOT EXISTS enviro.station_reading (
    id bigint GENERATED ALWAYS AS IDENTITY,
    code_station varchar(20) REFERENCES enviro.station_info(code_station) ON DELETE CASCADE,
    record_time timestamptz NOT NULL DEFAULT now(),
    salinity double precision,
    turbidity double precision,
    current_speed double precision,
    dissolved_oxygen double precision,
    water_density double precision,
    tide_level double precision,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (id, record_time) 
) PARTITION BY RANGE (record_time);

-- Partisi default sebagai jaring pengaman
CREATE TABLE IF NOT EXISTS enviro.station_reading_default
    PARTITION OF enviro.station_reading DEFAULT;

CREATE TABLE IF NOT EXISTS enviro.incident (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code_site varchar(20) REFERENCES site.info(code_site),
    code_vessel varchar(20) REFERENCES vessel.info(code_vessel) ON DELETE SET NULL,
    reported_by varchar(20) REFERENCES usr.info(code_user) ON DELETE SET NULL,
    incident_time timestamptz NOT NULL,
    incident_type varchar(50) NOT NULL,
    severity varchar(20) NOT NULL,
    description text NOT NULL,
    action_taken text,
    status varchar(20) DEFAULT 'INVESTIGATING',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz,
    CONSTRAINT chk_incident_status CHECK (status IN ('INVESTIGATING','RESOLVED','CLOSED'))
);

-- -----------------------------------------------------------------------------
-- SCHEMA: FORM
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS form.water_sampling (
    no_form varchar(20) PRIMARY KEY,
    type_site varchar(20) NOT NULL,
    sampling_date date NOT NULL,
    type_sample varchar(20) NOT NULL,
    total_sample numeric NOT NULL,
    recorded_by varchar(20) REFERENCES usr.info(code_user) ON DELETE SET NULL,
    received_by varchar(20) REFERENCES usr.info(code_user) ON DELETE SET NULL,
    status varchar(20) DEFAULT 'SUBMITTED',
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT chk_ws_status CHECK (status IN ('SUBMITTED','APPROVED','RECEIVED','REJECTED')),
    CONSTRAINT chk_ws_typ_site CHECK (type_site IN ('CTRL_SITE','ON_SITE','OFF_SITE'))
);

CREATE TABLE IF NOT EXISTS enviro.water_quality (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    no_form varchar(20) REFERENCES form.water_sampling(no_form) ON DELETE CASCADE,
    latitude numeric(10,7) NOT NULL,
    longitude numeric(10,7) NOT NULL,
    depth numeric NOT NULL,
    brightness numeric NOT NULL,
    temperature numeric NOT NULL,
    turbidity numeric NOT NULL,
    dissolved_oxygen numeric NOT NULL,
    ph_level numeric NOT NULL,
    salt numeric NOT NULL,
    condition varchar(250) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS enviro.water_sampling_draft (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    no_form varchar(20) REFERENCES form.water_sampling(no_form) ON DELETE CASCADE,
    latitude numeric(10,7) NOT NULL,
    longitude numeric(10,7) NOT NULL,
    depth numeric NOT NULL,
    brightness numeric NOT NULL,
    temperature numeric NOT NULL,
    turbidity numeric NOT NULL,
    dissolved_oxygen numeric NOT NULL,
    ph_level numeric NOT NULL,
    salt numeric NOT NULL,
    condition varchar(250) NOT NULL,
    status VARCHAR(20) DEFAULT 'PENDING',
    created_by VARCHAR(50),
    created_at timestamptz NOT NULL DEFAULT now(),
    archived_at timestamptz,
    CONSTRAINT chk_wsd_status CHECK (status IN ('PENDING','APPROVED','REJECTED')),
    CONSTRAINT chk_wsd_created_by CHECK (created_by IN (SELECT code_user FROM usr.info))
);

CREATE TABLE IF NOT EXISTS enviro.parameter_threshold (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    parameter_name varchar(50) NOT NULL,
    parameter_value double precision,
    uom varchar(10),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz
);

CREATE TABLE IF NOT EXISTS enviro.weather_log (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code_site varchar(20) REFERENCES site.info(code_site),
    recorded_by varchar(20) REFERENCES usr.info(code_user) ON DELETE SET NULL,
    log_time timestamptz NOT NULL DEFAULT now(),
    weather_condition varchar(50) NOT NULL,
    wind_speed double precision,
    wave_height double precision,
    description text,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS enviro.compliance_report (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    report_type varchar(50) NOT NULL,
    period_start date NOT NULL,
    period_end date NOT NULL,
    code_site varchar(20) REFERENCES site.info(code_site),
    submitted_to varchar(100),
    submission_date date,
    report_url text,
    status varchar(20) DEFAULT 'DRAFT',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz,
    CONSTRAINT chk_compliance_status CHECK (status IN ('DRAFT','SUBMITTED','APPROVED','REJECTED'))
);

CREATE TABLE IF NOT EXISTS form.sampling_worksheet (
    no_form varchar(20) PRIMARY KEY,
    sampling_date date NOT NULL,
    no_package numeric NOT NULL,
    type_sample varchar(20) NOT NULL,
    sample_total numeric NOT NULL,
    survey_by varchar(20) REFERENCES usr.info(code_user) ON DELETE SET NULL,
    code_vessel varchar(20) REFERENCES vessel.info(code_vessel) ON DELETE SET NULL,
    approved_by varchar(20) REFERENCES usr.info(code_user) ON DELETE SET NULL,
    remarks_by varchar(20) REFERENCES usr.info(code_user) ON DELETE SET NULL,
    status varchar(20) DEFAULT 'SUBMITTED',
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT chk_sws_status CHECK (status IN ('SUBMITTED','APPROVED','REJECTED'))
);

CREATE TABLE IF NOT EXISTS form.sampling_worksheet_detail (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    no_form varchar(20) REFERENCES form.sampling_worksheet(no_form) ON DELETE CASCADE,
    no_sample varchar(20) NOT NULL,
    latitude numeric(10,7) NOT NULL,
    longitude numeric(10,7) NOT NULL,
    geom geometry(Point, 4326) GENERATED ALWAYS AS (
        ST_SetSRID(ST_MakePoint(longitude::float8, latitude::float8), 4326)
    ) STORED,
    description varchar(255) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS form.volumetric_calc (
    no_form varchar(20) PRIMARY KEY,
    no_delivery varchar(20) REFERENCES operational.delivery_order(do_number) ON DELETE SET NULL,
    empty_draft numeric(20,6) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS form.volumetric_calc_detail (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    no_form varchar(20) REFERENCES form.volumetric_calc(no_form) ON DELETE CASCADE,
    calc_type varchar(20) NOT NULL,
    volume numeric(20,6) NOT NULL,
    date_measured date NOT NULL,
    recorded_by varchar(20) REFERENCES usr.info(code_user) ON DELETE SET NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT chk_volumetric_calc_type CHECK (calc_type IN ('DRAFT','FINAL'))
);

CREATE TABLE IF NOT EXISTS form.station_inspection (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code_station varchar(20) REFERENCES enviro.station_info(code_station) ON DELETE CASCADE,
    code_user varchar(20) REFERENCES usr.info(code_user) ON DELETE SET NULL,
    inspection_date date NOT NULL,
    inspection_type varchar(20) NOT NULL,
    weather_condition text,
    inspected_by varchar(20) REFERENCES usr.info(code_user) ON DELETE SET NULL,
    reviewed_by varchar(20) REFERENCES usr.info(code_user) ON DELETE SET NULL,
    status varchar(20) DEFAULT 'SUBMITTED',
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT chk_station_inspection_status CHECK (status IN ('SUBMITTED','REVIEWED','REJECTED'))
);

CREATE TABLE IF NOT EXISTS form.station_inspection_details (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_inspection bigint REFERENCES form.station_inspection(id) ON DELETE CASCADE,
    equipment_name varchar(50) NOT NULL,
    equipment_condition text,
    description text,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT chk_equipment_condition CHECK (equipment_condition IN ('OK','NOTE OK', 'N/A'))
);

CREATE TABLE IF NOT EXISTS form.daily_activities (
    no_form varchar(20) PRIMARY KEY,
    code_vessel varchar(20) REFERENCES vessel.info(code_vessel) ON DELETE SET NULL,
    activitie_date date NOT NULL,
    description text NOT NULL,
    recorded_by varchar(20) REFERENCES usr.info(code_user) ON DELETE SET NULL,
    created_at timestamptz DEFAULT now ()
);

CREATE TABLE IF NOT EXISTS form.daily_activities_details (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    no_form varchar(20) REFERENCES form.daily_activities(no_form) ON DELETE CASCADE,
    date_activities date NOT NULL,
    time_activities time NOT NULL,
    latitude numeric(10,7) NOT NULL,
    longitude numeric(10,7) NOT NULL,
    geom geometry(Point, 4326) GENERATED ALWAYS AS (
        ST_SetSRID(ST_MakePoint(longitude::float8, latitude::float8), 4326)
    ) STORED,
    run_hours_in time NOT NULL,
    run_hours_out time NOT NULL,
    description text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS form.daily_activities_weather (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    no_form varchar(20) REFERENCES form.daily_activities(no_form) ON DELETE CASCADE,
    date_weather date NOT NULL,
    time_weather time NOT NULL,
    wind_speed numeric NOT NULL,
    wave_height numeric NOT NULL,
    description text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS form.monitoring_survey (
    no_form varchar(20) PRIMARY KEY,
    survey_date date NOT NULL,
    survey_by varchar(20) REFERENCES usr.info(code_user) ON DELETE SET NULL,
    recorded_by varchar(20) REFERENCES usr.info(code_user) ON DELETE SET NULL,
    reviewed_by varchar(20) REFERENCES usr.info(code_user) ON DELETE SET NULL,
    status varchar(20) DEFAULT 'SUBMITTED',
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT chk_monitoring_survey_status CHECK (status IN ('SUBMITTED','REVIEWED','REJECTED'))
);

CREATE TABLE IF NOT EXISTS form.monitoring_survey_details (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    no_form varchar(20) REFERENCES form.monitoring_survey(no_form) ON DELETE CASCADE,
    latitude numeric(10,7) NOT NULL,
    longitude numeric(10,7) NOT NULL,
    geom geometry(Point, 4326) GENERATED ALWAYS AS (
        ST_SetSRID(ST_MakePoint(longitude::float8, latitude::float8), 4326)
    ) STORED,
    station_id varchar(20) REFERENCES enviro.station_info(code_station) ON DELETE SET NULL,
    depth_d numeric NOT NULL,
    depth_m numeric NOT NULL,
    time_deploy time NOT NULL,
    time_undeploy time NOT NULL,
    description text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);

-- -----------------------------------------------------------------------------
-- SCHEMA: AUDIT
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS audit.activity_log (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    event_id uuid NOT NULL DEFAULT gen_random_uuid(),
    code_user varchar(20) NOT NULL,
    action_type varchar(20) NOT NULL,
    schema_name varchar(50) NOT NULL,
    table_name varchar(50) NOT NULL,
    record_id varchar(50) NOT NULL,
    old_data jsonb,
    new_data jsonb,
    request_id uuid,
    transaction_id bigint,
    ip_address inet,
    user_agent text,
    created_at timestamptz NOT NULL DEFAULT now()
);
COMMENT ON COLUMN audit.activity_log.code_user IS 'Tidak ada FK ke usr.info karena log dapat mencatat aktivitas sistem atau user yang sudah dihapus.';

CREATE TABLE IF NOT EXISTS audit.error_log (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    error_source varchar(50) NOT NULL,
    severity varchar(20) NOT NULL DEFAULT 'ERROR',
    error_code varchar(50),
    error_message text NOT NULL,
    stack_trace text,
    payload_data jsonb,
    request_id uuid,
    correlation_id uuid,
    service_name varchar(100),
    environment varchar(20) DEFAULT 'production',
    resolved_status boolean DEFAULT false,
    resolved_by varchar(20) REFERENCES usr.info(code_user) ON DELETE SET NULL,
    resolved_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT chk_error_log_severity CHECK (severity IN ('DEBUG','INFO','WARNING','ERROR','CRITICAL')),
    CONSTRAINT chk_error_log_environment CHECK (environment IN ('development','staging','production'))
);

CREATE TABLE IF NOT EXISTS audit.login_history (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code_user varchar(20) NOT NULL,
    login_time timestamptz NOT NULL DEFAULT now(),
    ip_address inet,
    user_agent text,
    status varchar(20) NOT NULL,
    failure_reason text,
    CONSTRAINT chk_login_status CHECK (status IN ('SUCCESS','FAILED'))
);

-- -----------------------------------------------------------------------------
-- VIEWS
-- -----------------------------------------------------------------------------

-- View untuk validasi nilai turunan invoice
CREATE OR REPLACE VIEW finance.v_invoice_summary AS
SELECT 
    i.invoice_number,
    COALESCE(i.subtotal, 0) AS stored_subtotal,
    COALESCE(item_sum.total_item, 0) AS calculated_subtotal,
    COALESCE(i.total_amount, 0) AS stored_total,
    COALESCE(item_sum.total_item, 0) + COALESCE(tax_sum.total_tax, 0) AS calculated_total,
    CASE 
        WHEN COALESCE(i.subtotal, 0) = COALESCE(item_sum.total_item, 0)
         AND COALESCE(i.total_amount, 0) = COALESCE(item_sum.total_item, 0) + COALESCE(tax_sum.total_tax, 0)
        THEN 'VALID' ELSE 'MISMATCH' 
    END AS integrity_check
FROM finance.invoice i
LEFT JOIN (
    SELECT invoice_number, SUM(total_price) AS total_item
    FROM finance.invoice_item
    GROUP BY invoice_number
) item_sum ON i.invoice_number = item_sum.invoice_number
LEFT JOIN (
    SELECT invoice_number, SUM(tax_amount) AS total_tax
    FROM finance.invoice_tax
    GROUP BY invoice_number
) tax_sum ON i.invoice_number = tax_sum.invoice_number;

-- View untuk enviro
CREATE OR REPLACE VIEW enviro.v_monitoring_enviro AS
SELECT DISTINCT ON (a.code_station)
    a.code_station,
    a.salinity,
    a.turbidity,
    a.current_speed,
    a.dissolved_oxygen,
    a.water_density,
    a.tide_level
FROM 
    enviro.station_reading a
ORDER BY 
    a.code_station, 
    a.record_time DESC;

-- View untuk Produksi vs Sisa Stok.
CREATE OR REPLACE VIEW operational.v_production_chart AS
WITH daily_delta AS (
    SELECT
        code_site,
        transaction_time::date AS tgl,
        SUM(quantity_delta) AS day_delta,
        SUM(CASE WHEN transaction_type = 'PRODUCTION' THEN quantity ELSE 0 END) AS day_production
    FROM operational.stock_ledger
    GROUP BY code_site, transaction_time::date
)
SELECT
    code_site,
    tgl,
    day_production AS total_produksi,
    SUM(day_delta) OVER (
        PARTITION BY code_site ORDER BY tgl
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS total_deduction
FROM daily_delta
ORDER BY code_site, tgl;

-- View saldo stok terkini per site.
CREATE OR REPLACE VIEW operational.v_stock_balance AS
SELECT
    code_site,
    SUM(quantity_delta) AS current_balance,
    MAX(transaction_time) AS last_transaction_time
FROM operational.stock_ledger
GROUP BY code_site;

-- =============================================================================
-- AUTOMATION FUNCTIONS
-- =============================================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE OR REPLACE FUNCTION fn_audit_activity()
RETURNS TRIGGER 
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

    IF TG_NARGS > 0 THEN
        v_record_id := v_data ->> TG_ARGV[0];
    END IF;

    IF v_record_id IS NULL THEN
        v_record_id := COALESCE(
            v_data->>'id',
            v_data->>'code_user',
            v_data->>'code_vessel',
            v_data->>'code_site',
            v_data->>'code_partner',
            v_data->>'code_buyer',
            v_data->>'po_number',
            v_data->>'do_number',
            v_data->>'invoice_number',
            v_data->>'payment_number',
            v_data->>'no_form',
            v_data->>'code_station',
            v_data->>'code_role',
            v_data->>'code_type'
        );
    END IF;

    IF v_record_id IS NULL THEN
        v_record_id := 'COMPOSITE_KEY_OR_UNKNOWN';
    END IF;

    INSERT INTO audit.activity_log (
        code_user, action_type, schema_name, table_name,
        record_id, old_data, new_data,
        request_id, transaction_id, ip_address, user_agent, created_at
    ) VALUES (
        COALESCE(current_setting('app.current_user', true), 'SYSTEM'),
        TG_OP,
        TG_TABLE_SCHEMA,
        TG_TABLE_NAME,
        v_record_id,
        CASE WHEN TG_OP IN ('UPDATE','DELETE') THEN to_jsonb(OLD) ELSE NULL END,
        CASE WHEN TG_OP IN ('INSERT','UPDATE') THEN to_jsonb(NEW) ELSE NULL END,
        NULLIF(current_setting('app.request_id', true), '')::uuid,
        pg_catalog.txid_current(),
        NULLIF(current_setting('app.client_ip', true), '')::inet,
        NULLIF(current_setting('app.user_agent', true), ''),
        now()
    );
    
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_buyer_deposit_balance()
RETURNS TRIGGER 
SET search_path = '' 
AS $$
DECLARE
    v_balance NUMERIC(15,2);
    v_target_buyer VARCHAR(20); 
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_target_buyer := OLD.code_buyer;
    ELSE
        v_target_buyer := NEW.code_buyer;
    END IF;

    SELECT COALESCE(SUM(CASE WHEN transaction_type = 'CREDIT' THEN amount ELSE -amount END), 0)
    INTO v_balance
    FROM buyer.deposit_ledger
    WHERE code_buyer = v_target_buyer;

    UPDATE buyer.info
    SET deposit_balance = v_balance,
        updated_at = now()
    WHERE code_buyer = v_target_buyer;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION fn_approve_water_sampling()
RETURNS TRIGGER 
SET search_path = ''
AS $$
BEGIN
    IF NEW.status = 'APPROVED' AND OLD.status != 'APPROVED' THEN
        INSERT INTO enviro.water_quality (
            no_form, 
            latitude, 
            longitude, 
            depth, 
            brightness, 
            temperature, 
            turbidity, 
            dissolved_oxygen, 
            ph_level, 
            salt, 
            condition, 
            created_at
        )
        SELECT 
            d.no_form, 
            d.latitude, 
            d.longitude, 
            d.depth, 
            d.brightness, 
            d.temperature, 
            d.turbidity, 
            d.dissolved_oxygen, 
            d.ph_level, 
            d.salt, 
            d.condition, 
            now()
        FROM enviro.water_sampling_draft d
        WHERE d.no_form = NEW.no_form
          AND d.archived_at IS NULL
          AND NOT EXISTS (
              SELECT 1 FROM enviro.water_quality wq WHERE wq.no_form = NEW.no_form
          ); 

        UPDATE enviro.water_sampling_draft
        SET archived_at = now()
        WHERE no_form = NEW.no_form
          AND archived_at IS NULL;

    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION internal.automasi_partisi_bulanan()
RETURNS void 
SECURITY DEFINER 
SET search_path = ''
AS $$
DECLARE
    v_tabel_induk TEXT;
    v_daftar_tabel TEXT[] := ARRAY['vessel.movement_log', 'enviro.station_reading'];
    v_skema TEXT;
    v_nama_tabel TEXT;
    v_nama_partisi TEXT;
    v_waktu_target DATE;
    v_awal_bulan DATE;
    v_akhir_bulan DATE;
BEGIN
    FOR i IN 0..2 LOOP
        v_waktu_target := date_trunc('month', CURRENT_DATE + (i || ' month')::interval)::date;
        v_awal_bulan := v_waktu_target;
        v_akhir_bulan := v_waktu_target + interval '1 month';
        FOREACH v_tabel_induk IN ARRAY v_daftar_tabel LOOP
            v_skema := split_part(v_tabel_induk, '.', 1);
            v_nama_tabel := split_part(v_tabel_induk, '.', 2);
            v_nama_partisi := v_nama_tabel || '_' || to_char(v_waktu_target, 'YYYYMM');
            IF NOT EXISTS (
                SELECT 1
                FROM pg_catalog.pg_class c
                JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
                WHERE n.nspname = v_skema AND c.relname = v_nama_partisi
            ) THEN
                EXECUTE format(
                    'CREATE TABLE %I.%I PARTITION OF %I.%I FOR VALUES FROM (%L) TO (%L);',
                    v_skema, v_nama_partisi, v_skema, v_nama_tabel, v_awal_bulan, v_akhir_bulan
                );
                IF EXISTS (
                    SELECT 1 FROM pg_catalog.pg_class c
                    JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
                    WHERE n.nspname = v_skema AND c.relname = v_nama_tabel || '_default'
                ) THEN
                    EXECUTE format(
                        'WITH moved AS (
                            DELETE FROM %I.%I
                            WHERE %I >= %L AND %I < %L
                            RETURNING *
                        )
                        INSERT INTO %I.%I SELECT * FROM moved;',
                        v_skema, v_nama_tabel || '_default',
                        CASE WHEN v_nama_tabel = 'movement_log' THEN 'log_time' ELSE 'record_time' END,
                        v_awal_bulan,
                        CASE WHEN v_nama_tabel = 'movement_log' THEN 'log_time' ELSE 'record_time' END,
                        v_akhir_bulan,
                        v_skema, v_nama_tabel
                    );
                END IF;
            END IF;
        END LOOP;
    END LOOP;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION operational.post_production_to_ledger()
RETURNS TRIGGER
SET search_path = ''
AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        DELETE FROM operational.stock_ledger
        WHERE reference_type = 'daily_production'
          AND reference_id = OLD.id::text;
        RETURN OLD;
    END IF;

    IF TG_OP = 'INSERT' THEN
        INSERT INTO operational.stock_ledger (
            code_site, transaction_time, transaction_type,
            reference_type, reference_id, quantity, direction,
            created_by, remarks
        ) VALUES (
            NEW.code_site, NEW.production_date::timestamptz, 'PRODUCTION',
            'daily_production', NEW.id::text, NEW.volume_mined, -1,
            NEW.reported_by, 'Auto-posted from operational.daily_production'
        );
        RETURN NEW;
    END IF;

    UPDATE operational.stock_ledger
    SET code_site = NEW.code_site,
        transaction_time = NEW.production_date::timestamptz,
        quantity = NEW.volume_mined,
        created_by = NEW.reported_by
    WHERE reference_type = 'daily_production'
      AND reference_id = NEW.id::text;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- TRIGGERS, INDEXES, & CONSTRAINTS
-- =============================================================================

-- A. AUTOMATION TRIGGERS
DROP TRIGGER IF EXISTS trg_update_usr_info ON usr.info;
CREATE TRIGGER trg_update_usr_info BEFORE UPDATE ON usr.info FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();

DROP TRIGGER IF EXISTS trg_update_vessel_info ON vessel.info;
CREATE TRIGGER trg_update_vessel_info BEFORE UPDATE ON vessel.info FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();

DROP TRIGGER IF EXISTS trg_update_po ON operational.purchase_order;
CREATE TRIGGER trg_update_po BEFORE UPDATE ON operational.purchase_order FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();

DROP TRIGGER IF EXISTS trg_update_do ON operational.delivery_order;
CREATE TRIGGER trg_update_do BEFORE UPDATE ON operational.delivery_order FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();

DROP TRIGGER IF EXISTS trg_update_invoice ON finance.invoice;
CREATE TRIGGER trg_update_invoice BEFORE UPDATE ON finance.invoice FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();

DROP TRIGGER IF EXISTS trg_update_deposit_ledger ON buyer.deposit_ledger;
CREATE TRIGGER trg_update_deposit_ledger BEFORE UPDATE ON buyer.deposit_ledger FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();

-- B. TRIGGER UNTUK AUDIT OTOMATIS
DROP TRIGGER IF EXISTS trg_audit_usr_info ON usr.info;
CREATE TRIGGER trg_audit_usr_info AFTER INSERT OR UPDATE OR DELETE ON usr.info FOR EACH ROW EXECUTE PROCEDURE fn_audit_activity();

DROP TRIGGER IF EXISTS trg_audit_vessel_info ON vessel.info;
CREATE TRIGGER trg_audit_vessel_info AFTER INSERT OR UPDATE OR DELETE ON vessel.info FOR EACH ROW EXECUTE PROCEDURE fn_audit_activity();

DROP TRIGGER IF EXISTS trg_audit_po ON operational.purchase_order;
CREATE TRIGGER trg_audit_po AFTER INSERT OR UPDATE OR DELETE ON operational.purchase_order FOR EACH ROW EXECUTE PROCEDURE fn_audit_activity();

DROP TRIGGER IF EXISTS trg_audit_do ON operational.delivery_order;
CREATE TRIGGER trg_audit_do AFTER INSERT OR UPDATE OR DELETE ON operational.delivery_order FOR EACH ROW EXECUTE PROCEDURE fn_audit_activity();

DROP TRIGGER IF EXISTS trg_audit_invoice ON finance.invoice;
CREATE TRIGGER trg_audit_invoice AFTER INSERT OR UPDATE OR DELETE ON finance.invoice FOR EACH ROW EXECUTE PROCEDURE fn_audit_activity();

DROP TRIGGER IF EXISTS trg_audit_payment ON finance.payment;
CREATE TRIGGER trg_audit_payment AFTER INSERT OR UPDATE OR DELETE ON finance.payment FOR EACH ROW EXECUTE PROCEDURE fn_audit_activity();

DROP TRIGGER IF EXISTS trg_post_production_to_ledger ON operational.daily_production;
CREATE TRIGGER trg_post_production_to_ledger
AFTER INSERT OR UPDATE OR DELETE ON operational.daily_production
FOR EACH ROW
EXECUTE FUNCTION operational.post_production_to_ledger();

-- C. TRIGGER UNTUK SALDO DEPOSIT BUYER
DROP TRIGGER IF EXISTS trg_update_deposit_balance ON buyer.deposit_ledger;
CREATE TRIGGER trg_update_deposit_balance
AFTER INSERT OR UPDATE OR DELETE ON buyer.deposit_ledger
FOR EACH ROW EXECUTE PROCEDURE update_buyer_deposit_balance();

DROP TRIGGER IF EXISTS trg_approve_water ON enviro.water_sampling_draft;
CREATE TRIGGER trg_approve_water
AFTER UPDATE ON enviro.water_sampling_draft
FOR EACH ROW EXECUTE PROCEDURE fn_approve_water_sampling();

-- D. PERFORMANCE INDEXES
CREATE INDEX IF NOT EXISTS idx_audit_activity_user ON audit.activity_log (code_user);
CREATE INDEX IF NOT EXISTS idx_audit_activity_table ON audit.activity_log (table_name, record_id);
CREATE INDEX IF NOT EXISTS idx_audit_activity_time ON audit.activity_log (created_at);
CREATE INDEX IF NOT EXISTS idx_op_do_po ON operational.delivery_order (po_number);
CREATE INDEX IF NOT EXISTS idx_op_do_vessel ON operational.delivery_order (code_vessel_main);
CREATE INDEX IF NOT EXISTS idx_op_survey_do ON operational.cargo_survey (do_number);
CREATE INDEX IF NOT EXISTS idx_op_bl_do ON operational.bill_of_lading (do_number);
CREATE INDEX IF NOT EXISTS idx_fin_inv_buyer ON finance.invoice (code_buyer);
CREATE INDEX IF NOT EXISTS idx_fin_inv_partner ON finance.invoice (code_partner);
CREATE INDEX IF NOT EXISTS idx_fin_inv_do ON finance.invoice (do_number);
CREATE INDEX IF NOT EXISTS idx_fin_inv_del_do ON finance.invoice_delivery_order (do_number);
CREATE INDEX IF NOT EXISTS idx_fin_inv_del_inv ON finance.invoice_delivery_order (invoice_number);
CREATE INDEX IF NOT EXISTS idx_fin_inv_item_inv ON finance.invoice_item (invoice_number);
CREATE INDEX IF NOT EXISTS idx_fin_inv_tax_inv ON finance.invoice_tax (invoice_number);
CREATE INDEX IF NOT EXISTS idx_fin_payment_invoice ON finance.payment (invoice_number);
CREATE INDEX IF NOT EXISTS idx_fin_payment_date ON finance.payment (payment_date);
CREATE INDEX IF NOT EXISTS idx_env_station_reading_time ON enviro.station_reading (record_time);
CREATE INDEX IF NOT EXISTS idx_doc_link_ref ON document.entity_link (reference_document);
CREATE INDEX IF NOT EXISTS idx_vessel_movement_time ON vessel.movement_log (code_vessel, log_time);
CREATE INDEX IF NOT EXISTS idx_vessel_movement_geom ON vessel.movement_log USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_form_sw_detail_geom ON form.sampling_worksheet_detail USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_form_dailyact_det_geom ON form.daily_activities_details USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_form_monsurv_det_geom ON form.monitoring_survey_details USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_env_weather_time ON enviro.weather_log (code_site, log_time);
CREATE INDEX IF NOT EXISTS idx_daily_prod_site ON operational.daily_production (code_site);
CREATE INDEX IF NOT EXISTS idx_stock_ledger_site_time ON operational.stock_ledger (code_site, transaction_time);
CREATE INDEX IF NOT EXISTS idx_stock_ledger_reference ON operational.stock_ledger (reference_type, reference_id);
CREATE INDEX IF NOT EXISTS idx_daily_prod_vessel ON operational.daily_production (code_vessel);
CREATE INDEX IF NOT EXISTS idx_gov_dues_do ON finance.government_dues (do_number);
CREATE INDEX IF NOT EXISTS idx_op_sofp_do ON operational.statement_of_fact (do_number);
CREATE INDEX IF NOT EXISTS idx_movement_log_do ON vessel.movement_log (do_number);
CREATE INDEX IF NOT EXISTS idx_approval_ref ON operational.approval_log (ref_table, ref_id);
CREATE INDEX IF NOT EXISTS idx_notification_log_time ON param.notification_log (sent_at);
CREATE INDEX IF NOT EXISTS idx_buyer_deposit_ledger ON buyer.deposit_ledger (code_buyer);
CREATE INDEX IF NOT EXISTS idx_env_incident_status ON enviro.incident (status, severity);
CREATE INDEX IF NOT EXISTS idx_form_sw_detail_no ON form.sampling_worksheet_detail (no_form);
CREATE INDEX IF NOT EXISTS idx_form_volcalc_detail_no ON form.volumetric_calc_detail (no_form);
CREATE INDEX IF NOT EXISTS idx_form_insp_detail_id ON form.station_inspection_details (id_inspection);
CREATE INDEX IF NOT EXISTS idx_form_dailyact_detail_no ON form.daily_activities_details (no_form);
CREATE INDEX IF NOT EXISTS idx_form_dailyact_wea_no ON form.daily_activities_weather (no_form);
CREATE INDEX IF NOT EXISTS idx_form_monsurv_detail_no ON form.monitoring_survey_details (no_form);
CREATE INDEX IF NOT EXISTS idx_form_volcalc_do ON form.volumetric_calc (no_delivery);
CREATE INDEX IF NOT EXISTS idx_form_insp_station ON form.station_inspection (code_station);
CREATE INDEX IF NOT EXISTS idx_form_monsurv_det_station ON form.monitoring_survey_details (station_id); 
CREATE INDEX IF NOT EXISTS idx_form_dailyact_vessel ON form.daily_activities (code_vessel);
CREATE INDEX IF NOT EXISTS idx_form_sw_status_date ON form.sampling_worksheet (status, sampling_date);
CREATE INDEX IF NOT EXISTS idx_form_ws_status_date ON form.water_sampling (status, sampling_date);
CREATE INDEX IF NOT EXISTS idx_form_insp_status_date ON form.station_inspection (status, inspection_date);
CREATE INDEX IF NOT EXISTS idx_form_monsurv_status_date ON form.monitoring_survey (status, survey_date);
CREATE INDEX IF NOT EXISTS idx_form_dailyact_date ON form.daily_activities (activitie_date);

-- E. CHECK CONSTRAINTS
DO $$
BEGIN
    ALTER TABLE vessel.maintenance ADD CONSTRAINT chk_mt_status CHECK (status IN ('SCHEDULED','IN PROGRESS','COMPLETED','CANCELLED'));
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    ALTER TABLE vessel.crew_history ADD CONSTRAINT chk_crew_status CHECK (status IN ('ON_BOARD','SIGNED_OFF'));
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

-- F. GEOGRAPHIC COORDINATE VALIDATION
DO $$
DECLARE
    v_targets text[][] := ARRAY[
        ARRAY['site.info', 'chk_site_info_coords'],
        ARRAY['buyer.discharge_location', 'chk_discharge_location_coords'],
        ARRAY['vessel.movement_log', 'chk_movement_log_coords'],
        ARRAY['enviro.station_info', 'chk_station_info_coords'],
        ARRAY['form.sampling_worksheet_detail', 'chk_sw_detail_coords'],
        ARRAY['form.daily_activities_details', 'chk_dailyact_detail_coords'],
        ARRAY['form.monitoring_survey_details', 'chk_monsurv_detail_coords'],
        ARRAY['enviro.water_quality', 'chk_water_quality_coords'],
        ARRAY['enviro.water_sampling_draft', 'chk_water_sampling_draft_coords']
    ];
    v_row text[];
BEGIN
    FOREACH v_row SLICE 1 IN ARRAY v_targets LOOP
        IF NOT EXISTS (
            SELECT 1 FROM pg_constraint WHERE conname = v_row[2]
        ) THEN
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

-- G. BASIC DATA-QUALITY CONSTRAINTS
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_station_battery_level') THEN
        ALTER TABLE enviro.station_info ADD CONSTRAINT chk_station_battery_level
            CHECK (battery_level IS NULL OR battery_level BETWEEN 0 AND 100);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_station_reading_nonneg') THEN
        ALTER TABLE enviro.station_reading ADD CONSTRAINT chk_station_reading_nonneg
            CHECK (
                (salinity IS NULL OR salinity >= 0) AND
                (turbidity IS NULL OR turbidity >= 0) AND
                (current_speed IS NULL OR current_speed >= 0) AND
                (dissolved_oxygen IS NULL OR dissolved_oxygen >= 0) AND
                (water_density IS NULL OR water_density >= 0)
            );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_weather_log_nonneg') THEN
        ALTER TABLE enviro.weather_log ADD CONSTRAINT chk_weather_log_nonneg
            CHECK (
                (wind_speed IS NULL OR wind_speed >= 0) AND
                (wave_height IS NULL OR wave_height >= 0)
            );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_water_quality_nonneg') THEN
        ALTER TABLE enviro.water_quality ADD CONSTRAINT chk_water_quality_nonneg
            CHECK (turbidity >= 0 AND dissolved_oxygen >= 0 AND depth >= 0);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_daily_production_nonneg') THEN
        ALTER TABLE operational.daily_production ADD CONSTRAINT chk_daily_production_nonneg
            CHECK (volume_mined >= 0 AND operating_hours >= 0);
    END IF;
END $$;

-- H. SEED DATA
INSERT INTO param.uom (code_uom, name, description)
VALUES ('M3', 'Cubic Meter', 'Volume dalam meter kubik')
ON CONFLICT (code_uom) DO NOTHING;

-- Cabut hak akses dari pihak luar
REVOKE EXECUTE ON FUNCTION internal.automasi_partisi_bulanan() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION internal.automasi_partisi_bulanan() FROM anon;
REVOKE EXECUTE ON FUNCTION internal.automasi_partisi_bulanan() FROM authenticated;

-- Berikan kunci eksekusi kepada mesin Supabase
GRANT EXECUTE ON FUNCTION internal.automasi_partisi_bulanan() TO postgres, service_role;
GRANT SELECT ON operational.v_production_chart TO anon, authenticated, service_role;
GRANT SELECT ON operational.v_stock_balance TO anon, authenticated, service_role;

-- =============================================================================
-- ROLES, PRIVILEGE SEPARATION & AUDIT IMMUTABILITY
-- =============================================================================
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_admin') THEN
        CREATE ROLE app_admin NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_service') THEN
        CREATE ROLE app_service NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_readonly') THEN
        CREATE ROLE app_readonly NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'audit_reader') THEN
        CREATE ROLE audit_reader NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'reporting_reader') THEN
        CREATE ROLE reporting_reader NOLOGIN;
    END IF;
END $$;

-- Privilege separation
GRANT USAGE ON SCHEMA usr, site, vessel, partner, buyer, operational, enviro,
                      finance, document, form, param, ref, integration
    TO app_service;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA
    usr, site, vessel, partner, buyer, operational, enviro, finance,
    document, form, param, ref, integration
    TO app_service;

-- app_readonly / reporting_reader
GRANT USAGE ON SCHEMA usr, site, vessel, partner, buyer, operational, enviro,
                      finance, document, form, param, ref, reporting
    TO app_readonly, reporting_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA
    usr, site, vessel, partner, buyer, operational, enviro, finance,
    document, form, param, ref, reporting
    TO app_readonly, reporting_reader;

-- audit_reader
GRANT USAGE ON SCHEMA audit TO audit_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA audit TO audit_reader;

-- app_admin
GRANT app_service TO app_admin;
GRANT EXECUTE ON FUNCTION internal.automasi_partisi_bulanan() TO app_admin;

-- AUDIT IMMUTABILITY: audit tables are append-only
REVOKE UPDATE, DELETE ON audit.activity_log, audit.error_log, audit.login_history
    FROM app_service, app_readonly, audit_reader, reporting_reader, anon, authenticated;

-- -----------------------------------------------------------------------------
-- ROW LEVEL SECURITY
-- -----------------------------------------------------------------------------
ALTER TABLE finance.invoice ENABLE ROW LEVEL SECURITY;
ALTER TABLE finance.payment ENABLE ROW LEVEL SECURITY;
ALTER TABLE buyer.info ENABLE ROW LEVEL SECURITY;
ALTER TABLE usr.info ENABLE ROW LEVEL SECURITY;
ALTER TABLE document.file_registry ENABLE ROW LEVEL SECURITY;

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
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='buyer' AND tablename='info' AND policyname='buyer_info_read_authenticated') THEN
        CREATE POLICY buyer_info_read_authenticated ON buyer.info
            FOR SELECT TO authenticated USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='usr' AND tablename='info' AND policyname='usr_info_self_read') THEN
        CREATE POLICY usr_info_self_read ON usr.info
            FOR SELECT TO authenticated USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='document' AND tablename='file_registry' AND policyname='file_registry_read_nonconfidential') THEN
        CREATE POLICY file_registry_read_nonconfidential ON document.file_registry
            FOR SELECT TO authenticated USING (is_confidential = false);
    END IF;
END $$;

-- -----------------------------------------------------------------------------
-- CRON JOB
-- -----------------------------------------------------------------------------
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'otomasi_partisi_bulanan') THEN
        PERFORM cron.unschedule(jobid) FROM cron.job WHERE jobname = 'otomasi_partisi_bulanan';
    END IF;
END $$;

SELECT cron.schedule(
    'otomasi_partisi_bulanan',
    '0 0 25 * *',
    $$ SELECT internal.automasi_partisi_bulanan(); $$
);