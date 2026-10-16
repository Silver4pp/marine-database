-- DDL59 · Exact all-row count of archived document metadata records.
-- Preserves count(*) FROM document.document; no verification/link/file filter.
BEGIN;

CREATE OR REPLACE VIEW analytics.v_dashboard_document_archive_count AS
SELECT count(*) AS document_archive_count
  FROM document.document;

COMMENT ON VIEW analytics.v_dashboard_document_archive_count IS
  'Scalar read-only count of all document.document metadata rows keyed by document_id. It does not filter document type, entity, file_ref, verification state, links, or timestamp.';

COMMIT;
