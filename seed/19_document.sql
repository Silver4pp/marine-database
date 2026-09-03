-- ============================================================
-- SEED DATA: document reference data
-- file    : seed/19_document.sql
-- objects : 1 statement(s)
-- generated from original/schema_v1_original.sql by tools/split_schema.py
-- ============================================================

-- Document Types
INSERT INTO document.type (type_code, type_name, category, max_size_kb, allowed_extensions) VALUES
('CONTRACT','Contract','LEGAL',20480,'.pdf,.doc,.docx'),('CERTIFICATE','Certificate','CERT',5120,'.pdf,.jpg,.png'),
('REPORT','Report','REPORT',10240,'.pdf,.xlsx,.docx'),('IMAGE','Image','IMAGE',5120,'.jpg,.jpeg,.png,.gif'),
('DRAWING','Drawing','TECHNICAL',20480,'.pdf,.dwg,.dxf'),('INVOICE_DOC','Invoice','FINANCIAL',5120,'.pdf'),
('APPROVAL_DOC','Approval Doc','ADMIN',5120,'.pdf,.doc,.docx'),('PERMIT_DOC','Permit','HSE',10240,'.pdf');
