-- ============================================================
-- SEED DATA: enviro reference data
-- file    : seed/10_enviro.sql
-- objects : 1 statement(s)
-- generated from original/schema_v1_original.sql by tools/split_schema.py
-- ============================================================

-- Enviro Reading Types
INSERT INTO enviro.reading_type (type_code, type_name, description) VALUES
('TIDE','Tide Station','Tide measurement station'),('BUOY','Buoy Station','Buoy measurement station'),
('METEO','Meteorological','Meteorological station'),('WAVE','Wave Station','Wave measurement station');
