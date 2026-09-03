-- ============================================================
-- SEED DATA: security reference data
-- file    : seed/16_security.sql
-- objects : 1 statement(s)
-- generated from original/schema_v1_original.sql by tools/split_schema.py
-- ============================================================

-- Permissions
INSERT INTO security.permission (permission_code, permission_name, module) VALUES
('form.read','Read Forms','FORM'),('form.write','Write Forms','FORM'),
('commercial.read','Read Commercial','COMMERCIAL'),('commercial.write','Write Commercial','COMMERCIAL'),
('financial.read','Read Financial','FINANCIAL'),('financial.write','Write Financial','FINANCIAL'),
('hse.read','Read HSE','HSE'),('hse.write','Write HSE','HSE'),
('operational.read','Read Operational','OPERATIONAL'),('operational.write','Write Operational','OPERATIONAL'),
('fleet.read','Read Fleet','FLEET'),('fleet.write','Write Fleet','FLEET'),
('admin.users','Manage Users','ADMIN'),('admin.tenant','Manage Tenant','ADMIN');
