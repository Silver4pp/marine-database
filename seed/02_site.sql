-- ============================================================
-- SEED DATA: site reference data
-- file    : seed/02_site.sql
-- objects : 1 statement(s)
-- generated from original/schema_v1_original.sql by tools/split_schema.py
-- ============================================================

-- Site Types
INSERT INTO site.type (type_code, type_group, description) VALUES
('PORT','PORT','Port Facility'),('TERMINAL','TERMINAL','Terminal'),
('OFFSHORE','OFFSHORE','Offshore Location'),('DREDGE','DREDGE','Dredging Area'),
('DISPOSAL','DISPOSAL','Disposal Site'),('OFFICE','OFFICE','Office Building'),
('WAREHOUSE','WAREHOUSE','Warehouse');
