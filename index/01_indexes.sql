-- ============================================================
-- INDEX LAYER: All indexes
-- file    : index/01_indexes.sql
-- objects : 97 statement(s)
-- note    : Tables and materialized views. Includes the partial UNIQUE indexes moved out of the table bodies (FIX-1..3).
-- generated from original/schema_v1_original.sql by tools/split_schema.py
-- ============================================================

-- ============================================================
-- SECTION 28: INDEXES
-- ============================================================

-- Param indexes
CREATE INDEX IF NOT EXISTS idx_param_country_active ON param.country(is_active) WHERE is_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_param_currency_active ON param.currency(is_active) WHERE is_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_param_uom_category ON param.unit_of_measure(category) WHERE is_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_param_status_group ON param.status(status_group) WHERE is_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_param_threshold_param ON param.threshold(parameter_name) WHERE is_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_param_role_active ON param.role(is_active) WHERE is_active = TRUE;

-- Site indexes
CREATE INDEX IF NOT EXISTS idx_site_info_type ON site.info(type_code);

CREATE INDEX IF NOT EXISTS idx_site_info_geom ON site.info USING GIST(geom) WHERE geom IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_site_info_tenant ON site.info(tenant_id) WHERE tenant_id IS NOT NULL;

-- User indexes
CREATE INDEX IF NOT EXISTS idx_user_info_role ON "user".info(role);

CREATE INDEX IF NOT EXISTS idx_user_detail_user ON "user".detail(user_code);

CREATE UNIQUE INDEX IF NOT EXISTS uq_user_primary_contact ON "user".detail(user_code) WHERE is_primary = TRUE AND is_active = TRUE;

-- Partner indexes
CREATE INDEX IF NOT EXISTS idx_partner_info_type ON partner.info(type_code);

CREATE INDEX IF NOT EXISTS idx_partner_info_tenant ON partner.info(tenant_id) WHERE tenant_id IS NOT NULL;

-- Buyer indexes
CREATE INDEX IF NOT EXISTS idx_buyer_info_tenant ON buyer.info(tenant_id) WHERE tenant_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_buyer_ledger_buyer_date ON buyer.ledger_hist(buyer_code, transaction_date DESC, id DESC);

CREATE INDEX IF NOT EXISTS idx_buyer_ledger_ref ON buyer.ledger_hist(ref_doc) WHERE ref_doc IS NOT NULL;

-- Fleet indexes
CREATE INDEX IF NOT EXISTS idx_fleet_info_partner ON fleet.info(partner_code);

CREATE INDEX IF NOT EXISTS idx_fleet_info_type ON fleet.info(type_code);

CREATE INDEX IF NOT EXISTS idx_fleet_assign_site ON fleet.assignment_leg(site_code);

CREATE INDEX IF NOT EXISTS idx_fleet_mtc_fleet_date ON fleet.maintenance(fleet_code, start_date DESC);

-- Form indexes
CREATE INDEX IF NOT EXISTS idx_form_sampling_date ON form.water_sampling(sampling_date DESC);

CREATE INDEX IF NOT EXISTS idx_form_sampling_site ON form.water_sampling(site_code) WHERE site_code IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_form_sample_form ON form.sample(form_no);

CREATE INDEX IF NOT EXISTS idx_form_measurement_sample ON form.measurement(sample_id);

-- Laboratory indexes
CREATE INDEX IF NOT EXISTS idx_lab_result_doc ON laboratory.result(doc_no);

CREATE INDEX IF NOT EXISTS idx_lab_result_sample ON laboratory.result(sample_id) WHERE sample_id IS NOT NULL;

-- Survey indexes
CREATE INDEX IF NOT EXISTS idx_survey_sampling_date ON survey.water_sampling(sampling_date DESC);

CREATE INDEX IF NOT EXISTS idx_survey_measurement_form ON survey.measurement(form_no);

-- Enviro indexes
CREATE INDEX IF NOT EXISTS idx_env_station_site ON enviro.station(site_code) WHERE site_code IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_env_station_geom ON enviro.station USING GIST(geom) WHERE geom IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_env_wq_station_time ON enviro.water_quality(station_code, record_time DESC);

CREATE INDEX IF NOT EXISTS idx_env_tide_station_time ON enviro.tide_reading(station_code, record_time DESC);

CREATE INDEX IF NOT EXISTS idx_env_buoy_station_time ON enviro.buoy_reading(station_code, record_time DESC);

CREATE INDEX IF NOT EXISTS idx_env_reading_station ON enviro.reading(station_code, record_time DESC);

