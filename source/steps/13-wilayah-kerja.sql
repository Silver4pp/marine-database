-- =====================================================================================
-- 13-wilayah-kerja.sql — feat-v7.5 (BRD-v5 5.0-FINAL rev.4): Wilayah Kerja & Site
-- work_zone (izin induk + kuota tunggal + MultiPolygon) → work_area (site anak,
-- +zone_code/+geom/+fence_code by-code) → site_line (garis pembatas bernomor,
-- strip k=[garis k, garis k+1) setengah-terbuka, garis terakhir penutup).
-- trip +line_id +discharge_fence_code. Migrasi WK-01 sekali jalan & idempoten —
-- irisan poligon F-B04/F-B07 (±10,23 km²) DIBERSIHKAN saat migrasi dan
-- ST_Overlaps=false DIVERIFIKASI sebelum commit (NFR-5-02, temuan audit §10-1).
-- Urutan DDL: 12 (feat-v7) → 13 (v5 ini) → 14 (feat-v8/BRD-v4).
-- =====================================================================================
BEGIN;

-- ---------- 1 · work_zone — wilayah kerja (induk: izin + kuota + poligon) ----------
CREATE TABLE IF NOT EXISTS operational.work_zone (
  zone_code     varchar(30)  PRIMARY KEY,
  zone_name     varchar(150) NOT NULL,
  permit_no     varchar(50),
  status        varchar(20)  NOT NULL DEFAULT 'AKTIF',
  geom          geometry(MultiPolygon,4326) NOT NULL,
  quota_m3      numeric(14,3),
  quota_used_m3 numeric(14,3) NOT NULL DEFAULT 0,
  created_at    timestamptz  NOT NULL DEFAULT now(),
  updated_at    timestamptz  NOT NULL DEFAULT now(),
  CONSTRAINT chk_wz_status CHECK (status IN ('AKTIF','DITUTUP')),
  CONSTRAINT chk_wz_quota_used CHECK (quota_used_m3 >= 0)
);
CREATE INDEX IF NOT EXISTS idx_wz_geom ON operational.work_zone USING GIST (geom);

-- ---------- 2 · work_area jadi anak (site) ----------
ALTER TABLE operational.work_area
  ADD COLUMN IF NOT EXISTS zone_code  varchar(30) REFERENCES operational.work_zone(zone_code),
  ADD COLUMN IF NOT EXISTS geom       geometry(Polygon,4326),
  ADD COLUMN IF NOT EXISTS fence_code varchar(50) REFERENCES telemetry.geofence(fence_code);
CREATE INDEX IF NOT EXISTS idx_wa_geom ON operational.work_area USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_wa_zone ON operational.work_area(zone_code);
-- permit_no blok → informatif nullable (sub-nomor); kolom kuota work_area
-- DIPENSIUNKAN (nilai dimigrasi ke wilayah) — dibiarkan agar rollback aman.

-- ---------- 3 · site_line — garis pembatas bernomor per site (level ketiga) ----------
CREATE TABLE IF NOT EXISTS operational.site_line (
  line_id    bigserial PRIMARY KEY,
  line_code  varchar(40) NOT NULL,
  area_code  varchar(30) NOT NULL REFERENCES operational.work_area(area_code),
  line_no    integer     NOT NULL,
  geom       geometry(LineString,4326) NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_sl_code UNIQUE (line_code),
  CONSTRAINT uq_sl_area_no UNIQUE (area_code, line_no)
);
CREATE INDEX IF NOT EXISTS idx_sl_geom ON operational.site_line USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_sl_area ON operational.site_line(area_code, line_no);

-- ---------- 4 · trip: tambat line + lokasi bongkar (FR-5-13/15) ----------
ALTER TABLE operational.trip
  ADD COLUMN IF NOT EXISTS line_id bigint REFERENCES operational.site_line(line_id),
  ADD COLUMN IF NOT EXISTS discharge_fence_code varchar(50) REFERENCES telemetry.geofence(fence_code);

