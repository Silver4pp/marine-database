-- =============================================================================
-- DATABASE SKEMA PASIR LAUT - FINAL VERSION
-- Mencakup semua rekomendasi data architect
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. CREATING SCHEMAS (tanpa reserved keyword)
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

-- -----------------------------------------------------------------------------
-- 2. AUTOMATION FUNCTION
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE OR REPLACE FUNCTION fn_audit_activity()
RETURNS TRIGGER AS $$
DECLARE
    v_record_id TEXT;
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_record_id := OLD.id::TEXT;
    ELSE
        v_record_id := NEW.id::TEXT;
    END IF;

    INSERT INTO audit.activity_log (
        code_user, action_type, schema_name, table_name,
        record_id, old_data, new_data, ip_address, created_at
    ) VALUES (
        COALESCE(current_setting('app.current_user', true), 'SYSTEM'),
        TG_OP,
        TG_TABLE_SCHEMA,
        TG_TABLE_NAME,
        v_record_id,
        CASE WHEN TG_OP IN ('UPDATE','DELETE') THEN to_jsonb(OLD) ELSE NULL END,
        CASE WHEN TG_OP IN ('INSERT','UPDATE') THEN to_jsonb(NEW) ELSE NULL END,
        NULL,
        NOW()
    );
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_buyer_deposit_balance()
RETURNS TRIGGER AS $$
DECLARE
    v_balance NUMERIC(15,2);
BEGIN
    SELECT COALESCE(SUM(CASE WHEN transaction_type = 'CREDIT' THEN amount ELSE -amount END), 0)
    INTO v_balance
    FROM buyer.deposit_ledger
    WHERE code_buyer = COALESCE(NEW.code_buyer, OLD.code_buyer);

    UPDATE buyer.info
    SET deposit_balance = v_balance,
        updated_at = NOW()
    WHERE code_buyer = COALESCE(NEW.code_buyer, OLD.code_buyer);

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- -----------------------------------------------------------------------------
-- 3. SCHEMA: PARAM
-- -----------------------------------------------------------------------------
CREATE TABLE param.system_config (
    code_config varchar(50) PRIMARY KEY,
    config_value text NOT NULL,
    description text,
    is_secure boolean DEFAULT false,
    updated_by varchar(20),
    updated_at timestamp DEFAULT now()
);

CREATE TABLE param.dropdown_list (
    id serial PRIMARY KEY,
    category varchar(50) NOT NULL,
    code_value varchar(50) NOT NULL,
    display_label varchar(100) NOT NULL,
    sort_order integer DEFAULT 0,
    is_active boolean DEFAULT true,
    CONSTRAINT uq_dropdown UNIQUE (category, code_value)
);

CREATE TABLE param.notification_template (
    code_template varchar(50) PRIMARY KEY,
    platform varchar(20) NOT NULL,
    message_body text NOT NULL,
    is_active boolean DEFAULT true,
    updated_at timestamp DEFAULT now()
);

CREATE TABLE param.notification_log (
    id serial PRIMARY KEY,
    code_template varchar(50) REFERENCES param.notification_template(code_template),
    recipient varchar(100) NOT NULL,
    sent_at timestamp DEFAULT now(),
    status varchar(20) DEFAULT 'SENT',
    error_message text,
    created_at timestamp DEFAULT now()
);

CREATE TABLE param.abbreviation (
    code_abbr varchar(50) PRIMARY KEY,
    full_name varchar(255) NOT NULL,
    category varchar(50),
    description text,
    is_active boolean DEFAULT true,
    created_at timestamp DEFAULT now(),
    updated_at timestamp
);

CREATE TABLE param.uom (
    code_uom varchar(10) PRIMARY KEY,
    name varchar(50) NOT NULL,
    description text,
    is_active boolean DEFAULT true
);

INSERT INTO param.uom (code_uom, name) VALUES
    ('M3', 'Meter Kubik'),
    ('MT', 'Metrik Ton'),
    ('LTR', 'Liter'),
    ('KG', 'Kilogram')
ON CONFLICT (code_uom) DO NOTHING;

CREATE TABLE param.commodity (
    code_commodity varchar(20) PRIMARY KEY,
    name varchar(100) NOT NULL,
    default_uom varchar(10) REFERENCES param.uom(code_uom),
    description text,
    is_active boolean DEFAULT true
);

INSERT INTO param.commodity (code_commodity, name, default_uom) VALUES
    ('SEA_SAND', 'Pasir Laut', 'M3'),
    ('GRAVEL', 'Kerikil', 'M3')
ON CONFLICT (code_commodity) DO NOTHING;

CREATE TABLE param.organization (
    code_org varchar(20) PRIMARY KEY,
    name varchar(100) NOT NULL,
    is_active boolean DEFAULT true,
    created_at timestamp DEFAULT now(),
    updated_at timestamp
);

