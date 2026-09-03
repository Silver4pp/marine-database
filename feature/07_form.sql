-- ============================================================
-- FEATURE SCHEMA: form
-- file    : feature/07_form.sql
-- objects : 5 statement(s)
-- generated from original/schema_v1_original.sql by tools/split_schema.py
-- ============================================================

-- ============================================================
-- SECTION 10: FORM SCHEMA TABLES
-- ============================================================

CREATE TABLE form.water_sampling (
    form_no         VARCHAR(30)     PRIMARY KEY,
    form_type       VARCHAR(50)     NOT NULL DEFAULT 'WATER_SAMPLING',
    sampling_date   DATE            NOT NULL,
    total_sample    INT             NOT NULL DEFAULT 0 CHECK (total_sample >= 0),
    recorder_by     VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE SET NULL,
    received_by     VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE SET NULL,
    status          VARCHAR(30)
                        REFERENCES param.status(status_code) ON DELETE SET NULL,
    site_code       VARCHAR(30)
                        REFERENCES site.info(site_code) ON DELETE SET NULL,
    weather         VARCHAR(50),
    temperature     NUMERIC(8,2),
    humidity        NUMERIC(5,2),
    notes           TEXT,
    approved_by     VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE SET NULL,
    approved_at     TIMESTAMPTZ,
    tenant_id       UUID,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE form.sample (
    sample_id       BIGSERIAL       PRIMARY KEY,
    form_no         VARCHAR(30)     NOT NULL
                        REFERENCES form.water_sampling(form_no) ON DELETE CASCADE,
    sample_no       INT             NOT NULL,
    type_sample     VARCHAR(50)     NOT NULL,
    source_location VARCHAR(200),
    depth           NUMERIC(10,2),
    volume          NUMERIC(10,2),
    container_type  VARCHAR(50),
    preservation    VARCHAR(100),
    description     TEXT,
    status          VARCHAR(30)
                        REFERENCES param.status(status_code) ON DELETE SET NULL,
    received_at     TIMESTAMPTZ,
    analyzed_at     TIMESTAMPTZ,
    tenant_id       UUID,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    CONSTRAINT uq_sample_per_form UNIQUE (form_no, sample_no)
);

CREATE TABLE form.measurement (
    id              BIGSERIAL       PRIMARY KEY,
    form_no         VARCHAR(30)     NOT NULL
                        REFERENCES form.water_sampling(form_no) ON DELETE CASCADE,
    sample_id       BIGINT          NOT NULL
                        REFERENCES form.sample(sample_id) ON DELETE CASCADE,
    parameter_name  VARCHAR(100)    NOT NULL,
    parameter_value NUMERIC(18,6),
    uom_code        VARCHAR(20)
                        REFERENCES param.unit_of_measure(uom_code) ON DELETE SET NULL,
    method          VARCHAR(100),
    equipment_id    VARCHAR(50),
    analyst         VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE SET NULL,
    status          VARCHAR(30)
                        REFERENCES param.status(status_code) ON DELETE SET NULL,
    is_exceed       BOOLEAN         DEFAULT FALSE,
    notes           TEXT,
    tenant_id       UUID,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    CONSTRAINT uq_form_measurement UNIQUE (form_no, sample_id, parameter_name)
);

-- Form: Auto-update sample count
CREATE OR REPLACE FUNCTION form.fn_update_sample_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE form.water_sampling SET total_sample = total_sample + 1 WHERE form_no = NEW.form_no;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE form.water_sampling SET total_sample = total_sample - 1 WHERE form_no = OLD.form_no;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Form: Auto-update sample count
CREATE OR REPLACE TRIGGER trg_update_sample_count
AFTER INSERT OR DELETE ON form.sample
FOR EACH ROW EXECUTE FUNCTION form.fn_update_sample_count();
