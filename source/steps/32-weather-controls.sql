BEGIN;
ALTER TABLE operational.cuaca_grid ADD COLUMN IF NOT EXISTS source_meta jsonb NOT NULL DEFAULT '{}'::jsonb;
INSERT INTO param.system_parameter(param_key,label,nilai,satuan,keterangan,updated_by) VALUES
 ('alarm_wind80_ms','Ambang alarm angin model 80 m','','m/s','Kosong sampai pemilik menyetujui ambang khusus angin80m. Bukan angin permukaan atau gust.','migrasi'),
 ('alarm_wave_m','Ambang alarm tinggi gelombang','','m','Kosong sampai pemilik menyetujui ambang operasi. Prakiraan model bukan observasi.','migrasi'),
 ('alarm_weather_age_minutes','Batas umur pengambilan cuaca','120','menit','Batas freshness teknis; bukan umur run model dan bukan batas keselamatan.','migrasi')
ON CONFLICT(param_key) DO NOTHING;
COMMIT;
