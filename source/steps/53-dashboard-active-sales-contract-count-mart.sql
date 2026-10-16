-- DDL53 · Exact status-filtered sales-contract count for the module index.
-- Preserves status='AKTIF'; do not substitute is_active or date predicates.
BEGIN;

CREATE OR REPLACE VIEW analytics.v_dashboard_active_sales_contract_count AS
SELECT count(*) AS active_sales_contract_count
  FROM commercial.sales_contract
 WHERE status='AKTIF';

COMMENT ON VIEW analytics.v_dashboard_active_sales_contract_count IS
  'Scalar read-only count of commercial.sales_contract rows where status is exactly AKTIF, matching the module-index source. Does not add is_active, date, site, buyer, deposit, or standby-claim predicates.';

COMMIT;
