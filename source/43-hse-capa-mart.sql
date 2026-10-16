-- DDL43 · Read-only CAPA mart, one row per source CAPA, all source types.
-- Kept separate from v_hse_insidensi, whose documented grain is per incident.
BEGIN;

CREATE OR REPLACE VIEW analytics.v_hse_capa AS
SELECT c.capa_id,
       c.capa_no,
       c.source_type,
       c.source_ref,
       c.status AS capa_status,
       c.due_date AS capa_jatuh_tempo,
       c.closed_at,
       bool_and(c.closed_at IS NULL
                AND c.status <> 'CLOSED'
                AND c.due_date < (now() AT TIME ZONE 'Asia/Jakarta')::date) AS overdue
  FROM hse.capa c
 GROUP BY c.capa_id,c.capa_no,c.source_type,c.source_ref,c.status,c.due_date,c.closed_at;

COMMENT ON VIEW analytics.v_hse_capa IS
  'Read-only mart, one row per hse.capa across INCIDENT and INSPECTION. overdue exactly matches the existing CAPA alarm predicate using the Asia/Jakarta date. Aggregate grain prevents automatic view updates; not a safety assessment.';

COMMIT;
