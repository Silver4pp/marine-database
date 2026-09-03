-- ============================================================
-- BASE LAYER / 7: tenant-aware functions
-- file    : base/07_tenant_aware_functions.sql
-- note    : base/05 makes tenant_id NOT NULL on every tenant-scoped table. Three
--           existing helpers insert into such a table without supplying
--           tenant_id, so they stop working the moment 05 runs:
--
--             workflow.fn_start_instance    -> workflow.instance
--             document.fn_upload_document   -> document.document
--             buyer.fn_reverse_ledger_entry -> buyer.ledger_hist
--
--           Reproduced before this file existed:
--             ERROR: null value in column "tenant_id" of relation "instance"
--                    violates not-null constraint
--             ERROR: null value in column "tenant_id" of relation "ledger_hist"
--                    violates not-null constraint
--
--           The reversal also fixes a second, unrelated defect: it copied the
--           original's ref_doc/ref_type, which always collides with
--           uq_ledger_ref_doc, so no entry with a ref_doc could ever be reversed.
--             ERROR: duplicate key value violates unique constraint "uq_ledger_ref_doc"
--
--           All three are redefined here. The first two take a trailing
--           p_tenant_id defaulting to the caller's current tenant, so existing
--           call sites keep working.
--
-- depends : base/05_tenant_hardening.sql, feature/05_buyer.sql,
--           feature/18_workflow.sql, feature/19_document.sql
-- ============================================================

\set ON_ERROR_STOP on

-- ------------------------------------------------------------
-- workflow.fn_start_instance
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION workflow.fn_start_instance(
    p_workflow_code VARCHAR,
    p_document_type VARCHAR,
    p_document_id   VARCHAR,
    p_initiated_by  VARCHAR,
    p_priority      VARCHAR DEFAULT 'NORMAL',
    p_tenant_id     UUID    DEFAULT security.fn_get_current_tenant_id()
) RETURNS BIGINT AS $$
DECLARE
    v_workflow_id BIGINT; v_instance_id BIGINT; v_first_step_id BIGINT;
    v_first_step_order SMALLINT; v_instance_code VARCHAR(50);
BEGIN
    IF p_tenant_id IS NULL THEN
        RAISE EXCEPTION 'NO_TENANT: fn_start_instance needs a tenant. Pass p_tenant_id, or call it from a session with a resolvable security.user_scope.';
    END IF;

    SELECT workflow_id INTO v_workflow_id
    FROM workflow.definition WHERE workflow_code = p_workflow_code AND is_active = TRUE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Workflow not found: %', p_workflow_code; END IF;

    IF EXISTS (SELECT 1 FROM workflow.instance
               WHERE document_type = p_document_type AND document_id = p_document_id) THEN
        RAISE EXCEPTION 'Workflow already exists for document: % / %', p_document_type, p_document_id;
    END IF;

    SELECT step_id, step_order INTO v_first_step_id, v_first_step_order
    FROM workflow.step
    WHERE workflow_id = v_workflow_id AND step_order = 1 AND is_active = TRUE;

    v_instance_code := p_workflow_code || '_' || p_document_id || '_' || TO_CHAR(now(), 'YYYYMMDDHH24MISS');

    INSERT INTO workflow.instance (
        instance_code, workflow_id, document_type, document_id, current_step_order,
        status, initiated_by, due_date, priority, tenant_id
    ) VALUES (
        v_instance_code, v_workflow_id, p_document_type, p_document_id, v_first_step_order,
        'IN_PROGRESS', p_initiated_by, now() + INTERVAL '7 days', p_priority, p_tenant_id
    ) RETURNING instance_id INTO v_instance_id;

    INSERT INTO workflow.instance_step (instance_id, step_id, step_order, status, started_at, assigned_to)
    VALUES (v_instance_id, v_first_step_id, v_first_step_order, 'IN_PROGRESS', now(),
            (SELECT approver_user FROM workflow.step WHERE step_id = v_first_step_id));

    RETURN v_instance_id;
END;
$$ LANGUAGE plpgsql;

