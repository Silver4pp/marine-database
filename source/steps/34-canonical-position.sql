BEGIN;
ALTER TABLE telemetry.ais_position ADD COLUMN IF NOT EXISTS source_kind text NOT NULL DEFAULT 'UNKNOWN' CHECK(source_kind IN ('DEMO','MANUAL','GPS','AIS','UNKNOWN'));
ALTER TABLE telemetry.ais_position ADD COLUMN IF NOT EXISTS received_at timestamptz;
ALTER TABLE telemetry.ais_position ALTER COLUMN received_at SET DEFAULT clock_timestamp();
ALTER TABLE telemetry.ais_position ADD COLUMN IF NOT EXISTS source_ref text;
ALTER TABLE telemetry.ais_position ADD COLUMN IF NOT EXISTS event_key text;
ALTER TABLE telemetry.ais_position ADD COLUMN IF NOT EXISTS heading_deg numeric(6,1);
CREATE UNIQUE INDEX IF NOT EXISTS position_event72_uq ON telemetry.ais_position(fleet_code,source_kind,event_key) WHERE event_key IS NOT NULL;
CREATE INDEX IF NOT EXISTS position_real72_idx ON telemetry.ais_position(fleet_code,position_at DESC,position_id DESC) WHERE source_kind IN ('MANUAL','GPS','AIS');
CREATE INDEX IF NOT EXISTS position_unknown72_idx ON telemetry.ais_position(fleet_code,position_at DESC,position_id DESC) WHERE source_kind='UNKNOWN';
CREATE INDEX IF NOT EXISTS position_demo72_idx ON telemetry.ais_position(fleet_code,position_at DESC,position_id DESC) WHERE source_kind='DEMO';
ALTER TABLE fleet.info ADD COLUMN IF NOT EXISTS ais_mmsi varchar(9) CHECK(ais_mmsi ~ '^[0-9]{9}$');
CREATE UNIQUE INDEX IF NOT EXISTS fleet_mmsi72_uq ON fleet.info(ais_mmsi) WHERE ais_mmsi IS NOT NULL;
INSERT INTO param.system_parameter(param_key,label,nilai,satuan,keterangan,updated_by) VALUES
 ('position_stale_minutes','Umur posisi untuk monitoring','15','menit','Batas freshness, bukan bukti akurasi sensor.','migrasi'),
 ('position_jump_max_kn','Batas screening lompatan posisi','','knot','Kosong sampai ditetapkan: jangan menyimpulkan lolos screening. Batas kecepatan tersirat antartitik, bukan performa kapal.','migrasi')
ON CONFLICT(param_key) DO NOTHING;
ALTER TABLE fleet.info ADD COLUMN IF NOT EXISTS position_config_version bigint NOT NULL DEFAULT 1 CHECK(position_config_version>0);
COMMIT;
