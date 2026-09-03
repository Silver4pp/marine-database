-- ============================================================
-- FEATURE SCHEMA: compliance - regulatory obligation registry
-- file    : feature/24_compliance.sql
-- note    : NEW schema, so it creates itself.
--
--           Answers one question the rest of the schema cannot: which obligation
--           applies to which asset, is the evidence attached, and when does it
--           lapse.
--             requirement         what the regulation demands (global, not per tenant)
--             entity_requirement  which entity must satisfy it: fleet, site, buyer,
--                                 partner, person or document
--             evaluation          the graded result of one check
--             finding             the non-conformance raised from an evaluation
--             alert               what fn_scan_requirements() raises for anything
--                                 that is not COMPLIANT
--
--           Example: "every vessel must hold a valid seaworthiness certificate"
--           becomes one requirement, one entity_requirement per fleet_code, an
--           expiry date, a link to document.document as evidence, and a grade of
--           COMPLIANT / EXPIRING_SOON / EXPIRED / MISSING.
--
--           See compliance.v_requirement_status (view/02_views.sql) and the
--           daily compliance-scan job (cron/01_scheduled_jobs.sql).
-- depends : feature/02_site, 03_user, 04_partner, 05_buyer, 06_fleet, 19_document,
--           23_hse.sql
-- ============================================================

CREATE SCHEMA IF NOT EXISTS compliance;

-- ------------------------------------------------------------
-- compliance.requirement - the obligation itself, defined once for all tenants
-- ------------------------------------------------------------
CREATE TABLE compliance.requirement (
    requirement_id      BIGSERIAL       PRIMARY KEY,
    requirement_code    VARCHAR(30)     NOT NULL UNIQUE,
    requirement_name    VARCHAR(200)    NOT NULL,
    category            VARCHAR(50)     NOT NULL,
    description         TEXT,
    legal_basis         VARCHAR(200),
    issuing_authority   VARCHAR(150),
    applies_to          VARCHAR(30)     NOT NULL
                            CHECK (applies_to IN (
                                'FLEET','SITE','BUYER','PARTNER','PERSON','DOCUMENT','TENANT'
                            )),
    evidence_type_code  VARCHAR(50)
                            REFERENCES document.type(type_code) ON DELETE SET NULL,
    -- how long one issued certificate is good for, so an expiry can be derived
    valid_for_days      INT             CHECK (valid_for_days IS NULL OR valid_for_days > 0),
    warn_days_before    INT             NOT NULL DEFAULT 30 CHECK (warn_days_before >= 0),
    evidence_required   BOOLEAN         NOT NULL DEFAULT FALSE,
    severity            VARCHAR(20)     NOT NULL DEFAULT 'MAJOR'
                            CHECK (severity IN ('MINOR','MAJOR','CRITICAL')),
    is_mandatory        BOOLEAN         NOT NULL DEFAULT TRUE,
    is_active           BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT now()
);

COMMENT ON COLUMN compliance.requirement.category IS
    'Free classification, e.g. VESSEL_CERTIFICATE, CREW_CERTIFICATE, PERMIT, REPORT.';

