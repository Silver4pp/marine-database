-- DDL61 · Exact all-row count of uploaded-form photo metadata records.
-- Preserves count(*) FROM document.form_foto; do not filter by form, storage, blob, record, or date.
BEGIN;

CREATE OR REPLACE VIEW analytics.v_dashboard_uploaded_photo_count AS
SELECT count(*) AS uploaded_photo_count
  FROM document.form_foto;

COMMENT ON VIEW analytics.v_dashboard_uploaded_photo_count IS
  'Scalar read-only count of all document.form_foto upload metadata rows keyed by foto_id; includes every form type and storage mode, without record, blob, date, or time-zone filters.';

COMMIT;