-- ---------- 5 · View strip ter-derive (FR-5-08): strip k = [garis k, garis k+1)
-- ditutup segmen penghubung kedua ujung; garis terakhir = penutup (tanpa strip) ----------
CREATE OR REPLACE VIEW operational.site_strip_v AS
SELECT l1.area_code, l1.line_no AS strip_no,
       l1.line_id AS line_id_awal, l2.line_id AS line_id_akhir,
       l1.line_code AS code_awal, l2.line_code AS code_akhir,
       ST_MakePolygon(ST_MakeLine(ARRAY[
         l1.geom,
         ST_MakeLine(ST_EndPoint(l1.geom), ST_StartPoint(l2.geom)),
         l2.geom,
         ST_MakeLine(ST_EndPoint(l2.geom), ST_StartPoint(l1.geom))
       ])) AS geom
  FROM operational.site_line l1
  JOIN operational.site_line l2
    ON l2.area_code = l1.area_code AND l2.line_no = l1.line_no + 1;

-- ---------- 6 · Kuota wilayah hidup (FR-5-10): BAP sah menaikkan kuota zona,
-- koreksi BAP menyesuaikan dengan pola yang sama ----------
CREATE OR REPLACE FUNCTION operational.fn_bap_sah_kuota() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE v_zone text;
BEGIN
  SELECT w.zone_code INTO v_zone
    FROM commercial.bap b
    JOIN operational.trip t ON t.trip_id = b.trip_id
    JOIN operational.work_area w ON w.area_code = t.work_area_code
   WHERE b.bap_id = NEW.bap_id;
  IF v_zone IS NOT NULL THEN
    UPDATE operational.work_zone
       SET quota_used_m3 = quota_used_m3 + COALESCE(NEW.volume_m3, 0), updated_at = now()
     WHERE zone_code = v_zone;
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_bap_sah_kuota ON commercial.bap;
CREATE TRIGGER trg_bap_sah_kuota AFTER UPDATE OF status ON commercial.bap
  FOR EACH ROW
  WHEN (NEW.status = 'SIGNED' AND OLD.status IS DISTINCT FROM 'SIGNED')
  EXECUTE FUNCTION operational.fn_bap_sah_kuota();

CREATE OR REPLACE FUNCTION operational.fn_bap_koreksi_kuota() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE v_zone text;
BEGIN
  SELECT w.zone_code INTO v_zone
    FROM commercial.bap b
    JOIN operational.trip t ON t.trip_id = b.trip_id
    JOIN operational.work_area w ON w.area_code = t.work_area_code
   WHERE b.bap_id = NEW.bap_id;
  IF v_zone IS NOT NULL THEN
    UPDATE operational.work_zone
       SET quota_used_m3 = greatest(quota_used_m3 + COALESCE(NEW.delta_volume_m3, 0), 0),
           updated_at = now()
     WHERE zone_code = v_zone;
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_bap_koreksi_kuota ON commercial.bap_correction;
CREATE TRIGGER trg_bap_koreksi_kuota AFTER INSERT ON commercial.bap_correction
  FOR EACH ROW EXECUTE FUNCTION operational.fn_bap_koreksi_kuota();

-- ---------- 7 · Migrasi WK-01 (sekali jalan & idempoten) ----------
-- Kuota dihitung dari data LIVE saat eksekusi (angka BRD = snapshot verifikasi
-- 15 Sep 2026: 2.000.000 · 1.135.950). Irisan F-B04/F-B07 dipotong dari F-B07
-- (F-B04 dipertahankan penuh); verifikasi ST_Overlaps=false SEBELUM commit.
DO $migr$
DECLARE
  v_b04 geometry; v_b07 geometry; v_b07_cut geometry; v_union geometry;