-- ------------------------------------------------------------
-- compliance.entity_requirement - the obligation applied to exactly one subject
-- ------------------------------------------------------------
CREATE TABLE compliance.entity_requirement (
    entity_req_id       BIGSERIAL       PRIMARY KEY,
    requirement_id      BIGINT          NOT NULL
                            REFERENCES compliance.requirement(requirement_id) ON DELETE RESTRICT,
    entity_type         VARCHAR(30)     NOT NULL
                            CHECK (entity_type IN (
                                'FLEET','SITE','BUYER','PARTNER','PERSON','DOCUMENT','TENANT'
                            )),
    fleet_code          VARCHAR(30)
                            REFERENCES fleet.info(fleet_code) ON DELETE CASCADE,
    site_code           VARCHAR(30)
                            REFERENCES site.info(site_code) ON DELETE SET NULL,
    buyer_code          VARCHAR(30)
                            REFERENCES buyer.info(buyer_code) ON DELETE SET NULL,
    partner_code        VARCHAR(30)
                            REFERENCES partner.info(partner_code) ON DELETE SET NULL,
    person_user_code    VARCHAR(30)
                            REFERENCES "user".info(user_code) ON DELETE SET NULL,
    document_id         BIGINT
                            REFERENCES document.document(document_id) ON DELETE SET NULL,
    reference_no        VARCHAR(50),
    effective_from      DATE            NOT NULL DEFAULT CURRENT_DATE,
    expiry_date         DATE,
    last_verified_at    DATE,
    responsible_user    VARCHAR(30)
                            REFERENCES "user".info(user_code) ON DELETE SET NULL,
    is_active           BOOLEAN         NOT NULL DEFAULT TRUE,
    notes               TEXT,
    tenant_id           UUID,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT now(),
    -- One obligation may bind a subject once; reference_no is deliberately not
    -- part of the key, so re-issuing the certificate cannot create a second row.
    -- NULLS NOT DISTINCT is essential: every subject column except one is NULL,
    -- and a plain UNIQUE treats NULL as distinct, which would let the same
    -- requirement bind the same vessel an unlimited number of times.
    CONSTRAINT uq_entity_requirement_subject
        UNIQUE NULLS NOT DISTINCT (requirement_id, fleet_code, site_code, buyer_code,
                                   partner_code, person_user_code, document_id),
    CONSTRAINT chk_entity_one_subject CHECK (
        (CASE WHEN fleet_code       IS NOT NULL THEN 1 ELSE 0 END
       + CASE WHEN site_code        IS NOT NULL THEN 1 ELSE 0 END
       + CASE WHEN buyer_code       IS NOT NULL THEN 1 ELSE 0 END
       + CASE WHEN partner_code     IS NOT NULL THEN 1 ELSE 0 END
       + CASE WHEN person_user_code IS NOT NULL THEN 1 ELSE 0 END
       + CASE WHEN document_id      IS NOT NULL THEN 1 ELSE 0 END) = 1
    ),
    CONSTRAINT chk_entity_type_matches_subject CHECK (
        (entity_type <> 'FLEET'    OR fleet_code       IS NOT NULL)
        AND (entity_type <> 'SITE'     OR site_code        IS NOT NULL)
        AND (entity_type <> 'BUYER'    OR buyer_code       IS NOT NULL)
        AND (entity_type <> 'PARTNER'  OR partner_code     IS NOT NULL)
        AND (entity_type <> 'PERSON'   OR person_user_code IS NOT NULL)
        AND (entity_type <> 'DOCUMENT' OR document_id      IS NOT NULL)
    )
    -- Deliberately NO check that expiry_date >= effective_from. Registering an
    -- obligation that has already lapsed is the normal case when a registry is
    -- first populated, and that lapsed row is exactly what fn_scan_requirements
    -- has to grade EXPIRED.
);

-- ------------------------------------------------------------
-- compliance.evaluation - one graded check
-- ------------------------------------------------------------
CREATE TABLE compliance.evaluation (
    evaluation_id       BIGSERIAL       PRIMARY KEY,
    entity_req_id       BIGINT          NOT NULL
                            REFERENCES compliance.entity_requirement(entity_req_id) ON DELETE CASCADE,
    evaluated_at        TIMESTAMPTZ     NOT NULL DEFAULT now(),
    evaluated_by        VARCHAR(30)
                            REFERENCES "user".info(user_code) ON DELETE SET NULL,
    grade               VARCHAR(20)     NOT NULL
                            CHECK (grade IN ('COMPLIANT','EXPIRING_SOON','EXPIRED','MISSING')),
    days_to_expiry      INT,
    evidence_document_id BIGINT
                            REFERENCES document.document(document_id) ON DELETE SET NULL,
    source              VARCHAR(20)     NOT NULL DEFAULT 'AUTO'
                            CHECK (source IN ('AUTO','MANUAL','IMPORT')),
    evidence_notes      TEXT,
    tenant_id           UUID,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT now()
);