-- -----------------------------------------------------------------------------
-- 4. SCHEMA: USR (sebelumnya "user")
-- -----------------------------------------------------------------------------
CREATE TABLE usr.role (
    code_role varchar(20) PRIMARY KEY,
    description text,
    is_active boolean DEFAULT true,
    created_at timestamp DEFAULT now(),
    updated_at timestamp
);

CREATE TABLE usr.permission (
    code_permission varchar(50) PRIMARY KEY,
    module varchar(50) NOT NULL,
    created_at timestamp DEFAULT now()
);

CREATE TABLE usr.role_permission (
    code_role varchar(20) REFERENCES usr.role(code_role) ON DELETE CASCADE,
    code_permission varchar(50) REFERENCES usr.permission(code_permission) ON DELETE CASCADE,
    created_at timestamp DEFAULT now(),
    PRIMARY KEY (code_role, code_permission)
);

CREATE TABLE usr.info (
    code_user varchar(20) PRIMARY KEY,
    password_hash varchar(255) NOT NULL,
    name varchar(100) NOT NULL,
    citizen varchar(20) NOT NULL,
    role varchar(20) REFERENCES usr.role(code_role),
    organization varchar(20) REFERENCES param.organization(code_org),
    is_active boolean DEFAULT true,
    last_login timestamp,
    created_at timestamp DEFAULT now(),
    updated_at timestamp,
    deleted_at timestamp
);

CREATE TABLE usr.contact (
    id serial PRIMARY KEY,
    code_user varchar(20) REFERENCES usr.info(code_user) ON DELETE CASCADE,
    contact_type varchar(30) NOT NULL,
    contact_value varchar(100) NOT NULL,
    is_primary boolean DEFAULT false,
    created_at timestamp DEFAULT now(),
    updated_at timestamp
);

-- -----------------------------------------------------------------------------
-- 5. SCHEMA: SITE
-- -----------------------------------------------------------------------------
CREATE TABLE site.type (
    code_type varchar(20) PRIMARY KEY,
    description text,
    is_active boolean DEFAULT true,
    created_at timestamp DEFAULT now()
);

CREATE TABLE site.info (
    code_site varchar(20) PRIMARY KEY,
    code_type varchar(20) REFERENCES site.type(code_type),
    name varchar(100) NOT NULL,
    address text,
    city varchar(100),
    latitude double precision NOT NULL,
    longitude double precision NOT NULL,
    is_active boolean DEFAULT true,
    created_at timestamp DEFAULT now(),
    updated_at timestamp
);

CREATE TABLE site.roster (
    id serial PRIMARY KEY,
    code_site varchar(20) REFERENCES site.info(code_site) ON DELETE CASCADE,
    code_user varchar(20) REFERENCES usr.info(code_user) ON DELETE CASCADE,
    work_date date NOT NULL,
    is_pic boolean DEFAULT false,
    shift varchar(20) NOT NULL,
    status varchar(20) DEFAULT 'SCHEDULED',
    created_at timestamp DEFAULT now(),
    updated_at timestamp,
    CONSTRAINT roster_prevent_double_booking UNIQUE (code_user, work_date, shift)
);

-- -----------------------------------------------------------------------------
-- 6. SCHEMA: PARTNER
-- -----------------------------------------------------------------------------
CREATE TABLE partner.type (
    code_type varchar(20) PRIMARY KEY,
    description text,
    is_active boolean DEFAULT true,
    created_at timestamp DEFAULT now()
);

CREATE TABLE partner.info (
    code_partner varchar(20) PRIMARY KEY,
    code_type varchar(20) REFERENCES partner.type(code_type),
    name varchar(100) NOT NULL,
    address text,
    city varchar(50),
    country varchar(50),
    is_active boolean DEFAULT true,
    created_at timestamp DEFAULT now(),
    updated_at timestamp
);

CREATE TABLE partner.contact (
    id serial PRIMARY KEY,
    code_partner varchar(20) REFERENCES partner.info(code_partner) ON DELETE CASCADE,
    pic_name varchar(100),
    contact_type varchar(30) NOT NULL,
    contact_value varchar(100) NOT NULL,
    is_primary boolean DEFAULT false,
    created_at timestamp DEFAULT now(),
    updated_at timestamp
);

-- -----------------------------------------------------------------------------
-- 7. SCHEMA: VESSEL
-- -----------------------------------------------------------------------------
CREATE TABLE vessel.type (
    code_type varchar(20) PRIMARY KEY,
    description text,
    is_active boolean DEFAULT true,
    created_at timestamp DEFAULT now()
);

