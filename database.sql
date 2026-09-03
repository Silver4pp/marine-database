-- ============================================================
-- ADDITIONAL DATABASE FEATURES
-- 1. Security & Row Level Security (RLS)
-- 2. Audit Trail System
-- 3. Workflow Engine
-- 4. Document Management
-- 5. Table Partitioning
-- ============================================================

-- ============================================================
-- PART 1: SECURITY & ROW LEVEL SECURITY (RLS)
-- ============================================================

-- Create application role for different access levels
DO $$
BEGIN
    -- Super Admin - Full access
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'app_super_admin') THEN
        CREATE ROLE app_super_admin NOLOGIN;
    END IF;
    
    -- Admin - Full access within their scope
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'app_admin') THEN
        CREATE ROLE app_admin NOLOGIN;
    END IF;
    
    -- Manager - Read/Write with approval
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'app_manager') THEN
        CREATE ROLE app_manager NOLOGIN;
    END IF;
    
    -- Operator - Read/Write without approval
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'app_operator') THEN
        CREATE ROLE app_operator NOLOGIN;
    END IF;
    
    -- Viewer - Read only
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'app_viewer') THEN
        CREATE ROLE app_viewer NOLOGIN;
    END IF;
    
    -- API Service - For external integrations
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'app_service') THEN
        CREATE ROLE app_service NOLOGIN;
    END IF;
END
$$;

-- Create tenant/site based access control
CREATE SCHEMA IF NOT EXISTS security;

