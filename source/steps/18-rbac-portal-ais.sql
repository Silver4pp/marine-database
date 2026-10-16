-- =====================================================================================
-- 18-rbac-portal-ais.sql — feat-v11 (BRD-v7): RBAC per modul + arsip audit +
-- kepatuhan strip per line + pemetaan site↔kontrak.
--
-- Idempoten (aman ditempel berulang). Tabel Django (core_peran_user.partner_code)
-- TIDAK di sini — dibuat migrasi 0005 via bootstrap_auth (migrate) di live.
-- =====================================================================================

-- ---------- 1 · W1 FR-7-01: matriks hak akses modul (RBAC) ----------
-- Seed = nilai AKSES hardcoded views.py pada feat-v10 (-17).
CREATE TABLE IF NOT EXISTS param.module_acl (
    modul_key  varchar(40) NOT NULL,
    peran      varchar(12) NOT NULL,
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT pk_module_acl PRIMARY KEY (modul_key, peran)
);

INSERT INTO param.module_acl (modul_key, peran)
SELECT v.m, v.p FROM (VALUES
    ('dashboard','ADMIN'),('dashboard','OPS'),('dashboard','KEU'),('dashboard','HSE'),
    ('trips','ADMIN'),('trips','OPS'),('trips','KEU'),
    ('pelayaran','ADMIN'),('pelayaran','OPS'),
    ('wilayah','ADMIN'),('wilayah','OPS'),
    ('misi','ADMIN'),('misi','OPS'),('misi','SURVEYOR'),
    ('misi_rekap','ADMIN'),('misi_rekap','KEU'),('misi_rekap','OPS'),
    ('deposit','ADMIN'),('deposit','KEU'),
    ('armada','ADMIN'),('armada','OPS'),
    ('kapal','ADMIN'),('kapal','OPS'),
    ('survey','ADMIN'),('survey','OPS'),
    ('keu','ADMIN'),('keu','KEU'),
    ('enviro','ADMIN'),('enviro','OPS'),('enviro','HSE'),
    ('hse','ADMIN'),('hse','HSE'),
    ('laporan','ADMIN'),('laporan','OPS'),('laporan','KEU'),('laporan','HSE'),
    ('notifikasi','ADMIN'),
    ('analitik','ADMIN'),('analitik','OPS'),('analitik','KEU'),('analitik','HSE'),
    ('formulir','ADMIN'),('formulir','OPS'),('formulir','HSE'),
    ('pengaturan','ADMIN'),
    ('indeks','ADMIN'),('indeks','OPS'),('indeks','KEU'),('indeks','HSE'),('indeks','SURVEYOR')
) AS v(m, p)
ON CONFLICT (modul_key, peran) DO NOTHING;

COMMENT ON TABLE param.module_acl IS
'RBAC per modul (BRD-v7 W1): matriks modul×peran — dibaca loader _akses() views.py; guardrail: ADMIN×pengaturan tak boleh dihapus (server-side).';

-- ---------- 2 · W1 FR-7-05: arsip audit (retensi 12 bulan) ----------
CREATE TABLE IF NOT EXISTS param.audit_log_arch (
    audit_id     bigint NOT NULL,
    tabel        text NOT NULL,
    record_key   text NOT NULL,
    kolom        text NOT NULL,
    nilai_lama   text,
    nilai_baru   text,
    diubah_oleh  text NOT NULL,
    diubah_pada  timestamptz NOT NULL,
    diarsip_pada timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT pk_audit_log_arch PRIMARY KEY (audit_id, diarsip_pada)
);
CREATE INDEX IF NOT EXISTS idx_audit_arch_waktu ON param.audit_log_arch (diubah_pada);
CREATE INDEX IF NOT EXISTS idx_audit_arch_tabel ON param.audit_log_arch (tabel);

COMMENT ON TABLE param.audit_log_arch IS
'Arsip param.audit_log > 12 bulan (BRD-v7 W1, keputusan retensi) — dipindah command arsip_audit (cron harian, idempoten); tanpa penghapusan permanen.';

-- ---------- 3 · W3 FR-7-23: pemetaan site↔kontrak ----------
CREATE TABLE IF NOT EXISTS operational.site_contract (
    site_contract_id  bigserial PRIMARY KEY,
    area_code         varchar(30) NOT NULL REFERENCES operational.work_area(area_code),
    sales_contract_id bigint NOT NULL REFERENCES commercial.sales_contract(sales_contract_id),
    valid_from        date NOT NULL,
    valid_to          date,
    catatan           text,
    created_by        varchar(150),
    created_at        timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_site_contract UNIQUE (area_code, sales_contract_id, valid_from),
    CONSTRAINT chk_sc_periode CHECK (valid_to IS NULL OR valid_to >= valid_from)
);
CREATE INDEX IF NOT EXISTS idx_site_contract_area ON operational.site_contract (area_code);