CREATE TABLE vessel.info (
    code_vessel varchar(20) PRIMARY KEY,
    code_partner varchar(20) REFERENCES partner.info(code_partner),
    code_type varchar(20) REFERENCES vessel.type(code_type),
    name varchar(100) NOT NULL,
    imo_number varchar(20) UNIQUE,
    call_sign varchar(20) UNIQUE,
    flag varchar(50) DEFAULT 'Indonesia',
    grt double precision,
    dwt double precision,
    is_active boolean DEFAULT true,
    created_at timestamp DEFAULT now(),
    updated_at timestamp
);

CREATE TABLE vessel.site_assignment (
    id serial PRIMARY KEY,
    code_vessel varchar(20) REFERENCES vessel.info(code_vessel) ON DELETE CASCADE,
    code_site varchar(20) REFERENCES site.info(code_site),
    start_date date NOT NULL,
    end_date date,
    created_at timestamp DEFAULT now(),
    updated_at timestamp,
    CONSTRAINT chk_site_assignment_dates CHECK (end_date IS NULL OR end_date >= start_date)
);

CREATE TABLE vessel.certificate (
    id serial PRIMARY KEY,
    code_vessel varchar(20) REFERENCES vessel.info(code_vessel) ON DELETE CASCADE,
    name varchar(100) NOT NULL,
    issuer varchar(100) NOT NULL,
    issued_date date NOT NULL,
    expiry_date date NOT NULL,
    is_active boolean DEFAULT true,
    created_at timestamp DEFAULT now(),
    updated_at timestamp
);

CREATE TABLE vessel.crew_history (
    id serial PRIMARY KEY,
    code_vessel varchar(20) REFERENCES vessel.info(code_vessel) ON DELETE CASCADE,
    code_user varchar(20) REFERENCES usr.info(code_user) ON DELETE CASCADE,
    position varchar(50) NOT NULL,
    sign_on_date date NOT NULL,
    sign_off_date date,
    status varchar(20) DEFAULT 'ON_BOARD',
    created_at timestamp DEFAULT now(),
    updated_at timestamp
);

CREATE TABLE vessel.maintenance (
    id serial PRIMARY KEY,
    code_vessel varchar(20) REFERENCES vessel.info(code_vessel) ON DELETE CASCADE,
    code_partner varchar(20) REFERENCES partner.info(code_partner) ON DELETE SET NULL,
    description text NOT NULL,
    start_date date NOT NULL,
    end_date date,
    status varchar(20) DEFAULT 'SCHEDULED',
    created_at timestamp DEFAULT now(),
    updated_at timestamp
);

CREATE TABLE vessel.movement_log (
    id serial PRIMARY KEY,
    code_vessel varchar(20) REFERENCES vessel.info(code_vessel) ON DELETE CASCADE,
    code_site varchar(20) REFERENCES site.info(code_site) ON DELETE SET NULL,
    do_number varchar(50) REFERENCES operational.delivery_order(do_number) ON DELETE SET NULL,
    status varchar(30) NOT NULL,
    latitude double precision,
    longitude double precision,
    log_time timestamp DEFAULT now(),
    notes text,
    created_at timestamp DEFAULT now()
) PARTITION BY RANGE (log_time);

-- Partisi contoh (Jan - Feb 2026)
CREATE TABLE vessel.movement_log_202601 PARTITION OF vessel.movement_log
    FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');
CREATE TABLE vessel.movement_log_202602 PARTITION OF vessel.movement_log
    FOR VALUES FROM ('2026-02-01') TO ('2026-03-01');

-- -----------------------------------------------------------------------------
-- 8. SCHEMA: BUYER
-- -----------------------------------------------------------------------------
CREATE TABLE buyer.type (
    code_type varchar(20) PRIMARY KEY,
    description text,
    is_active boolean DEFAULT true,
    created_at timestamp DEFAULT now()
);

CREATE TABLE buyer.info (
    code_buyer varchar(20) PRIMARY KEY,
    code_type varchar(20) REFERENCES buyer.type(code_type),
    name varchar(100) NOT NULL,
    address text,
    city varchar(50),
    country varchar(50) DEFAULT 'Indonesia',
    deposit_balance numeric(15,2) DEFAULT 0.00,
    is_active boolean DEFAULT true,
    created_at timestamp DEFAULT now(),
    updated_at timestamp
);

CREATE TABLE buyer.discharge_location (
    id serial PRIMARY KEY,
    code_buyer varchar(20) REFERENCES buyer.info(code_buyer) ON DELETE CASCADE,
    name varchar(100) NOT NULL,
    latitude double precision NOT NULL,
    longitude double precision NOT NULL,
    is_active boolean DEFAULT true,
    created_at timestamp DEFAULT now(),
    updated_at timestamp
);