CREATE TABLE security.tenant (
    tenant_id       UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_code      VARCHAR(30)     NOT NULL UNIQUE,
    tenant_name     VARCHAR(200)    NOT NULL,
    site_code       VARCHAR(30)
                        REFERENCES site.info(site_code) ON DELETE SET NULL,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE security.user_tenant_assignment (
    id              BIGSERIAL       PRIMARY KEY,
    user_code       VARCHAR(30)     NOT NULL
                        REFERENCES "user".info(user_code) ON DELETE CASCADE,
    tenant_id       UUID            NOT NULL
                        REFERENCES security.tenant(tenant_id) ON DELETE CASCADE,
    role_name       VARCHAR(50)     NOT NULL,
    is_primary      BOOLEAN         NOT NULL DEFAULT FALSE,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    
    CONSTRAINT uq_user_tenant UNIQUE (user_code, tenant_id)
);

CREATE TABLE security.permission (
    permission_id   BIGSERIAL       PRIMARY KEY,
    permission_code VARCHAR(100)    NOT NULL UNIQUE,
    permission_name VARCHAR(200)    NOT NULL,
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

-- Enable RLS on tables
ALTER TABLE security.tenant ENABLE ROW LEVEL SECURITY;
ALTER TABLE security.user_tenant_assignment ENABLE ROW LEVEL SECURITY;

-- RLS Policies for security schema
CREATE POLICY tenant_isolation_policy ON security.tenant
    USING (tenant_id = current_setting('app.current_tenant_id', TRUE)::UUID);

CREATE POLICY user_tenant_isolation_policy ON security.user_tenant_assignment
    USING (tenant_id = current_setting('app.current_tenant_id', TRUE)::UUID);

-- Add tenant_id to all main tables for multi-tenant support
ALTER TABLE form.water_sampling ADD COLUMN tenant_id UUID;
ALTER TABLE form.sample ADD COLUMN tenant_id UUID;
ALTER TABLE form.measurement ADD COLUMN tenant_id UUID;
ALTER TABLE commercial.purchase_order ADD COLUMN tenant_id UUID;
ALTER TABLE commercial.delivery_order ADD COLUMN tenant_id UUID;
ALTER TABLE operational.shipment_instruction ADD COLUMN tenant_id UUID;
ALTER TABLE operational.work_activity ADD COLUMN tenant_id UUID;
ALTER TABLE operational.dredging_records ADD COLUMN tenant_id UUID;
ALTER TABLE hse.incident ADD COLUMN tenant_id UUID;
ALTER TABLE hse.inspection ADD COLUMN tenant_id UUID;
ALTER TABLE hse.permit ADD COLUMN tenant_id UUID;
ALTER TABLE financial.invoice ADD COLUMN tenant_id UUID;
ALTER TABLE financial.journal ADD COLUMN tenant_id UUID;
ALTER TABLE financial.payment ADD COLUMN tenant_id UUID;

-- Enable RLS on main tables
ALTER TABLE form.water_sampling ENABLE ROW LEVEL SECURITY;
ALTER TABLE commercial.purchase_order ENABLE ROW LEVEL SECURITY;
ALTER TABLE commercial.delivery_order ENABLE ROW LEVEL SECURITY;
ALTER TABLE operational.shipment_instruction ENABLE ROW LEVEL SECURITY;
ALTER TABLE operational.work_activity ENABLE ROW LEVEL SECURITY;
ALTER TABLE operational.dredging_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE hse.incident ENABLE ROW LEVEL SECURITY;
ALTER TABLE hse.inspection ENABLE ROW LEVEL SECURITY;
ALTER TABLE hse.permit ENABLE ROW LEVEL SECURITY;
ALTER TABLE financial.invoice ENABLE ROW LEVEL SECURITY;
ALTER TABLE financial.journal ENABLE ROW LEVEL SECURITY;
ALTER TABLE financial.payment ENABLE ROW LEVEL SECURITY;

-- RLS Policies for main tables
CREATE POLICY tenant_isolation_form ON form.water_sampling
    FOR ALL USING (tenant_id = current_setting('app.current_tenant_id', TRUE)::UUID);

CREATE POLICY tenant_isolation_po ON commercial.purchase_order
    FOR ALL USING (tenant_id = current_setting('app.current_tenant_id', TRUE)::UUID);

CREATE POLICY tenant_isolation_do ON commercial.delivery_order
    FOR ALL USING (tenant_id = current_setting('app.current_tenant_id', TRUE)::UUID);

CREATE POLICY tenant_isolation_si ON operational.shipment_instruction
    FOR ALL USING (tenant_id = current_setting('app.current_tenant_id', TRUE)::UUID);

CREATE POLICY tenant_isolation_activity ON operational.work_activity
    FOR ALL USING (tenant_id = current_setting('app.current_tenant_id', TRUE)::UUID);

CREATE POLICY tenant_isolation_dredging ON operational.dredging_records
    FOR ALL USING (tenant_id = current_setting('app.current_tenant_id', TRUE)::UUID);

CREATE POLICY tenant_isolation_incident ON hse.incident
    FOR ALL USING (tenant_id = current_setting('app.current_tenant_id', TRUE)::UUID);

CREATE POLICY tenant_isolation_inspection ON hse.inspection
    FOR ALL USING (tenant_id = current_setting('app.current_tenant_id', TRUE)::UUID);

CREATE POLICY tenant_isolation_permit ON hse.permit
    FOR ALL USING (tenant_id = current_setting('app.current_tenant_id', TRUE)::UUID);

CREATE POLICY tenant_isolation_invoice ON financial.invoice
    FOR ALL USING (tenant_id = current_setting('app.current_tenant_id', TRUE)::UUID);

CREATE POLICY tenant_isolation_journal ON financial.journal
    FOR ALL USING (tenant_id = current_setting('app.current_tenant_id', TRUE)::UUID);

CREATE POLICY tenant_isolation_payment ON financial.payment
    FOR ALL USING (tenant_id = current_setting('app.current_tenant_id', TRUE)::UUID);

-- Grant roles
GRANT USAGE ON SCHEMA security TO app_super_admin, app_admin, app_manager, app_operator, app_viewer, app_service;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA security TO app_super_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA security TO app_admin;
GRANT SELECT ON ALL TABLES IN SCHEMA security TO app_manager;
GRANT SELECT ON ALL TABLES IN SCHEMA security TO app_operator;
GRANT SELECT ON ALL TABLES IN SCHEMA security TO app_viewer;

-- ============================================================
-- PART 2: AUDIT TRAIL SYSTEM
-- ============================================================

CREATE SCHEMA IF NOT EXISTS audit;

CREATE TABLE audit.log (
    log_id          BIGSERIAL       PRIMARY KEY,
    session_id      UUID,
    user_code       VARCHAR(30),
    user_name       VARCHAR(150),
    action          VARCHAR(10)     NOT NULL, -- INSERT, UPDATE, DELETE, SELECT
    table_schema    VARCHAR(100)    NOT NULL,
    table_name      VARCHAR(100)    NOT NULL,
    record_id       TEXT,
    old_data        JSONB,
    new_data        JSONB,
    changed_fields  JSONB,
    ip_address      INET,
    user_agent      TEXT,
    app_version     VARCHAR(50),
    request_id      UUID,
    executed_at     TIMESTAMPTZ     NOT NULL DEFAULT now(),
    execution_time  INTERVAL
);

CREATE INDEX idx_audit_log_schema_table ON audit.log(table_schema, table_name);
CREATE INDEX idx_audit_log_user ON audit.log(user_code, executed_at DESC);
CREATE INDEX idx_audit_log_record ON audit.log(table_schema, table_name, record_id);
CREATE INDEX idx_audit_log_time ON audit.log(executed_at DESC);
CREATE INDEX idx_audit_log_action ON audit.log(action);

-- Function to create audit trigger
CREATE OR REPLACE FUNCTION audit.fn_create_audit_trigger(
    p_table_schema TEXT,
    p_table_name TEXT
) RETURNS VOID AS $$
DECLARE
    v_trigger_name TEXT := 'trg_audit_' || p_table_name;
    v_func_name TEXT := 'audit.fn_' || p_table_name || '_audit';
BEGIN
    -- Create audit function for specific table
    EXECUTE format(
        'CREATE OR REPLACE FUNCTION %I.%I() RETURNS TRIGGER AS $$
        BEGIN
            IF TG_OP = ''INSERT'' THEN
                INSERT INTO audit.log (action, table_schema, table_name, record_id, new_data, user_code, session_id)
                VALUES (''INSERT'', %L, %L, COALESCE(NEW.id::TEXT, NEW.%s::TEXT), row_to_json(NEW)::jsonb, 
                        current_setting(''app.current_user'', TRUE), 
                        current_setting(''app.session_id'', TRUE)::uuid);
                RETURN NEW;
            ELSIF TG_OP = ''UPDATE'' THEN
                INSERT INTO audit.log (action, table_schema, table_name, record_id, old_data, new_data, changed_fields, user_code, session_id)
                VALUES (''UPDATE'', %L, %L, COALESCE(NEW.id::TEXT, NEW.%s::TEXT), row_to_json(OLD)::jsonb, row_to_json(NEW)::jsonb,
                        (SELECT jsonb_object_agg(key, value) FROM jsonb_each(row_to_json(NEW)) n(key, value)
                         JOIN jsonb_each(row_to_json(OLD)) o(key, value) ON n.key = o.key WHERE n.value <> o.value),
                        current_setting(''app.current_user'', TRUE),
                        current_setting(''app.session_id'', TRUE)::uuid);
                RETURN NEW;
            ELSIF TG_OP = ''DELETE'' THEN
                INSERT INTO audit.log (action, table_schema, table_name, record_id, old_data, user_code, session_id)
                VALUES (''DELETE'', %L, %L, COALESCE(OLD.id::TEXT, OLD.%s::TEXT), row_to_json(OLD)::jsonb,
                        current_setting(''app.current_user'', TRUE),
                        current_setting(''app.session_id'', TRUE)::uuid);
                RETURN OLD;
            END IF;
        END;
        $$ LANGUAGE plpgsql;',
        p_table_schema, v_func_name,
        p_table_schema, p_table_name, 
        CASE WHEN p_table_name = 'ledger_hist' THEN 'id' ELSE (SELECT a.attname FROM pg_attribute a JOIN pg_class c ON c.oid = a.attrelid WHERE c.relname = p_table_name AND a.attnum = 1) END,
        p_table_schema, p_table_name,
        CASE WHEN p_table_name = 'ledger_hist' THEN 'id' ELSE (SELECT a.attname FROM pg_attribute a JOIN pg_class c ON c.oid = a.attrelid WHERE c.relname = p_table_name AND a.attnum = 1) END,
        p_table_schema, p_table_name,
        CASE WHEN p_table_name = 'ledger_hist' THEN 'id' ELSE (SELECT a.attname FROM pg_attribute a JOIN pg_class c ON c.oid = a.attrelid WHERE c.relname = p_table_name AND a.attnum = 1) END
    );
    
    -- Create trigger
    EXECUTE format(
        'DROP TRIGGER IF EXISTS %I ON %I.%I',
        v_trigger_name, p_table_schema, p_table_name
    );
    
    EXECUTE format(
        'CREATE TRIGGER %I AFTER INSERT OR UPDATE OR DELETE ON %I.%I
         FOR EACH ROW EXECUTE FUNCTION %I.%I()',
        v_trigger_name, p_table_schema, p_table_name, p_table_schema, v_func_name
    );
END;
$$ LANGUAGE plpgsql;

-- Create audit triggers for important tables
SELECT audit.fn_create_audit_trigger('form', 'water_sampling');
SELECT audit.fn_create_audit_trigger('form', 'sample');
SELECT audit.fn_create_audit_trigger('form', 'measurement');
SELECT audit.fn_create_audit_trigger('commercial', 'purchase_order');
SELECT audit.fn_create_audit_trigger('commercial', 'delivery_order');
SELECT audit.fn_create_audit_trigger('operational', 'shipment_instruction');
SELECT audit.fn_create_audit_trigger('operational', 'work_activity');
SELECT audit.fn_create_audit_trigger('operational', 'dredging_records');
SELECT audit.fn_create_audit_trigger('financial', 'journal');
SELECT audit.fn_create_audit_trigger('financial', 'journal_line');
SELECT audit.fn_create_audit_trigger('financial', 'invoice');
SELECT audit.fn_create_audit_trigger('financial', 'payment');
SELECT audit.fn_create_audit_trigger('hse', 'incident');
SELECT audit.fn_create_audit_trigger('hse', 'inspection');
SELECT audit.fn_create_audit_trigger('hse', 'permit');
SELECT audit.fn_create_audit_trigger('buyer', 'ledger_hist');
SELECT audit.fn_create_audit_trigger('fleet', 'info');
SELECT audit.fn_create_audit_trigger('enviro', 'station');

-- View: Audit Summary
CREATE OR REPLACE VIEW audit.v_audit_summary AS
SELECT 
    table_schema,
    table_name,
    action,
    COUNT(*) AS change_count,
    COUNT(DISTINCT user_code) AS unique_users,
    MIN(executed_at) AS first_change,
    MAX(executed_at) AS last_change
FROM audit.log
GROUP BY table_schema, table_name, action
ORDER BY MAX(executed_at) DESC;

-- View: Recent Changes by User
CREATE OR REPLACE VIEW audit.v_user_recent_changes AS
SELECT 
    user_code,
    user_name,
    table_schema,
    table_name,
    action,
    record_id,
    changed_fields,
    executed_at
FROM audit.log
WHERE executed_at > now() - INTERVAL '24 hours'
ORDER BY executed_at DESC;

-- ============================================================
-- PART 3: WORKFLOW ENGINE
-- ============================================================

CREATE SCHEMA IF NOT EXISTS workflow;

CREATE TABLE workflow.definition (
    workflow_id     BIGSERIAL       PRIMARY KEY,
    workflow_code   VARCHAR(50)     NOT NULL UNIQUE,
    workflow_name   VARCHAR(200)    NOT NULL,
    module          VARCHAR(50)     NOT NULL,
    description     TEXT,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE workflow.step (
    step_id         BIGSERIAL       PRIMARY KEY,
    workflow_id     BIGINT          NOT NULL
                        REFERENCES workflow.definition(workflow_id) ON DELETE CASCADE,
    step_order      SMALLINT        NOT NULL,
    step_name       VARCHAR(100)    NOT NULL,
    step_type       VARCHAR(30)     NOT NULL
                        CHECK (step_type IN ('START','APPROVAL','REJECTION','CONDITION','NOTIFICATION','END')),
    approver_role   VARCHAR(50),
    approver_user   VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE SET NULL,
    is_auto_approve BOOLEAN         DEFAULT FALSE,
    timeout_hours   INT,
    required_approval_count INT DEFAULT 1,
    can_skip        BOOLEAN         DEFAULT FALSE,
    next_step_on_approve INT,
    next_step_on_reject INT,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE workflow.instance (
    instance_id     BIGSERIAL       PRIMARY KEY,
    instance_code   VARCHAR(50)     NOT NULL UNIQUE,
    workflow_id     BIGINT          NOT NULL
                        REFERENCES workflow.definition(workflow_id) ON DELETE RESTRICT,
    document_type   VARCHAR(50)     NOT NULL,
    document_id     VARCHAR(50)     NOT NULL,
    current_step    INT             NOT NULL DEFAULT 1,
    status          VARCHAR(30)     NOT NULL
                        CHECK (status IN ('PENDING','IN_PROGRESS','APPROVED','REJECTED','CANCELLED','EXPIRED')),
    initiated_by    VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE SET NULL,
    initiated_at    TIMESTAMPTZ     NOT NULL DEFAULT now(),
    completed_at    TIMESTAMPTZ,
    due_date        TIMESTAMPTZ,
    priority        VARCHAR(20)     DEFAULT 'NORMAL',
    notes           TEXT,
    metadata        JSONB,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE workflow.instance_step (
    instance_step_id BIGSERIAL      PRIMARY KEY,
    instance_id     BIGINT          NOT NULL
                        REFERENCES workflow.instance(instance_id) ON DELETE CASCADE,
    step_id         BIGINT          NOT NULL
                        REFERENCES workflow.step(step_id) ON DELETE RESTRICT,
    step_order      SMALLINT        NOT NULL,
    status          VARCHAR(30)     NOT NULL
                        CHECK (status IN ('PENDING','IN_PROGRESS','APPROVED','REJECTED','SKIPPED')),
    started_at      TIMESTAMPTZ,
    completed_at    TIMESTAMPTZ,
    due_at          TIMESTAMPTZ,
    assigned_to     VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE SET NULL,
    comments        TEXT,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    
    CONSTRAINT uq_instance_step UNIQUE (instance_id, step_order)
);

CREATE TABLE workflow.approval (
    approval_id     BIGSERIAL       PRIMARY KEY,
    instance_step_id BIGINT         NOT NULL
                        REFERENCES workflow.instance_step(instance_step_id) ON DELETE CASCADE,
    approver_user   VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE SET NULL,
    approver_name   VARCHAR(150),
    decision        VARCHAR(20)     NOT NULL
                        CHECK (decision IN ('APPROVED','REJECTED','CONDITIONAL')),
    comments        TEXT,
    sequence_no     SMALLINT        NOT NULL,
    decided_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    ip_address      INET,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE workflow.history (
    history_id      BIGSERIAL       PRIMARY KEY,
    instance_id     BIGINT          NOT NULL
                        REFERENCES workflow.instance(instance_id) ON DELETE CASCADE,
    action          VARCHAR(50)     NOT NULL,
    from_step       INT,
    to_step         INT,
    performed_by    VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE SET NULL,
    performed_at    TIMESTAMPTZ     NOT NULL DEFAULT now(),
    details         JSONB
);

-- Workflow for Purchase Order
INSERT INTO workflow.definition (workflow_code, workflow_name, module, description) VALUES
('WF_PO_APPROVAL', 'Purchase Order Approval', 'COMMERCIAL', 'Approval workflow for Purchase Orders');

INSERT INTO workflow.step (workflow_id, step_order, step_name, step_type, approver_role, is_auto_approve, timeout_hours, next_step_on_approve, next_step_on_reject) 
SELECT wf.workflow_id, 1, 'Manager Review', 'APPROVAL', 'MANAGER', FALSE, 24, 2, NULL
FROM workflow.definition wf WHERE wf.workflow_code = 'WF_PO_APPROVAL';

INSERT INTO workflow.step (workflow_id, step_order, step_name, step_type, approver_role, timeout_hours, next_step_on_approve, next_step_on_reject) 
SELECT wf.workflow_id, 2, 'Director Approval', 'APPROVAL', 'DIRECTOR', 48, 3, NULL
FROM workflow.definition wf WHERE wf.workflow_code = 'WF_PO_APPROVAL';

INSERT INTO workflow.step (workflow_id, step_order, step_name, step_type, next_step_on_approve) 
SELECT wf.workflow_id, 3, 'Finalize', 'END', NULL, NULL
FROM workflow.definition wf WHERE wf.workflow_code = 'WF_PO_APPROVAL';

-- Workflow for HSE Incident
INSERT INTO workflow.definition (workflow_code, workflow_name, module, description) VALUES
('WF_INCIDENT', 'Incident Investigation Workflow', 'HSE', 'Workflow for HSE incident investigation and closure');

INSERT INTO workflow.step (workflow_id, step_order, step_name, step_type, approver_role, timeout_hours, next_step_on_approve, next_step_on_reject) 
SELECT wf.workflow_id, 1, 'Initial Report', 'START', NULL, 0, 2, NULL
FROM workflow.definition wf WHERE wf.workflow_code = 'WF_INCIDENT';

INSERT INTO workflow.step (workflow_id, step_order, step_name, step_type, approver_role, timeout_hours, next_step_on_approve, next_step_on_reject) 
SELECT wf.workflow_id, 2, 'Safety Officer Review', 'APPROVAL', 'SAFETY_OFFICER', 24, 3, NULL
FROM workflow.definition wf WHERE wf.workflow_code = 'WF_INCIDENT';

INSERT INTO workflow.step (workflow_id, step_order, step_name, step_type, approver_role, timeout_hours, next_step_on_approve, next_step_on_reject) 
SELECT wf.workflow_id, 3, 'Manager Approval', 'APPROVAL', 'MANAGER', 48, 4, NULL
FROM workflow.definition wf WHERE wf.workflow_code = 'WF_INCIDENT';

INSERT INTO workflow.step (workflow_id, step_order, step_name, step_type, next_step_on_approve) 
SELECT wf.workflow_id, 4, 'Close Incident', 'END', NULL, NULL
FROM workflow.definition wf WHERE wf.workflow_code = 'WF_INCIDENT';

-- Function to start workflow instance
CREATE OR REPLACE FUNCTION workflow.fn_start_instance(
    p_workflow_code VARCHAR,
    p_document_type VARCHAR,
    p_document_id VARCHAR,
    p_initiated_by VARCHAR,
    p_priority VARCHAR DEFAULT 'NORMAL'
) RETURNS BIGINT AS $$
DECLARE
    v_workflow_id   BIGINT;
    v_instance_id   BIGINT;
    v_first_step    BIGINT;
    v_instance_code VARCHAR;
BEGIN
    -- Get workflow definition
    SELECT workflow_id INTO v_workflow_id
    FROM workflow.definition
    WHERE workflow_code = p_workflow_code AND is_active = TRUE;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Workflow not found: %', p_workflow_code;
    END IF;
    
    -- Get first step
    SELECT step_id INTO v_first_step
    FROM workflow.step
    WHERE workflow_id = v_workflow_id AND step_order = 1 AND is_active = TRUE;
    
    -- Generate instance code
    v_instance_code := p_workflow_code || '_' || p_document_id || '_' || TO_CHAR(now(), 'YYYYMMDDHH24MISS');
    
    -- Create instance
    INSERT INTO workflow.instance (
        instance_code, workflow_id, document_type, document_id,
        current_step, status, initiated_by, due_date, priority
    ) VALUES (
        v_instance_code, v_workflow_id, p_document_type, p_document_id,
        1, 'IN_PROGRESS', p_initiated_by, 
        now() + INTERVAL '7 days', p_priority
    ) RETURNING instance_id INTO v_instance_id;
    
    -- Create first step instance
    INSERT INTO workflow.instance_step (
        instance_id, step_id, step_order, status, started_at, assigned_to
    ) VALUES (
        v_instance_id, v_first_step, 1, 'IN_PROGRESS', now(),
        (SELECT approver_user FROM workflow.step WHERE step_id = v_first_step)
    );
    
    RETURN v_instance_id;
END;
$$ LANGUAGE plpgsql;

-- Function to approve/reject workflow step
CREATE OR REPLACE FUNCTION workflow.fn_process_step(
    p_instance_id BIGINT,
    p_approver_user VARCHAR,
    p_decision VARCHAR,
    p_comments TEXT DEFAULT NULL
) RETURNS BOOLEAN AS $$
DECLARE
    v_instance      RECORD;
    v_current_step  RECORD;
    v_next_step     BIGINT;
    v_approval_count INT;
BEGIN
    -- Get instance info
    SELECT * INTO v_instance FROM workflow.instance WHERE instance_id = p_instance_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Instance not found: %', p_instance_id;
    END IF;
    
    -- Get current step info
    SELECT * INTO v_current_step 
    FROM workflow.instance_step
    WHERE instance_id = p_instance_id AND step_order = v_instance.current_step;
    
    -- Count existing approvals
    SELECT COUNT(*) INTO v_approval_count
    FROM workflow.approval
    WHERE instance_step_id = v_current_step.instance_step_id;
    
    -- Add approval record
    INSERT INTO workflow.approval (
        instance_step_id, approver_user, decision, comments, sequence_no
    ) VALUES (
        v_current_step.instance_step_id, p_approver_user, p_decision, p_comments, v_approval_count + 1
    );
    
    -- Check if step is complete
    IF p_decision = 'APPROVED' THEN
        -- Update current step
        UPDATE workflow.instance_step
        SET status = 'APPROVED', completed_at = now()
        WHERE instance_step_id = v_current_step.instance_step_id;
        
        -- Get next step
        SELECT next_step_on_approve INTO v_next_step
        FROM workflow.step
        WHERE step_id = v_current_step.step_id;
        
        IF v_next_step IS NULL THEN
            -- Workflow complete
            UPDATE workflow.instance
            SET status = 'APPROVED', current_step = 0, completed_at = now()
            WHERE instance_id = p_instance_id;
            
            -- Add to history
            INSERT INTO workflow.history (instance_id, action, from_step, performed_by, details)
            VALUES (p_instance_id, 'COMPLETED', v_current_step.step_order, p_approver_user, 
                    jsonb_build_object('decision', p_decision));
        ELSE
            -- Move to next step
            UPDATE workflow.instance
            SET current_step = v_next_step
            WHERE instance_id = p_instance_id;
            
            -- Create new step instance
            INSERT INTO workflow.instance_step (
                instance_id, step_id, step_order, status, started_at, assigned_to
            ) VALUES (
                p_instance_id, v_next_step, 
                (SELECT step_order FROM workflow.step WHERE step_id = v_next_step),
                'IN_PROGRESS', now(),
                (SELECT approver_user FROM workflow.step WHERE step_id = v_next_step)
            );
            
            -- Add to history
            INSERT INTO workflow.history (instance_id, action, from_step, to_step, performed_by, details)
            VALUES (p_instance_id, 'APPROVED', v_current_step.step_order, v_next_step, p_approver_user,
                    jsonb_build_object('decision', p_decision, 'comments', p_comments));
        END IF;
        
    ELSIF p_decision = 'REJECTED' THEN
        -- Update current step
        UPDATE workflow.instance_step
        SET status = 'REJECTED', completed_at = now()
        WHERE instance_step_id = v_current_step.instance_step_id;
        
        -- Update instance status
        UPDATE workflow.instance
        SET status = 'REJECTED', completed_at = now()
        WHERE instance_id = p_instance_id;
        
        -- Add to history
        INSERT INTO workflow.history (instance_id, action, from_step, performed_by, details)
        VALUES (p_instance_id, 'REJECTED', v_current_step.step_order, p_approver_user,
                jsonb_build_object('decision', p_decision, 'comments', p_comments));
    END IF;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Indexes for workflow
CREATE INDEX idx_workflow_instance_doc ON workflow.instance(document_type, document_id);
CREATE INDEX idx_workflow_instance_status ON workflow.instance(status);
CREATE INDEX idx_workflow_instance_step ON workflow.instance_step(instance_id, step_order);
CREATE INDEX idx_workflow_approval_step ON workflow.approval(instance_step_id);
CREATE INDEX idx_workflow_history_instance ON workflow.history(instance_id);

-- ============================================================
-- PART 4: DOCUMENT MANAGEMENT
-- ============================================================

CREATE SCHEMA IF NOT EXISTS document;

CREATE TABLE document.type (
    type_id         BIGSERIAL       PRIMARY KEY,
    type_code       VARCHAR(50)     NOT NULL UNIQUE,
    type_name       VARCHAR(200)    NOT NULL,
    description     TEXT,
    max_size_kb     INT             DEFAULT 10240, -- 10MB default
    allowed_extensions TEXT,
    category        VARCHAR(50),
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE document.info (
    doc_id          BIGSERIAL       PRIMARY KEY,
    doc_code        VARCHAR(50)     NOT NULL UNIQUE,
    doc_name        VARCHAR(300)    NOT NULL,
    original_name   VARCHAR(300),
    type_code       VARCHAR(50)     NOT NULL
                        REFERENCES document.type(type_code) ON DELETE RESTRICT,
    file_path       VARCHAR(500)    NOT NULL,
    file_size       BIGINT,
    mime_type       VARCHAR(100),
    checksum        VARCHAR(64),
    version         INT             NOT NULL DEFAULT 1,
    parent_doc_id   BIGINT
                        REFERENCES document.info(doc_id) ON DELETE SET NULL,
    document_type   VARCHAR(50)     NOT NULL,
    document_id     VARCHAR(50)     NOT NULL,
    description     TEXT,
    is_latest       BOOLEAN         NOT NULL DEFAULT TRUE,
    status          VARCHAR(30)
                        REFERENCES param.status(status_code) ON DELETE SET NULL,
    uploaded_by     VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE SET NULL,
    approved_by     VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE SET NULL,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE document.permission (
    perm_id         BIGSERIAL       PRIMARY KEY,
    doc_id          BIGINT          NOT NULL
                        REFERENCES document.info(doc_id) ON DELETE CASCADE,
    user_code       VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE CASCADE,
    role_name       VARCHAR(50),
    can_view        BOOLEAN         DEFAULT TRUE,
    can_download    BOOLEAN         DEFAULT TRUE,
    can_edit        BOOLEAN         DEFAULT FALSE,
    can_delete      BOOLEAN         DEFAULT FALSE,
    is_inherited    BOOLEAN         DEFAULT TRUE,
    expires_at      TIMESTAMPTZ,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE document.signature (
    sign_id         BIGSERIAL       PRIMARY KEY,
    doc_id          BIGINT          NOT NULL
                        REFERENCES document.info(doc_id) ON DELETE CASCADE,
    sign_order      SMALLINT        NOT NULL,
    signer_user     VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE SET NULL,
    signer_name     VARCHAR(150),
    signer_role     VARCHAR(50),
    signature_data  TEXT,
    ip_address      INET,
    signed_at      TIMESTAMPTZ,
    is_valid        BOOLEAN,
    reason          VARCHAR(200),
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE document.audit (
    audit_id        BIGSERIAL       PRIMARY KEY,
    doc_id          BIGINT          NOT NULL
                        REFERENCES document.info(doc_id) ON DELETE CASCADE,
    action          VARCHAR(50)     NOT NULL,
    user_code       VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE SET NULL,
    ip_address      INET,
    details         JSONB,
    executed_at     TIMESTAMPTZ     NOT NULL DEFAULT now()
);

-- Insert default document types
INSERT INTO document.type (type_code, type_name, category, max_size_kb, allowed_extensions) VALUES
('CONTRACT', 'Contract Document', 'LEGAL', 20480, '.pdf,.doc,.docx'),
('CERTIFICATE', 'Certificate', 'CERT', 5120, '.pdf,.jpg,.png'),
('REPORT', 'Report Document', 'REPORT', 10240, '.pdf,.xlsx,.docx'),
('IMAGE', 'Image', 'IMAGE', 5120, '.jpg,.jpeg,.png,.gif'),
('DRAWING', 'Technical Drawing', 'TECHNICAL', 20480, '.pdf,.dwg,.dxf'),
('INVOICE_DOC', 'Invoice Document', 'FINANCIAL', 5120, '.pdf'),
('APPROVAL_DOC', 'Approval Document', 'ADMIN', 5120, '.pdf,.doc,.docx'),
('PERMIT_DOC', 'Permit Document', 'HSE', 10240, '.pdf');

-- Function to upload new document version
CREATE OR REPLACE FUNCTION document.fn_upload_version(
    p_doc_code VARCHAR,
    p_doc_name VARCHAR,
    p_type_code VARCHAR,
    p_file_path VARCHAR,
    p_file_size BIGINT,
    p_mime_type VARCHAR,
    p_checksum VARCHAR,
    p_uploaded_by VARCHAR,
    p_description TEXT DEFAULT NULL
) RETURNS BIGINT AS $$
DECLARE
    v_old_doc_id    BIGINT;
    v_new_doc_id    BIGINT;
    v_new_version   INT;
BEGIN
    -- Get current latest document
    SELECT doc_id, version INTO v_old_doc_id, v_new_version
    FROM document.info
    WHERE doc_code = p_doc_code AND is_latest = TRUE;
    
    -- Mark old version as not latest
    IF v_old_doc_id IS NOT NULL THEN
        UPDATE document.info SET is_latest = FALSE WHERE doc_id = v_old_doc_id;
        v_new_version := v_new_version + 1;
    END IF;
    
    -- Insert new version
    INSERT INTO document.info (
        doc_code, doc_name, type_code, file_path, file_size, mime_type,
        checksum, version, parent_doc_id, document_type, document_id,
        description, is_latest, uploaded_by
    ) VALUES (
        p_doc_code, p_doc_name, p_type_code, p_file_path, p_file_size, p_mime_type,
        p_checksum, v_new_version, v_old_doc_id,
        (SELECT document_type FROM document.info WHERE doc_id = v_old_doc_id),
        (SELECT document_id FROM document.info WHERE doc_id = v_old_doc_id),
        p_description, TRUE, p_uploaded_by
    ) RETURNING doc_id INTO v_new_doc_id;
    
    RETURN v_new_doc_id;
END;
$$ LANGUAGE plpgsql;

-- Indexes for document
CREATE INDEX idx_document_info_type ON document.info(type_code);
CREATE INDEX idx_document_info_doc ON document.info(document_type, document_id);
CREATE INDEX idx_document_info_latest ON document.info(doc_code, is_latest) WHERE is_latest = TRUE;
CREATE INDEX idx_document_perm_doc_user ON document.permission(doc_id, user_code);
CREATE INDEX idx_document_signature_doc ON document.signature(doc_id);
CREATE INDEX idx_document_audit_doc ON document.audit(doc_id, executed_at DESC);

-- ============================================================
-- PART 5: TABLE PARTITIONING
-- ============================================================

-- Partition for time-series data: enviro.water_quality
CREATE TABLE enviro.water_quality_partitioned (
    LIKE enviro.water_quality INCLUDING ALL
) PARTITION BY RANGE (record_time);

-- Create partitions for current and next year
CREATE TABLE enviro.water_quality_2025 PARTITION OF enviro.water_quality_partitioned
    FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');

CREATE TABLE enviro.water_quality_2026 PARTITION OF enviro.water_quality_partitioned
    FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');

CREATE TABLE enviro.water_quality_2027 PARTITION OF enviro.water_quality_partitioned
    FOR VALUES FROM ('2027-01-01') TO ('2028-01-01');

-- Swap old table with partitioned table
ALTER TABLE enviro.water_quality RENAME TO water_quality_old;
ALTER TABLE enviro.water_quality_partitioned RENAME TO water_quality;

-- Partition for tide readings
CREATE TABLE enviro.tide_reading_partitioned (
    LIKE enviro.tide_reading INCLUDING ALL
) PARTITION BY RANGE (record_time);

CREATE TABLE enviro.tide_reading_2025 PARTITION OF enviro.tide_reading_partitioned
    FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');

CREATE TABLE enviro.tide_reading_2026 PARTITION OF enviro.tide_reading_partitioned
    FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');

CREATE TABLE enviro.tide_reading_2027 PARTITION OF enviro.tide_reading_partitioned
    FOR VALUES FROM ('2027-01-01') TO ('2028-01-01');

ALTER TABLE enviro.tide_reading RENAME TO tide_reading_old;
ALTER TABLE enviro.tide_reading_partitioned RENAME TO tide_reading;

-- Partition for buoy readings
CREATE TABLE enviro.buoy_reading_partitioned (
    LIKE enviro.buoy_reading INCLUDING ALL
) PARTITION BY RANGE (record_time);

CREATE TABLE enviro.buoy_reading_2025 PARTITION OF enviro.buoy_reading_partitioned
    FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');

CREATE TABLE enviro.buoy_reading_2026 PARTITION OF enviro.buoy_reading_partitioned
    FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');

CREATE TABLE enviro.buoy_reading_2027 PARTITION OF enviro.buoy_reading_partitioned
    FOR VALUES FROM ('2027-01-01') TO ('2028-01-01');

ALTER TABLE enviro.buoy_reading RENAME TO buoy_reading_old;
ALTER TABLE enviro.buoy_reading_partitioned RENAME TO buoy_reading;

-- Partition for voyage data
CREATE TABLE voyage.voyage_partitioned (
    LIKE voyage.voyage INCLUDING ALL
) PARTITION BY RANGE (record_time);

CREATE TABLE voyage.voyage_2025 PARTITION OF voyage.voyage_partitioned
    FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');

CREATE TABLE voyage.voyage_2026 PARTITION OF voyage.voyage_partitioned
    FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');

CREATE TABLE voyage.voyage_2027 PARTITION OF voyage.voyage_partitioned
    FOR VALUES FROM ('2027-01-01') TO ('2028-01-01');

ALTER TABLE voyage.voyage RENAME TO voyage_old;
ALTER TABLE voyage.voyage_partitioned RENAME TO voyage;

-- Partition for voyage history
CREATE TABLE voyage.voyage_hist_partitioned (
    LIKE voyage.voyage_hist INCLUDING ALL
) PARTITION BY RANGE (record_time);

CREATE TABLE voyage.voyage_hist_2025 PARTITION OF voyage.voyage_hist_partitioned
    FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');

CREATE TABLE voyage.voyage_hist_2026 PARTITION OF voyage.voyage_hist_partitioned
    FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');

CREATE TABLE voyage.voyage_hist_2027 PARTITION OF voyage.voyage_hist_partitioned
    FOR VALUES FROM ('2027-01-01') TO ('2028-01-01');

ALTER TABLE voyage.voyage_hist RENAME TO voyage_hist_old;
ALTER TABLE voyage.voyage_hist_partitioned RENAME TO voyage.voyage_hist;

-- Partition for audit log
CREATE TABLE audit.log_partitioned (
    LIKE audit.log INCLUDING ALL
) PARTITION BY RANGE (executed_at);

CREATE TABLE audit.log_2025 PARTITION OF audit.log_partitioned
    FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');

CREATE TABLE audit.log_2026 PARTITION OF audit.log_partitioned
    FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');

CREATE TABLE audit.log_2027 PARTITION OF audit.log_partitioned
    FOR VALUES FROM ('2027-01-01') TO ('2028-01-01');

ALTER TABLE audit.log RENAME TO log_old;
ALTER TABLE audit.log_partitioned RENAME TO audit.log;

-- Function to create new partition automatically
CREATE OR REPLACE FUNCTION audit.fn_create_partition(
    p_schema_name TEXT,
    p_table_name TEXT,
    p_year INT
) RETURNS VOID AS $$
DECLARE
    v_partition_name TEXT := p_table_name || '_' || p_year;
    v_start_date TEXT := p_year || '-01-01';
    v_end_date TEXT := (p_year + 1) || '-01-01';
BEGIN
    EXECUTE format(
        'CREATE TABLE %I.%I PARTITION OF %I.%I
         FOR VALUES FROM (%L) TO (%L)',
        p_schema_name, v_partition_name,
        p_schema_name, p_table_name,
        v_start_date, v_end_date
    );
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- ADDITIONAL USEFUL FUNCTIONS
-- ============================================================

-- Function to set session context
CREATE OR REPLACE FUNCTION public.fn_set_session_context(
    p_user_code VARCHAR,
    p_tenant_id UUID,
    p_session_id UUID DEFAULT gen_random_uuid()
) RETURNS VOID AS $$
BEGIN
    PERFORM set_config('app.current_user', p_user_code, TRUE);
    PERFORM set_config('app.current_tenant_id', p_tenant_id::TEXT, TRUE);
    PERFORM set_config('app.session_id', p_session_id::TEXT, TRUE);
END;
$$ LANGUAGE plpgsql;

-- Function to clear session context
CREATE OR REPLACE FUNCTION public.fn_clear_session_context()
RETURNS VOID AS $$
BEGIN
    PERFORM set_config('app.current_user', NULL, TRUE);
    PERFORM set_config('app.current_tenant_id', NULL, TRUE);
    PERFORM set_config('app.session_id', NULL, TRUE);
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- SEED DATA: Initial Reference Data
-- ============================================================

-- Countries (ISO 3166-1)
INSERT INTO param.country (iso_alpha2, iso_alpha3, iso_name, iso_numeric, name) VALUES
('ID', 'IDN', 'Indonesia', 360, 'Indonesia'),
('MY', 'MYS', 'Malaysia', 458, 'Malaysia'),
('SG', 'SGP', 'Singapore', 702, 'Singapore'),
('TH', 'THA', 'Thailand', 764, 'Thailand'),
('PH', 'PHL', 'Philippines', 608, 'Philippines'),
('VN', 'VNM', 'Vietnam', 704, 'Vietnam'),
('CN', 'CHN', 'China', 156, 'China'),
('JP', 'JPN', 'Japan', 392, 'Japan'),
('KR', 'KOR', 'South Korea', 410, 'South Korea'),
('AU', 'AUS', 'Australia', 36, 'Australia'),
('US', 'USA', 'United States', 840, 'United States'),
('GB', 'GBR', 'United Kingdom', 826, 'United Kingdom'),
('DE', 'DEU', 'Germany', 276, 'Germany'),
('NL', 'NLD', 'Netherlands', 528, 'Netherlands'),
('PA', 'PAN', 'Panama', 591, 'Panama'),
('LR', 'LBR', 'Liberia', 430, 'Liberia'),
('MH', 'MHL', 'Marshall Islands', 584, 'Marshall Islands');

-- Currencies
INSERT INTO param.currency (currency_code, name, symbol, decimal_places) VALUES
('IDR', 'Indonesian Rupiah', 'Rp', 0),
('USD', 'US Dollar', '$', 2),
('EUR', 'Euro', '€', 2),
('GBP', 'British Pound', '£', 2),
('SGD', 'Singapore Dollar', 'S$', 2),
('MYR', 'Malaysian Ringgit', 'RM', 2),
('THB', 'Thai Baht', '฿', 2),
('JPY', 'Japanese Yen', '¥', 0),
('CNY', 'Chinese Yuan', '¥', 2);

-- Unit of Measures
INSERT INTO param.unit_of_measure (uom_code, name, category, symbol) VALUES
('M3', 'Cubic Meter', 'VOLUME', 'm³'),
('M2', 'Square Meter', 'AREA', 'm²'),
('M', 'Meter', 'LENGTH', 'm'),
('CM', 'Centimeter', 'LENGTH', 'cm'),
('MM', 'Millimeter', 'LENGTH', 'mm'),
('KM', 'Kilometer', 'LENGTH', 'km'),
('FT', 'Foot', 'LENGTH', 'ft'),
('IN', 'Inch', 'LENGTH', 'in'),
('L', 'Liter', 'VOLUME', 'L'),
('ML', 'Milliliter', 'VOLUME', 'mL'),
('GAL', 'Gallon', 'VOLUME', 'gal'),
('BBL', 'Barrel', 'VOLUME', 'bbl'),
('KG', 'Kilogram', 'MASS', 'kg'),
('G', 'Gram', 'MASS', 'g'),
('MG', 'Milligram', 'MASS', 'mg'),
('LB', 'Pound', 'MASS', 'lb'),
('TON', 'Metric Ton', 'MASS', 't'),
('MT', 'Metric Ton', 'MASS', 'mt'),
('CELSIUS', 'Celsius', 'TEMPERATURE', '°C'),
('FAHRENHEIT', 'Fahrenheit', 'TEMPERATURE', '°F'),
('HOUR', 'Hour', 'TIME', 'h'),
('DAY', 'Day', 'TIME', 'd'),
('SHIFT', 'Shift', 'TIME', 'shift'),
('PSI', 'PSI', 'PRESSURE', 'psi'),
('BAR', 'Bar', 'PRESSURE', 'bar');

-- Unit Conversions
INSERT INTO param.unit_conversion (uom_code, uom_from, uom_to, conv_value) VALUES
('UC001', 'M3', 'BBL', 6.28981),
('UC002', 'BBL', 'M3', 0.158987),
('UC003', 'M', 'FT', 3.28084),
('UC004', 'FT', 'M', 0.3048),
('UC005', 'KG', 'LB', 2.20462),
('UC006', 'LB', 'KG', 0.453592),
('UC007', 'L', 'GAL', 0.264172),
('UC008', 'GAL', 'L', 3.78541),
('UC009', 'MT', 'M3', 1.0),  -- Assuming density 1
('UC010', 'TON', 'KG', 1000),
('UC011', 'KG', 'TON', 0.001),
('UC012', 'KM', 'MI', 0.621371),
('UC013', 'MI', 'KM', 1.60934);

-- Status Groups
INSERT INTO param.status_group (group_code, group_name, description) VALUES
('FORM_STATUS', 'Form Status', 'Status for forms and documents'),
('PO_STATUS', 'Purchase Order Status', 'Status for Purchase Orders'),
('DO_STATUS', 'Delivery Order Status', 'Status for Delivery Orders'),
('SI_STATUS', 'Shipment Instruction Status', 'Status for Shipment Instructions'),
('ACTIVITY_STATUS', 'Activity Status', 'Status for work activities'),
('INCIDENT_STATUS', 'Incident Status', 'Status for HSE incidents'),
('PAYMENT_STATUS', 'Payment Status', 'Status for payments'),
('INVOICE_STATUS', 'Invoice Status', 'Status for invoices'),
('PERMIT_STATUS', 'Permit Status', 'Status for permits'),
('INSPECTION_STATUS', 'Inspection Status', 'Status for inspections');

-- Status Codes
INSERT INTO param.status (status_code, status_group, display_name, description, sort_order) VALUES
-- Form Status
('DRAFT', 'FORM_STATUS', 'Draft', 'Document is in draft state', 1),
('SUBMITTED', 'FORM_STATUS', 'Submitted', 'Document has been submitted', 2),
('REVIEWED', 'FORM_STATUS', 'Reviewed', 'Document has been reviewed', 3),
('APPROVED', 'FORM_STATUS', 'Approved', 'Document has been approved', 4),
('REJECTED', 'FORM_STATUS', 'Rejected', 'Document has been rejected', 5),

-- PO Status
('PO_DRAFT', 'PO_STATUS', 'Draft', 'Purchase Order is draft', 1),
('PO_PENDING', 'PO_STATUS', 'Pending Approval', 'PO awaiting approval', 2),
('PO_APPROVED', 'PO_STATUS', 'Approved', 'Purchase Order approved', 3),
('PO_IN_PROGRESS', 'PO_STATUS', 'In Progress', 'PO is being executed', 4),
('PO_COMPLETED', 'PO_STATUS', 'Completed', 'PO completed', 5),
('PO_CANCELLED', 'PO_STATUS', 'Cancelled', 'PO cancelled', 6),

-- DO Status
('DO_DRAFT', 'DO_STATUS', 'Draft', 'Delivery Order is draft', 1),
('DO_LOADING', 'DO_STATUS', 'Loading', 'Vessel is loading', 2),
('DO_DEPARTED', 'DO_STATUS', 'Departed', 'Vessel has departed', 3),
('DO_ARRIVED', 'DO_STATUS', 'Arrived', 'Vessel has arrived', 4),
('DO_DISCHARGING', 'DO_STATUS', 'Discharging', 'Discharging in progress', 5),
('DO_COMPLETED', 'DO_STATUS', 'Completed', 'Delivery completed', 6),
('DO_CANCELLED', 'DO_STATUS', 'Cancelled', 'Delivery cancelled', 7),

-- Activity Status
('ACT_PLANNED', 'ACTIVITY_STATUS', 'Planned', 'Activity is planned', 1),
('ACT_STARTED', 'ACTIVITY_STATUS', 'Started', 'Activity has started', 2),
('ACT_IN_PROGRESS', 'ACTIVITY_STATUS', 'In Progress', 'Activity in progress', 3),
('ACT_PAUSED', 'ACTIVITY_STATUS', 'Paused', 'Activity paused', 4),
('ACT_COMPLETED', 'ACTIVITY_STATUS', 'Completed', 'Activity completed', 5),
('ACT_CANCELLED', 'ACTIVITY_STATUS', 'Cancelled', 'Activity cancelled', 6),

-- Incident Status
('INC_OPEN', 'INCIDENT_STATUS', 'Open', 'Incident is open', 1),
('INC_INVESTIGATING', 'INCIDENT_STATUS', 'Investigating', 'Incident under investigation', 2),
('INC_ACTION_PENDING', 'INCIDENT_STATUS', 'Action Pending', 'Corrective action pending', 3),
('INC_CLOSED', 'INCIDENT_STATUS', 'Closed', 'Incident closed', 4),

-- Payment Status
('PAY_PENDING', 'PAYMENT_STATUS', 'Pending', 'Payment pending', 1),
('PAY_PROCESSING', 'PAYMENT_STATUS', 'Processing', 'Payment being processed', 2),
('PAY_COMPLETED', 'PAYMENT_STATUS', 'Completed', 'Payment completed', 3),
('PAY_FAILED', 'PAYMENT_STATUS', 'Failed', 'Payment failed', 4),
('PAY_CANCELLED', 'PAYMENT_STATUS', 'Cancelled', 'Payment cancelled', 5),

-- Invoice Status
('INV_DRAFT', 'INVOICE_STATUS', 'Draft', 'Invoice is draft', 1),
('INV_ISSUED', 'INVOICE_STATUS', 'Issued', 'Invoice issued', 2),
('INV_PARTIAL', 'INVOICE_STATUS', 'Partially Paid', 'Invoice partially paid', 3),
('INV_PAID', 'INVOICE_STATUS', 'Paid', 'Invoice fully paid', 4),
('INV_OVERDUE', 'INVOICE_STATUS', 'Overdue', 'Invoice overdue', 5),
('INV_CANCELLED', 'INVOICE_STATUS', 'Cancelled', 'Invoice cancelled', 6);

-- Roles
INSERT INTO param.role (role_code, role_name, description, permissions) VALUES
('SUPER_ADMIN', 'Super Administrator', 'Full system access', 
 '{"*": ["read", "write", "delete", "admin"]}'::jsonb),
('ADMIN', 'Administrator', 'Full access within tenant',
 '{"*": ["read", "write", "delete"]}'::jsonb),
('DIRECTOR', 'Director', 'Executive level access',
 '{"commercial": ["read", "write"], "financial": ["read", "write"], "hse": ["read", "write"]}'::jsonb),
('MANAGER', 'Manager', 'Managerial access',
 '{"commercial": ["read", "write"], "operational": ["read", "write"], "hse": ["read"]}'::jsonb),
('OPERATOR', 'Operator', 'Operational user',
 '{"operational": ["read", "write"], "form": ["read", "write"], "enviro": ["read", "write"]}'::jsonb),
('VIEWER', 'Viewer', 'Read-only access',
 '{"*": ["read"]}'::jsonb),
('SAFETY_OFFICER', 'Safety Officer', 'HSE dedicated role',
 '{"hse": ["read", "write"], "incident": ["read", "write"], "inspection": ["read", "write"]}'::jsonb);

-- Fleet Types
INSERT INTO fleet.type (type_code, type_group, description) VALUES
('TS', 'TUGBOAT', 'Tugboat'),
('TB', 'TUGBOAT', 'Tug Boat'),
('BC', 'BARGE', 'Barge Carrier'),
('BG', 'BARGE', 'Barge'),
('DP', 'DREDGER', 'Dredger Pump'),
('DC', 'DREDGER', 'Dredger Cutter'),
('HD', 'DREDGER', 'Hopper Dredger'),
('SB', 'SURVEY', 'Survey Boat'),
('SB2', 'SURVEY', 'Speed Boat'),
('CR', 'CARGO', 'Cargo Vessel'),
('TK', 'TANKER', 'Tanker Vessel');

-- Site Types
INSERT INTO site.type (type_code, type_group, description) VALUES
('PORT', 'PORT', 'Port Facility'),
('TERMINAL', 'TERMINAL', 'Terminal'),
('OFFSHORE', 'OFFSHORE', 'Offshore Location'),
('DREDGE', 'DREDGE', 'Dredging Area'),
('DISPOSAL', 'DISPOSAL', 'Disposal Site'),
('OFFICE', 'OFFICE', 'Office Building'),
('WAREHOUSE', 'WAREHOUSE', 'Warehouse');

-- Partner Types
INSERT INTO partner.type (type_code, type_group, description) VALUES
('VENDOR', 'VENDOR', 'Material/Service Vendor'),
('CONTRACTOR', 'CONTRACTOR', 'Contractor'),
('SUPPLIER', 'SUPPLIER', 'Supplier'),
('CLIENT', 'CLIENT', 'Client/Customer'),
('CONSULTANT', 'CONSULTANT', 'Consultant'),
('TRANSPORTER', 'TRANSPORTER', 'Transporter'),
('INSURANCE', 'INSURANCE', 'Insurance Company'),
('BANK', 'BANK', 'Bank');

-- Environmental Station Types
INSERT INTO enviro.reading_type (type_code, type_name, description) VALUES
('TIDE', 'Tide Station', 'Tide measurement station'),
('BUOY', 'Buoy Station', 'Buoy measurement station'),
('METEO', 'Meteorological', 'Meteorological station'),
('WAVE', 'Wave Station', 'Wave measurement station');

-- HSE Incident Types
INSERT INTO hse.incident_type (type_code, type_name, severity_levels, description) VALUES
('NEAR_MISS', 'Near Miss', '{"levels": ["LOW", "MEDIUM", "HIGH"]}'::jsonb, 'Near miss incident'),
('INJURY', 'Personal Injury', '{"levels": ["LOW", "MEDIUM", "HIGH", "CRITICAL"]}'::jsonb, 'Personal injury'),
('ENVIRONMENTAL', 'Environmental', '{"levels": ["LOW", "MEDIUM", "HIGH", "CRITICAL"]}'::jsonb, 'Environmental incident'),
('PROPERTY', 'Property Damage', '{"levels": ["LOW", "MEDIUM", "HIGH"]}'::jsonb, 'Property damage'),
('FIRE', 'Fire', '{"levels": ["MEDIUM", "HIGH", "CRITICAL"]}'::jsonb, 'Fire incident'),
('SPILL', 'Spill', '{"levels": ["LOW", "MEDIUM", "HIGH", "CRITICAL"]}'::jsonb, 'Spill incident');

-- ============================================================
-- ADDITIONAL REPORTING VIEWS
-- ============================================================

-- View: Financial Summary by Period
CREATE MATERIALIZED VIEW IF NOT EXISTS reporting.financial_summary AS
SELECT
    fj.period_year,
    fj.period_month,
    fa.account_type,
    SUM(fjl.debit) AS total_debit,
    SUM(fjl.credit) AS total_credit,
    SUM(fjl.debit) - SUM(fjl.credit) AS balance
FROM financial.journal fj
JOIN financial.journal_line fjl ON fjl.journal_id = fj.journal_id
JOIN financial.account fa ON fa.account_code = fjl.account_code
WHERE fj.is_posted = TRUE
GROUP BY fj.period_year, fj.period_month, fa.account_type
WITH DATA;

CREATE UNIQUE INDEX idx_fin_sum_period_type 
    ON reporting.financial_summary(period_year, period_month, account_type);

-- View: Aging Report for Receivables
CREATE MATERIALIZED VIEW IF NOT EXISTS reporting.ar_aging AS
SELECT
    fi.partner_code,
    pi.name AS partner_name,
    fi.invoice_no,
    fi.invoice_date,
    fi.due_date,
    fi.total_amount,
    COALESCE(fi.total_amount - 
        (SELECT COALESCE(SUM(pl.amount), 0) 
         FROM financial.payment_line pl 
         WHERE pl.invoice_id = fi.invoice_id), 
        fi.total_amount) AS outstanding_amount,
    CURRENT_DATE - fi.due_date AS days_overdue,
    CASE 
        WHEN CURRENT_DATE - fi.due_date <= 0 THEN 'CURRENT'
        WHEN CURRENT_DATE - fi.due_date BETWEEN 1 AND 30 THEN '1-30 DAYS'
        WHEN CURRENT_DATE - fi.due_date BETWEEN 31 AND 60 THEN '31-60 DAYS'
        WHEN CURRENT_DATE - fi.due_date BETWEEN 61 AND 90 THEN '61-90 DAYS'
        ELSE 'OVER 90 DAYS'
    END AS aging_bucket
FROM financial.invoice fi
JOIN partner.info pi ON pi.partner_code = fi.partner_code
WHERE fi.invoice_type = 'SALES' 
  AND fi.status NOT IN ('PAID', 'CANCELLED')
WITH DATA;

CREATE UNIQUE INDEX idx_ar_aging_invoice ON reporting.ar_aging(invoice_no);

-- View: Fleet Performance
CREATE MATERIALIZED VIEW IF NOT EXISTS reporting.fleet_performance AS
SELECT
    fi.fleet_code,
    fi.name AS fleet_name,
    ft.type_name,
    COUNT(DISTINCT si.si_num) AS total_shipments,
    SUM(dr.dredging_volume) AS total_volume,
    COUNT(DISTINCT DATE_TRUNC('day', si.actual_start)) AS working_days,
    AVG(EXTRACT(EPOCH FROM (si.actual_end - si.actual_start))/3600) AS avg_hours_per_job,
    COUNT(DISTINCT wa.area_code) AS areas_visited
FROM fleet.info fi
LEFT JOIN fleet.type ft ON ft.type_code = fi.type_code
LEFT JOIN operational.shipment_instruction si ON si.fleet_main_code = fi.fleet_code
LEFT JOIN operational.dredging_records dr ON dr.si_num = si.si_num
LEFT JOIN operational.work_area wa ON wa.area_code = si.work_area_code
GROUP BY fi.fleet_code, fi.name, ft.type_name
WITH DATA;

CREATE UNIQUE INDEX idx_fleet_perf_code ON reporting.fleet_performance(fleet_code);

-- View: HSE Dashboard
CREATE MATERIALIZED VIEW IF NOT EXISTS reporting.hse_dashboard AS
SELECT
    EXTRACT(YEAR FROM hi.incident_date) AS year,
    EXTRACT(MONTH FROM hi.incident_date) AS month,
    hi.severity,
    COUNT(*) AS incident_count,
    COUNT(CASE WHEN hi.status = 'CLOSED' THEN 1 END) AS closed_count,
    AVG(EXTRACT(EPOCH FROM (COALESCE(hi.updated_at, now()) - hi.incident_date))/86400) AS avg_close_days
FROM hse.incident hi
GROUP BY EXTRACT(YEAR FROM hi.incident_date), EXTRACT(MONTH FROM hi.incident_date), hi.severity
WITH DATA;

CREATE UNIQUE INDEX idx_hse_dash_year_month_sev 
    ON reporting.hse_dashboard(year, month, severity);

-- ============================================================
-- END OF ADDITIONAL FEATURES
-- ============================================================