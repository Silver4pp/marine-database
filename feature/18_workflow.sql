-- ============================================================
-- FEATURE SCHEMA: workflow
-- file    : feature/18_workflow.sql
-- objects : 8 statement(s)
-- generated from original/schema_v1_original.sql by tools/split_schema.py
-- ============================================================

-- ============================================================
-- SECTION 21: WORKFLOW SCHEMA TABLES
-- ============================================================

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
    step_id                 BIGSERIAL       PRIMARY KEY,
    workflow_id             BIGINT          NOT NULL
                                REFERENCES workflow.definition(workflow_id) ON DELETE CASCADE,
    step_order              SMALLINT        NOT NULL,
    step_name               VARCHAR(100)    NOT NULL,
    step_type               VARCHAR(30)     NOT NULL
                                CHECK (step_type IN ('START','APPROVAL','NOTIFICATION','CONDITION','END')),
    approver_role           VARCHAR(50),
    approver_user           VARCHAR(30),
    is_auto_approve         BOOLEAN         DEFAULT FALSE,
    timeout_hours           INT,
    required_approval_count INT             DEFAULT 1,
    next_step_order_approve  SMALLINT,
    next_step_order_reject  SMALLINT,
    can_skip                BOOLEAN         DEFAULT FALSE,
    is_active               BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at              TIMESTAMPTZ     NOT NULL DEFAULT now(),
    CONSTRAINT uq_workflow_step_order UNIQUE (workflow_id, step_order)
);

CREATE TABLE workflow.instance (
    instance_id     BIGSERIAL       PRIMARY KEY,
    instance_code   VARCHAR(50)     NOT NULL UNIQUE,
    workflow_id     BIGINT          NOT NULL
                        REFERENCES workflow.definition(workflow_id) ON DELETE RESTRICT,
    document_type   VARCHAR(50)     NOT NULL,
    document_id     VARCHAR(50)     NOT NULL,
    current_step_order SMALLINT     NOT NULL DEFAULT 1,
    status          VARCHAR(30)     NOT NULL
                        CHECK (status IN ('PENDING','IN_PROGRESS','APPROVED','REJECTED','CANCELLED','EXPIRED')),
    initiated_by    VARCHAR(30),
    initiated_at    TIMESTAMPTZ     NOT NULL DEFAULT now(),
    completed_at    TIMESTAMPTZ,
    due_date        TIMESTAMPTZ,
    priority        VARCHAR(20)     DEFAULT 'NORMAL',
    notes           TEXT,
    is_locked       BOOLEAN         DEFAULT FALSE,
    metadata        JSONB,
    tenant_id       UUID,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    CONSTRAINT uq_instance_doc UNIQUE (document_type, document_id)
);

CREATE TABLE workflow.instance_step (
    instance_step_id BIGSERIAL      PRIMARY KEY,
    instance_id     BIGINT         NOT NULL
                        REFERENCES workflow.instance(instance_id) ON DELETE CASCADE,
    step_id         BIGINT         NOT NULL
                        REFERENCES workflow.step(step_id) ON DELETE RESTRICT,
    step_order      SMALLINT       NOT NULL,
    status          VARCHAR(30)     NOT NULL
                        CHECK (status IN ('PENDING','IN_PROGRESS','APPROVED','REJECTED','SKIPPED')),
    started_at      TIMESTAMPTZ,
    completed_at    TIMESTAMPTZ,
    due_at          TIMESTAMPTZ,
    assigned_to     VARCHAR(30),
    comments        TEXT,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    CONSTRAINT uq_instance_step_order UNIQUE (instance_id, step_order)
);

CREATE TABLE workflow.approval (
    approval_id     BIGSERIAL       PRIMARY KEY,
    instance_step_id BIGINT         NOT NULL
                        REFERENCES workflow.instance_step(instance_step_id) ON DELETE CASCADE,
    approver_user   VARCHAR(30),
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
    instance_id     BIGINT         NOT NULL
                        REFERENCES workflow.instance(instance_id) ON DELETE CASCADE,
    action          VARCHAR(50)     NOT NULL,
    from_step_order INT,
    to_step_order   INT,
    performed_by    VARCHAR(30),
    performed_at    TIMESTAMPTZ     NOT NULL DEFAULT now(),
    details         JSONB
);

-- Workflow: Start instance
CREATE OR REPLACE FUNCTION workflow.fn_start_instance(
    p_workflow_code VARCHAR, p_document_type VARCHAR, p_document_id VARCHAR,
    p_initiated_by VARCHAR, p_priority VARCHAR DEFAULT 'NORMAL'
) RETURNS BIGINT AS $$
DECLARE
    v_workflow_id BIGINT; v_instance_id BIGINT; v_first_step_id BIGINT;
    v_first_step_order SMALLINT; v_instance_code VARCHAR(50);
BEGIN
    SELECT workflow_id INTO v_workflow_id FROM workflow.definition WHERE workflow_code = p_workflow_code AND is_active = TRUE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Workflow not found: %', p_workflow_code; END IF;
    IF EXISTS (SELECT 1 FROM workflow.instance WHERE document_type = p_document_type AND document_id = p_document_id) THEN
        RAISE EXCEPTION 'Workflow already exists for document: % / %', p_document_type, p_document_id;
    END IF;
    SELECT step_id, step_order INTO v_first_step_id, v_first_step_order
    FROM workflow.step WHERE workflow_id = v_workflow_id AND step_order = 1 AND is_active = TRUE;
    v_instance_code := p_workflow_code || '_' || p_document_id || '_' || TO_CHAR(now(), 'YYYYMMDDHH24MISS');
    INSERT INTO workflow.instance (instance_code, workflow_id, document_type, document_id, current_step_order, status, initiated_by, due_date, priority)
    VALUES (v_instance_code, v_workflow_id, p_document_type, p_document_id, v_first_step_order, 'IN_PROGRESS', p_initiated_by, now() + INTERVAL '7 days', p_priority)
    RETURNING instance_id INTO v_instance_id;
    INSERT INTO workflow.instance_step (instance_id, step_id, step_order, status, started_at, assigned_to)
    VALUES (v_instance_id, v_first_step_id, v_first_step_order, 'IN_PROGRESS', now(), (SELECT approver_user FROM workflow.step WHERE step_id = v_first_step_id));
    RETURN v_instance_id;