CREATE TABLE buyer.deposit_ledger (
    id serial PRIMARY KEY,
    code_buyer varchar(20) REFERENCES buyer.info(code_buyer) ON DELETE CASCADE,
    transaction_date timestamp DEFAULT now(),
    transaction_type varchar(30) NOT NULL,
    amount numeric(15,2) NOT NULL,
    reference_doc varchar(50),
    notes text,
    created_by varchar(20) REFERENCES usr.info(code_user),
    created_at timestamp DEFAULT now(),
    updated_at timestamp
);

-- -----------------------------------------------------------------------------
-- 9. SCHEMA: OPERATIONAL
-- -----------------------------------------------------------------------------
CREATE TABLE operational.purchase_order (
    po_number varchar(50) PRIMARY KEY,
    public_id UUID DEFAULT gen_random_uuid() UNIQUE NOT NULL,
    code_buyer varchar(20) REFERENCES buyer.info(code_buyer),
    po_date date NOT NULL,
    target_completion_date date,
    code_commodity varchar(20) REFERENCES param.commodity(code_commodity) DEFAULT 'SEA_SAND',
    uom varchar(10) REFERENCES param.uom(code_uom) DEFAULT 'M3',
    total_volume double precision NOT NULL,
    unit_price numeric(15,2) NOT NULL,
    total_amount numeric(15,2) NOT NULL,
    status varchar(20) DEFAULT 'DRAFT',
    notes text,
    created_at timestamp DEFAULT now(),
    updated_at timestamp,
    CONSTRAINT chk_po_status CHECK (status IN ('DRAFT','SUBMITTED','APPROVED','IN PROGRESS','COMPLETED','CANCELLED'))
);

CREATE TABLE operational.approval_log (
    id serial PRIMARY KEY,
    ref_table varchar(50) NOT NULL,
    ref_id varchar(50) NOT NULL,
    action varchar(20) NOT NULL,
    approved_by varchar(20) REFERENCES usr.info(code_user),
    approved_at timestamp DEFAULT now(),
    remarks text,
    created_at timestamp DEFAULT now()
);

CREATE TABLE operational.daily_production (
    id serial PRIMARY KEY,
    code_site varchar(20) REFERENCES site.info(code_site),
    code_vessel varchar(20) REFERENCES vessel.info(code_vessel),
    production_date date NOT NULL,
    volume_mined double precision NOT NULL,
    operating_hours double precision NOT NULL,
    reported_by varchar(20) REFERENCES usr.info(code_user) ON DELETE SET NULL,
    created_at timestamp DEFAULT now(),
    CONSTRAINT uq_daily_production UNIQUE (code_vessel, production_date)
);

CREATE TABLE operational.delivery_order (
    do_number varchar(50) PRIMARY KEY,
    public_id UUID DEFAULT gen_random_uuid() UNIQUE NOT NULL,
    po_number varchar(50) REFERENCES operational.purchase_order(po_number),
    code_vessel_main varchar(20) REFERENCES vessel.info(code_vessel),
    code_vessel_assist varchar(20) REFERENCES vessel.info(code_vessel) ON DELETE SET NULL,
    loading_site varchar(20) REFERENCES site.info(code_site),
    discharge_location_id integer REFERENCES buyer.discharge_location(id),
    target_volume double precision NOT NULL,
    status varchar(20) DEFAULT 'ISSUED',
    created_at timestamp DEFAULT now(),
    updated_at timestamp,
    CONSTRAINT chk_do_status CHECK (status IN ('ISSUED','LOADING','SAILING','DELIVERED','CANCELLED'))
);

CREATE TABLE operational.cargo_survey (
    id serial PRIMARY KEY,
    do_number varchar(50) REFERENCES operational.delivery_order(do_number) ON DELETE CASCADE,
    code_partner varchar(20) REFERENCES partner.info(code_partner),
    survey_type varchar(30) NOT NULL,
    survey_date timestamp NOT NULL,
    gross_volume double precision NOT NULL,
    moisture_pct double precision,
    net_volume double precision NOT NULL,
    report_doc_number varchar(100),
    status varchar(20) DEFAULT 'VERIFIED',
    created_at timestamp DEFAULT now(),
    CONSTRAINT chk_survey_status CHECK (status IN ('PENDING','VERIFIED','REJECTED'))
);

CREATE TABLE operational.bill_of_lading (
    bl_number varchar(50) PRIMARY KEY,
    public_id UUID DEFAULT gen_random_uuid() UNIQUE NOT NULL,
    do_number varchar(50) REFERENCES operational.delivery_order(do_number) ON DELETE CASCADE,
    issue_date date NOT NULL,
    port_of_loading varchar(100) NOT NULL,
    port_of_discharge varchar(100) NOT NULL,
    shipped_volume double precision NOT NULL,
    status varchar(20) DEFAULT 'ISSUED',
    created_at timestamp DEFAULT now(),
    CONSTRAINT chk_bl_status CHECK (status IN ('ISSUED','RELEASED','SURRENDERED'))
);

