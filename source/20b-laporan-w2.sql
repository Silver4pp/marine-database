-- W2: lapisan laporan detail dan filter jadwal. Aditif/idempoten.
BEGIN;
ALTER TABLE notification.report_schedule ADD COLUMN IF NOT EXISTS filters jsonb NOT NULL DEFAULT '{}'::jsonb;

CREATE OR REPLACE VIEW analytics.v_laporan_hse AS
SELECT 'INSIDEN'::text AS kelompok, i.incident_no AS nomor, i.bulan, i.tanggal::date AS tanggal,
       i.fleet_code, i.jenis, i.status, i.capa_no, i.capa_status, i.capa_jatuh_tempo,
       NULL::boolean AS inspeksi_terlambat
FROM analytics.v_hse_insidensi i
UNION ALL
SELECT 'INSPEKSI', inspection_no, to_char(scheduled_date,'YYYY-MM'), scheduled_date,
       unit_kode, checklist, status, NULL, NULL, NULL,
       status='SCHEDULED' AND scheduled_date < (now() AT TIME ZONE 'Asia/Jakarta')::date
FROM hse.inspection;

CREATE OR REPLACE VIEW analytics.v_laporan_misi AS
SELECT v.*, substring(v.rencana_mulai,1,10)::date AS tanggal,
       CASE WHEN v.jenis IN ('BATHY','SAMP','ENV','BUOY') THEN 1 ELSE 0 END AS lms_wajib,
       (SELECT count(*) FROM document.document d WHERE d.entity_type='mission'
         AND d.entity_id=v.mission_id AND d.doc_type='LAPORAN_AKHIR') AS lms_terunggah,
       (SELECT count(*) FROM document.document d WHERE d.entity_type='mission'
         AND d.entity_id=v.mission_id AND d.doc_type='LAPORAN_AKHIR'
         AND EXISTS (SELECT 1 FROM document.doc_verification dv WHERE dv.document_id=d.document_id AND dv.status='COCOK')) AS lms_terverifikasi
FROM analytics.v_misi_rekap v;

-- Agregasi EWS dipisah supaya banyak EWS tidak menggandakan jumlah parameter.
CREATE OR REPLACE VIEW analytics.v_laporan_ikal AS
WITH readings AS (
 SELECT r.station_code,s.station_name,substring(r.source_ref FROM 6) AS periode,
   max(r.value) FILTER(WHERE parameter_code='TSS') AS nilai_tss,
   max(r.value) FILTER(WHERE parameter_code='DO') AS nilai_do,
   max(r.value) FILTER(WHERE parameter_code='MINYAK_LEMAK') AS nilai_minyak_lemak,
   max(r.value) FILTER(WHERE parameter_code='AMONIA_TOTAL') AS nilai_amonia_total,
   max(r.value) FILTER(WHERE parameter_code='ORTOFOSFAT') AS nilai_ortofosfat,
   count(DISTINCT parameter_code) FILTER(WHERE r.value IS NOT NULL AND parameter_code IN ('TSS','DO','MINYAK_LEMAK','AMONIA_TOTAL','ORTOFOSFAT')) AS n_param
 FROM enviro.reading_detail r JOIN enviro.station s ON s.station_code=r.station_code
 WHERE r.source_ref ~ '^IKAL-[0-9]{6}$'
 GROUP BY r.station_code,s.station_name,substring(r.source_ref FROM 6)
)
SELECT r.*, to_date(r.periode||'01','YYYYMMDD') AS tanggal,
 CASE WHEN n_param=5 THEN 'LENGKAP' ELSE 'PARSIAL' END AS status,
 (SELECT count(*) FROM enviro.ews_event e WHERE e.station_code=r.station_code AND to_char(e.created_at AT TIME ZONE 'Asia/Jakarta','YYYYMM')=r.periode) AS ews_total,
 (SELECT count(*) FROM enviro.ews_event e WHERE e.station_code=r.station_code AND to_char(e.created_at AT TIME ZONE 'Asia/Jakarta','YYYYMM')=r.periode AND e.closed_at IS NULL) AS ews_terbuka
FROM readings r;

CREATE OR REPLACE VIEW analytics.v_laporan_armada AS
SELECT v.*, (t.ts_loading_start AT TIME ZONE 'Asia/Jakarta')::date AS tanggal,
       v.status_trip AS status,
       (SELECT string_agg(m.jenis||': '||to_char(m.window_start AT TIME ZONE 'Asia/Jakarta','YYYY-MM-DD HH24:MI')||'–'||to_char(m.window_end AT TIME ZONE 'Asia/Jakarta','YYYY-MM-DD HH24:MI'), '; ' ORDER BY m.window_start)
        FROM fleet.vessel_maintenance m WHERE m.fleet_code=v.fleet_code
          AND m.window_start <= COALESCE(t.ts_closed,now()) AND m.window_end >= t.ts_loading_start) AS jendela_perawatan,
       'Jam fase per trip; bukan jam mesin atau persentase utilisasi kalender'::text AS basis_jam
FROM analytics.v_armada_utilisasi v JOIN operational.trip t ON t.trip_id=v.trip_id;

CREATE OR REPLACE VIEW analytics.v_laporan_kuota AS
WITH hist AS (
 SELECT t.work_area_code,
 sum(GREATEST(0,b.volume_m3-COALESCE((SELECT sum(c.delta_volume_m3) FROM commercial.bap_correction c WHERE c.bap_id=b.bap_id),0))) AS volume_90hari
 FROM commercial.bap b JOIN operational.trip t ON t.trip_id=b.trip_id
 WHERE b.status IN ('SIGNED','CORRECTED') AND b.issued_at >= now()-interval '90 days' AND b.issued_at <= now()
 GROUP BY t.work_area_code
), scope AS (
 SELECT 'BLOK'::text AS level,h.work_area_code AS kode,h.volume_90hari FROM hist h
 UNION ALL
 SELECT 'WILAYAH', a.zone_code,sum(h.volume_90hari) FROM hist h
 JOIN operational.work_area a ON a.area_code=h.work_area_code GROUP BY a.zone_code
)
SELECT v.*, h.volume_90hari,
 CASE WHEN h.volume_90hari>0 THEN round(GREATEST(0,v.sisa_m3)/(h.volume_90hari/90),1) END AS estimasi_hari_habis,
 'Estimasi linier 90 hari kalender; kelengkapan histori belum diverifikasi'::text AS basis_proyeksi
FROM analytics.v_kuota_wilayah v LEFT JOIN scope h ON h.level=v.level AND h.kode=v.kode;

CREATE OR REPLACE VIEW analytics.v_laporan_pwa AS
SELECT v.*, t.fleet_code, substring(v.waktu_lapangan,1,10)::date AS tanggal,
       'DITERIMA'::text AS status, NULL::integer AS antrean_lokal,
       'Antrean offline belum diketahui server; menunggu heartbeat W4'::text AS kualitas_antrean
FROM analytics.v_pwa_sinkron v LEFT JOIN operational.trip t ON t.trip_id=v.trip_id;
-- Pertahankan kontrak BI lama, tetapi gunakan hitungan parameter/EWS yang tidak berlipat.
CREATE OR REPLACE VIEW analytics.v_ikal_periode AS
SELECT station_code,station_name,periode,nilai_tss,nilai_do,nilai_minyak_lemak,
       nilai_amonia_total,nilai_ortofosfat,n_param,(n_param=5) AS param_lengkap,
       ews_terbuka,ews_total
FROM analytics.v_laporan_ikal;
COMMIT;
