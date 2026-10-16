-- ============================================================================
-- 15-misi-rutin-insiden.sql — feat-v8.1 (FR-4-11 lanjutan) + FR-4-14 opsional
--   1) Generator misi rutin dari enviro.mon_schedule → draft misi RENCANA
--      (review OPS/ADMIN): kolom source + schedule_id + parameter misi_rutin_*.
--   2) Tautan insiden HSE ↔ misi: kolom incident_id di survey.mission.
-- Idempoten — aman dijalankan berulang. Dijalankan oleh start.sh / runbook.
-- ============================================================================

ALTER TABLE survey.mission
  ADD COLUMN IF NOT EXISTS source      varchar(12) NOT NULL DEFAULT 'MANUAL',
  ADD COLUMN IF NOT EXISTS schedule_id bigint REFERENCES enviro.mon_schedule(schedule_id),
  ADD COLUMN IF NOT EXISTS incident_id bigint REFERENCES hse.incident(incident_id);

CREATE INDEX IF NOT EXISTS idx_msn_schedule ON survey.mission (schedule_id);
CREATE INDEX IF NOT EXISTS idx_msn_incident ON survey.mission (incident_id);

COMMENT ON COLUMN survey.mission.source IS
  'feat-v8.1: asal misi — MANUAL (form OPS/ADMIN) / RUTIN (generator dari enviro.mon_schedule)';
COMMENT ON COLUMN survey.mission.schedule_id IS
  'feat-v8.1: jadwal monitoring asal bila misi dibuat generator rutin (nullable)';
COMMENT ON COLUMN survey.mission.incident_id IS
  'FR-4-14: insiden HSE yang terjadi selama misi (nullable, 1-1 per misi)';

-- taksonomi source dijaga constraint (ditambah sekali, cek dulu agar re-run aman)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_mission_source') THEN
    ALTER TABLE survey.mission
      ADD CONSTRAINT chk_mission_source CHECK (source IN ('MANUAL', 'RUTIN'));
  END IF;
END $$;

INSERT INTO param.system_parameter (param_key, label, nilai, satuan, keterangan, updated_by) VALUES
  ('misi_rutin_aktif', 'Generator misi rutin', '1', 'flag',
   '0/1 — generator terjadwal membuat draft misi RENCANA dari jadwal monitoring untuk review OPS/ADMIN', 'seed'),
  ('misi_rutin_horizon_hari', 'Horizon misi rutin', '7', 'hari',
   'Rentang hari ke depan: jadwal yang jatuh tempo dalam rentang ini dibuatkan draft misi', 'seed'),
  ('misi_rutin_terakhir', 'Generator misi rutin terakhir', '', 'waktu',
   'Terisi otomatis oleh pekerjaan terjadwal (05:30) — dipantau halaman Status Sistem', 'seed')
ON CONFLICT (param_key) DO NOTHING;

-- ---------------- verifikasi pasca-DDL (gagal keras bila salah) ----------------
DO $$
DECLARE
  n_source int; n_sched int; n_incid int; n_param int; n_chk int;
BEGIN
  SELECT count(*) INTO n_source FROM information_schema.columns
   WHERE table_schema='survey' AND table_name='mission' AND column_name IN ('source','schedule_id','incident_id');
  SELECT count(*) INTO n_sched FROM information_schema.columns
   WHERE table_schema='enviro' AND table_name='mon_schedule' AND column_name='next_due';
  SELECT count(*) INTO n_incid FROM information_schema.columns
   WHERE table_schema='hse' AND table_name='incident' AND column_name='incident_id';
  SELECT count(*) INTO n_param FROM param.system_parameter
   WHERE param_key IN ('misi_rutin_aktif', 'misi_rutin_horizon_hari', 'misi_rutin_terakhir');
  SELECT count(*) INTO n_chk FROM pg_constraint WHERE conname = 'chk_mission_source';
  IF n_source <> 3 THEN RAISE EXCEPTION '15: kolom survey.mission kurang (%/3)', n_source; END IF;
  IF n_sched <> 1 THEN RAISE EXCEPTION '15: kolom mon_schedule.next_due tidak ada'; END IF;
  IF n_incid <> 1 THEN RAISE EXCEPTION '15: kolom hse.incident.incident_id tidak ada'; END IF;
  IF n_param <> 3 THEN RAISE EXCEPTION '15: parameter misi_rutin_* kurang (%/3)', n_param; END IF;
  IF n_chk <> 1 THEN RAISE EXCEPTION '15: constraint chk_mission_source tidak terpasang'; END IF;
  RAISE NOTICE '15 OK: source/schedule_id/incident_id + idx + chk_mission_source + 3 param misi_rutin_*';
END $$;
