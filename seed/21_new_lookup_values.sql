-- ============================================================
-- SEED DATA: lookup values for the newly added layers
-- file    : seed/21_new_lookup_values.sql
-- note    : param.status is the shared status registry the original tables point
--           at, so the new tables need their own status groups and codes here.
--           Requirements, obligations and their evidence are business data, not
--           reference data, so compliance.requirement is deliberately not seeded.
-- depends : seed/01_param.sql, feature/23_hse.sql, feature/24_compliance.sql
-- ============================================================

\set ON_ERROR_STOP on

INSERT INTO param.status_group (group_code, group_name) VALUES
('CA_STATUS','Corrective Action Status'),
('COMPLIANCE_STATUS','Compliance Finding Status')
ON CONFLICT (group_code) DO NOTHING;

INSERT INTO param.status (status_code, status_group, display_name, sort_order) VALUES
('CA_OPEN','CA_STATUS','Open',1),
('CA_IN_PROGRESS','CA_STATUS','In Progress',2),
('CA_COMPLETED','CA_STATUS','Completed',3),
('CA_CLOSED','CA_STATUS','Closed',4),
('CA_CANCELLED','CA_STATUS','Cancelled',5),
('COMP_OPEN','COMPLIANCE_STATUS','Open',1),
('COMP_IN_PROGRESS','COMPLIANCE_STATUS','In Progress',2),
('COMP_CLOSED','COMPLIANCE_STATUS','Closed',3)
ON CONFLICT (status_code) DO NOTHING;

SELECT 'CA_STATUS codes' AS seeded, count(*)::TEXT FROM param.status WHERE status_group = 'CA_STATUS'
UNION ALL
SELECT 'COMPLIANCE_STATUS codes', count(*)::TEXT FROM param.status WHERE status_group = 'COMPLIANCE_STATUS';
