-- ============================================================
-- SEED DATA: fleet reference data
-- file    : seed/06_fleet.sql
-- objects : 1 statement(s)
-- generated from original/schema_v1_original.sql by tools/split_schema.py
-- ============================================================

-- Fleet Types
INSERT INTO fleet.type (type_code, type_group, description) VALUES
('TS','TUGBOAT','Tugboat'),('TB','TUGBOAT','Tug Boat'),('BG','BARGE','Barge'),
('DP','DREDGER','Dredger Pump'),('DC','DREDGER','Dredger Cutter'),
('HD','DREDGER','Hopper Dredger'),('SB','SURVEY','Survey Boat'),
('CR','CARGO','Cargo Vessel'),('TK','TANKER','Tanker Vessel');
