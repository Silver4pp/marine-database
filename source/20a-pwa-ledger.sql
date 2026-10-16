-- Patch -38. Aditif/idempoten; jalankan sebelum kode -38. Tidak mengubah DDL-21 alarm.
BEGIN;
CREATE TABLE IF NOT EXISTS operational.pwa_receipt (
    client_id uuid PRIMARY KEY,
    actor varchar(150) NOT NULL,
    jenis varchar(10) NOT NULL CHECK (jenis IN ('SURVEY','BAP')),
    trip_id bigint NOT NULL,
    tipe varchar(30) NOT NULL DEFAULT '',
    payload_hash varchar(64) NOT NULL,
    record_id bigint NOT NULL,
    snapshot jsonb NOT NULL,
    previous_snapshot jsonb,
    snapshot_hash varchar(64) NOT NULL,
    foto_hash varchar(64) NOT NULL DEFAULT '',
    foto_done boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    foto_completed_at timestamptz
);
ALTER TABLE operational.pwa_receipt ADD COLUMN IF NOT EXISTS previous_snapshot jsonb;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='operational.pwa_receipt'::regclass AND conname='pwa_receipt_trip_fk') THEN
    ALTER TABLE operational.pwa_receipt ADD CONSTRAINT pwa_receipt_trip_fk
      FOREIGN KEY (trip_id) REFERENCES operational.trip(trip_id) ON DELETE RESTRICT NOT VALID;
  END IF;
END $$;
ALTER TABLE operational.pwa_receipt VALIDATE CONSTRAINT pwa_receipt_trip_fk;
CREATE INDEX IF NOT EXISTS pwa_receipt_trip_idx ON operational.pwa_receipt(trip_id);
ALTER TABLE document.form_foto ADD COLUMN IF NOT EXISTS pwa_event uuid;
CREATE UNIQUE INDEX IF NOT EXISTS form_foto_pwa_event_uq ON document.form_foto(pwa_event);
-- Seed/import lama bisa mempunyai ID lebih tinggi daripada posisi sequence.
LOCK TABLE commercial.bap IN SHARE ROW EXCLUSIVE MODE;
SELECT setval(pg_get_serial_sequence('commercial.bap','bap_id'),
              GREATEST(COALESCE((SELECT max(bap_id) FROM commercial.bap),1),
                       nextval(pg_get_serial_sequence('commercial.bap','bap_id'))), true);
COMMIT;
