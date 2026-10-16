-- ============================================================================
-- 06-notifikasi-prod.sql — FEAT-V2: NOTIFIKASI INSTAN (WA/TELEGRAM) · PROD
-- ============================================================================
-- Dua tabel outbox: notification.notif_penerima (dikelola ADMIN di
-- /modul/notifikasi/) + notification.notif_outbox (antrean pesan otomatis
-- dari event operasional: TUGASKAN · SANGGAHAN · SANGGAHAN_PUTUSAN ·
-- MAINTENANCE).
-- Mode OUTBOX (default): pesan tersimpan di DB — tidak terkirim ke mana pun,
-- aman tanpa kredensial. Kirim nyata (go-live): set env TELEGRAM_BOT_TOKEN
-- dan/atau WA_API_URL lalu cron `python manage.py kirim_notif`.
-- Idempoten — aman dijalankan berulang.
-- Pemakaian PROD (Supabase): psql "$DATABASE_URL" -f 06-notifikasi-prod.sql
-- CATATAN: tabel 2FA TOTP tidak ada di file ini — kolom totp_* dibuat
-- OTOMATIS oleh bootstrap_auth (migrasi Django 0002_totp) saat deploy.
-- ============================================================================

-- ---------- 1 · DDL ----------
CREATE SEQUENCE IF NOT EXISTS notification.notif_penerima_penerima_id_seq;
CREATE TABLE IF NOT EXISTS notification.notif_penerima (
    penerima_id bigint NOT NULL DEFAULT nextval('notification.notif_penerima_penerima_id_seq'),
    kanal       character varying(12) NOT NULL,
    tujuan      character varying(120) NOT NULL,
    label       character varying(80) NOT NULL,
    aktif       boolean NOT NULL DEFAULT true,
    created_at  timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT notif_penerima_pkey PRIMARY KEY (penerima_id),
    CONSTRAINT chk_notif_penerima_kanal CHECK (kanal IN ('TELEGRAM','WHATSAPP'))
);
CREATE INDEX IF NOT EXISTS idx_notif_penerima_aktif
    ON notification.notif_penerima (aktif);

CREATE SEQUENCE IF NOT EXISTS notification.notif_outbox_outbox_id_seq;
CREATE TABLE IF NOT EXISTS notification.notif_outbox (
    outbox_id   bigint NOT NULL DEFAULT nextval('notification.notif_outbox_outbox_id_seq'),
    penerima_id bigint REFERENCES notification.notif_penerima,
    kanal       character varying(12) NOT NULL,
    tujuan      character varying(120) NOT NULL,
    event       character varying(40) NOT NULL,
    judul       character varying(200) NOT NULL,
    isi         text NOT NULL,
    status      character varying(10) NOT NULL DEFAULT 'OUTBOX',
    error       text,
    created_at  timestamp with time zone DEFAULT now() NOT NULL,
    sent_at     timestamp with time zone,
    CONSTRAINT notif_outbox_pkey PRIMARY KEY (outbox_id),
    CONSTRAINT chk_notif_outbox_status CHECK (status IN ('OUTBOX','TERKIRIM','GAGAL')),
    CONSTRAINT chk_notif_outbox_kanal CHECK (kanal IN ('TELEGRAM','WHATSAPP'))
);
CREATE INDEX IF NOT EXISTS idx_notif_outbox_status
    ON notification.notif_outbox (status, outbox_id);

COMMENT ON TABLE  notification.notif_penerima IS 'feat-v2: penerima notifikasi instan (WA/Telegram) — dikelola ADMIN di /modul/notifikasi/';
COMMENT ON TABLE  notification.notif_outbox    IS 'feat-v2: antrean pesan instan — status OUTBOX → TERKIRIM/GAGAL oleh command kirim_notif';

-- ---------- 2 · seed: 2 penerima demo (idempoten) ----------
INSERT INTO notification.notif_penerima (kanal, tujuan, label)
SELECT 'TELEGRAM', '-1001234567890', 'Grup Dispatch (demo)'
WHERE NOT EXISTS (SELECT 1 FROM notification.notif_penerima
                   WHERE tujuan = '-1001234567890');
INSERT INTO notification.notif_penerima (kanal, tujuan, label)
SELECT 'WHATSAPP', '+6281234567890', 'Manager Ops (demo)'
WHERE NOT EXISTS (SELECT 1 FROM notification.notif_penerima
                   WHERE tujuan = '+6281234567890');