CREATE TABLE operational.statement_of_fact (
    id serial PRIMARY KEY,
    do_number varchar(50) REFERENCES operational.delivery_order(do_number) ON DELETE CASCADE,
    event_time timestamp NOT NULL,
    event_type varchar(50) NOT NULL,
    remarks text,
    recorded_by varchar(20) REFERENCES usr.info(code_user) ON DELETE SET NULL,
    created_at timestamp DEFAULT now()
);

-- -----------------------------------------------------------------------------
-- 10. SCHEMA: FINANCE
-- -----------------------------------------------------------------------------
CREATE TABLE finance.exchange_rate (
    id serial PRIMARY KEY,
    currency_from varchar(3) NOT NULL,
    currency_to varchar(3) DEFAULT 'IDR',
    rate_date date NOT NULL,
    rate_type varchar(30) NOT NULL,
    exchange_rate numeric(15,4) NOT NULL,
    created_at timestamp DEFAULT now(),
    CONSTRAINT uq_exchange_rate UNIQUE (currency_from, currency_to, rate_date, rate_type)
);

CREATE TABLE finance.invoice (
    invoice_number varchar(50) PRIMARY KEY,
    public_id UUID DEFAULT gen_random_uuid() UNIQUE NOT NULL,
    invoice_type varchar(20) NOT NULL,
    invoice_category varchar(20) DEFAULT 'FINAL',
    parent_invoice_number varchar(50) REFERENCES finance.invoice(invoice_number) ON DELETE SET NULL,
    code_buyer varchar(20) REFERENCES buyer.info(code_buyer),
    code_partner varchar(20) REFERENCES partner.info(code_partner),
    po_number varchar(50) REFERENCES operational.purchase_order(po_number) ON DELETE SET NULL,
    do_number varchar(50) REFERENCES operational.delivery_order(do_number) ON DELETE SET NULL,
    issue_date date NOT NULL,
    due_date date NOT NULL,
    currency_code varchar(3) DEFAULT 'IDR',
    exchange_rate_id integer REFERENCES finance.exchange_rate(id) ON DELETE SET NULL,
    subtotal numeric(15,2) DEFAULT 0.00,
    total_amount numeric(15,2) DEFAULT 0.00,
    subtotal_idr numeric(15,2) DEFAULT 0.00,
    total_amount_idr numeric(15,2) DEFAULT 0.00,
    status varchar(20) DEFAULT 'DRAFT',
    notes text,
    created_at timestamp DEFAULT now(),
    updated_at timestamp,
    CONSTRAINT chk_invoice_entity CHECK (
        (invoice_type = 'SALES' AND code_buyer IS NOT NULL AND code_partner IS NULL) OR
        (invoice_type = 'PURCHASE' AND code_partner IS NOT NULL AND code_buyer IS NULL)
    ),
    CONSTRAINT chk_invoice_status CHECK (status IN ('DRAFT','ISSUED','PAID','PARTIAL','CANCELLED'))
);

-- Tabel jembatan invoice - delivery order (many-to-many)
CREATE TABLE finance.invoice_delivery_order (
    id serial PRIMARY KEY,
    invoice_number varchar(50) REFERENCES finance.invoice(invoice_number) ON DELETE CASCADE,
    do_number varchar(50) REFERENCES operational.delivery_order(do_number) ON DELETE CASCADE,
    allocated_volume double precision,
    notes text,
    created_at timestamp DEFAULT now(),
    CONSTRAINT uq_invoice_do UNIQUE (invoice_number, do_number)
);

CREATE TABLE finance.invoice_item (
    id serial PRIMARY KEY,
    invoice_number varchar(50) REFERENCES finance.invoice(invoice_number) ON DELETE CASCADE,
    description varchar(255) NOT NULL,
    quantity double precision NOT NULL,
    uom varchar(20) NOT NULL,
    unit_price numeric(15,2) NOT NULL,
    total_price numeric(15,2) NOT NULL,
    created_at timestamp DEFAULT now()
);

CREATE TABLE finance.invoice_tax (
    id serial PRIMARY KEY,
    invoice_number varchar(50) REFERENCES finance.invoice(invoice_number) ON DELETE CASCADE,
    tax_type varchar(30) NOT NULL,
    tax_rate_pct numeric(5,2) NOT NULL,
    tax_amount numeric(15,2) NOT NULL,
    tax_amount_idr numeric(15,2) NOT NULL,
    tax_doc_number varchar(50),
    created_at timestamp DEFAULT now()
);

