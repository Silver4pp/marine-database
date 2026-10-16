-- ============================================================================
-- 04-fitur-gap-prod.sql — TUTUP GAP MOCKUP (feat-v1 · v2026.09.11-5)
-- ============================================================================
-- Empat fitur yang dijanjikan mockup tapi belum terealisasi:
--   1. Tugaskan Kapal (DO antre → SI otomatis + trip dibuat, FR-02-02)
--      → TANPA DDL baru: operational.shipment_instruction + operational.trip
--        + commercial.delivery_order sudah ada. Yang diperbaiki: SEQUENCE
--        si_id/trip_id tertinggal di 28 (seed memakai id eksplisit) — wajib
--        setval agar INSERT baru tidak bentrok PRIMARY KEY.
--   2. Sanggahan customer / BapObjection (FR-05-09) → TANPA DDL
--      (commercial.bap_objection sudah ada sejak Sprint 1).
--   3. QA sample vs spec kontrak → TANPA DDL (commercial.qa_sample ada).
--   4. Maintenance window = hard constraint penjadwalan (fleet.vessel_maintenance)
--      → SATU-SATUNYA DDL baru di file ini + seed 2 jendela perawatan.
-- Seed tambahan: 2 DO berstatus ISSUED (antre) agar fitur Tugaskan Kapal
-- langsung terlihat bermakna.
-- Idempoten — aman dijalankan berulang.
-- Pemakaian PROD (Supabase): psql "$DATABASE_URL" -f 04-fitur-gap-prod.sql
-- Pemakaian DEV          : sudo -u postgres psql -d uat_pasir_laut -f /tmp/04.sql
-- ============================================================================

-- ---------- 1 · DDL: jendela perawatan kapal (hard constraint) ----------
CREATE SEQUENCE IF NOT EXISTS fleet.vessel_maintenance_maintenance_id_seq;

CREATE TABLE IF NOT EXISTS fleet.vessel_maintenance (
    maintenance_id bigint NOT NULL DEFAULT nextval('fleet.vessel_maintenance_maintenance_id_seq'),
    fleet_code     character varying(30) NOT NULL REFERENCES fleet.info(fleet_code),
    jenis          character varying(30) NOT NULL DEFAULT 'PERBAIKAN_RUTIN',
    window_start   timestamp with time zone NOT NULL,
    window_end     timestamp with time zone NOT NULL,
    catatan        text,
    dibuat_oleh    character varying(150),
    created_at     timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT vessel_maintenance_pkey PRIMARY KEY (maintenance_id),
    CONSTRAINT chk_maintenance_jenis CHECK (jenis IN ('DOCKING','PERBAIKAN_RUTIN','DARURAT')),
    CONSTRAINT chk_maintenance_window CHECK (window_end > window_start)
);
CREATE INDEX IF NOT EXISTS idx_maintenance_window
    ON fleet.vessel_maintenance (fleet_code, window_start);
COMMENT ON TABLE  fleet.vessel_maintenance IS 'Jendela perawatan kapal — HARD CONSTRAINT: kapal di dalam jendela tidak boleh ditugaskan (Tugaskan Kapal) & digambar di Gantt';
COMMENT ON COLUMN fleet.vessel_maintenance.jenis IS 'DOCKING · PERBAIKAN_RUTIN · DARURAT';

-- ---------- 2 · setval sequence SI & TRIP (seed memakai id eksplisit!) ----------
SELECT setval('operational.shipment_instruction_si_id_seq',
              COALESCE((SELECT max(si_id) FROM operational.shipment_instruction), 1));
SELECT setval('operational.trip_trip_id_seq',
              COALESCE((SELECT max(trip_id) FROM operational.trip), 1));
SELECT setval('commercial.delivery_order_do_id_seq',
              COALESCE((SELECT max(do_id) FROM commercial.delivery_order), 1));
SELECT setval('commercial.bap_objection_bap_objection_id_seq',
              COALESCE((SELECT max(bap_objection_id) FROM commercial.bap_objection), 1));
SELECT setval('fleet.vessel_maintenance_maintenance_id_seq',
              COALESCE((SELECT max(maintenance_id) FROM fleet.vessel_maintenance), 1));

-- ---------- 3 · seed: 2 jendela perawatan (idempoten) ----------
INSERT INTO fleet.vessel_maintenance (fleet_code, jenis, window_start, window_end, catatan, dibuat_oleh)
SELECT 'SL07', 'DOCKING', now() - interval '6 hours', now() + interval '5 days',
       'Docking berkala 2 tahun — kapal TIDAK DITUGASKAN selama jendela ini.', 'system'
WHERE NOT EXISTS (SELECT 1 FROM fleet.vessel_maintenance
                   WHERE fleet_code='SL07' AND jenis='DOCKING');

INSERT INTO fleet.vessel_maintenance (fleet_code, jenis, window_start, window_end, catatan, dibuat_oleh)
SELECT 'LI02', 'PERBAIKAN_RUTIN', now() - interval '2 hours', now() + interval '2 days',
       'Perbaikan pompa hopper di darat — belum siap berlayar.', 'system'
WHERE NOT EXISTS (SELECT 1 FROM fleet.vessel_maintenance
                   WHERE fleet_code='LI02' AND jenis='PERBAIKAN_RUTIN');

-- ---------- 4 · seed: 2 DO antre (ISSUED, belum ditugaskan) ----------
INSERT INTO commercial.delivery_order (do_no, po_id, vessel_name, volume_m3, do_date, status, fleet_code)
SELECT 'DO-2026-0399', (SELECT po_id FROM commercial.purchase_order WHERE po_no = 'PO-2026-0088'),
       '—', 5200.000, current_date, 'ISSUED', NULL
WHERE NOT EXISTS (SELECT 1 FROM commercial.delivery_order WHERE do_no = 'DO-2026-0399')
  AND EXISTS (SELECT 1 FROM commercial.purchase_order WHERE po_no = 'PO-2026-0088');

INSERT INTO commercial.delivery_order (do_no, po_id, vessel_name, volume_m3, do_date, status, fleet_code)
SELECT 'DO-2026-0400', (SELECT po_id FROM commercial.purchase_order WHERE po_no = 'PO-2026-0090'),
       '—', 3200.000, current_date, 'ISSUED', NULL
WHERE NOT EXISTS (SELECT 1 FROM commercial.delivery_order WHERE do_no = 'DO-2026-0400')
  AND EXISTS (SELECT 1 FROM commercial.purchase_order WHERE po_no = 'PO-2026-0090');