-- Commercial indexes
CREATE INDEX IF NOT EXISTS idx_po_buyer_date ON commercial.purchase_order(buyer_code, po_date DESC);

CREATE INDEX IF NOT EXISTS idx_po_status_date ON commercial.purchase_order(status, po_date DESC) WHERE status IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_do_po_num ON commercial.delivery_order(po_num);

-- Operational indexes
CREATE INDEX IF NOT EXISTS idx_work_area_geom ON operational.work_area USING GIST(geom) WHERE geom IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_si_do ON operational.shipment_instruction(do_num);

CREATE INDEX IF NOT EXISTS idx_si_fleet_main ON operational.shipment_instruction(fleet_main_code);

CREATE INDEX IF NOT EXISTS idx_work_activity_si ON operational.work_activity(si_num, planned_start DESC);

CREATE INDEX IF NOT EXISTS idx_dredging_si_activity ON operational.dredging_records(si_num, activity_num);

CREATE INDEX IF NOT EXISTS idx_dredging_date ON operational.dredging_records(record_date DESC);

-- Voyage indexes
CREATE INDEX IF NOT EXISTS idx_voyage_fleet_time ON voyage.voyage(fleet_code, record_time DESC);

CREATE INDEX IF NOT EXISTS idx_voyage_geom ON voyage.voyage USING GIST(geom) WHERE geom IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_voyage_hist_fleet ON voyage.voyage_hist(fleet_code, record_time DESC);

CREATE INDEX IF NOT EXISTS idx_voyage_hist_geom ON voyage.voyage_hist USING GIST(geom) WHERE geom IS NOT NULL;

-- Financial indexes
CREATE INDEX IF NOT EXISTS idx_fin_account_type ON financial.account(account_type) WHERE is_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_fin_journal_no ON financial.journal(journal_no);

CREATE INDEX IF NOT EXISTS idx_fin_journal_period ON financial.journal(period_year, period_month);

CREATE INDEX IF NOT EXISTS idx_fin_journal_line_journal ON financial.journal_line(journal_id);

CREATE INDEX IF NOT EXISTS idx_fin_invoice_no ON financial.invoice(invoice_no);

CREATE INDEX IF NOT EXISTS idx_fin_invoice_partner ON financial.invoice(partner_code, invoice_date DESC);

CREATE INDEX IF NOT EXISTS idx_fin_payment_no ON financial.payment(payment_no);

CREATE INDEX IF NOT EXISTS idx_fin_payment_partner ON financial.payment(partner_code, payment_date DESC);

-- HSE indexes
CREATE INDEX IF NOT EXISTS idx_hse_incident_no ON hse.incident(incident_no);

CREATE INDEX IF NOT EXISTS idx_hse_incident_date ON hse.incident(incident_date DESC);

CREATE INDEX IF NOT EXISTS idx_hse_incident_severity ON hse.incident(incident_type, severity);

CREATE INDEX IF NOT EXISTS idx_hse_incident_status ON hse.incident(status) WHERE status IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_hse_inspection_no ON hse.inspection(inspection_no);

CREATE INDEX IF NOT EXISTS idx_hse_permit_no ON hse.permit(permit_no);

CREATE INDEX IF NOT EXISTS idx_hse_permit_dates ON hse.permit(start_date, end_date);

CREATE INDEX IF NOT EXISTS idx_hse_emp_training_user ON hse.employee_training(user_code);

CREATE INDEX IF NOT EXISTS idx_hse_emp_training_exp ON hse.employee_training(expiry_date) WHERE expiry_date IS NOT NULL;

-- Security indexes
CREATE INDEX IF NOT EXISTS idx_security_user_scope_auth ON security.user_scope(auth_user_id);

CREATE INDEX IF NOT EXISTS idx_security_user_scope_tenant ON security.user_scope(tenant_id);

CREATE INDEX IF NOT EXISTS idx_security_permission_module ON security.permission(module) WHERE is_active = TRUE;

-- Audit indexes
CREATE INDEX IF NOT EXISTS idx_audit_log_tenant ON audit.log(tenant_id) WHERE tenant_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_audit_log_user ON audit.log(auth_user_id, executed_at DESC);

CREATE INDEX IF NOT EXISTS idx_audit_log_schema_table ON audit.log(table_schema, table_name);

CREATE INDEX IF NOT EXISTS idx_audit_log_time ON audit.log(executed_at DESC);

-- Workflow indexes
CREATE INDEX IF NOT EXISTS idx_workflow_instance_doc ON workflow.instance(document_type, document_id);

CREATE INDEX IF NOT EXISTS idx_workflow_instance_status ON workflow.instance(status);