COMMENT ON TABLE operational.site_contract IS
'Pemetaan site (work_area) ↔ kontrak penjualan (BRD-v7 W3): periode berlaku; informatif — TIDAK memblokir trip (keputusan default).';

-- ---------- 4 · W3 FR-7-20: event pelanggaran strip per line ----------
CREATE TABLE IF NOT EXISTS operational.line_compliance (
    compliance_id bigserial PRIMARY KEY,
    trip_id       bigint NOT NULL REFERENCES operational.trip(trip_id),
    line_id       bigint NOT NULL REFERENCES operational.site_line(line_id),
    lon           numeric(10,6) NOT NULL,
    lat           numeric(10,6) NOT NULL,
    jarak_m       integer,
    created_at    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_lc_trip ON operational.line_compliance (trip_id);
CREATE INDEX IF NOT EXISTS idx_lc_line ON operational.line_compliance (line_id);
CREATE INDEX IF NOT EXISTS idx_lc_created ON operational.line_compliance (created_at);

COMMENT ON TABLE operational.line_compliance IS
'Kepatuhan strip per line (BRD-v7 W3): kapal fase MUAT di luar strip line-nya (buffer ±150 m) — dicatat tarik_ais (--cek-strip); notif STRIP_VIOLATION anti-spam 60 mnt.';

-- ---------- 5 · seed demo (feat-v11 W3): 2 garis B-04 + trip LOADING ber-line ----------
-- Supaya fitur strip/kepatuhan bisa DILIHAT (detail trip, laporan, cek strip cron)
-- tanpa harus menggambar garis dulu. Idempoten; kode garis ikut konvensi B04-Lxx.
-- Catatan: strip 1 (antar kedua garis) sengaja MEMUAT pusat blok B-04
-- (±105.954, -5.8325) — kapal fase MUAT yang didrift simulator ke pusat blok
-- tetap PATUH di dalam strip (tidak memicu pelanggaran terus-menerus).
INSERT INTO operational.site_line (line_code, area_code, line_no, geom)
SELECT 'B04-L01', 'B-04', 1,
       ST_GeomFromGeoJSON('{"type":"LineString","coordinates":[[105.935,-5.828],[105.972,-5.827]]}')
WHERE NOT EXISTS (SELECT 1 FROM operational.site_line WHERE area_code='B-04' AND line_no=1);

INSERT INTO operational.site_line (line_code, area_code, line_no, geom)
SELECT 'B04-L02', 'B-04', 2,
       ST_GeomFromGeoJSON('{"type":"LineString","coordinates":[[105.936,-5.836],[105.973,-5.835]]}')
WHERE NOT EXISTS (SELECT 1 FROM operational.site_line WHERE area_code='B-04' AND line_no=2);

INSERT INTO operational.shipment_instruction (si_num, issued_at, status)
SELECT 'SI-2026-DEMO-STRIP', now() - interval '3 hours', 'ISSUED'
WHERE NOT EXISTS (SELECT 1 FROM operational.shipment_instruction WHERE si_num='SI-2026-DEMO-STRIP');

-- Kapal M03 (TB Mulya 03 — sebelumnya fase DOK): dipilih agar TIDAK mengubah
-- kapal yang diasertifkan suite (SL02/S05/B12 punya asersi fase/geofence).
INSERT INTO operational.trip (trip_no, si_num, fleet_code, work_area_code, status,
                              ts_loading_start, line_id, volume_load_m3)
SELECT 'TRP-2026-DEMO-STRIP', 'SI-2026-DEMO-STRIP', 'M03', 'B-04', 'LOADING',
       now() - interval '2 hours',
       (SELECT line_id FROM operational.site_line WHERE area_code='B-04' AND line_no=1), 3200
WHERE NOT EXISTS (SELECT 1 FROM operational.trip WHERE trip_no='TRP-2026-DEMO-STRIP');

-- posisi M03 di dalam strip 1 (patuh), bertanggal konsisten dgn dataset seed
-- (7 Sep — TIDAK tersapu pembersih-an hari-ini milik uji_ops).
INSERT INTO telemetry.ais_position (fleet_code, mmsi, lat, lng, speed_kn, course_deg, position_at)
SELECT 'M03', '', -5.8325, 105.953, 0.4, 90, '2026-09-07 08:30:00+00'
WHERE NOT EXISTS (SELECT 1 FROM telemetry.ais_position
                  WHERE fleet_code='M03' AND lat=-5.8325 AND lng=105.953);
