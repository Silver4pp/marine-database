-- ============================================================
-- SEED DATA: partner reference data
-- file    : seed/04_partner.sql
-- objects : 1 statement(s)
-- generated from original/schema_v1_original.sql by tools/split_schema.py
-- ============================================================

-- Partner Types
INSERT INTO partner.type (type_code, type_group, description) VALUES
('VENDOR','VENDOR','Material/Service Vendor'),('CONTRACTOR','CONTRACTOR','Contractor'),
('SUPPLIER','SUPPLIER','Supplier'),('CLIENT','CLIENT','Client/Customer'),
('CONSULTANT','CONSULTANT','Consultant'),('TRANSPORTER','TRANSPORTER','Transporter');
