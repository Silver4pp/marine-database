-- =====================================================================================
-- 19-cuaca-grid.sql — BRD-v8.2 W0 (FR-8-12): arsip cuaca Open-Meteo di database.
--
-- Tabel penyimpanan grid cuaca area operasi (121 titik, resolusi 0,1°) yang
-- diambil endpoint /peta/cuaca-grid/ (FR-8-10): satu baris per titik grid per
-- jam valid, jendela D-1 s/d D+2 WIB. Setiap fetch segar di-upsert (ON
-- CONFLICT DO UPDATE) sehingga histori cuaca terkumpul lokal dan laporan /
-- analitik cukup membaca tabel ini lewat SQL — tidak memanggil API lagi.
--
-- Idempoten (aman ditempel berulang) · murni aditif · rollback =
--   DROP TABLE operational.cuaca_grid;
--
-- Konvensi: jam_valid = waktu lokal WIB TANPA zona (naive), konsisten dengan
-- konvensi tampilan aplikasi; diperbarui = waktu upsert terakhir (tz aware).
-- Kolom gelombang NULL untuk titik daratan (Marine API tanpa data).
-- =====================================================================================

-- ---------- 1 · FR-8-12: tabel arsip grid cuaca ----------
CREATE TABLE IF NOT EXISTS operational.cuaca_grid (
    lat            numeric(4,2) NOT NULL,     -- -6.50 s/d -5.50
    lon            numeric(5,2) NOT NULL,     -- 105.50 s/d 106.50
    jam_valid      timestamp    NOT NULL,     -- WIB (naive), per jam
    angin_ms       numeric(5,1),              -- kecepatan angin 80 m (m/s)
    angin_der      smallint,                  -- arah datang (derajat)
    hujan_mm       numeric(5,1),              -- presipitasi per jam (mm)
    awan_pct       smallint,                  -- tutupan awan (%)
    gelombang_m    numeric(4,1),              -- tinggi gelombang (m) — null di daratan
    gelombang_der  smallint,                  -- arah gelombang (derajat)
    diperbarui     timestamptz  NOT NULL DEFAULT now(),
    CONSTRAINT pk_cuaca_grid PRIMARY KEY (lat, lon, jam_valid)
);

-- akses per jam (laporan/klien BI membaca jendela waktu)
CREATE INDEX IF NOT EXISTS idx_cuaca_grid_jam ON operational.cuaca_grid (jam_valid);
