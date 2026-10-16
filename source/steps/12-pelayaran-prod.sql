-- =====================================================================================
-- 12-pelayaran-prod.sql — feat-v7 (BRD-v3 3.0-FINAL rev.2): Dokumen Pelayaran
-- W1: RPL/BAK/BAT + approval 2 tingkat + gate berangkat + verifikasi kelengkapan
--     pra-pengiriman (TANPA OCR) + dokumen eksternal + QR keaslian + Lampiran A.
-- Urutan DDL: setelah 11-riwayat-bulanan-demo.sql (dev -13). Idempoten.
-- =====================================================================================
BEGIN;

-- ---------- 1 · Rencana Pelayaran (RPL) — 1 per trip ----------
CREATE TABLE IF NOT EXISTS operational.voyage_plan (
  plan_id               bigserial PRIMARY KEY,
  trip_id               bigint NOT NULL REFERENCES operational.trip(trip_id),
  plan_no               varchar(40) NOT NULL,   -- Lampiran A: RPL/[RUTE]/[KAPAL]/[YYMM]/[DO]-[RPL]
  qr_token              varchar(16) NOT NULL,
  do_seq                integer,                -- urutan pengiriman bulanan (rute|kapal) — dipakai BAK/BAT
  route_note            text,
  etd_plan              timestamptz,
  eta_plan              timestamptz,
  discharge_window      varchar(80),
  discharge_method_plan varchar(20),
  volume_plan_m3        numeric(14,3),
  nav_note              text,
  status                varchar(12) NOT NULL DEFAULT 'DRAFT',  -- DRAFT/SUBMITTED/APPROVED/REJECTED
  created_by            varchar(150),
  submitted_by          varchar(150),
  submitted_at          timestamptz,
  decided_at            timestamptz,
  is_locked             boolean NOT NULL DEFAULT false,
  tenant_id             uuid,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_vp_trip  UNIQUE (trip_id),
  CONSTRAINT uq_vp_no    UNIQUE (plan_no),
  CONSTRAINT uq_vp_qr    UNIQUE (qr_token),
  CONSTRAINT chk_vp_status CHECK (status IN ('DRAFT','SUBMITTED','APPROVED','REJECTED'))
);
CREATE INDEX IF NOT EXISTS idx_vp_status ON operational.voyage_plan(status);

-- ---------- 2 · BA Keberangkatan / BA Kedatangan (payload jsonb per jenis) ----------
CREATE TABLE IF NOT EXISTS operational.voyage_doc (
  doc_id       bigserial PRIMARY KEY,
  doc_no       varchar(40) NOT NULL,   -- BAK/... / BAT/...
  qr_token     varchar(16) NOT NULL,
  doc_type     varchar(20) NOT NULL,   -- BA_KEBERANGKATAN / BA_KEDATANGAN
  trip_id      bigint NOT NULL REFERENCES operational.trip(trip_id),
  payload      jsonb NOT NULL DEFAULT '{}',
  nor_id       uuid REFERENCES operational.nor(nor_id),   -- deklarasi NOR (BAT)
  status       varchar(12) NOT NULL DEFAULT 'DRAFT',
  submitted_by varchar(150),
  submitted_at timestamptz,
  decided_at   timestamptz,
  is_locked    boolean NOT NULL DEFAULT false,
  tenant_id    uuid,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_vd_trip_type UNIQUE (trip_id, doc_type),
  CONSTRAINT uq_vd_no        UNIQUE (doc_no),
  CONSTRAINT uq_vd_qr        UNIQUE (qr_token),
  CONSTRAINT chk_vd_type   CHECK (doc_type IN ('BA_KEBERANGKATAN','BA_KEDATANGAN')),
  CONSTRAINT chk_vd_status CHECK (status IN ('DRAFT','SUBMITTED','APPROVED','REJECTED'))
);
CREATE INDEX IF NOT EXISTS idx_vd_status ON operational.voyage_doc(status);

-- ---------- 3 · Mesin approval generik 2 tingkat (tingkat 1 OPS, tingkat 2 ADMIN) ----------
CREATE TABLE IF NOT EXISTS operational.doc_approval (
  approval_id   bigserial PRIMARY KEY,
  doc_kind      varchar(20) NOT NULL,   -- VOYAGE_PLAN / VOYAGE_DOC
  doc_id        bigint NOT NULL,
  level         integer NOT NULL,       -- 1 = OPS senior · 2 = ADMIN
  approver_role varchar(12) NOT NULL,
  status        varchar(10) NOT NULL DEFAULT 'PENDING',
  decided_by    varchar(150),
  decided_at    timestamptz,
  catatan       text,
  created_at    timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_ap_doc_level UNIQUE (doc_kind, doc_id, level),
  CONSTRAINT chk_ap_status CHECK (status IN ('PENDING','APPROVED','REJECTED')),
  CONSTRAINT chk_ap_level  CHECK (level IN (1,2))
);
CREATE INDEX IF NOT EXISTS idx_ap_doc ON operational.doc_approval(doc_kind, doc_id);

