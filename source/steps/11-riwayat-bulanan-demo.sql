-- ============================================================================
-- DDL 11 — FEAT-V6: riwayat pengiriman bulanan DEMO (W4.1 tren + W4.2 forecast)
-- ============================================================================
-- BRD v2 §6 W4.1 (tren musiman) & W4.2 (forecast Holt per pembeli) butuh
-- riwayat bulanan per pembeli ≥6 bulan — data transaksional seed hanya
-- mencakup Jul–Sep 2026. Tabel ini = AGREGAT DEMO (perusahaan fiktif):
-- ganti dengan agregat BAP aktual saat produksi (view/ETL menyusul).
--
--   commercial.shipment_monthly (bulan, buyer_code, volume_m3)
--   · PK (bulan, buyer_code) · source='DEMO_SEED' utk baris contoh
--   · Pola seed: musiman (puncak Aug–Sep, lembah Jun) + lonjakan B-PRN
--     Sep (deviasi >20% vs forecast — memicu peringatan W4.2 di demo).
-- Idempoten: ON CONFLICT DO NOTHING.
-- ============================================================================

CREATE TABLE IF NOT EXISTS commercial.shipment_monthly (
    bulan        date         NOT NULL,
    buyer_code   varchar(30)  NOT NULL,
    volume_m3    numeric(14,3) NOT NULL DEFAULT 0,
    source       varchar(20)  NOT NULL DEFAULT 'DEMO_SEED',
    created_at   timestamptz  NOT NULL DEFAULT now(),
    CONSTRAINT shipment_monthly_pk PRIMARY KEY (bulan, buyer_code),
    CONSTRAINT shipment_monthly_source_check CHECK (source IN ('DEMO_SEED', 'AGG_BAP'))
);
COMMENT ON TABLE commercial.shipment_monthly IS
  'feat-v6 W4.1/W4.2: agregat volume pengiriman bulanan per pembeli — baris DEMO_SEED = riwayat contoh perusahaan fiktif (ganti AGG_BAP saat produksi)';

INSERT INTO commercial.shipment_monthly (bulan, buyer_code, volume_m3) VALUES
  -- B-PRN (kontrak 300 rb m³, IDR 21.500) — tren naik + lonjakan Sep (deviasi)
  ('2026-04-01', 'B-PRN', 21000), ('2026-05-01', 'B-PRN', 22500),
  ('2026-06-01', 'B-PRN', 19800), ('2026-07-01', 'B-PRN', 24600),
  ('2026-08-01', 'B-PRN', 27300), ('2026-09-01', 'B-PRN', 34800),
  -- B-PSR (150 rb m³, IDR 21.000) — musiman halus
  ('2026-04-01', 'B-PSR', 12400), ('2026-05-01', 'B-PSR', 13200),
  ('2026-06-01', 'B-PSR', 10900), ('2026-07-01', 'B-PSR', 14100),
  ('2026-08-01', 'B-PSR', 15600), ('2026-09-01', 'B-PSR', 15200),
  -- B-WKR (non-kontrak aktif — riwayat sporadis, utk demo 'data kurang')
  ('2026-06-01', 'B-WKR', 5200),  ('2026-08-01', 'B-WKR', 6100),
  ('2026-09-01', 'B-WKR', 7400)
ON CONFLICT (bulan, buyer_code) DO NOTHING;
