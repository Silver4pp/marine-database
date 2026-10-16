-- DDL64 · Exact-grain W4 readers for H+1 weather evaluation and canonical positions.
-- The one-row VALUES join is intentionally transparent (one output row per source row)
-- and makes each projection a non-updatable view. Window, key, filter, precedence,
-- timestamp and ordering logic remain with their existing application readers.
BEGIN;

CREATE OR REPLACE VIEW analytics.v_dashboard_weather_grid_records AS
SELECT g.lat, g.lon, g.jam_valid, g.angin_ms, g.angin_der, g.hujan_mm,
       g.awan_pct, g.gelombang_m, g.gelombang_der, g.diperbarui, g.source_meta
  FROM operational.cuaca_grid AS g
 CROSS JOIN (VALUES (1)) AS read_only_guard(singleton);
COMMENT ON VIEW analytics.v_dashboard_weather_grid_records IS
  'One-to-one pass-through of operational.cuaca_grid at (lat,lon,jam_valid) grain. The singleton join only prevents automatic updates; H+1 WIB day bounds, per-cell filtering, jam_valid ordering, assessment and alarm effects remain in weather_controls.evaluate().';

CREATE OR REPLACE VIEW analytics.v_dashboard_position_records AS
SELECT a.position_id, a.fleet_code, a.mmsi, a.lat, a.lng, a.speed_kn,
       a.course_deg, a.position_at, a.source_kind, a.received_at,
       a.source_ref, a.event_key, a.heading_deg
  FROM telemetry.ais_position AS a
 CROSS JOIN (VALUES (1)) AS read_only_guard(singleton);
COMMENT ON VIEW analytics.v_dashboard_position_records IS
  'One-to-one pass-through of telemetry.ais_position at position_id grain. It does not filter or select a canonical position; MANUAL/GPS/AIS versus UNKNOWN priority, DEMO mode, coordinate/time validity, cutoff, tie-breakers, freshness, jump screening, and trail ordering remain in core.positions.';

COMMIT;
