-- ============================================================
-- SEED DATA: param reference data
-- file    : seed/01_param.sql
-- objects : 7 statement(s)
-- generated from original/schema_v1_original.sql by tools/split_schema.py
-- ============================================================

-- ============================================================
-- SECTION 29: SEED DATA
-- ============================================================

-- Countries
INSERT INTO param.country (iso_alpha2, iso_alpha3, iso_name, iso_numeric, name) VALUES
('ID','IDN','Indonesia',360,'Indonesia'),('MY','MYS','Malaysia',458,'Malaysia'),
('SG','SGP','Singapore',702,'Singapore'),('TH','THA','Thailand',764,'Thailand'),
('PH','PHL','Philippines',608,'Philippines'),('VN','VNM','Vietnam',704,'Vietnam'),
('CN','CHN','China',156,'China'),('JP','JPN','Japan',392,'Japan'),
('KR','KOR','South Korea',410,'South Korea'),('AU','AUS','Australia',36,'Australia'),
('US','USA','United States',840,'United States'),('GB','GBR','United Kingdom',826,'United Kingdom'),
('DE','DEU','Germany',276,'Germany'),('NL','NLD','Netherlands',528,'Netherlands'),
('PA','PAN','Panama',591,'Panama'),('LR','LBR','Liberia',430,'Liberia');

-- Currencies
INSERT INTO param.currency (currency_code, name, symbol, decimal_places) VALUES
('IDR','Indonesian Rupiah','Rp',0),('USD','US Dollar','$',2),
('EUR','Euro','€',2),('GBP','British Pound','£',2),('SGD','Singapore Dollar','S$',2),
('MYR','Malaysian Ringgit','RM',2),('THB','Thai Baht','฿',2),('JPY','Japanese Yen','¥',0);

-- Unit of Measures
INSERT INTO param.unit_of_measure (uom_code, name, category, symbol) VALUES
('M3','Cubic Meter','VOLUME','m³'),('M2','Square Meter','AREA','m²'),('M','Meter','LENGTH','m'),
('CM','Centimeter','LENGTH','cm'),('MM','Millimeter','LENGTH','mm'),('KM','Kilometer','LENGTH','km'),
('FT','Foot','LENGTH','ft'),('IN','Inch','LENGTH','in'),('L','Liter','VOLUME','L'),
('ML','Milliliter','VOLUME','mL'),('GAL','Gallon','VOLUME','gal'),('BBL','Barrel','VOLUME','bbl'),
('KG','Kilogram','MASS','kg'),('G','Gram','MASS','g'),('MG','Milligram','MASS','mg'),
('LB','Pound','MASS','lb'),('TON','Metric Ton','MASS','t'),('MT','Metric Ton','MASS','mt'),
('CELSIUS','Celsius','TEMPERATURE','°C'),('FAHRENHEIT','Fahrenheit','TEMPERATURE','°F'),
('HOUR','Hour','TIME','h'),('DAY','Day','TIME','d'),('SHIFT','Shift','TIME','shift'),
('PSI','PSI','PRESSURE','psi'),('BAR','Bar','PRESSURE','bar');

-- Unit Conversions
-- [FIX-5] The original column list used `uom_code`, which is not a column of
-- param.unit_conversion (its PK column is `uc_code`) ->
--   column "uom_code" of relation "unit_conversion" does not exist
INSERT INTO param.unit_conversion (uc_code, uom_from, uom_to, conv_value) VALUES
('UC001','M3','BBL',6.28981),('UC002','BBL','M3',0.158987),('UC003','M','FT',3.28084),
('UC004','FT','M',0.3048),('UC005','KG','LB',2.20462),('UC006','LB','KG',0.453592),
('UC007','L','GAL',0.264172),('UC008','GAL','L',3.78541),('UC009','MT','M3',1.0),
('UC010','TON','KG',1000),('UC011','KG','TON',0.001);

-- Status Groups
INSERT INTO param.status_group (group_code, group_name) VALUES
('FORM_STATUS','Form Status'),('PO_STATUS','Purchase Order Status'),
('DO_STATUS','Delivery Order Status'),('SI_STATUS','Shipment Instruction Status'),
('ACTIVITY_STATUS','Activity Status'),('INCIDENT_STATUS','Incident Status'),
('PAYMENT_STATUS','Payment Status'),('INVOICE_STATUS','Invoice Status'),
('PERMIT_STATUS','Permit Status'),('INSPECTION_STATUS','Inspection Status');

-- Status Codes
INSERT INTO param.status (status_code, status_group, display_name, sort_order) VALUES
('DRAFT','FORM_STATUS','Draft',1),('SUBMITTED','FORM_STATUS','Submitted',2),
('APPROVED','FORM_STATUS','Approved',3),('REJECTED','FORM_STATUS','Rejected',4),
('PO_DRAFT','PO_STATUS','Draft',1),('PO_PENDING','PO_STATUS','Pending Approval',2),
('PO_APPROVED','PO_STATUS','Approved',3),('PO_IN_PROGRESS','PO_STATUS','In Progress',4),
('PO_COMPLETED','PO_STATUS','Completed',5),('PO_CANCELLED','PO_STATUS','Cancelled',6),
('DO_DRAFT','DO_STATUS','Draft',1),('DO_LOADING','DO_STATUS','Loading',2),
('DO_DEPARTED','DO_STATUS','Departed',3),('DO_ARRIVED','DO_STATUS','Arrived',4),
('DO_COMPLETED','DO_STATUS','Completed',5),('DO_CANCELLED','DO_STATUS','Cancelled',6),
('ACT_PLANNED','ACTIVITY_STATUS','Planned',1),('ACT_STARTED','ACTIVITY_STATUS','Started',2),
('ACT_IN_PROGRESS','ACTIVITY_STATUS','In Progress',3),('ACT_COMPLETED','ACTIVITY_STATUS','Completed',4),
('INC_OPEN','INCIDENT_STATUS','Open',1),('INC_INVESTIGATING','INCIDENT_STATUS','Investigating',2),
('INC_CLOSED','INCIDENT_STATUS','Closed',3),
('PAY_PENDING','PAYMENT_STATUS','Pending',1),('PAY_COMPLETED','PAYMENT_STATUS','Completed',2),
('INV_DRAFT','INVOICE_STATUS','Draft',1),('INV_ISSUED','INVOICE_STATUS','Issued',2),
('INV_PAID','INVOICE_STATUS','Paid',3),('INV_OVERDUE','INVOICE_STATUS','Overdue',4);

-- Roles
INSERT INTO param.role (role_code, role_name, description) VALUES
('SUPER_ADMIN','Super Administrator','Full system access'),
('ADMIN','Administrator','Full access within tenant'),
('MANAGER','Manager','Managerial access'),
('OPERATOR','Operator','Operational user'),
('VIEWER','Viewer','Read-only access'),
('SAFETY_OFFICER','Safety Officer','HSE dedicated role');