CREATE TABLE finance.payment (
    payment_number varchar(50) PRIMARY KEY,
    invoice_number varchar(50) REFERENCES finance.invoice(invoice_number),
    payment_date timestamp DEFAULT now(),
    payment_method varchar(30) NOT NULL,
    currency_code varchar(3) DEFAULT 'IDR',
    exchange_rate_id integer REFERENCES finance.exchange_rate(id) ON DELETE SET NULL,
    amount numeric(15,2) NOT NULL,
    amount_idr numeric(15,2) NOT NULL,
    reference_code varchar(100),
    status varchar(20) DEFAULT 'COMPLETED',
    created_at timestamp DEFAULT now(),
    CONSTRAINT chk_payment_status CHECK (status IN ('PENDING','COMPLETED','FAILED'))
);

CREATE TABLE finance.government_dues (
    id serial PRIMARY KEY,
    do_number varchar(50) REFERENCES operational.delivery_order(do_number) ON DELETE SET NULL,
    tax_type varchar(50) NOT NULL,
    volume_basis double precision NOT NULL,
    tariff_rate numeric(15,2) NOT NULL,
    total_amount_idr numeric(15,2) NOT NULL,
    billing_code varchar(50),
    payment_date date,
    status varchar(20) DEFAULT 'UNPAID',
    created_at timestamp DEFAULT now(),
    updated_at timestamp,
    CONSTRAINT chk_govdues_status CHECK (status IN ('UNPAID','PAID'))
);

-- View untuk validasi nilai turunan invoice
CREATE OR REPLACE VIEW finance.v_invoice_summary AS
SELECT 
    i.invoice_number,
    i.subtotal AS stored_subtotal,
    COALESCE(item_sum.total_item, 0) AS calculated_subtotal,
    i.total_amount AS stored_total,
    COALESCE(item_sum.total_item, 0) + COALESCE(tax_sum.total_tax, 0) AS calculated_total,
    CASE 
        WHEN i.subtotal = COALESCE(item_sum.total_item, 0) AND i.total_amount = COALESCE(item_sum.total_item, 0) + COALESCE(tax_sum.total_tax, 0) 
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

-- -----------------------------------------------------------------------------
-- 11. SCHEMA: ENVIRO
-- -----------------------------------------------------------------------------
CREATE TABLE enviro.buoy_info (
    code_buoy varchar(20) PRIMARY KEY,
    code_site varchar(20) REFERENCES site.info(code_site),
    buoy_type varchar(50) NOT NULL,
    latitude double precision NOT NULL,
    longitude double precision NOT NULL,
    battery_level double precision,
    last_maintenance date,
    status varchar(20) DEFAULT 'ACTIVE',
    created_at timestamp DEFAULT now(),
    updated_at timestamp,
    CONSTRAINT chk_buoy_status CHECK (status IN ('ACTIVE','INACTIVE','MAINTENANCE'))
);

CREATE TABLE enviro.buoy_reading (
    id serial,
    code_buoy varchar(20) REFERENCES enviro.buoy_info(code_buoy) ON DELETE CASCADE,
    record_time timestamp DEFAULT now(),
    salinity double precision,
    turbidity double precision,
    current_speed double precision,
    dissolved_oxygen double precision,
    water_density double precision,
    tide_level double precision,
    created_at timestamp DEFAULT now(),
    CONSTRAINT uq_buoy_reading UNIQUE (code_buoy, record_time)
) PARTITION BY RANGE (record_time);

-- Partisi contoh
CREATE TABLE enviro.buoy_reading_202601 PARTITION OF enviro.buoy_reading
    FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');
CREATE TABLE enviro.buoy_reading_202602 PARTITION OF enviro.buoy_reading
    FOR VALUES FROM ('2026-02-01') TO ('2026-03-01');

CREATE TABLE enviro.incident (
    id serial PRIMARY KEY,
    code_site varchar(20) REFERENCES site.info(code_site),
    code_vessel varchar(20) REFERENCES vessel.info(code_vessel) ON DELETE SET NULL,
    reported_by varchar(20) REFERENCES usr.info(code_user) ON DELETE SET NULL,
    incident_time timestamp NOT NULL,
    incident_type varchar(50) NOT NULL,
    severity varchar(20) NOT NULL,
    description text NOT NULL,
    action_taken text,
    status varchar(20) DEFAULT 'INVESTIGATING',
    created_at timestamp DEFAULT now(),
    updated_at timestamp,
    CONSTRAINT chk_incident_status CHECK (status IN ('INVESTIGATING','RESOLVED','CLOSED'))
);

CREATE TABLE enviro.water_quality (
    id serial PRIMARY KEY,
    code_site varchar(20) REFERENCES site.info(code_site),
    tested_by varchar(20) REFERENCES usr.info(code_user) ON DELETE SET NULL,
    code_partner varchar(20) REFERENCES partner.info(code_partner) ON DELETE SET NULL,
    test_date date NOT NULL,
    tss double precision,
    ph_level double precision,
    status varchar(20) DEFAULT 'NORMAL',
    created_at timestamp DEFAULT now(),
    CONSTRAINT chk_wq_status CHECK (status IN ('NORMAL','WARNING','CRITICAL'))
);

