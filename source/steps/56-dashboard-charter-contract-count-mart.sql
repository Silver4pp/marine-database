-- DDL56 · Exact all-row count of registered partner charter contracts.
-- Preserves count(*) FROM partner.charter_contract; no status/date/partner/fleet filter.
BEGIN;

CREATE OR REPLACE VIEW analytics.v_dashboard_charter_contract_count AS
SELECT count(*) AS charter_contract_count
  FROM partner.charter_contract;

COMMENT ON VIEW analytics.v_dashboard_charter_contract_count IS
  'Scalar read-only count of every partner.charter_contract row, matching the module-index source. Does not filter status/date or join partner, fleet, rate-card, statement, invoice, cost, or trip relations.';

COMMIT;
