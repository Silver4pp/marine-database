-- Target deliberately unset until an ADMIN records the process owner's decision.
INSERT INTO param.system_parameter(param_key,label,nilai,satuan,keterangan,updated_by)
VALUES('alarm_toolbox_target_pct','Target pelaksanaan toolbox tercatat','','persen',
'W4: >0 sampai 100; kosong = belum ditetapkan. Per unit/bulan awal period_week, hanya jendela 7 hari yang sudah selesai. Denominator hanya rencana tersimpan; bukan bukti kehadiran/kelengkapan rencana.','migrasi')
ON CONFLICT(param_key) DO NOTHING;