CREATE TABLE enviro.water_quality_parameter (
    id serial PRIMARY KEY,
    water_quality_id integer REFERENCES enviro.water_quality(id) ON DELETE CASCADE,
    parameter_name varchar(50) NOT NULL,
    parameter_value double precision,
    uom varchar(10),
    created_at timestamp DEFAULT now()
);

CREATE TABLE enviro.weather_log (
    id serial PRIMARY KEY,
    code_site varchar(20) REFERENCES site.info(code_site),
    recorded_by varchar(20) REFERENCES usr.info(code_user) ON DELETE SET NULL,
    log_time timestamp DEFAULT now(),
    weather_condition varchar(50) NOT NULL,
    wind_speed double precision,
    wave_height double precision,
    notes text,
    created_at timestamp DEFAULT now()
);

CREATE TABLE enviro.compliance_report (
    id serial PRIMARY KEY,
    report_type varchar(50) NOT NULL,
    period_start date NOT NULL,
    period_end date NOT NULL,
    code_site varchar(20) REFERENCES site.info(code_site),
    submitted_to varchar(100),
    submission_date date,
    report_url text,
    status varchar(20) DEFAULT 'DRAFT',
    created_at timestamp DEFAULT now(),
    updated_at timestamp,
    CONSTRAINT chk_compliance_status CHECK (status IN ('DRAFT','SUBMITTED','APPROVED','REJECTED'))
);

-- -----------------------------------------------------------------------------
-- 12. SCHEMA: DOCUMENT
-- -----------------------------------------------------------------------------
CREATE TABLE document.category (
    code_category varchar(30) PRIMARY KEY,
    description varchar(255) NOT NULL,
    is_active boolean DEFAULT true
);

CREATE TABLE document.file_registry (
    id serial PRIMARY KEY,
    code_category varchar(30) REFERENCES document.category(code_category),
    file_name varchar(255) NOT NULL,
    storage_url text NOT NULL,
    mime_type varchar(50) NOT NULL,
    size_kb double precision NOT NULL,
    is_confidential boolean DEFAULT false,
    uploaded_by varchar(20) REFERENCES usr.info(code_user) ON DELETE SET NULL,
    uploaded_at timestamp DEFAULT now()
);

CREATE TABLE document.entity_link (
    id serial PRIMARY KEY,
    document_id integer REFERENCES document.file_registry(id) ON DELETE CASCADE,
    reference_schema varchar(50) NOT NULL,
    reference_table varchar(50) NOT NULL,
    reference_id varchar(100) NOT NULL,
    linked_at timestamp DEFAULT now()
);

-- -----------------------------------------------------------------------------
-- 13. SCHEMA: AUDIT
-- -----------------------------------------------------------------------------
CREATE TABLE audit.activity_log (
    id serial PRIMARY KEY,
    code_user varchar(20) NOT NULL,  -- Tidak ada FK karena bisa mencatat aktivitas sistem atau user yang sudah dihapus
    action_type varchar(20) NOT NULL,
    schema_name varchar(50) NOT NULL,
    table_name varchar(50) NOT NULL,
    record_id varchar(50) NOT NULL,
    old_data jsonb,
    new_data jsonb,
    ip_address varchar(50),
    created_at timestamp DEFAULT now()
);
COMMENT ON COLUMN audit.activity_log.code_user IS 'Tidak ada FK ke usr.info karena log dapat mencatat aktivitas sistem atau user yang sudah dihapus.';

CREATE TABLE audit.error_log (
    id serial PRIMARY KEY,
    error_source varchar(50) NOT NULL,
    error_level varchar(20) NOT NULL,
    error_message text NOT NULL,
    stack_trace text,
    payload_data jsonb,
    resolved_status boolean DEFAULT false,
    resolved_at timestamp,
    created_at timestamp DEFAULT now()
);

CREATE TABLE audit.login_history (
    id serial PRIMARY KEY,
    code_user varchar(20) NOT NULL,
    login_time timestamp DEFAULT now(),
    ip_address varchar(50),
    user_agent text,
    status varchar(20) NOT NULL
);


-- =============================================================================
-- 14. TRIGGERS, INDEXES, & CONSTRAINTS (FINAL POLISHING)
-- =============================================================================

