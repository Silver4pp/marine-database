-- ============================================================
-- FEATURE SCHEMA: hse
-- file    : feature/15_hse.sql
-- objects : 12 statement(s)
-- generated from original/schema_v1_original.sql by tools/split_schema.py
-- ============================================================

-- ============================================================
-- SECTION 18: HSE SCHEMA TABLES
-- ============================================================

CREATE TABLE hse.incident_type (
    type_code       VARCHAR(30)     PRIMARY KEY,
    type_name       VARCHAR(100)    NOT NULL,
    severity_levels JSONB,
    description     TEXT,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE hse.incident (
    incident_id     BIGSERIAL       PRIMARY KEY,
    incident_no     VARCHAR(30)     NOT NULL UNIQUE,
    incident_type   VARCHAR(30)     NOT NULL
                        REFERENCES hse.incident_type(type_code) ON DELETE RESTRICT,
    severity        VARCHAR(20)     NOT NULL
                        CHECK (severity IN ('LOW','MEDIUM','HIGH','CRITICAL')),
    incident_date   TIMESTAMPTZ     NOT NULL,
    site_code       VARCHAR(30)
                        REFERENCES site.info(site_code) ON DELETE SET NULL,
    location_desc   VARCHAR(200),
    lat             NUMERIC(10,7),
    long            NUMERIC(11,7),
    title           VARCHAR(300)    NOT NULL,
    description     TEXT            NOT NULL,
    immediate_action TEXT,
    root_cause      TEXT,
    corrective_action TEXT,
    preventive_action TEXT,
    status          VARCHAR(30)
                        REFERENCES param.status(status_code) ON DELETE SET NULL,
    reported_by     VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE SET NULL,
    assigned_to     VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE SET NULL,
    approved_by     VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE SET NULL,
    closed_at       TIMESTAMPTZ,
    tenant_id       UUID,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE hse.incident_witness (
    witness_id      BIGSERIAL       PRIMARY KEY,
    incident_id     BIGINT          NOT NULL
                        REFERENCES hse.incident(incident_id) ON DELETE CASCADE,
    witness_name    VARCHAR(150)    NOT NULL,
    witness_contact VARCHAR(100),
    statement       TEXT,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE hse.permit (
    permit_id       BIGSERIAL       PRIMARY KEY,
    permit_no       VARCHAR(30)     NOT NULL UNIQUE,
    permit_type     VARCHAR(50)     NOT NULL,
    work_type       VARCHAR(100)    NOT NULL,
    site_code       VARCHAR(30)
                        REFERENCES site.info(site_code) ON DELETE SET NULL,
    location_desc   VARCHAR(200),
    lat             NUMERIC(10,7),
    long            NUMERIC(11,7),
    description     TEXT,
    start_date      TIMESTAMPTZ     NOT NULL,
    end_date        TIMESTAMPTZ     NOT NULL,
    hazard_analysis TEXT,
    ppe_required    VARCHAR(200),
    status          VARCHAR(30)
                        REFERENCES param.status(status_code) ON DELETE SET NULL,
    applicant       VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE SET NULL,
    approved_by     VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE SET NULL,
    issued_at       TIMESTAMPTZ,
    tenant_id       UUID,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    CONSTRAINT chk_permit_dates CHECK (end_date >= start_date)
);

CREATE TABLE hse.permit_approval (
    approval_id     BIGSERIAL       PRIMARY KEY,
    permit_id       BIGINT          NOT NULL
                        REFERENCES hse.permit(permit_id) ON DELETE CASCADE,
    approver_role   VARCHAR(50)     NOT NULL,
    approver_user   VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE SET NULL,
    decision        VARCHAR(20)     NOT NULL CHECK (decision IN ('APPROVED','REJECTED','CONDITIONAL')),
    comments        TEXT,
    approved_at     TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE hse.inspection (
    inspection_id   BIGSERIAL       PRIMARY KEY,
    inspection_no   VARCHAR(30)     NOT NULL UNIQUE,
    inspection_type VARCHAR(50)      NOT NULL,
    site_code       VARCHAR(30)
                        REFERENCES site.info(site_code) ON DELETE SET NULL,
    work_area_code  VARCHAR(30)
                        REFERENCES operational.work_area(area_code) ON DELETE SET NULL,
    fleet_code      VARCHAR(30)
                        REFERENCES fleet.info(fleet_code) ON DELETE SET NULL,
    inspection_date TIMESTAMPTZ     NOT NULL,
    inspector       VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE SET NULL,
    findings_count  INT             DEFAULT 0,
    compliance_score NUMERIC(5,2),
    status          VARCHAR(30)
                        REFERENCES param.status(status_code) ON DELETE SET NULL,
    summary         TEXT,
    tenant_id       UUID,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE hse.inspection_finding (
    finding_id      BIGSERIAL       PRIMARY KEY,
    inspection_id   BIGINT          NOT NULL
                        REFERENCES hse.inspection(inspection_id) ON DELETE CASCADE,
    finding_no      INT             NOT NULL,
    category        VARCHAR(50)     NOT NULL,
    severity        VARCHAR(20)     NOT NULL CHECK (severity IN ('LOW','MEDIUM','HIGH','CRITICAL')),
    description     TEXT            NOT NULL,
    location_desc   VARCHAR(200),
    corrective_action TEXT,
    due_date        DATE,
    status          VARCHAR(30)
                        REFERENCES param.status(status_code) ON DELETE SET NULL,
    assigned_to     VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE SET NULL,
    closed_at       TIMESTAMPTZ,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    CONSTRAINT uq_inspection_finding UNIQUE (inspection_id, finding_no)
);

CREATE TABLE hse.training (
    training_id     BIGSERIAL       PRIMARY KEY,
    training_code   VARCHAR(30)     NOT NULL UNIQUE,
    training_name   VARCHAR(200)    NOT NULL,
    training_type   VARCHAR(50)     NOT NULL,
    description     TEXT,
    duration_hours  NUMERIC(6,2),
    valid_for_days  INT,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE hse.employee_training (
    record_id       BIGSERIAL       PRIMARY KEY,
    user_code       VARCHAR(30)     NOT NULL
                        REFERENCES "user".info(user_code) ON DELETE CASCADE,
    training_id     BIGINT          NOT NULL
                        REFERENCES hse.training(training_id) ON DELETE RESTRICT,
    training_date   DATE            NOT NULL,
    expiry_date     DATE,
    score           NUMERIC(5,2),
    certificate_no  VARCHAR(50),
    certificate_file VARCHAR(200),
    status          VARCHAR(30)
                        REFERENCES param.status(status_code) ON DELETE SET NULL,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE hse.ppe_inventory (
    ppe_id          BIGSERIAL       PRIMARY KEY,
    ppe_code        VARCHAR(30)     NOT NULL UNIQUE,
    ppe_name        VARCHAR(150)    NOT NULL,
    category        VARCHAR(50)      NOT NULL,
    size            VARCHAR(20),
    color           VARCHAR(30),
    quantity_total  INT             NOT NULL DEFAULT 0,
    quantity_available INT          NOT NULL DEFAULT 0,
    quantity_in_use INT             NOT NULL DEFAULT 0,
    site_code       VARCHAR(30)
                        REFERENCES site.info(site_code) ON DELETE SET NULL,
    storage_location VARCHAR(100),
    reorder_level   INT,
    tenant_id       UUID,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE hse.ppe_distribution (
    dist_id         BIGSERIAL       PRIMARY KEY,
    user_code       VARCHAR(30)     NOT NULL
                        REFERENCES "user".info(user_code) ON DELETE CASCADE,
    ppe_id          BIGINT          NOT NULL
                        REFERENCES hse.ppe_inventory(ppe_id) ON DELETE RESTRICT,
    quantity        INT             NOT NULL DEFAULT 1,
    issue_date      DATE            NOT NULL,
    return_date     DATE,
    condition_when_issue VARCHAR(30),
    condition_when_return VARCHAR(30),
    issued_by       VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE SET NULL,
    notes           TEXT,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE hse.risk_assessment (
    assessment_id   BIGSERIAL       PRIMARY KEY,
    assessment_no   VARCHAR(30)     NOT NULL UNIQUE,
    activity_name  VARCHAR(200)    NOT NULL,
    site_code       VARCHAR(30)
                        REFERENCES site.info(site_code) ON DELETE SET NULL,
    assessment_date DATE            NOT NULL,
    assessor        VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE SET NULL,
    risk_level     VARCHAR(20)
                        CHECK (risk_level IN ('LOW','MEDIUM','HIGH','CRITICAL')),
    hazard_identified TEXT,
    risk_controls   TEXT,
    residual_risk   TEXT,
    status          VARCHAR(30)
                        REFERENCES param.status(status_code) ON DELETE SET NULL,
    approved_by     VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE SET NULL,
    tenant_id       UUID,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);
