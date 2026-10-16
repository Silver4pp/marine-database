BEGIN;
CREATE TABLE IF NOT EXISTS operational.pwa_device_health (
 user_id bigint NOT NULL, reported_by varchar(150) NOT NULL, device_id uuid NOT NULL,
 first_seen_at timestamptz NOT NULL DEFAULT now(), last_seen_at timestamptz NOT NULL DEFAULT now(),
 trip_id bigint REFERENCES operational.trip(trip_id) ON DELETE SET NULL,
 queue_count integer CHECK(queue_count BETWEEN 0 AND 10000),
 PRIMARY KEY(user_id,reported_by,device_id)
);
CREATE INDEX IF NOT EXISTS pwa_device_health_trip ON operational.pwa_device_health(trip_id,last_seen_at);
INSERT INTO param.system_parameter(param_key,label,nilai,satuan,keterangan,updated_by) VALUES
 ('pwa_heartbeat_stale_hours','Heartbeat perlu perhatian setelah','6','jam','Hanya trip aktif; bukan bukti perangkat rusak atau kapal offline','patch56'),
 ('rate_bi_per_minute','Batas permintaan BI per IP','60','per menit','Fixed window; konfigurasi cache dibaca ulang maksimal 30 detik','patch56'),
 ('rate_pwa_per_minute','Batas sinkronisasi PWA per IP','30','per menit','Kapal dan surveyor berbagi batas; antrean klien tidak dibuang saat 429','patch56'),
 ('rate_heartbeat_per_second','Batas heartbeat per IP','1','per detik','IP proxy tidak dipercaya kecuali dikonfigurasi eksplisit','patch56')
 ON CONFLICT(param_key) DO NOTHING;
COMMENT ON TABLE operational.pwa_device_health IS 'Receipt time server; queue/trip are client claims. UUID is browser identity, not authenticated physical hardware. Auth lives in a separate DB; owner ID plus username prevents reuse confusion.';
-- Imported document IDs must not collide with the next generated internal ID.
LOCK TABLE document.document IN SHARE ROW EXCLUSIVE MODE;
SELECT setval('document.document_document_id_seq',
  greatest((SELECT last_value FROM document.document_document_id_seq),
           coalesce((SELECT max(document_id) FROM document.document),1)),true);
COMMIT;
