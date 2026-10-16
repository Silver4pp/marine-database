-- =====================================================================================
-- 20-analytics-mart.sql — BRD-v8.3 W1 (FR-8-01): mart analitik, schema `analytics`.
--
-- 8 view READ-ONLY di schema `analytics` sebagai lapisan stabil untuk laporan,
-- ekspor BI (FR-8-03), dan analisis ad-hoc — aplikasi/BI tidak lagi menulis SQL
-- lintas skema secara manual. Grain TRANSAKSIONAL (per baris sumber) + kolom
-- dimensi tanggal/periode WIB; agregasi (harian/bulanan) ditinggalkan pada
-- pemakai view (GROUP BY) — bukan pre-agregat, agar laporan berpasangan
-- (FR-8-02) menghasilkan baris yang SAMA PERSIS dengan query lamanya.
--
--   v_produksi_harian  : per trip × BAP + tanggal muat     (pasangan produksi-bap)
--   v_pnbp_bulanan     : per PNBP charge + periode         (pasangan pnbp)
--   v_armada_utilisasi : per trip, jam per fase pelayaran  (pasangan standby — parsial,
--                        kolom claim tetap dari commercial.standby_claim)
--   v_hse_insidensi    : per insiden (+CAPA) + bulan, LTI = category 'LTI'
--   v_ikal_periode     : pivot 5 parameter IKAL per (stasiun, periode) + EWS terbuka
--   v_kuota_wilayah    : kuota vs realisasi terkunci per WILAYAH dan per BLOK
--   v_misi_rekap       : per misi (jenis/status/hasil/check) + durasi aktual
--   v_pwa_sinkron      : per event laporan PWA kapal + latensi sinkron
--
-- Rumus IKAL (bobot IKAL_W/IKAL_Q + pembulatan Lampiran III) TIDAK diduplikasi
-- ke SQL — tetap satu sumber kebenaran di aplikasi (core/views.py). View
-- v_ikal_periode hanya menyiapkan INPUT per parameter + status EWS; nilai
-- indeks dihitung aplikasi. Antrean offline PWA bersifat lokal per perangkat
-- (localStorage) — tidak terlihat server; v_pwa_sinkron = event yang sudah
-- diterima + latensinya.
--
-- Konvensi: semua kolom waktu tampil sebagai teks WIB (AT TIME ZONE
-- 'Asia/Jakarta'), konsisten dengan konvensi tampilan aplikasi.
--
-- Idempoten (aman ditempel berulang) · murni aditif · rollback =
--   DROP VIEW analytics.v_produksi_harian, analytics.v_pnbp_bulanan,
--     analytics.v_armada_utilisasi, analytics.v_hse_insidensi,
--     analytics.v_ikal_periode, analytics.v_kuota_wilayah,
--     analytics.v_misi_rekap, analytics.v_pwa_sinkron;
--   DROP SCHEMA analytics;
--
-- Kepemilikan (dev lokal, aplikasi connect sebagai role `erp`): jalankan
-- database/fix-owner.sql SETELAH file ini — blok DO-nya mengalihkan pemilik
-- semua schema/view (termasuk analytics) ke erp. Di Supabase role aplikasi =
-- postgres sehingga tidak diperlukan langkah tambahan.
-- =====================================================================================

-- ---------- 0 · schema ----------
CREATE SCHEMA IF NOT EXISTS analytics;
COMMENT ON SCHEMA analytics IS 'Mart analitik read-only (BRD-v8.3 W1/FR-8-01): 8 view lapisan laporan & BI — grain transaksional, waktu WIB.';

-- ---------- 1 · v_produksi_harian (pasangan laporan produksi-bap) ----------
CREATE OR REPLACE VIEW analytics.v_produksi_harian AS
SELECT t.trip_id,
       to_char(t.ts_loading_start AT TIME ZONE 'Asia/Jakarta', 'YYYY-MM-DD') AS tanggal,
       t.trip_no, t.fleet_code, t.work_area_code, t.status AS status_trip,
       t.volume_load_m3,
       b.bap_no, b.volume_m3 AS volume_bap_m3, b.status AS status_bap,
       to_char(b.issued_at AT TIME ZONE 'Asia/Jakarta', 'YYYY-MM-DD HH24:MI') AS waktu_bap
  FROM operational.trip t
  LEFT JOIN commercial.bap b ON b.trip_id = t.trip_id;
COMMENT ON VIEW analytics.v_produksi_harian IS 'Per trip×BAP + tanggal muat (WIB). Laporan produksi-bap membaca view ini — kolom output identik query lama.';