-- ------------------------------------------------------------
-- compliance.finding - the non-conformance
-- ------------------------------------------------------------
CREATE TABLE compliance.finding (
    finding_id          BIGSERIAL       PRIMARY KEY,
    finding_no          VARCHAR(30)     NOT NULL UNIQUE,
    evaluation_id       BIGINT          NOT NULL
                            REFERENCES compliance.evaluation(evaluation_id) ON DELETE CASCADE,
    entity_req_id       BIGINT          NOT NULL
                            REFERENCES compliance.entity_requirement(entity_req_id) ON DELETE CASCADE,
    grade               VARCHAR(20)     NOT NULL
                            CHECK (grade IN ('EXPIRING_SOON','EXPIRED','MISSING')),
    description         TEXT            NOT NULL,
    severity            VARCHAR(20)     NOT NULL
                            CHECK (severity IN ('MINOR','MAJOR','CRITICAL')),
    reported_to         VARCHAR(150),
    corrective_action_id BIGINT
                            REFERENCES hse.corrective_action(action_id) ON DELETE SET NULL,
    status              VARCHAR(30)
                            REFERENCES param.status(status_code) ON DELETE SET NULL,
    due_date            DATE,
    closed_at           TIMESTAMPTZ,
    tenant_id           UUID,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT now(),
    CONSTRAINT chk_finding_close_needs_date CHECK (
        closed_at IS NULL OR status IS NOT NULL
    )
);

-- ------------------------------------------------------------
-- compliance.alert - what the scanner raises
-- tenant_id deliberately gets no composite FK: entity_requirement has no
-- (tenant_id, entity_req_id) unique key to target, and entity_req_id is already
-- a global surrogate. Isolation comes from RLS instead.
-- ------------------------------------------------------------
CREATE TABLE compliance.alert (
    alert_id            BIGSERIAL       PRIMARY KEY,
    entity_req_id       BIGINT          NOT NULL
                            REFERENCES compliance.entity_requirement(entity_req_id) ON DELETE CASCADE,
    evaluation_id       BIGINT
                            REFERENCES compliance.evaluation(evaluation_id) ON DELETE SET NULL,
    alert_type          VARCHAR(20)     NOT NULL
                            CHECK (alert_type IN ('EXPIRING_SOON','EXPIRED','MISSING')),
    message             TEXT            NOT NULL,
    severity            VARCHAR(20)     NOT NULL
                            CHECK (severity IN ('MINOR','MAJOR','CRITICAL')),
    notify_user         VARCHAR(30)
                            REFERENCES "user".info(user_code) ON DELETE SET NULL,
    is_acknowledged     BOOLEAN         NOT NULL DEFAULT FALSE,
    acknowledged_at     TIMESTAMPTZ,
    acknowledged_by     VARCHAR(30)
                            REFERENCES "user".info(user_code) ON DELETE SET NULL,
    is_active           BOOLEAN         NOT NULL DEFAULT TRUE,
    tenant_id           UUID,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT now()
);

-- one live alert per obligation per type, which is what makes the scanner
-- re-runnable: a second pass inserts nothing
CREATE UNIQUE INDEX IF NOT EXISTS uq_alert_live_per_subject
    ON compliance.alert(entity_req_id, alert_type) WHERE is_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_entity_req_expires
    ON compliance.entity_requirement(expiry_date) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_compliance_alert_open
    ON compliance.alert(notify_user, created_at) WHERE is_active = TRUE AND NOT is_acknowledged;

