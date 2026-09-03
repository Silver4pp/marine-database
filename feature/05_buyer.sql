-- ============================================================
-- FEATURE SCHEMA: buyer
-- file    : feature/05_buyer.sql
-- objects : 6 statement(s)
-- generated from original/schema_v1_original.sql by tools/split_schema.py
-- ============================================================

-- ============================================================
-- SECTION 8: BUYER SCHEMA TABLES
-- ============================================================

CREATE TABLE buyer.info (
    buyer_code      VARCHAR(30)     PRIMARY KEY,
    name            VARCHAR(150)    NOT NULL,
    site_code       VARCHAR(30)
                        REFERENCES site.info(site_code) ON DELETE SET NULL,
    credit_limit    NUMERIC(18,2)   DEFAULT 0 CHECK (credit_limit >= 0),
    payment_terms   VARCHAR(50),
    tax_id          VARCHAR(50),
    contact_person  VARCHAR(150),
    contact_phone   VARCHAR(50),
    contact_email   VARCHAR(100),
    address         TEXT,
    tenant_id       UUID,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE buyer.site (
    id              BIGSERIAL       PRIMARY KEY,
    buyer_code      VARCHAR(30)     NOT NULL
                        REFERENCES buyer.info(buyer_code) ON DELETE CASCADE,
    name            VARCHAR(150),
    site_code       VARCHAR(30)     NOT NULL
                        REFERENCES site.info(site_code) ON DELETE RESTRICT,
    is_primary      BOOLEAN         NOT NULL DEFAULT FALSE,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    CONSTRAINT uq_buyer_site UNIQUE (buyer_code, site_code)
);

CREATE TABLE buyer.ledger_hist (
    id              BIGSERIAL       PRIMARY KEY,
    buyer_code      VARCHAR(30)     NOT NULL
                        REFERENCES buyer.info(buyer_code) ON DELETE RESTRICT,
    transaction_date DATE           NOT NULL,
    transaction_type VARCHAR(20)    NOT NULL
                        CHECK (transaction_type IN ('CREDIT','DEBIT')),
    amount          NUMERIC(18,2)   NOT NULL CHECK (amount >= 0),
    currency_code   CHAR(3)         NOT NULL
                        REFERENCES param.currency(currency_code) ON DELETE RESTRICT,
    ref_doc         VARCHAR(100),
    ref_type        VARCHAR(50),
    description     TEXT,
    reversal_of_id  BIGINT          REFERENCES buyer.ledger_hist(id) ON DELETE SET NULL,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    tenant_id       UUID
    -- [FIX-1] A WHERE predicate is not allowed on a table-level UNIQUE
    -- constraint (PostgreSQL: "syntax error at or near WHERE"). The equivalent
    -- partial UNIQUE index now lives in index/01_indexes.sql.
    -- ORIGINAL (invalid):
    --   CONSTRAINT uq_ledger_ref_doc UNIQUE (buyer_code, ref_doc, ref_type)
    --       WHERE ref_doc IS NOT NULL
);

-- ============================================================
-- END OF TABLES
-- ============================================================

-- ============================================================
-- SECTION 25: FUNCTIONS
-- ============================================================

-- Buyer: Prevent ledger updates
CREATE OR REPLACE FUNCTION buyer.fn_prevent_ledger_update()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Ledger entries are immutable. Create a reversal entry instead.';
END;
$$ LANGUAGE plpgsql;

-- Buyer: Reverse ledger entry
CREATE OR REPLACE FUNCTION buyer.fn_reverse_ledger_entry(
    p_entry_id BIGINT,
    p_reason TEXT
) RETURNS BIGINT AS $$
DECLARE
    v_new_id BIGINT;
    v_entry buyer.ledger_hist%ROWTYPE;
BEGIN
    SELECT * INTO v_entry FROM buyer.ledger_hist WHERE id = p_entry_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Ledger entry not found: %', p_entry_id;
    END IF;
    INSERT INTO buyer.ledger_hist (
        buyer_code, transaction_date, transaction_type, amount,
        currency_code, ref_doc, ref_type, description, reversal_of_id
    ) VALUES (
        v_entry.buyer_code, CURRENT_DATE,
        CASE v_entry.transaction_type WHEN 'CREDIT' THEN 'DEBIT' ELSE 'CREDIT' END,
        v_entry.amount, v_entry.currency_code, v_entry.ref_doc,
        v_entry.ref_type, 'REVERSAL: ' || p_reason, p_entry_id
    ) RETURNING id INTO v_new_id;
    RETURN v_new_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- SECTION 26: TRIGGERS
-- ============================================================

-- Buyer: Prevent ledger updates
CREATE OR REPLACE TRIGGER trg_prevent_ledger_update
BEFORE UPDATE OR DELETE ON buyer.ledger_hist
FOR EACH ROW EXECUTE FUNCTION buyer.fn_prevent_ledger_update();
