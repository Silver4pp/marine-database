-- DDL57 · Exact all-row count of general-ledger journal headers for the module index.
-- Preserves count(*) FROM financial.journal; do not count journal lines instead.
BEGIN;

CREATE OR REPLACE VIEW analytics.v_dashboard_journal_header_count AS
SELECT count(*) AS journal_header_count
  FROM financial.journal;

COMMENT ON VIEW analytics.v_dashboard_journal_header_count IS
  'Scalar read-only count of all financial.journal header rows, matching the module-index source. It does not count journal lines or filter date/reference/status/balance.';

COMMIT;