-- ------------------------------------------------------------
-- Grading
-- MISSING only when the obligation demands evidence and none is attached;
-- otherwise the grade is a pure function of the expiry date.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION compliance.fn_grade(
    p_expiry_date DATE,
    p_warn_days INT,
    p_evidence_required BOOLEAN,
    p_has_evidence BOOLEAN,
    p_ref_date DATE DEFAULT CURRENT_DATE
) RETURNS VARCHAR(20) AS $$
BEGIN
    IF p_evidence_required AND NOT p_has_evidence THEN
        RETURN 'MISSING';
    END IF;
    IF p_expiry_date IS NULL THEN
        RETURN 'COMPLIANT';        -- open-ended obligation
    END IF;
    IF p_expiry_date < p_ref_date THEN
        RETURN 'EXPIRED';
    END IF;
    IF p_expiry_date <= p_ref_date + COALESCE(p_warn_days, 30) THEN
        RETURN 'EXPIRING_SOON';
    END IF;
    RETURN 'COMPLIANT';
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ------------------------------------------------------------
-- Scanner: grade every active obligation, record the evaluation, raise an alert
-- for anything that is not COMPLIANT. Returns the number of NEW alerts, so a
-- second run in a row returns 0 while the live alerts stay live.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION compliance.fn_scan_requirements(
    p_tenant_id UUID DEFAULT NULL
) RETURNS INT AS $$
DECLARE
    r RECORD;
    v_grade VARCHAR(20);
    v_days INT;
    v_eval_id BIGINT;
    v_created INT := 0;
BEGIN
    FOR r IN
        SELECT er.entity_req_id, er.tenant_id, er.expiry_date, er.document_id,
               er.reference_no, er.responsible_user, er.entity_type,
               COALESCE(er.fleet_code, er.site_code, er.buyer_code, er.partner_code,
                        er.person_user_code, er.document_id::TEXT, 'TENANT') AS subject,
               req.requirement_code, req.requirement_name, req.warn_days_before,
               req.severity, req.evidence_required
        FROM compliance.entity_requirement er
        JOIN compliance.requirement req ON req.requirement_id = er.requirement_id
        WHERE er.is_active = TRUE
          AND req.is_active = TRUE
          AND (p_tenant_id IS NULL OR er.tenant_id = p_tenant_id)
    LOOP
        v_days := CASE WHEN r.expiry_date IS NULL THEN NULL
                       ELSE (r.expiry_date - CURRENT_DATE) END;

        v_grade := compliance.fn_grade(r.expiry_date, r.warn_days_before,
                                       r.evidence_required, r.document_id IS NOT NULL);

        INSERT INTO compliance.evaluation (
            entity_req_id, evaluated_by, grade, days_to_expiry,
            evidence_document_id, source, tenant_id
        ) VALUES (
            r.entity_req_id, NULL, v_grade, v_days, r.document_id, 'AUTO', r.tenant_id
        ) RETURNING evaluation_id INTO v_eval_id;

        UPDATE compliance.entity_requirement
        SET last_verified_at = CURRENT_DATE, updated_at = now()
        WHERE entity_req_id = r.entity_req_id;

        IF v_grade <> 'COMPLIANT' THEN
            INSERT INTO compliance.alert (
                entity_req_id, evaluation_id, alert_type, message,
                severity, notify_user, tenant_id
            )
            SELECT r.entity_req_id, v_eval_id, v_grade,
                   format('%s [%s] on %s %s: %s',
                          r.requirement_name, r.requirement_code,
                          lower(r.entity_type), COALESCE(r.subject, r.reference_no),
                          CASE v_grade
                              WHEN 'MISSING' THEN 'required evidence document is not attached'
                              WHEN 'EXPIRED' THEN format('expired %s day(s) ago', ABS(v_days))
                              ELSE format('expires in %s day(s)', v_days)
                          END),
                   r.severity, r.responsible_user, r.tenant_id
            ON CONFLICT DO NOTHING;

            IF FOUND THEN v_created := v_created + 1; END IF;
        END IF;
    END LOOP;

    RETURN v_created;
END;
$$ LANGUAGE plpgsql;
