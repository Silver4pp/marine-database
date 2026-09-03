-- ============================================================
-- SEED DATA: survey reference data
-- file    : seed/09_survey.sql
-- objects : 1 statement(s)
-- generated from original/schema_v1_original.sql by tools/split_schema.py
-- ============================================================

-- Survey Types
INSERT INTO survey.type (type_code, type_name, description) VALUES
('BATHYMETRIC','Bathymetric Survey','Bathymetric survey'),('GEOTECHNICAL','Geotechnical Survey','Geotechnical investigation'),
('ENVIRONMENTAL','Environmental Survey','Environmental assessment'),('HYDROGRAPHIC','Hydrographic Survey','Hydrographic survey');
