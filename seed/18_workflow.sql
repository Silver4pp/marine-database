-- ============================================================
-- SEED DATA: workflow reference data
-- file    : seed/18_workflow.sql
-- objects : 7 statement(s)
-- generated from original/schema_v1_original.sql by tools/split_schema.py
-- ============================================================

-- Workflow: PO Approval
INSERT INTO workflow.definition (workflow_code, workflow_name, module) VALUES
('WF_PO_APPROVAL','Purchase Order Approval','COMMERCIAL');

WITH wf AS (SELECT workflow_id FROM workflow.definition WHERE workflow_code = 'WF_PO_APPROVAL')
INSERT INTO workflow.step (workflow_id, step_order, step_name, step_type, approver_role, timeout_hours, next_step_order_approve)
SELECT wf.workflow_id, 1, 'Manager Review', 'APPROVAL', 'MANAGER', 24, 2 FROM wf;

WITH wf AS (SELECT workflow_id FROM workflow.definition WHERE workflow_code = 'WF_PO_APPROVAL')
INSERT INTO workflow.step (workflow_id, step_order, step_name, step_type, next_step_order_approve)
SELECT wf.workflow_id, 2, 'Finalize', 'END', NULL FROM wf;

-- Workflow: HSE Incident
INSERT INTO workflow.definition (workflow_code, workflow_name, module) VALUES
('WF_INCIDENT','Incident Investigation','HSE');

WITH wf AS (SELECT workflow_id FROM workflow.definition WHERE workflow_code = 'WF_INCIDENT')
INSERT INTO workflow.step (workflow_id, step_order, step_name, step_type, next_step_order_approve)
SELECT wf.workflow_id, 1, 'Start', 'START', 2 FROM wf;

WITH wf AS (SELECT workflow_id FROM workflow.definition WHERE workflow_code = 'WF_INCIDENT')
INSERT INTO workflow.step (workflow_id, step_order, step_name, step_type, approver_role, timeout_hours, next_step_order_approve)
SELECT wf.workflow_id, 2, 'Safety Officer Review', 'APPROVAL', 'SAFETY_OFFICER', 24, 3 FROM wf;

WITH wf AS (SELECT workflow_id FROM workflow.definition WHERE workflow_code = 'WF_INCIDENT')
INSERT INTO workflow.step (workflow_id, step_order, step_name, step_type, next_step_order_approve)
SELECT wf.workflow_id, 3, 'Close', 'END', NULL FROM wf;