-- ---------- 2 · v_pnbp_bulanan (pasangan laporan pnbp) ----------
CREATE OR REPLACE VIEW analytics.v_pnbp_bulanan AS
SELECT pc.pnbp_charge_id, pc.period, pc.trip_id, t.trip_no, pc.bap_id, b.bap_no,
       pc.volume_basis_m3, pc.rate, pc.amount, pc.status
  FROM financial.pnbp_charge pc
  JOIN operational.trip t ON t.trip_id = pc.trip_id
  JOIN commercial.bap b ON b.bap_id = pc.bap_id;
COMMENT ON VIEW analytics.v_pnbp_bulanan IS 'Per PNBP charge + periode (teks YYYY-MM, passthrough). Laporan pnbp membaca view ini — kolom output identik query lama.';

-- ---------- 3 · v_armada_utilisasi (pasangan laporan standby — parsial) ----------
CREATE OR REPLACE VIEW analytics.v_armada_utilisasi AS
SELECT t.trip_id, t.trip_no, t.fleet_code, t.status AS status_trip, t.is_locked,
       to_char(t.ts_loading_start AT TIME ZONE 'Asia/Jakarta', 'YYYY-MM') AS bulan_muat,
       round(EXTRACT(EPOCH FROM (t.ts_departed - t.ts_loading_start)) / 3600.0, 2) AS jam_muat,
       round(EXTRACT(EPOCH FROM (t.ts_arrived - t.ts_departed)) / 3600.0, 2) AS jam_pelayaran,
       round(EXTRACT(EPOCH FROM (t.ts_discharge_start - t.ts_arrived)) / 3600.0, 2) AS jam_menunggu,
       round(EXTRACT(EPOCH FROM (t.ts_discharge_end - t.ts_discharge_start)) / 3600.0, 2) AS jam_bongkar,
       round(EXTRACT(EPOCH FROM (t.ts_closed - t.ts_loading_start)) / 3600.0, 2) AS jam_total
  FROM operational.trip t;
COMMENT ON VIEW analytics.v_armada_utilisasi IS 'Per trip: jam tiap fase pelayaran (null bila fase belum terjadi) + bulan muat WIB. Kolom klaim standby TIDAK di sini — laporan standby JOIN commercial.standby_claim.';

-- ---------- 4 · v_hse_insidensi ----------
CREATE OR REPLACE VIEW analytics.v_hse_insidensi AS
SELECT i.incident_id, i.incident_no,
       to_char(i.occurred_at AT TIME ZONE 'Asia/Jakarta', 'YYYY-MM') AS bulan,
       to_char(i.occurred_at AT TIME ZONE 'Asia/Jakarta', 'YYYY-MM-DD') AS tanggal,
       i.fleet_code, i.category AS jenis, (i.category = 'LTI') AS is_lti,
       i.reported_via, i.status,
       CASE WHEN i.closed_at IS NOT NULL
            THEN round(EXTRACT(EPOCH FROM (i.closed_at - i.occurred_at)) / 86400.0, 1) END AS hari_penutupan,
       c.capa_no, c.status AS capa_status, c.due_date AS capa_jatuh_tempo
  FROM hse.incident i
  LEFT JOIN hse.capa c ON c.source_type = 'INCIDENT' AND c.source_ref = i.incident_no
 WHERE i.deleted_at IS NULL;
COMMENT ON VIEW analytics.v_hse_insidensi IS 'Per insiden (soft-delete disaring) + CAPA terkait (source_type INCIDENT, key incident_no). LTI adalah nilai category, bukan flag terpisah.';

-- ---------- 5 · v_ikal_periode ----------
CREATE OR REPLACE VIEW analytics.v_ikal_periode AS
SELECT r.station_code, s.station_name,
       substring(r.source_ref FROM 6) AS periode,           -- 'IKAL-YYYYMM' → 'YYYYMM'
       max(r.value) FILTER (WHERE r.parameter_code = 'TSS')           AS nilai_tss,
       max(r.value) FILTER (WHERE r.parameter_code = 'DO')            AS nilai_do,
       max(r.value) FILTER (WHERE r.parameter_code = 'MINYAK_LEMAK')  AS nilai_minyak_lemak,
       max(r.value) FILTER (WHERE r.parameter_code = 'AMONIA_TOTAL')  AS nilai_amonia_total,
       max(r.value) FILTER (WHERE r.parameter_code = 'ORTOFOSFAT')    AS nilai_ortofosfat,
       count(r.value) AS n_param,
       (count(r.value) >= 5) AS param_lengkap,
       count(e.ews_event_id) FILTER (WHERE e.closed_at IS NULL) AS ews_terbuka,
       count(e.ews_event_id) AS ews_total
  FROM enviro.reading_detail r
  JOIN enviro.station s ON s.station_code = r.station_code
  LEFT JOIN enviro.ews_event e
         ON e.station_code = r.station_code
        AND to_char(e.created_at AT TIME ZONE 'Asia/Jakarta', 'YYYYMM') = substring(r.source_ref FROM 6)
 WHERE r.source_ref LIKE 'IKAL-______'
 GROUP BY r.station_code, s.station_name, substring(r.source_ref FROM 6);
