BEGIN;
INSERT INTO param.system_parameter(param_key,label,nilai,satuan,keterangan,updated_by)
VALUES('alarm_shrinkage_pct','Ambang alarm shrinkage trip','5','persen',
 'FR-9-01: total BAP SIGNED/CORRECTED dibanding volume muat setelah bongkar selesai. Perbandingan ketat > ambang, tanpa pembulatan. Berbeda dari flag QA laporan >2%.','migrasi')
ON CONFLICT(param_key) DO NOTHING;
COMMIT;
