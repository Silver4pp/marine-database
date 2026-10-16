-- DDL54 · Exact raw total deposit balance for the module index.
-- Preserves COALESCE(SUM(balance),0) FROM buyer.deposit; no currency conversion,
-- contract-status, tenant, date, or transaction-ledger predicate is introduced.
BEGIN;

CREATE OR REPLACE VIEW analytics.v_dashboard_deposit_balance_total AS
SELECT COALESCE(SUM(balance),0) AS deposit_balance_total
  FROM buyer.deposit;

COMMENT ON VIEW analytics.v_dashboard_deposit_balance_total IS
  'Scalar read-only raw sum of buyer.deposit.balance with the module-index source semantics. No joins, currency conversion, contract-status, tenant, timestamp, or deposit-transaction filters.';

COMMIT;