COMMENT ON VIEW analytics.v_ikal_periode IS 'Pivot 5 parameter IKAL per (stasiun, periode YYYYMM) + status EWS. Rumus indeks IKAL tetap di aplikasi (satu sumber kebenaran) — view hanya input.';

-- ---------- 6 · v_kuota_wilayah ----------
CREATE OR REPLACE VIEW analytics.v_kuota_wilayah AS
SELECT 'WILAYAH' AS level, z.zone_code AS kode, z.zone_name AS nama,
       z.permit_no, z.status, z.quota_m3, z.quota_used_m3,
       round(z.quota_used_m3 / NULLIF(z.quota_m3, 0) * 100, 1) AS pct_terpakai,
       (z.quota_m3 - z.quota_used_m3) AS sisa_m3,
       (SELECT count(*) FROM operational.work_area a WHERE a.zone_code = z.zone_code) AS n_blok
  FROM operational.work_zone z
UNION ALL
SELECT 'BLOK', a.area_code, a.area_name,
       a.permit_no, a.status, a.quota_m3, a.quota_used_m3,
       round(a.quota_used_m3 / NULLIF(a.quota_m3, 0) * 100, 1),
       (a.quota_m3 - a.quota_used_m3),
       0
  FROM operational.work_area a;
COMMENT ON VIEW analytics.v_kuota_wilayah IS 'Kuota vs realisasi terkunci (dipicu BAP sah) per WILAYAH (work_zone) dan per BLOK (work_area) — satu bentuk kolom, dibedakan kolom level.';

-- ---------- 7 · v_misi_rekap ----------
CREATE OR REPLACE VIEW analytics.v_misi_rekap AS
SELECT m.mission_id, m.mission_no, m.fleet_code,
       m.mission_kind AS jenis, m.target_type, m.target_code, m.status, m.is_locked,
       m.source, m.schedule_id, m.incident_id,
       to_char(m.planned_start AT TIME ZONE 'Asia/Jakarta', 'YYYY-MM') AS bulan_rencana,
       to_char(m.planned_start AT TIME ZONE 'Asia/Jakarta', 'YYYY-MM-DD HH24:MI') AS rencana_mulai,
       to_char(m.planned_end   AT TIME ZONE 'Asia/Jakarta', 'YYYY-MM-DD HH24:MI') AS rencana_selesai,
       to_char(m.ts_departed   AT TIME ZONE 'Asia/Jakarta', 'YYYY-MM-DD HH24:MI') AS aktual_berangkat,
       to_char(m.ts_returned   AT TIME ZONE 'Asia/Jakarta', 'YYYY-MM-DD HH24:MI') AS aktual_kembali,
       round(EXTRACT(EPOCH FROM (m.ts_returned - m.ts_departed)) / 3600.0, 1) AS durasi_jam,
       (SELECT count(*) FROM survey.mission_result mr WHERE mr.mission_id = m.mission_id) AS n_hasil,
       (SELECT count(*) FROM survey.mission_check mc WHERE mc.mission_id = m.mission_id) AS n_check
  FROM survey.mission m;
COMMENT ON VIEW analytics.v_misi_rekap IS 'Per misi: jenis/status/rentang rencana vs aktual + jumlah hasil & check. Deliverable per misi (unggah vs wajib) menyusul di W2.';

-- ---------- 8 · v_pwa_sinkron ----------
CREATE OR REPLACE VIEW analytics.v_pwa_sinkron AS
SELECT mr.report_id, mr.trip_id, t.trip_no,
       mr.report_type AS jenis_event, mr.reported_by AS perangkat,
       to_char(mr.reported_at AT TIME ZONE 'Asia/Jakarta', 'YYYY-MM') AS bulan,
       to_char(mr.reported_at AT TIME ZONE 'Asia/Jakarta', 'YYYY-MM-DD HH24:MI') AS waktu_lapangan,
       to_char(mr.created_at  AT TIME ZONE 'Asia/Jakarta', 'YYYY-MM-DD HH24:MI') AS waktu_diterima,
       round(EXTRACT(EPOCH FROM (mr.created_at - mr.reported_at)) / 60.0, 1) AS latensi_menit,
       to_char(mr.client_synced_at AT TIME ZONE 'Asia/Jakarta', 'YYYY-MM-DD HH24:MI') AS waktu_sinkron_klien
  FROM operational.manual_report mr
  LEFT JOIN operational.trip t ON t.trip_id = mr.trip_id;
COMMENT ON VIEW analytics.v_pwa_sinkron IS 'Per event laporan PWA kapal yang SUDAH diterima server + latensi (waktu diterima − waktu lapangan). Antrean offline (pending) hidup di localStorage perangkat — tidak terlihat server.';