END;
$$ LANGUAGE plpgsql;

-- Workflow: Process step
CREATE OR REPLACE FUNCTION workflow.fn_process_step(
    p_instance_id BIGINT, p_approver_user VARCHAR, p_decision VARCHAR, p_comments TEXT DEFAULT NULL
) RETURNS BOOLEAN AS $$
DECLARE
    v_instance RECORD; v_current_step RECORD; v_current_step_def RECORD;
    v_next_step_order SMALLINT; v_next_step_id BIGINT; v_approval_count INT; v_required_count INT; v_row_locked BIGINT;
BEGIN
    SELECT instance_id INTO v_row_locked FROM workflow.instance WHERE instance_id = p_instance_id AND is_locked = FALSE FOR UPDATE;
    IF v_row_locked IS NULL THEN RAISE EXCEPTION 'Instance is locked or not found: %', p_instance_id; END IF;
    UPDATE workflow.instance SET is_locked = TRUE WHERE instance_id = p_instance_id;
    BEGIN
        SELECT * INTO v_instance FROM workflow.instance WHERE instance_id = p_instance_id;
        SELECT ws.*, wsi.instance_step_id INTO v_current_step
        FROM workflow.instance_step wsi JOIN workflow.step ws ON ws.step_id = wsi.step_id
        WHERE wsi.instance_id = p_instance_id AND wsi.step_order = v_instance.current_step_order;
        SELECT COUNT(*) INTO v_approval_count FROM workflow.approval WHERE instance_step_id = v_current_step.instance_step_id AND approver_user = p_approver_user;
        IF v_approval_count > 0 THEN RAISE EXCEPTION 'User % has already processed this step', p_approver_user; END IF;
        SELECT required_approval_count INTO v_required_count FROM workflow.step WHERE step_id = v_current_step.step_id;
        INSERT INTO workflow.approval (instance_step_id, approver_user, decision, comments, sequence_no)
        VALUES (v_current_step.instance_step_id, p_approver_user, p_decision, p_comments, v_approval_count + 1);
        IF p_decision = 'REJECTED' THEN
            UPDATE workflow.instance_step SET status = 'REJECTED', completed_at = now() WHERE instance_step_id = v_current_step.instance_step_id;
            UPDATE workflow.instance SET status = 'REJECTED', current_step_order = 0, completed_at = now(), is_locked = FALSE WHERE instance_id = p_instance_id;
            INSERT INTO workflow.history (instance_id, action, from_step_order, performed_by, details)
            VALUES (p_instance_id, 'REJECTED', v_instance.current_step_order, p_approver_user, jsonb_build_object('decision', p_decision, 'comments', p_comments));
            RETURN TRUE;
        END IF;
        SELECT COUNT(*) INTO v_approval_count FROM workflow.approval WHERE instance_step_id = v_current_step.instance_step_id AND decision = 'APPROVED';
        IF v_approval_count < v_required_count THEN UPDATE workflow.instance SET is_locked = FALSE WHERE instance_id = p_instance_id; RETURN TRUE; END IF;
        UPDATE workflow.instance_step SET status = 'APPROVED', completed_at = now() WHERE instance_step_id = v_current_step.instance_step_id;
        SELECT * INTO v_current_step_def FROM workflow.step WHERE step_id = v_current_step.step_id;
        v_next_step_order := v_current_step_def.next_step_order_approve;
        IF v_next_step_order IS NULL THEN
            UPDATE workflow.instance SET status = 'APPROVED', completed_at = now(), is_locked = FALSE WHERE instance_id = p_instance_id;
            INSERT INTO workflow.history (instance_id, action, from_step_order, performed_by, details)
            VALUES (p_instance_id, 'COMPLETED', v_instance.current_step_order, p_approver_user, jsonb_build_object('decision', p_decision));
            RETURN TRUE;
        END IF;
        SELECT step_id INTO v_next_step_id FROM workflow.step WHERE workflow_id = v_instance.workflow_id AND step_order = v_next_step_order;
        UPDATE workflow.instance SET current_step_order = v_next_step_order, is_locked = FALSE WHERE instance_id = p_instance_id;
        INSERT INTO workflow.instance_step (instance_id, step_id, step_order, status, started_at, assigned_to)
        VALUES (p_instance_id, v_next_step_id, v_next_step_order, 'IN_PROGRESS', now(), (SELECT approver_user FROM workflow.step WHERE step_id = v_next_step_id));
        INSERT INTO workflow.history (instance_id, action, from_step_order, to_step_order, performed_by, details)
        VALUES (p_instance_id, 'APPROVED', v_instance.current_step_order, v_next_step_order, p_approver_user, jsonb_build_object('decision', p_decision, 'comments', p_comments));
        RETURN TRUE;
    EXCEPTION WHEN OTHERS THEN UPDATE workflow.instance SET is_locked = FALSE WHERE instance_id = p_instance_id; RAISE;
    END;
END;
$$ LANGUAGE plpgsql;