-- ------------------------------------------------------------
-- document.fn_upload_document
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION document.fn_upload_document(
    p_document_name  VARCHAR,
    p_type_code      VARCHAR,
    p_entity_type    VARCHAR,
    p_entity_id      VARCHAR,
    p_file_name      VARCHAR,
    p_file_path      VARCHAR,
    p_file_size      BIGINT,
    p_mime_type      VARCHAR,
    p_checksum       VARCHAR,
    p_storage_bucket VARCHAR,
    p_uploaded_by    VARCHAR,
    p_version_notes  TEXT    DEFAULT NULL,
    p_is_update      BOOLEAN DEFAULT FALSE,
    p_tenant_id      UUID    DEFAULT security.fn_get_current_tenant_id()
) RETURNS BIGINT AS $$
DECLARE
    v_document_id BIGINT; v_version_no INT; v_document_code VARCHAR(50);
BEGIN
    IF p_tenant_id IS NULL THEN
        RAISE EXCEPTION 'NO_TENANT: fn_upload_document needs a tenant. Pass p_tenant_id, or call it from a session with a resolvable security.user_scope.';
    END IF;

    IF p_is_update THEN
        SELECT document_id, current_version + 1 INTO v_document_id, v_version_no
        FROM document.document WHERE entity_type = p_entity_type AND entity_id = p_entity_id;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Document not found for update: % / %', p_entity_type, p_entity_id;
        END IF;
        UPDATE document.version SET is_current = FALSE
        WHERE document_id = v_document_id AND is_current = TRUE;
        UPDATE document.document
        SET document_name = p_document_name, current_version = v_version_no, updated_at = now()
        WHERE document_id = v_document_id;
    ELSE
        v_document_code := p_entity_type || '_' || p_entity_id || '_' || EXTRACT(EPOCH FROM now())::TEXT;
        v_version_no := 1;
        INSERT INTO document.document (
            document_code, document_name, type_code, entity_type, entity_id,
            current_version, uploaded_by, tenant_id
        ) VALUES (
            v_document_code, p_document_name, p_type_code, p_entity_type, p_entity_id,
            v_version_no, p_uploaded_by, p_tenant_id
        ) RETURNING document_id INTO v_document_id;
    END IF;

    INSERT INTO document.version (
        document_id, version_no, file_name, file_path, file_size, mime_type,
        checksum, storage_bucket, is_current, version_notes, uploaded_by
    ) VALUES (
        v_document_id, v_version_no, p_file_name, p_file_path, p_file_size, p_mime_type,
        p_checksum, p_storage_bucket, TRUE, p_version_notes, p_uploaded_by
    );

    INSERT INTO document.audit (document_id, action, user_code, version_no, details)
    VALUES (v_document_id, CASE WHEN p_is_update THEN 'VERSION_UPLOADED' ELSE 'CREATED' END,
            p_uploaded_by, v_version_no,
            jsonb_build_object('file_name', p_file_name, 'checksum', p_checksum));

    RETURN v_document_id;
END;
$$ LANGUAGE plpgsql;

-- ------------------------------------------------------------
-- buyer.fn_reverse_ledger_entry
-- The reversal carries the tenant of the entry it reverses, which is the only
-- correct value: a reversal must land in the same tenant as the original.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION buyer.fn_reverse_ledger_entry(
    p_entry_id BIGINT,
    p_reason   TEXT
) RETURNS BIGINT AS $$
DECLARE
    v_new_id BIGINT;
    v_entry  buyer.ledger_hist%ROWTYPE;
BEGIN
    SELECT * INTO v_entry FROM buyer.ledger_hist WHERE id = p_entry_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Ledger entry not found: %', p_entry_id;
    END IF;

    INSERT INTO buyer.ledger_hist (
        buyer_code, transaction_date, transaction_type, amount,
        currency_code, ref_doc, ref_type, description, reversal_of_id, tenant_id
    ) VALUES (
        v_entry.buyer_code, CURRENT_DATE,
        CASE v_entry.transaction_type WHEN 'CREDIT' THEN 'DEBIT' ELSE 'CREDIT' END,
        v_entry.amount, v_entry.currency_code,
        -- ref_doc is deliberately NOT copied. uq_ledger_ref_doc is unique on
        -- (buyer_code, ref_doc, ref_type) for non-null ref_doc, so a reversal
        -- carrying the original's ref_doc collides with the entry it reverses
        -- and the function can never succeed. reversal_of_id is the link.
        NULL, 'REVERSAL', 'REVERSAL: ' || p_reason, p_entry_id, v_entry.tenant_id
    ) RETURNING id INTO v_new_id;

    RETURN v_new_id;
END;
$$ LANGUAGE plpgsql;