CREATE INDEX IF NOT EXISTS idx_workflow_instance_step ON workflow.instance_step(instance_id, step_order);

-- Document indexes
CREATE INDEX IF NOT EXISTS idx_document_entity ON document.document(entity_type, entity_id);

CREATE INDEX IF NOT EXISTS idx_document_version_doc ON document.version(document_id, version_no);

CREATE INDEX IF NOT EXISTS idx_document_version_current ON document.version(document_id) WHERE is_current = TRUE;

-- Telemetry indexes
CREATE INDEX IF NOT EXISTS idx_telemetry_raw_partner ON telemetry.raw_message(partner_code, received_at DESC);

CREATE INDEX IF NOT EXISTS idx_telemetry_ais_fleet ON telemetry.ais_position(fleet_code, reported_at DESC);

CREATE INDEX IF NOT EXISTS idx_telemetry_ais_mmsi ON telemetry.ais_position(mmsi, received_at DESC);

CREATE INDEX IF NOT EXISTS idx_telemetry_ais_geom ON telemetry.ais_position USING GIST(geom);

CREATE INDEX IF NOT EXISTS idx_telemetry_latest_partner ON telemetry.vessel_position_latest(partner_code);

CREATE INDEX IF NOT EXISTS idx_telemetry_health_fleet ON telemetry.tracking_health(fleet_code, check_time DESC);

CREATE INDEX IF NOT EXISTS idx_telemetry_geofence_geom ON telemetry.geofence USING GIST(geom);

CREATE INDEX IF NOT EXISTS idx_telemetry_geofence_event ON telemetry.geofence_event(fleet_code, event_time DESC);

-- BRIN indexes for time-series data
CREATE INDEX IF NOT EXISTS brin_env_wq_time ON enviro.water_quality USING BRIN(record_time);

CREATE INDEX IF NOT EXISTS brin_env_tide_time ON enviro.tide_reading USING BRIN(record_time);

CREATE INDEX IF NOT EXISTS brin_env_buoy_time ON enviro.buoy_reading USING BRIN(record_time);

CREATE INDEX IF NOT EXISTS brin_voyage_time ON voyage.voyage USING BRIN(record_time);

CREATE INDEX IF NOT EXISTS brin_voyage_hist_time ON voyage.voyage_hist USING BRIN(record_time);

CREATE INDEX IF NOT EXISTS brin_form_meas_time ON form.measurement USING BRIN(created_at);

-- Reporting view indexes
CREATE UNIQUE INDEX IF NOT EXISTS idx_report_tide_daily ON reporting.tide_read_daily(tenant_id, station_code, record_date);

CREATE UNIQUE INDEX IF NOT EXISTS idx_report_buoy_daily ON reporting.buoy_read_daily(tenant_id, station_code, record_date);

CREATE UNIQUE INDEX IF NOT EXISTS idx_report_dredging_si_date ON reporting.dredging_production(tenant_id, si_num, work_date);

CREATE UNIQUE INDEX IF NOT EXISTS idx_report_account_code ON reporting.account_balance(account_code);

CREATE UNIQUE INDEX IF NOT EXISTS idx_report_hse_month ON reporting.hse_incident_summary(tenant_id, incident_type, severity, incident_month);

-- ============================================================
-- PARTIAL UNIQUE INDEXES (restore FIX-1 .. FIX-3)
-- A UNIQUE constraint inside CREATE TABLE cannot carry a WHERE predicate;
-- these indexes enforce exactly the rule the original constraints intended.
-- ============================================================

-- [FIX-1] was: CONSTRAINT uq_ledger_ref_doc UNIQUE (buyer_code, ref_doc, ref_type) WHERE ref_doc IS NOT NULL
CREATE UNIQUE INDEX IF NOT EXISTS uq_ledger_ref_doc
    ON buyer.ledger_hist(buyer_code, ref_doc, ref_type)
    WHERE ref_doc IS NOT NULL;

-- [FIX-2] were: CONSTRAINT uq_fleet_imo / uq_fleet_mmsi
CREATE UNIQUE INDEX IF NOT EXISTS uq_fleet_imo
    ON fleet.info(imo_number)
    WHERE imo_number IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_fleet_mmsi
    ON fleet.info(mmsi_number)
    WHERE mmsi_number IS NOT NULL;

-- [FIX-3] was: CONSTRAINT uq_current_version UNIQUE (document_id) WHERE is_current = TRUE
CREATE UNIQUE INDEX IF NOT EXISTS uq_current_version
    ON document.version(document_id)
    WHERE is_current = TRUE;