BEGIN
  IF EXISTS (SELECT 1 FROM operational.work_zone WHERE zone_code = 'WK-01') THEN
    RAISE NOTICE 'MIGRASI WK-01: sudah ada — lewati (idempoten).';
    RETURN;
  END IF;
  SELECT geom INTO v_b04 FROM telemetry.geofence WHERE fence_code = 'F-B04';
  SELECT geom INTO v_b07 FROM telemetry.geofence WHERE fence_code = 'F-B07';
  IF v_b04 IS NULL OR v_b07 IS NULL THEN
    RAISE EXCEPTION 'MIGRASI WK-01: geofence F-B04/F-B07 tidak ditemukan';
  END IF;
  -- bersihkan irisan: bagian F-B07 yang menumpuk F-B04 dibuang. Difference kedua
  -- (buffer 1e-7° ≈ 1 cm) membuang sliver presisi sub-cm dari koordinat miring
  -- yang membuat ST_Overlaps tetap true walau irisan tampak berupa garis
  -- (temuan uji spasial 15 Sep 2026 — berbagi tepi tetap dibolehkan FR-5-03).
  v_b07_cut := ST_Difference(ST_Difference(v_b07, v_b04),
                             ST_Buffer(v_b04, 0.0000001));
  IF ST_GeometryType(v_b07_cut) = 'ST_MultiPolygon' AND ST_NumGeometries(v_b07_cut) = 1 THEN
    v_b07_cut := ST_GeometryN(v_b07_cut, 1);   -- pastikan Polygon tunggal utk kolom site
  END IF;
  IF ST_GeometryType(v_b07_cut) <> 'ST_Polygon' THEN
    RAISE EXCEPTION 'MIGRASI WK-01: hasil potong F-B07 bukan poligon tunggal (%)',
                    ST_GeometryType(v_b07_cut);
  END IF;
  IF ST_Overlaps(v_b04, v_b07_cut) THEN
    RAISE EXCEPTION 'MIGRASI WK-01: irisan F-B04/F-B07 belum bersih — batalkan';
  END IF;
  v_union := ST_Multi(ST_Union(v_b04, v_b07_cut));

  INSERT INTO operational.work_zone (zone_code, zone_name, permit_no, status, geom,
                                     quota_m3, quota_used_m3)
  VALUES ('WK-01', 'Wilayah Kerja IPPL-2026-014', 'IPPL-2026-014', 'AKTIF', v_union,
          (SELECT sum(quota_m3)      FROM operational.work_area WHERE area_code IN ('B-04','B-07')),
          (SELECT COALESCE(sum(quota_used_m3), 0)
             FROM operational.work_area WHERE area_code IN ('B-04','B-07')));

  UPDATE operational.work_area
     SET zone_code = 'WK-01', geom = v_b04, fence_code = 'F-B04'
   WHERE area_code = 'B-04' AND geom IS NULL;
  UPDATE operational.work_area
     SET zone_code = 'WK-01', geom = v_b07_cut, fence_code = 'F-B07'
   WHERE area_code = 'B-07' AND geom IS NULL;

  -- sumber tunggal: geofence PENGERUKAN tersinkron dari master (read-only di UI)
  UPDATE telemetry.geofence g
     SET geom = w.geom
    FROM operational.work_area w
   WHERE g.fence_code = w.fence_code AND g.fence_type = 'PENGERUKAN' AND w.geom IS NOT NULL;

  -- verifikasi akhir sebelum commit transaksi DDL ini
  IF EXISTS (SELECT 1 FROM operational.work_area a, operational.work_area b
              WHERE a.zone_code IS NOT NULL AND b.zone_code IS NOT NULL
                AND a.area_code < b.area_code AND a.zone_code = b.zone_code
                AND ST_Overlaps(a.geom, b.geom)) THEN
    RAISE EXCEPTION 'MIGRASI WK-01: antar-site masih overlap — batalkan';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM operational.work_zone WHERE zone_code = 'WK-01'
                  AND ST_Covers(geom, (SELECT ST_Union(geom) FROM operational.work_area
                                         WHERE zone_code = 'WK-01'))) THEN
    RAISE EXCEPTION 'MIGRASI WK-01: site tidak tertutup wilayah — batalkan';
  END IF;
  RAISE NOTICE 'MIGRASI WK-01: selesai — irisan dibersihkan, ST_Overlaps=false terverifikasi.';
END $migr$;

COMMIT;
