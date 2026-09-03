-- ============================================================
-- FEATURE SCHEMA: document
-- file    : feature/19_document.sql
-- objects : 7 statement(s)
-- generated from original/schema_v1_original.sql by tools/split_schema.py
-- ============================================================

-- ============================================================
-- SECTION 22: DOCUMENT SCHEMA TABLES
-- ============================================================

CREATE TABLE document.type (
    type_id         BIGSERIAL       PRIMARY KEY,
    type_code       VARCHAR(50)     NOT NULL UNIQUE,
    type_name       VARCHAR(200)    NOT NULL,
    description     TEXT,
    max_size_kb     INT             DEFAULT 10240,
    allowed_extensions TEXT,
    category        VARCHAR(50),
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE document.document (
    document_id     BIGSERIAL       PRIMARY KEY,
    document_code   VARCHAR(50)     NOT NULL UNIQUE,
    document_name   VARCHAR(300)    NOT NULL,
    type_code       VARCHAR(50)     NOT NULL
                        REFERENCES document.type(type_code) ON DELETE RESTRICT,
    entity_type     VARCHAR(50)     NOT NULL,
    entity_id       VARCHAR(50)     NOT NULL,
    tenant_id       UUID,
    current_version INT             NOT NULL DEFAULT 1,
    status          VARCHAR(30),
    uploaded_by     VARCHAR(30),
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    CONSTRAINT uq_document_entity UNIQUE (entity_type, entity_id)
);

CREATE TABLE document.version (
    version_id      BIGSERIAL       PRIMARY KEY,
    document_id     BIGINT          NOT NULL
                        REFERENCES document.document(document_id) ON DELETE CASCADE,
    version_no      INT             NOT NULL,
    file_name       VARCHAR(300)    NOT NULL,
    file_path       VARCHAR(500)    NOT NULL,
    file_size       BIGINT,
    mime_type       VARCHAR(100),
    checksum        VARCHAR(64),
    storage_bucket  VARCHAR(100),
    is_current      BOOLEAN         NOT NULL DEFAULT FALSE,
    version_notes   TEXT,
    uploaded_by     VARCHAR(30),
    uploaded_at     TIMESTAMPTZ     NOT NULL DEFAULT now(),
    CONSTRAINT uq_document_version UNIQUE (document_id, version_no)
    -- [FIX-3] UNIQUE ... WHERE is not valid inside a table body.
    -- Re-created as a partial UNIQUE index in index/01_indexes.sql.
    -- ORIGINAL (invalid):
    --   CONSTRAINT uq_current_version UNIQUE (document_id) WHERE is_current = TRUE
);

CREATE TABLE document.permission (
    perm_id         BIGSERIAL       PRIMARY KEY,
    document_id     BIGINT          NOT NULL
                        REFERENCES document.document(document_id) ON DELETE CASCADE,
    user_code       VARCHAR(30),
    role_name       VARCHAR(50),
    can_view        BOOLEAN         DEFAULT TRUE,
    can_download    BOOLEAN         DEFAULT TRUE,
    can_edit        BOOLEAN         DEFAULT FALSE,
    can_delete      BOOLEAN         DEFAULT FALSE,
    expires_at      TIMESTAMPTZ,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE document.signature (
    sign_id         BIGSERIAL       PRIMARY KEY,
    document_id     BIGINT          NOT NULL
                        REFERENCES document.document(document_id) ON DELETE CASCADE,
    sign_order      SMALLINT        NOT NULL,
    signer_user     VARCHAR(30),
    signer_name     VARCHAR(150),
    signer_role     VARCHAR(50),
    signature_data  TEXT,
    signed_at       TIMESTAMPTZ,
    is_valid        BOOLEAN,
    reason          VARCHAR(200),
    ip_address      INET,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE document.audit (
    audit_id        BIGSERIAL       PRIMARY KEY,
    document_id     BIGINT          NOT NULL
                        REFERENCES document.document(document_id) ON DELETE CASCADE,
    action          VARCHAR(50)     NOT NULL,
    user_code       VARCHAR(30),
    version_no      INT,
    details         JSONB,
    executed_at     TIMESTAMPTZ     NOT NULL DEFAULT now()
);

-- Document: Upload document
CREATE OR REPLACE FUNCTION document.fn_upload_document(
    p_document_name VARCHAR, p_type_code VARCHAR, p_entity_type VARCHAR, p_entity_id VARCHAR,
    p_file_name VARCHAR, p_file_path VARCHAR, p_file_size BIGINT, p_mime_type VARCHAR,
    p_checksum VARCHAR, p_storage_bucket VARCHAR, p_uploaded_by VARCHAR,
    p_version_notes TEXT DEFAULT NULL, p_is_update BOOLEAN DEFAULT FALSE
) RETURNS BIGINT AS $$
DECLARE
    v_document_id BIGINT; v_version_no INT; v_document_code VARCHAR(50);
BEGIN
    IF p_is_update THEN
        SELECT document_id, current_version + 1 INTO v_document_id, v_version_no
        FROM document.document WHERE entity_type = p_entity_type AND entity_id = p_entity_id;
        IF NOT FOUND THEN RAISE EXCEPTION 'Document not found for update: % / %', p_entity_type, p_entity_id; END IF;
        UPDATE document.version SET is_current = FALSE WHERE document_id = v_document_id AND is_current = TRUE;
        UPDATE document.document SET document_name = p_document_name, current_version = v_version_no, updated_at = now() WHERE document_id = v_document_id;
    ELSE
        v_document_code := p_entity_type || '_' || p_entity_id || '_' || EXTRACT(EPOCH FROM now())::TEXT;
        v_version_no := 1;
        INSERT INTO document.document (document_code, document_name, type_code, entity_type, entity_id, current_version, uploaded_by)
        VALUES (v_document_code, p_document_name, p_type_code, p_entity_type, p_entity_id, v_version_no, p_uploaded_by)
        RETURNING document_id INTO v_document_id;
    END IF;
    INSERT INTO document.version (document_id, version_no, file_name, file_path, file_size, mime_type, checksum, storage_bucket, is_current, version_notes, uploaded_by)
    VALUES (v_document_id, v_version_no, p_file_name, p_file_path, p_file_size, p_mime_type, p_checksum, p_storage_bucket, TRUE, p_version_notes, p_uploaded_by);
    INSERT INTO document.audit (document_id, action, user_code, version_no, details)
    VALUES (v_document_id, CASE WHEN p_is_update THEN 'VERSION_UPLOADED' ELSE 'CREATED' END, p_uploaded_by, v_version_no, jsonb_build_object('file_name', p_file_name, 'checksum', p_checksum));
    RETURN v_document_id;
END;
$$ LANGUAGE plpgsql;
