-- ============================================================================
-- 00-truncate.sql — KOSONGKAN DATA BISNIS ERP PASIR LAUT (reload data dummy)
-- ============================================================================
-- Pemakaian (Supabase, SQL Editor):
--   1. Jalankan file ini        → semua tabel data bisnis dikosongkan
--   2. Jalankan 02-data-dummy.sql (v2) → isi ulang data demo lengkap
--
-- AMAN:
--   - Schema `public` TIDAK disentuh — akun login (auth_user, core_peran_user),
--     sesi, dan migrasi Django tetap utuh.
--   - RESTART IDENTITY mereset semua sequence (02-data-dummy membawa setval sendiri).
--   - CASCADE menangani FK antar 13 schema secara otomatis.
--
-- PERINGATAN: data operasional yang Anda input sendiri akan TERHAPUS.
-- Termasuk 70 tabel di 15 schema: buyer, commercial, document, enviro, financial, fleet, hse, notification, operational, param, partner, site, survey, telemetry, voyage.
-- ============================================================================

BEGIN;

TRUNCATE TABLE
    buyer.deposit,
    buyer.deposit_transaction,
    buyer.info,
    buyer.ledger_hist,
    buyer.site,
    commercial.bap,
    commercial.bap_correction,
    commercial.bap_objection,
    commercial.delivery_order,
    commercial.purchase_order,
    commercial.qa_sample,
    commercial.sales_contract,
    commercial.sand_spec,
    commercial.standby_claim,
    document.document,
    document.document_link,
    enviro.ews_event,
    enviro.mon_parameter,
    enviro.mon_report,
    enviro.mon_schedule,
    enviro.mon_work_order,
    enviro.reading_detail,
    enviro.remediation,
    enviro.station,
    financial.cost_entry,
    financial.invoice,
    financial.journal,
    financial.journal_line,
    financial.pnbp_charge,
    financial.pnbp_tahap_awal,
    financial.pnbp_tarif,
    fleet.info,
    hse.capa,
    hse.certificate,
    hse.incident,
    hse.induction,
    hse.inspection,
    hse.toolbox_meeting,
    notification.email_outbox,
    notification.log,
    notification.report_schedule,
    notification.rule,
    operational.discharge_event,
    operational.manual_report,
    operational.nor,
    operational.schedule_plan,
    operational.schedule_proposal,
    operational.shipment_instruction,
    operational.site_permit,
    operational.trip,
    operational.waiting_log,
    operational.work_area,
    param.audit_log,
    param.currency,
    param.status,
    param.system_parameter,
    partner.charter_contract,
    partner.info,
    partner.invoice,
    partner.payment,
    partner.payment_allocation,
    partner.rate_card,
    partner.statement_line,
    site.info,
    survey.draft_survey,
    telemetry.ais_position,
    telemetry.geofence,
    telemetry.geofence_event,
    telemetry.vessel_device,
    voyage.voyage
RESTART IDENTITY CASCADE;

COMMIT;

-- Selesai. Lanjutkan dengan menjalankan 02-data-dummy.sql.