-- ---------- 4 · Hasil aksi "Verifikasi Kelengkapan" per trip (riwayat, terakhir = berlaku) ----------
CREATE TABLE IF NOT EXISTS operational.trip_doc_check (
  check_id    bigserial PRIMARY KEY,
  trip_id     bigint NOT NULL REFERENCES operational.trip(trip_id),
  result      varchar(10) NOT NULL,     -- LULUS / TIDAK
  catatan     text,
  verified_by varchar(150) NOT NULL,
  verified_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_tdc_trip ON operational.trip_doc_check(trip_id, verified_at DESC);

-- ---------- 5 · Verifikasi manual dokumen eksternal (FR-3-12, TANPA OCR) ----------
CREATE TABLE IF NOT EXISTS document.doc_verification (
  verification_id bigserial PRIMARY KEY,
  document_id     bigint NOT NULL REFERENCES document.document(document_id) ON DELETE CASCADE,
  status          varchar(12) NOT NULL DEFAULT 'PENDING',  -- PENDING/COCOK/TIDAK_COCOK
  catatan         text,
  verified_by     varchar(150),
  verified_at     timestamptz,
  CONSTRAINT chk_dv_status CHECK (status IN ('PENDING','COCOK','TIDAK_COCOK'))
);
CREATE INDEX IF NOT EXISTS idx_dv_doc ON document.doc_verification(document_id);

-- ---------- 6 · Registry kode pendek Lampiran A (§9-9: seed master DB, daftar resmi menyusul) ----------
CREATE TABLE IF NOT EXISTS param.doc_code (
  code_kind  varchar(10) NOT NULL,      -- RUTE / LOKASI / KAPAL / BUOY
  code       varchar(20) NOT NULL,
  label      varchar(150),
  ref_table  varchar(40),
  ref_key    varchar(40),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT pk_doc_code PRIMARY KEY (code_kind, code)
);

-- seed: KAPAL dari fleet.info
INSERT INTO param.doc_code (code_kind, code, label, ref_table, ref_key)
SELECT 'KAPAL', f.fleet_code, f.fleet_name, 'fleet.info', f.fleet_code
  FROM fleet.info f
ON CONFLICT (code_kind, code) DO NOTHING;
-- seed: RUTE/LOKASI dari operational.work_area (kode pendek = area_code tanpa strip;
-- daftar resmi asal-tujuan menyusul → ADMIN memperbarui param.doc_code)
INSERT INTO param.doc_code (code_kind, code, label, ref_table, ref_key)
SELECT 'RUTE', replace(w.area_code,'-',''), w.area_name, 'operational.work_area', w.area_code
  FROM operational.work_area w
ON CONFLICT (code_kind, code) DO NOTHING;

-- ---------- 7 · Sequence nomor dokumen — reset bulanan per (jenis, scope) ----------
CREATE TABLE IF NOT EXISTS param.doc_seq (
  jenis    varchar(10) NOT NULL,
  scope    varchar(60) NOT NULL,
  thbl     varchar(6)  NOT NULL,       -- YYMM
  last_no  integer NOT NULL DEFAULT 0,
  CONSTRAINT pk_doc_seq PRIMARY KEY (jenis, scope, thbl)
);

-- ---------- 8 · Parameter gate & checklist (FR-3-10/11 — keras, per parameter) ----------
INSERT INTO param.system_parameter (param_key, label, nilai, keterangan, updated_by) VALUES
  ('pelayaran_gate_rpl',   'Gate berlayar: RPL disetujui', '1', 'Berlayar wajib RPL disetujui (0 = lunak)', 'seed'),
  ('pelayaran_gate_bak',   'Gate berlayar: BA Keberangkatan disetujui', '1', 'Berlayar wajib BAK disetujui (0 = lunak)', 'seed'),
  ('pelayaran_gate_verif', 'Gate berlayar: LULUS VERIFIKASI', '1', 'Berlayar wajib lulus verifikasi kelengkapan (0 = lunak)', 'seed'),
  ('pelayaran_doc_wajib',  'Item checklist wajib', 'RPL,BAK,BAT,BAP', 'EKSTERNAL = opsional terverifikasi', 'seed'),
  ('pelayaran_sla_jam',    'SLA persetujuan dokumen (jam)', '24', 'Pengingat aging persetujuan', 'seed')
ON CONFLICT (param_key) DO NOTHING;

-- ---------- 9 · Perluas CHECK form_foto: jenis DOK_EKSTERNAL (FR-3-12) ----------
-- (tabel dibuat 01-schema.sql dgn 5 jenis feat-v5/v6; feat-v7 menambah satu)
ALTER TABLE document.form_foto DROP CONSTRAINT IF EXISTS form_foto_jenis_check;
ALTER TABLE document.form_foto ADD CONSTRAINT form_foto_jenis_check
  CHECK (form_jenis IN ('DRAFT_SURVEY','BAP','INSPEKSI_HSE','TOOLBOX',
                        'MONITORING_ENVIRO','DOK_EKSTERNAL'));

COMMIT;
