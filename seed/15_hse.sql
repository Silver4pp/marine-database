-- ============================================================
-- SEED DATA: hse reference data
-- file    : seed/15_hse.sql
-- objects : 1 statement(s)
-- generated from original/schema_v1_original.sql by tools/split_schema.py
-- ============================================================

-- HSE Incident Types
INSERT INTO hse.incident_type (type_code, type_name, description) VALUES
('NEAR_MISS','Near Miss','Near miss incident'),('INJURY','Personal Injury','Personal injury'),
('ENVIRONMENTAL','Environmental','Environmental incident'),('PROPERTY','Property Damage','Property damage'),
('FIRE','Fire','Fire incident'),('SPILL','Spill','Spill incident');
