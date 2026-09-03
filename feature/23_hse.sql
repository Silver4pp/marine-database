-- ============================================================
-- FEATURE SCHEMA: hse - corrective actions
-- file    : feature/23_hse.sql
-- note    : The hse tables themselves come from the original (feature/15_hse.sql).
--           This file adds the one entity the original was missing.
--
--           Until now a corrective action was a free-text column:
--           hse.incident.corrective_action TEXT, hse.inspection_finding.corrective_action
--           TEXT, hse.inspection_finding.assigned_to / due_date / status. Free text
--           cannot be owned, cannot be aged, and cannot be reported, so overdue
--           HSE work was invisible.
--
--           hse.corrective_action makes it a first-class row: an owner, a due
--           date, a verification step, and hse.v_overdue_actions to surface what
--           is late. Findings link to it through inspection_finding.corrective_action_id.
--
--           Child tables without their own tenant_id (incident_witness,
--           permit_approval, inspection_finding, employee_training,
--           ppe_distribution) are covered by parent-verifying RLS policies in
--           base/06_rls.sql rather than by a denormalised tenant_id column.
-- depends : feature/03_user.sql, feature/02_site.sql, feature/15_hse.sql
-- ============================================================

-- ------------------------------------------------------------
-- hse.corrective_action
-- ------------------------------------------------------------
CREATE TABLE hse.corrective_action (
    action_id       BIGSERIAL       PRIMARY KEY,
    action_no       VARCHAR(30)     NOT NULL UNIQUE,
    source_type     VARCHAR(30)     NOT NULL
                        CHECK (source_type IN (
                            'INCIDENT','PERMIT','INSPECTION_FINDING','AUDIT','REGULATORY'
                        )),
    -- generic origin, so a new source needs no schema change
    source_id       BIGINT          NOT NULL,
    -- typed conveniences for the sources that exist today
    incident_id     BIGINT
                        REFERENCES hse.incident(incident_id) ON DELETE CASCADE,
    finding_id      BIGINT,          -- FK added below, after the table exists
    title           VARCHAR(300)    NOT NULL,
    description     TEXT,
    severity        VARCHAR(20)
                        CHECK (severity IN ('LOW','MEDIUM','HIGH','CRITICAL')),
    owner_user_code VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE SET NULL,
    site_code       VARCHAR(30)
                        REFERENCES site.info(site_code) ON DELETE SET NULL,
    opened_at       TIMESTAMPTZ     NOT NULL DEFAULT now(),
    due_date        DATE            NOT NULL,
    status          VARCHAR(30)
                        REFERENCES param.status(status_code) ON DELETE SET NULL,
    completed_at    TIMESTAMPTZ,
    verified_by     VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE SET NULL,
    verified_at     TIMESTAMPTZ,
    closed_at       TIMESTAMPTZ,
    effectiveness_review_at DATE,
    notes           TEXT,
    tenant_id       UUID,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    CONSTRAINT uq_corrective_source UNIQUE (source_type, source_id),
    CONSTRAINT chk_ca_source_matches CHECK (
        (source_type <> 'INCIDENT' OR incident_id IS NOT NULL)
        AND (source_type <> 'INSPECTION_FINDING' OR finding_id IS NOT NULL)
    ),
    CONSTRAINT chk_ca_complete_needs_date CHECK (
        completed_at IS NULL OR (completed_at >= opened_at)
    ),
    -- the point of the whole table: nobody may close an action without naming
    -- who verified it. Keyed on closed_at, not on status, so it also catches
    -- a plain "UPDATE ... SET closed_at = now()".
    CONSTRAINT chk_ca_close_requires_verify CHECK (
        closed_at IS NULL OR (verified_by IS NOT NULL AND verified_at IS NOT NULL)
    ),
    CONSTRAINT chk_ca_close_after_complete CHECK (
        closed_at IS NULL OR completed_at IS NULL OR closed_at >= completed_at
    )
);

-- deferred: a finding and its corrective action are created in one transaction
ALTER TABLE hse.corrective_action
    ADD CONSTRAINT fk_ca_finding
    FOREIGN KEY (finding_id) REFERENCES hse.inspection_finding(finding_id)
    ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;

-- the reverse link, so the free-text column can be migrated to a real reference
ALTER TABLE hse.inspection_finding
    ADD COLUMN corrective_action_id BIGINT
        REFERENCES hse.corrective_action(action_id) ON DELETE SET NULL;

COMMENT ON COLUMN hse.inspection_finding.corrective_action IS
    'LEGACY free-text action. Use corrective_action_id -> hse.corrective_action instead.';

CREATE INDEX IF NOT EXISTS idx_ca_open_due
    ON hse.corrective_action (due_date)
    WHERE closed_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_ca_owner_open
    ON hse.corrective_action (owner_user_code, due_date)
    WHERE closed_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_ca_incident
    ON hse.corrective_action (incident_id) WHERE incident_id IS NOT NULL;

-- ------------------------------------------------------------
-- Ageing helper. Zero for anything already closed, so a "days late" column never
-- keeps counting after the work is done.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION hse.fn_days_overdue(p_due_date DATE, p_closed_at TIMESTAMPTZ)
RETURNS INT AS $$
BEGIN
    IF p_closed_at IS NOT NULL THEN RETURN 0; END IF;
    RETURN GREATEST(0, (CURRENT_DATE - p_due_date));
END;
$$ LANGUAGE plpgsql STABLE;