-- A. AUTOMATION TRIGGERS
CREATE TRIGGER trg_update_usr_info BEFORE UPDATE ON usr.info FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();
CREATE TRIGGER trg_update_vessel_info BEFORE UPDATE ON vessel.info FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();
CREATE TRIGGER trg_update_po BEFORE UPDATE ON operational.purchase_order FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();
CREATE TRIGGER trg_update_do BEFORE UPDATE ON operational.delivery_order FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();
CREATE TRIGGER trg_update_invoice BEFORE UPDATE ON finance.invoice FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();
CREATE TRIGGER trg_update_deposit_ledger BEFORE UPDATE ON buyer.deposit_ledger FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();

-- B. TRIGGER UNTUK AUDIT OTOMATIS
CREATE TRIGGER trg_audit_usr_info AFTER INSERT OR UPDATE OR DELETE ON usr.info FOR EACH ROW EXECUTE PROCEDURE fn_audit_activity();
CREATE TRIGGER trg_audit_vessel_info AFTER INSERT OR UPDATE OR DELETE ON vessel.info FOR EACH ROW EXECUTE PROCEDURE fn_audit_activity();
CREATE TRIGGER trg_audit_po AFTER INSERT OR UPDATE OR DELETE ON operational.purchase_order FOR EACH ROW EXECUTE PROCEDURE fn_audit_activity();
CREATE TRIGGER trg_audit_do AFTER INSERT OR UPDATE OR DELETE ON operational.delivery_order FOR EACH ROW EXECUTE PROCEDURE fn_audit_activity();
CREATE TRIGGER trg_audit_invoice AFTER INSERT OR UPDATE OR DELETE ON finance.invoice FOR EACH ROW EXECUTE PROCEDURE fn_audit_activity();
CREATE TRIGGER trg_audit_payment AFTER INSERT OR UPDATE OR DELETE ON finance.payment FOR EACH ROW EXECUTE PROCEDURE fn_audit_activity();

-- C. TRIGGER UNTUK SALDO DEPOSIT BUYER
CREATE TRIGGER trg_update_deposit_balance
AFTER INSERT OR UPDATE OR DELETE ON buyer.deposit_ledger
FOR EACH ROW EXECUTE PROCEDURE update_buyer_deposit_balance();

-- D. PERFORMANCE INDEXES (tambahan + existing)
CREATE INDEX idx_audit_activity_user ON audit.activity_log (code_user);
CREATE INDEX idx_audit_activity_table ON audit.activity_log (table_name, record_id);
CREATE INDEX idx_audit_activity_time ON audit.activity_log (created_at);
CREATE INDEX idx_op_do_po ON operational.delivery_order (po_number);
CREATE INDEX idx_op_do_vessel ON operational.delivery_order (code_vessel_main);
CREATE INDEX idx_op_survey_do ON operational.cargo_survey (do_number);
CREATE INDEX idx_op_bl_do ON operational.bill_of_lading (do_number);
CREATE INDEX idx_fin_invoice_buyer ON finance.invoice (code_buyer);
CREATE INDEX idx_fin_invoice_partner ON finance.invoice (code_partner);
CREATE INDEX idx_fin_invoice_do ON finance.invoice (do_number);
CREATE INDEX idx_fin_payment_invoice ON finance.payment (invoice_number);
CREATE INDEX idx_fin_payment_date ON finance.payment (payment_date);
CREATE INDEX idx_env_buoy_reading_time ON enviro.buoy_reading (record_time);  -- hanya pada partisi induk, otomatis diwarisi
CREATE INDEX idx_doc_link_ref ON document.entity_link (reference_schema, reference_table, reference_id);
CREATE INDEX idx_vessel_movement_time ON vessel.movement_log (code_vessel, log_time);
CREATE INDEX idx_env_weather_time ON enviro.weather_log (code_site, log_time);
CREATE INDEX idx_daily_prod_site ON operational.daily_production (code_site);
CREATE INDEX idx_daily_prod_vessel ON operational.daily_production (code_vessel);
CREATE INDEX idx_gov_dues_do ON finance.government_dues (do_number);
CREATE INDEX idx_op_sofp_do ON operational.statement_of_fact (do_number);
CREATE INDEX idx_fin_invoice_del_do ON finance.invoice_delivery_order (do_number);
CREATE INDEX idx_fin_invoice_del_inv ON finance.invoice_delivery_order (invoice_number);
CREATE INDEX idx_movement_log_do ON vessel.movement_log (do_number);
CREATE INDEX idx_approval_ref ON operational.approval_log (ref_table, ref_id);
CREATE INDEX idx_notification_log_time ON param.notification_log (sent_at);

-- E. CHECK CONSTRAINTS (tambahan untuk tabel yang belum)
ALTER TABLE vessel.maintenance ADD CONSTRAINT chk_mt_status CHECK (status IN ('SCHEDULED','IN PROGRESS','COMPLETED','CANCELLED'));
ALTER TABLE vessel.crew_history ADD CONSTRAINT chk_crew_status CHECK (status IN ('ON_BOARD','SIGNED_OFF'));