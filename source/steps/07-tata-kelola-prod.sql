-- ============================================================================
-- 07-tata-kelola-prod.sql — FEAT-V3 (W1.5): NOTIFIKASI IN-APP · PROD
-- ============================================================================
-- Satu tabel baru: notification.notif_inapp — kotak masuk notifikasi per
-- pengguna (ikon 🔔 topbar + halaman /notifikasi/saya/). Diisi otomatis oleh
-- event yang sama dengan outbox WA/Telegram (TUGASKAN · SANGGAHAN ·
-- SANGGAHAN_PUTUSAN · MAINTENANCE · UJI) — penerima per peran.
--
-- CATATAN: kolom wajib_ganti_sandi + tabel core_login_attempt TIDAK ada di
-- file ini — dibuat OTOMATIS oleh bootstrap_auth (migrasi Django
-- 0003_tata_kelola) saat deploy.
--
-- Idempoten — aman dijalankan berulang.
-- Pemakaian PROD (Supabase): psql "$DATABASE_URL" -f 07-tata-kelola-prod.sql
-- ============================================================================

-- ---------- 1 · DDL ----------
CREATE SCHEMA IF NOT EXISTS notification;
CREATE SEQUENCE IF NOT EXISTS notification.notif_inapp_inapp_id_seq;
CREATE TABLE IF NOT EXISTS notification.notif_inapp (
    inapp_id   bigint NOT NULL DEFAULT nextval('notification.notif_inapp_inapp_id_seq'),
    username   character varying(150) NOT NULL,
    event      character varying(40)  NOT NULL DEFAULT '',
    judul      character varying(200) NOT NULL DEFAULT '',
    isi        character varying(2000) NOT NULL DEFAULT '',
    url        character varying(200) NOT NULL DEFAULT '',
    dibaca     boolean NOT NULL DEFAULT false,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT notif_inapp_pkey PRIMARY KEY (inapp_id)
);
CREATE INDEX IF NOT EXISTS idx_notif_inbox
    ON notification.notif_inapp (username, dibaca);
