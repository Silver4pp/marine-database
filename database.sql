-- -----------------------------------------------------------------------------
-- 1. CREATING SCHEMAS
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
CREATE TABLE IF NOT EXISTS param.system_config (
    code_config varchar(50) PRIMARY KEY,
    config_value text NOT NULL,
    description text,
    is_secure boolean DEFAULT false,
    updated_by varchar(20),
    updated_at timestamp DEFAULT now()
);

CREATE TABLE IF NOT EXISTS param.dropdown_list (
    id serial PRIMARY KEY,
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
    updated_at timestamp DEFAULT now()
);

CREATE TABLE IF NOT EXISTS param.notification_log (
    id serial PRIMARY KEY,
    code_template varchar(50) REFERENCES param.notification_template(code_template),
    recipient varchar(100) NOT NULL,
    sent_at timestamp DEFAULT now(),
    status varchar(20) DEFAULT 'SENT',
    error_message text,
    created_at timestamp DEFAULT now()
);

CREATE TABLE IF NOT EXISTS param.abbreviation (
    code_abbr varchar(50) PRIMARY KEY,
    full_name varchar(255) NOT NULL,
    category varchar(50),
    description text,
    is_active boolean DEFAULT true,
    created_at timestamp DEFAULT now(),
    updated_at timestamp
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
    created_at timestamp DEFAULT now(),
    updated_at timestamp
);

-- -----------------------------------------------------------------------------
-- 4. SCHEMA: USR
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS usr.role (
    code_role varchar(20) PRIMARY KEY,
    description text,
    is_active boolean DEFAULT true,
    created_at timestamp DEFAULT now(),
    updated_at timestamp
);

CREATE TABLE IF NOT EXISTS usr.permission (
    code_permission varchar(50) PRIMARY KEY,
    module varchar(50) NOT NULL,
    created_at timestamp DEFAULT now()
);

CREATE TABLE IF NOT EXISTS usr.role_permission (
    code_role varchar(20) REFERENCES usr.role(code_role) ON DELETE CASCADE,
    code_permission varchar(50) REFERENCES usr.permission(code_permission) ON DELETE CASCADE,
    created_at timestamp DEFAULT now(),
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
    last_login timestamp,
    created_at timestamp DEFAULT now(),
    updated_at timestamp,
    deleted_at timestamp
);

