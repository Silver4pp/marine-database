-- DDL52 · Exact all-row site registry count for the module index.
-- Matches the existing count(*) FROM site.info; no geometry/owner filter.
BEGIN;

CREATE OR REPLACE VIEW analytics.v_dashboard_site_record_count AS
SELECT count(*) AS site_record_count
  FROM site.info;

COMMENT ON VIEW analytics.v_dashboard_site_record_count IS
  'Scalar read-only count of every site.info registry row, matching the module-index count(*) source. No owner join, polygon/location, status, trip, or time filter; not a count of mapped/active sites.';

COMMIT;
