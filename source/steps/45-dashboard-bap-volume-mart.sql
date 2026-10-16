-- DDL45 · Dashboard mart for correction-adjusted signed BAP volume.
-- One row per eligible BAP; retains the exact timestamp and WIB month grain.
BEGIN;

CREATE OR REPLACE VIEW analytics.v_dashboard_bap_volume AS
SELECT b.bap_id,
       b.trip_id,
       b.status AS status_bap,
       b.issued_at,
       date_trunc('month', b.issued_at AT TIME ZONE 'Asia/Jakarta') AS bulan_wib,
       t.work_area_code,
       GREATEST(0::numeric,
                b.volume_m3 - COALESCE(sum(c.delta_volume_m3), 0::numeric))
         AS volume_terkoreksi_m3
  FROM commercial.bap b
  JOIN operational.trip t ON t.trip_id = b.trip_id
  LEFT JOIN commercial.bap_correction c ON c.bap_id = b.bap_id
 WHERE b.status IN ('SIGNED', 'CORRECTED')
   AND b.issued_at <= now()
 GROUP BY b.bap_id, b.trip_id, b.status, b.issued_at,
          t.work_area_code, b.volume_m3;

COMMENT ON VIEW analytics.v_dashboard_bap_volume IS
  'One row per SIGNED/CORRECTED BAP issued by transaction time; exact correction sum and positive floor used by dashboard monthly volume/top-area summaries. issued_at stays timestamptz and bulan_wib is month-truncated Asia/Jakarta time. Not a settled cash/revenue measure.';

COMMIT;
