-- DDL47 · H+6 weather summary over existing active work-area geometry.
-- The active-area scope, WIB target-hour basis, ST_Covers predicate, and
-- per-area aggregate match the existing Kokpit query; no geometry is created.
BEGIN;

CREATE OR REPLACE VIEW analytics.v_dashboard_weather_h6 AS
WITH target AS (
  SELECT date_trunc('hour', now() AT TIME ZONE 'Asia/Jakarta') + interval '6 hours' AS jam_h6_wib
)
SELECT a.area_code,
       a.area_name,
       (a.geom IS NOT NULL) AS geometry_available,
       count(w.lat)::integer AS grid_cells,
       count(w.angin_ms)::integer AS wind_cells,
       min(w.angin_ms) AS wind_min,
       max(w.angin_ms) AS wind_max,
       count(w.gelombang_m)::integer AS wave_cells,
       min(w.gelombang_m) AS wave_min,
       max(w.gelombang_m) AS wave_max,
       min(w.diperbarui) AS oldest_update,
       max(w.diperbarui) AS newest_update
  FROM operational.work_area a
  JOIN operational.work_zone z
    ON z.zone_code = a.zone_code AND z.status = 'AKTIF'
 CROSS JOIN target h
  LEFT JOIN operational.cuaca_grid w
    ON w.jam_valid = h.jam_h6_wib
   AND a.geom IS NOT NULL
   AND ST_Covers(a.geom,
         ST_SetSRID(ST_Point(w.lon::double precision, w.lat::double precision), 4326))
 WHERE a.status = 'AKTIF'
 GROUP BY a.area_code, a.area_name, (a.geom IS NOT NULL);

COMMENT ON VIEW analytics.v_dashboard_weather_h6 IS
  'One row per active work area in an active work zone. H+6 WIB is database current full hour plus six hours. Existing geometry and ST_Covers constrain grid cells; absent geometry/data remains explicit. Forecast grid summary only, not observation or safety clearance.';

COMMIT;