CREATE TABLE IF NOT EXISTS usr.contact (
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
CREATE TABLE IF NOT EXISTS site.type (
    code_type varchar(20) PRIMARY KEY,
    description text,
    is_active boolean DEFAULT true,
    created_at timestamp DEFAULT now()
);

CREATE TABLE IF NOT EXISTS site.info (
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

CREATE TABLE IF NOT EXISTS site.roster (
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
CREATE TABLE IF NOT EXISTS partner.type (
    code_type varchar(20) PRIMARY KEY,
    description text,
    is_active boolean DEFAULT true,
    created_at timestamp DEFAULT now()
);

CREATE TABLE IF NOT EXISTS partner.info (
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

CREATE TABLE IF NOT EXISTS partner.contact (
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
CREATE TABLE IF NOT EXISTS vessel.type (
    code_type varchar(20) PRIMARY KEY,
    description text,
    is_active boolean DEFAULT true,
    created_at timestamp DEFAULT now()
);

CREATE TABLE IF NOT EXISTS vessel.info (
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

CREATE TABLE IF NOT EXISTS vessel.site_assignment (
    id serial PRIMARY KEY,
    code_vessel varchar(20) REFERENCES vessel.info(code_vessel) ON DELETE CASCADE,
    code_site varchar(20) REFERENCES site.info(code_site),
    start_date date NOT NULL,
    end_date date,
    created_at timestamp DEFAULT now(),
    updated_at timestamp,
    CONSTRAINT chk_site_assignment_dates CHECK (end_date IS NULL OR end_date >= start_date)
);

CREATE TABLE IF NOT EXISTS vessel.certificate (
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

CREATE TABLE IF NOT EXISTS vessel.crew_history (
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

CREATE TABLE IF NOT EXISTS vessel.maintenance (
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

-- -----------------------------------------------------------------------------
-- 8. SCHEMA: BUYER
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS buyer.type (
    code_type varchar(20) PRIMARY KEY,
    description text,
    is_active boolean DEFAULT true,
    created_at timestamp DEFAULT now()
);

CREATE TABLE IF NOT EXISTS buyer.info (
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

CREATE TABLE IF NOT EXISTS buyer.discharge_location (
    id serial PRIMARY KEY,
    code_buyer varchar(20) REFERENCES buyer.info(code_buyer) ON DELETE CASCADE,
    name varchar(100) NOT NULL,
    latitude double precision NOT NULL,
    longitude double precision NOT NULL,
    is_active boolean DEFAULT true,
    created_at timestamp DEFAULT now(),
    updated_at timestamp
);

CREATE TABLE IF NOT EXISTS buyer.deposit_ledger (
    id serial PRIMARY KEY,
    code_buyer varchar(20) REFERENCES buyer.info(code_buyer) ON DELETE CASCADE,
    transaction_date timestamp DEFAULT now(),
    transaction_type varchar(30) NOT NULL,
    amount numeric(15,2) NOT NULL,
    reference_doc varchar(50),
    description text,
    created_by varchar(20) REFERENCES usr.info(code_user),
    created_at timestamp DEFAULT now(),
    updated_at timestamp
);

-- -----------------------------------------------------------------------------
-- 9. SCHEMA: OPERATIONAL
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS operational.purchase_order (
    po_number varchar(50) PRIMARY KEY,
    public_id UUID DEFAULT gen_random_uuid() UNIQUE NOT NULL,
    code_buyer varchar(20) REFERENCES buyer.info(code_buyer),
    po_date date NOT NULL,
    target_completion_date date,
    uom varchar(10) REFERENCES param.uom(code_uom) DEFAULT 'M3',
    total_volume double precision NOT NULL,
    unit_price numeric(15,2) NOT NULL,
    total_amount numeric(15,2) NOT NULL,
    status varchar(20) DEFAULT 'DRAFT',
    description text,
    created_at timestamp DEFAULT now(),
    updated_at timestamp,
    CONSTRAINT chk_po_status CHECK (status IN ('DRAFT','SUBMITTED','APPROVED','IN PROGRESS','COMPLETED','CANCELLED'))
);

CREATE TABLE IF NOT EXISTS operational.approval_log (
    id serial PRIMARY KEY,
    ref_table varchar(50) NOT NULL,
    ref_id varchar(50) NOT NULL,
    action varchar(20) NOT NULL,
    approved_by varchar(20) REFERENCES usr.info(code_user),
    approved_at timestamp DEFAULT now(),
    remarks text,
    created_at timestamp DEFAULT now()
);

CREATE TABLE IF NOT EXISTS operational.daily_production (
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

CREATE TABLE IF NOT EXISTS operational.delivery_order (
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

CREATE TABLE IF NOT EXISTS operational.cargo_survey (
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

CREATE TABLE IF NOT EXISTS operational.bill_of_lading (
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

CREATE TABLE IF NOT EXISTS operational.statement_of_fact (
    id serial PRIMARY KEY,
    do_number varchar(50) REFERENCES operational.delivery_order(do_number) ON DELETE CASCADE,
    event_time timestamp NOT NULL,
    event_type varchar(50) NOT NULL,
    remarks text,
    recorded_by varchar(20) REFERENCES usr.info(code_user) ON DELETE SET NULL,
    created_at timestamp DEFAULT now()
);

-- -----------------------------------------------------------------------------
-- 7B. VESSEL MOVEMENT_LOG
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS vessel.movement_log (
    id serial,
    code_vessel varchar(20) REFERENCES vessel.info(code_vessel) ON DELETE CASCADE,
    code_site varchar(20) REFERENCES site.info(code_site) ON DELETE SET NULL,
    do_number varchar(50) REFERENCES operational.delivery_order(do_number) ON DELETE SET NULL,
    status varchar(30) NOT NULL,
    latitude double precision,
    longitude double precision,
    log_time timestamp DEFAULT now(),
    description text,
    created_at timestamp DEFAULT now(),
    PRIMARY KEY (id, log_time)
) PARTITION BY RANGE (log_time);

-- Partisi Movement Log
CREATE TABLE IF NOT EXISTS vessel.movement_log_202601 PARTITION OF vessel.movement_log
    FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');
CREATE TABLE IF NOT EXISTS vessel.movement_log_202602 PARTITION OF vessel.movement_log
    FOR VALUES FROM ('2026-02-01') TO ('2026-03-01');

-- -----------------------------------------------------------------------------
-- 10. SCHEMA: FINANCE
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS finance.exchange_rate (
    id serial PRIMARY KEY,
    currency_from varchar(3) NOT NULL,
    currency_to varchar(3) DEFAULT 'IDR',
    rate_date date NOT NULL,
    rate_type varchar(30) NOT NULL,
    exchange_rate numeric(15,4) NOT NULL,
    created_at timestamp DEFAULT now(),
    CONSTRAINT uq_exchange_rate UNIQUE (currency_from, currency_to, rate_date, rate_type)
);

CREATE TABLE IF NOT EXISTS finance.invoice (
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
    description text,
    created_at timestamp DEFAULT now(),
    updated_at timestamp,
    CONSTRAINT chk_invoice_entity CHECK (
        (invoice_type = 'SALES' AND code_buyer IS NOT NULL AND code_partner IS NULL) OR
        (invoice_type = 'PURCHASE' AND code_partner IS NOT NULL AND code_buyer IS NULL)
    ),
    CONSTRAINT chk_invoice_status CHECK (status IN ('DRAFT','ISSUED','PAID','PARTIAL','CANCELLED'))
);

CREATE TABLE IF NOT EXISTS finance.invoice_delivery_order (
    id serial PRIMARY KEY,
    invoice_number varchar(50) REFERENCES finance.invoice(invoice_number) ON DELETE CASCADE,
    do_number varchar(50) REFERENCES operational.delivery_order(do_number) ON DELETE CASCADE,
    allocated_volume double precision,
    description text,
    created_at timestamp DEFAULT now(),
    CONSTRAINT uq_invoice_do UNIQUE (invoice_number, do_number)
);

CREATE TABLE IF NOT EXISTS finance.invoice_item (
    id serial PRIMARY KEY,
    invoice_number varchar(50) REFERENCES finance.invoice(invoice_number) ON DELETE CASCADE,
    description varchar(255) NOT NULL,
    quantity double precision NOT NULL,
    uom varchar(20) NOT NULL,
    unit_price numeric(15,2) NOT NULL,
    total_price numeric(15,2) NOT NULL,
    created_at timestamp DEFAULT now()
);

CREATE TABLE IF NOT EXISTS finance.invoice_tax (
    id serial PRIMARY KEY,
    invoice_number varchar(50) REFERENCES finance.invoice(invoice_number) ON DELETE CASCADE,
    tax_type varchar(30) NOT NULL,
    tax_rate_pct numeric(5,2) NOT NULL,
    tax_amount numeric(15,2) NOT NULL,
    tax_amount_idr numeric(15,2) NOT NULL,
    tax_doc_number varchar(50),
    created_at timestamp DEFAULT now()
);

CREATE TABLE IF NOT EXISTS finance.payment (
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

CREATE TABLE IF NOT EXISTS finance.government_dues (
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

-- -----------------------------------------------------------------------------
-- 11. SCHEMA: DOCUMENT
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS document.category (
    code_category varchar(30) PRIMARY KEY,
    description varchar(255) NOT NULL,
    is_active boolean DEFAULT true
);

CREATE TABLE IF NOT EXISTS document.file_registry (
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

CREATE TABLE IF NOT EXISTS document.entity_link (
    id serial PRIMARY KEY,
    document_id integer REFERENCES document.file_registry(id) ON DELETE CASCADE,
    reference_document varchar(100) NOT NULL,
    linked_at timestamp DEFAULT now()
);

-- -----------------------------------------------------------------------------
-- 12. SCHEMA: FORM
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS form.sampling_worksheet (
    no_form varchar(20) PRIMARY KEY,
    sampling_date date NOT NULL,
    no_package numeric NOT NULL,
    type_sample varchar(20) NOT NULL,
    sample_total numeric NOT NULL,
    survey_by varchar(20) REFERENCES partner.info(code_partner) ON DELETE SET NULL,
    code_vessel varchar(20) REFERENCES vessel.info(code_vessel) ON DELETE SET NULL,
    created_at timestamp DEFAULT now()
);

CREATE TABLE IF NOT EXISTS form.sampling_worksheet_detail (
    no_form varchar(20) REFERENCES form.sampling_worksheet(no_form) ON DELETE CASCADE,
    no_sample varchar(20) NOT NULL,
    latitude double precision NOT NULL,
    longitude double precision NOT NULL,
    description varchar(255) NOT NULL,
    created_at timestamp DEFAULT now()
);

CREATE TABLE IF NOT EXISTS form.water_sampling (
    no_form varchar(20) PRIMARY KEY,
    sampling_date date NOT NULL,
    type_sample varchar(20) NOT NULL,
    total_sample numeric NOT NULL,
    survey_by varchar(20) REFERENCES partner.info(code_partner) ON DELETE SET NULL,
    created_at timestamp DEFAULT now()
);

CREATE TABLE IF NOT EXISTS form.volumetric_calc (
    no_form varchar(20) PRIMARY KEY,
    no_delivery varchar(20) REFERENCES operational.delivery_order(do_number) ON DELETE SET NULL,
    empty_draft double precision NOT NULL,
    created_at timestamp DEFAULT now()
);

CREATE TABLE IF NOT EXISTS form.volumetric_calc_detail (
    no_form varchar(20) REFERENCES form.volumetric_calc(no_form) ON DELETE CASCADE,
    calc_type varchar(20) NOT NULL,
    volume double precision NOT NULL,
    date_measured date NOT NULL,
    recorded_by varchar(20) REFERENCES usr.info(code_user) ON DELETE SET NULL,
    created_at timestamp DEFAULT now(),
    CONSTRAINT chk_volumetric_calc_type CHECK (calc_type IN ('DRAFT','FINAL'))
);

CREATE TABLE IF NOT EXISTS form.station_inspection (
    id serial PRIMARY KEY,
    code_station varchar(20) REFERENCES enviro.station_info(code_station) ON DELETE CASCADE,
    code_user varchar(20) REFERENCES usr.info(code_user) ON DELETE SET NULL,
    inspection_date date NOT NULL,
    inspection_type varchar(20) NOT NULL,
    weather_condition text,
    recorded_by varchar(20) REFERENCES usr.info(code_user) ON DELETE SET NULL,
    created_at timestamp DEFAULT now()
);

CREATE TABLE IF NOT EXISTS form.station_inspection_details (
    id serial PRIMARY KEY,
    id_inspection integer REFERENCES form.station_inspection(id) ON DELETE CASCADE,
    equipment_name varchar(50) NOT NULL,
    equipment_condition text,
    description text,
    created_at timestamp DEFAULT now(),
    CONSTRAINT chk_equipment_condition CHECK (equipment_condition IN ('OK','NOTE OK', 'N/A'))
);

CREATE TABLE IF NOT EXISTS form.daily_activities (
    no_form varchar(20) PRIMARY KEY,
    code_vessel varchar(20) REFERENCES vessel.info(code_vessel) ON DELETE SET NULL,
    activitie_date date NOT NULL,
    description text NOT NULL,
    recorded_by varchar(20) REFERENCES usr.info(code_user) ON DELETE SET NULL,
    created_at date NOT NULL
);

CREATE TABLE IF NOT EXISTS form.daily_activities_details (
    no_form varchar(20) REFERENCES form.daily_activities(no_form) ON DELETE CASCADE,
    date_activities date NOT NULL,
    time_activities time NOT NULL,
    latitude double precision NOT NULL,
    longitude double precision NOT NULL,
    run_hours_in time NOT NULL,
    run_hours_out time NOT NULL,
    description text NOT NULL,
    created_at timestamp DEFAULT now()
);

CREATE TABLE IF NOT EXISTS form.daily_activities_weather (
    no_form varchar(20) REFERENCES form.daily_activities(no_form) ON DELETE CASCADE,
    date_weather date NOT NULL,
    time_weather time NOT NULL,
    wind_speed numeric NOT NULL,
    wave_height numeric NOT NULL,
    description text NOT NULL,
    created_at timestamp DEFAULT now()
);

CREATE TABLE IF NOT EXISTS form.monitoring_survey (
    no_form varchar(20) PRIMARY KEY,
    survey_date date NOT NULL,
    survey_by varchar(20) REFERENCES usr.info(code_user) ON DELETE SET NULL,
    recorded_by varchar(20) REFERENCES usr.info(code_user) ON DELETE SET NULL,
    reviewed_by varchar(20) REFERENCES usr.info(code_user) ON DELETE SET NULL,
    created_at timestamp DEFAULT now()
);

CREATE TABLE IF NOT EXISTS form.monitoring_survey_details (
    id serial PRIMARY KEY,
    no_form varchar(20) REFERENCES form.monitoring_survey(no_form) ON DELETE CASCADE,
    latitude double precision NOT NULL,
    longitude double precision NOT NULL,
    station_id varchar(20) REFERENCES enviro.station_info(code_station) ON DELETE SET NULL,
    depth_d numeric NOT NULL,
    depth_m numeric NOT NULL,
    time_deploy time NOT NULL,
    time_undeploy time NOT NULL,
    description text NOT NULL,
    created_at timestamp DEFAULT now()
);

-- -----------------------------------------------------------------------------
-- 13. SCHEMA: ENVIRO
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS enviro.station_info (
    code_station varchar(20) PRIMARY KEY,
    code_site varchar(20) REFERENCES site.info(code_site),
    station_type varchar(50) NOT NULL,
    latitude double precision NOT NULL,
    longitude double precision NOT NULL,
    battery_level double precision,
    last_maintenance date,
    status varchar(20) DEFAULT 'ACTIVE',
    created_at timestamp DEFAULT now(),
    updated_at timestamp,
    CONSTRAINT chk_station_status CHECK (status IN ('ACTIVE','INACTIVE','MAINTENANCE'))
);

CREATE TABLE IF NOT EXISTS enviro.station_reading (
    id serial,
    code_station varchar(20) REFERENCES enviro.station_info(code_station) ON DELETE CASCADE,
    record_time timestamp DEFAULT now(),
    salinity double precision,
    turbidity double precision,
    current_speed double precision,
    dissolved_oxygen double precision,
    water_density double precision,
    tide_level double precision,
    created_at timestamp DEFAULT now(),
    PRIMARY KEY (id, record_time) 
) PARTITION BY RANGE (record_time);

-- Partition Station Reading
CREATE TABLE IF NOT EXISTS enviro.station_reading_202601 PARTITION OF enviro.station_reading
    FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');
CREATE TABLE IF NOT EXISTS enviro.station_reading_202602 PARTITION OF enviro.station_reading
    FOR VALUES FROM ('2026-02-01') TO ('2026-03-01');

CREATE TABLE IF NOT EXISTS enviro.incident (
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

CREATE TABLE IF NOT EXISTS enviro.water_quality (
    id serial PRIMARY KEY,
    no_form varchar(20) REFERENCES form.water_sampling(no_form) ON DELETE CASCADE,
    latitude double precision NOT NULL,
    longitude double precision NOT NULL,
    depth numeric NOT NULL,
    brightness numeric NOT NULL,
    temperature numeric NOT NULL,
    turbidity numeric NOT NULL,
    dissolved_oxygen numeric NOT NULL,
    ph_level numeric NOT NULL,
    salt numeric NOT NULL,
    condition varchar(250) NOT NULL,
    created_at timestamp DEFAULT now()
);


CREATE TABLE IF NOT EXISTS enviro.parameter_threshold (
    id serial PRIMARY KEY,
    parameter_name varchar(50) NOT NULL,
    parameter_value double precision,
    uom varchar(10),
    created_at timestamp DEFAULT now(),
    updated_at timestamp
);

CREATE TABLE IF NOT EXISTS enviro.weather_log (
    id serial PRIMARY KEY,
    code_site varchar(20) REFERENCES site.info(code_site),
    recorded_by varchar(20) REFERENCES usr.info(code_user) ON DELETE SET NULL,
    log_time timestamp DEFAULT now(),
    weather_condition varchar(50) NOT NULL,
    wind_speed double precision,
    wave_height double precision,
    description text,
    created_at timestamp DEFAULT now()
);

CREATE TABLE IF NOT EXISTS enviro.compliance_report (
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
-- 14. SCHEMA: AUDIT
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS audit.activity_log (
    id serial PRIMARY KEY,
    code_user varchar(20) NOT NULL,
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

CREATE TABLE IF NOT EXISTS audit.error_log (
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

CREATE TABLE IF NOT EXISTS audit.login_history (
    id serial PRIMARY KEY,
    code_user varchar(20) NOT NULL,
    login_time timestamp DEFAULT now(),
    ip_address varchar(50),
    user_agent text,
    status varchar(20) NOT NULL
);

-- -----------------------------------------------------------------------------
-- 15. VIEWS
-- -----------------------------------------------------------------------------

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

-- =============================================================================
-- 16. TRIGGERS, INDEXES, & CONSTRAINTS
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

-- D. PERFORMANCE INDEXES
CREATE INDEX idx_audit_activity_user ON audit.activity_log (code_user);
CREATE INDEX idx_audit_activity_table ON audit.activity_log (table_name, record_id);
CREATE INDEX idx_audit_activity_time ON audit.activity_log (created_at);
CREATE INDEX idx_op_do_po ON operational.delivery_order (po_number);
CREATE INDEX idx_op_do_vessel ON operational.delivery_order (code_vessel_main);
CREATE INDEX idx_op_survey_do ON operational.cargo_survey (do_number);
CREATE INDEX idx_op_bl_do ON operational.bill_of_lading (do_number);
CREATE INDEX idx_fin_inv_buyer ON finance.invoice (code_buyer);
CREATE INDEX idx_fin_inv_partner ON finance.invoice (code_partner);
CREATE INDEX idx_fin_inv_do ON finance.invoice (do_number);
CREATE INDEX idx_fin_inv_del_do ON finance.invoice_delivery_order (do_number);
CREATE INDEX idx_fin_inv_del_inv ON finance.invoice_delivery_order (invoice_number);
CREATE INDEX idx_fin_inv_item_inv ON finance.invoice_item (invoice_number);
CREATE INDEX idx_fin_inv_tax_inv ON finance.invoice_tax (invoice_number);
CREATE INDEX idx_fin_payment_invoice ON finance.payment (invoice_number);
CREATE INDEX idx_fin_payment_date ON finance.payment (payment_date);
CREATE INDEX idx_env_station_reading_time ON enviro.station_reading (record_time);
CREATE INDEX idx_doc_link_ref ON document.entity_link (reference_document);
CREATE INDEX idx_vessel_movement_time ON vessel.movement_log (code_vessel, log_time);
CREATE INDEX idx_env_weather_time ON enviro.weather_log (code_site, log_time);
CREATE INDEX idx_daily_prod_site ON operational.daily_production (code_site);
CREATE INDEX idx_daily_prod_vessel ON operational.daily_production (code_vessel);
CREATE INDEX idx_gov_dues_do ON finance.government_dues (do_number);
CREATE INDEX idx_op_sofp_do ON operational.statement_of_fact (do_number);
CREATE INDEX idx_movement_log_do ON vessel.movement_log (do_number);
CREATE INDEX idx_approval_ref ON operational.approval_log (ref_table, ref_id);
CREATE INDEX idx_notification_log_time ON param.notification_log (sent_at);
CREATE INDEX idx_buyer_deposit_ledger ON buyer.deposit_ledger (code_buyer);
CREATE INDEX idx_env_incident_status ON enviro.incident (status, severity);

-- E. CHECK CONSTRAINTS
ALTER TABLE vessel.maintenance ADD CONSTRAINT chk_mt_status CHECK (status IN ('SCHEDULED','IN PROGRESS','COMPLETED','CANCELLED'));
ALTER TABLE vessel.crew_history ADD CONSTRAINT chk_crew_status CHECK (status IN ('ON_BOARD','SIGNED_OFF'));