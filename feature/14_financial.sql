-- ============================================================
-- FEATURE SCHEMA: financial
-- file    : feature/14_financial.sql
-- objects : 12 statement(s)
-- generated from original/schema_v1_original.sql by tools/split_schema.py
-- ============================================================

-- ============================================================
-- SECTION 17: FINANCIAL SCHEMA TABLES
-- ============================================================

CREATE TABLE financial.account (
    account_code    VARCHAR(30)     PRIMARY KEY,
    account_name    VARCHAR(200)    NOT NULL,
    account_type    VARCHAR(30)     NOT NULL
                        CHECK (account_type IN (
                            'ASSET','LIABILITY','EQUITY',
                            'REVENUE','EXPENSE','OTHER'
                        )),
    parent_code     VARCHAR(30)
                        REFERENCES financial.account(account_code) ON DELETE SET NULL,
    account_level   SMALLINT        NOT NULL DEFAULT 1,
    is_detail       BOOLEAN         NOT NULL DEFAULT TRUE,
    currency_code   CHAR(3)
                        REFERENCES param.currency(currency_code) ON DELETE SET NULL,
    description     TEXT,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE financial.journal (
    journal_id      BIGSERIAL       PRIMARY KEY,
    journal_no      VARCHAR(30)     NOT NULL UNIQUE,
    journal_date    DATE            NOT NULL,
    period_year     SMALLINT        NOT NULL,
    period_month    SMALLINT        NOT NULL,
    journal_type    VARCHAR(30)     NOT NULL,
    reference       VARCHAR(100),
    description     TEXT,
    source_module   VARCHAR(30),
    source_id       VARCHAR(50),
    is_posted       BOOLEAN         NOT NULL DEFAULT FALSE,
    posted_by       VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE SET NULL,
    posted_at       TIMESTAMPTZ,
    created_by      VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE SET NULL,
    tenant_id       UUID,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    CONSTRAINT uq_journal_no UNIQUE (journal_no),
    CONSTRAINT chk_period_month CHECK (period_month BETWEEN 1 AND 12)
);

CREATE TABLE financial.journal_line (
    line_id         BIGSERIAL       PRIMARY KEY,
    journal_id      BIGINT          NOT NULL
                        REFERENCES financial.journal(journal_id) ON DELETE CASCADE,
    account_code    VARCHAR(30)     NOT NULL
                        REFERENCES financial.account(account_code) ON DELETE RESTRICT,
    debit           NUMERIC(18,2)   DEFAULT 0 CHECK (debit >= 0),
    credit          NUMERIC(18,2)   DEFAULT 0 CHECK (credit >= 0),
    currency_code   CHAR(3)         NOT NULL
                        REFERENCES param.currency(currency_code) ON DELETE RESTRICT,
    exchange_rate   NUMERIC(18,6)   DEFAULT 1,
    description     TEXT,
    cost_center     VARCHAR(30),
    project_code    VARCHAR(30),
    partner_code    VARCHAR(30)
                        REFERENCES partner.info(partner_code) ON DELETE SET NULL,
    tenant_id       UUID,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    CONSTRAINT chk_debit_or_credit CHECK (
        (debit > 0 AND credit = 0) OR (debit = 0 AND credit > 0)
    )
);

CREATE TABLE financial.invoice (
    invoice_id      BIGSERIAL       PRIMARY KEY,
    invoice_no      VARCHAR(50)     NOT NULL UNIQUE,
    invoice_type    VARCHAR(20)     NOT NULL CHECK (invoice_type IN ('SALES','PURCHASE')),
    partner_code    VARCHAR(30)     NOT NULL
                        REFERENCES partner.info(partner_code) ON DELETE RESTRICT,
    invoice_date    DATE            NOT NULL,
    due_date        DATE,
    currency_code   CHAR(3)         NOT NULL
                        REFERENCES param.currency(currency_code) ON DELETE RESTRICT,
    subtotal        NUMERIC(18,2)   NOT NULL DEFAULT 0,
    tax_amount      NUMERIC(18,2)   NOT NULL DEFAULT 0,
    discount_amount NUMERIC(18,2)   NOT NULL DEFAULT 0,
    total_amount    NUMERIC(18,2)   NOT NULL DEFAULT 0,
    status          VARCHAR(30)
                        REFERENCES param.status(status_code) ON DELETE SET NULL,
    source_module   VARCHAR(30),
    source_doc_no   VARCHAR(50),
    notes           TEXT,
    created_by      VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE SET NULL,
    approved_by     VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE SET NULL,
    tenant_id       UUID,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE financial.invoice_line (
    line_id         BIGSERIAL       PRIMARY KEY,
    invoice_id      BIGINT          NOT NULL
                        REFERENCES financial.invoice(invoice_id) ON DELETE CASCADE,
    description     VARCHAR(500)   NOT NULL,
    quantity        NUMERIC(18,4)  NOT NULL DEFAULT 1,
    uom_code        VARCHAR(20)
                        REFERENCES param.unit_of_measure(uom_code) ON DELETE SET NULL,
    unit_price      NUMERIC(18,4)  NOT NULL DEFAULT 0,
    tax_code        VARCHAR(30),
    tax_rate        NUMERIC(5,2)    DEFAULT 0,
    line_total      NUMERIC(18,2)   NOT NULL DEFAULT 0,
    discount_amount NUMERIC(18,2)   DEFAULT 0,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE financial.payment (
    payment_id      BIGSERIAL       PRIMARY KEY,
    payment_no      VARCHAR(50)     NOT NULL UNIQUE,
    payment_type    VARCHAR(20)     NOT NULL CHECK (payment_type IN ('RECEIPT','DISBURSEMENT')),
    payment_method  VARCHAR(30)     NOT NULL
                        CHECK (payment_method IN ('CASH','BANK_TRANSFER','CHECK','GIRO','OTHER')),
    partner_code    VARCHAR(30)     NOT NULL
                        REFERENCES partner.info(partner_code) ON DELETE RESTRICT,
    payment_date    DATE            NOT NULL,
    currency_code   CHAR(3)         NOT NULL
                        REFERENCES param.currency(currency_code) ON DELETE RESTRICT,
    amount          NUMERIC(18,2)   NOT NULL,
    bank_account    VARCHAR(50),
    reference       VARCHAR(100),
    notes           TEXT,
    status          VARCHAR(30)
                        REFERENCES param.status(status_code) ON DELETE SET NULL,
    created_by      VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE SET NULL,
    tenant_id       UUID,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE financial.payment_line (
    line_id         BIGSERIAL       PRIMARY KEY,
    payment_id      BIGINT          NOT NULL
                        REFERENCES financial.payment(payment_id) ON DELETE CASCADE,
    invoice_id      BIGINT
                        REFERENCES financial.invoice(invoice_id) ON DELETE SET NULL,
    amount          NUMERIC(18,2)   NOT NULL,
    currency_code   CHAR(3)         NOT NULL
                        REFERENCES param.currency(currency_code) ON DELETE RESTRICT,
    exchange_rate   NUMERIC(18,6)   DEFAULT 1,
    notes           TEXT,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE financial.bank_account (
    account_id      VARCHAR(30)     PRIMARY KEY,
    bank_name       VARCHAR(100)    NOT NULL,
    account_number  VARCHAR(50)     NOT NULL,
    account_name    VARCHAR(150)    NOT NULL,
    account_type    VARCHAR(30)     NOT NULL CHECK (account_type IN ('SAVINGS','CHECKING','DEPOSIT')),
    currency_code   CHAR(3)         NOT NULL
                        REFERENCES param.currency(currency_code) ON DELETE RESTRICT,
    branch          VARCHAR(100),
    swift_code      VARCHAR(20),
    tenant_id       UUID,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE financial.bank_transaction (
    trans_id        BIGSERIAL       PRIMARY KEY,
    account_id      VARCHAR(30)     NOT NULL
                        REFERENCES financial.bank_account(account_id) ON DELETE RESTRICT,
    trans_date      DATE            NOT NULL,
    trans_type      VARCHAR(20)     NOT NULL CHECK (trans_type IN ('DEPOSIT','WITHDRAWAL','TRANSFER')),
    amount          NUMERIC(18,2)   NOT NULL,
    currency_code   CHAR(3)         NOT NULL
                        REFERENCES param.currency(currency_code) ON DELETE RESTRICT,
    reference       VARCHAR(100),
    description     TEXT,
    balance_before  NUMERIC(18,2),
    balance_after   NUMERIC(18,2),
    created_by      VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE SET NULL,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE financial.cost_center (
    cost_center_code VARCHAR(30)    PRIMARY KEY,
    cost_center_name VARCHAR(200)    NOT NULL,
    parent_code     VARCHAR(30)
                        REFERENCES financial.cost_center(cost_center_code) ON DELETE SET NULL,
    site_code       VARCHAR(30)
                        REFERENCES site.info(site_code) ON DELETE SET NULL,
    manager_user    VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE SET NULL,
    budget_amount   NUMERIC(18,2),
    tenant_id       UUID,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

-- Financial: Validate journal balance
CREATE OR REPLACE FUNCTION financial.fn_validate_journal_balance()
RETURNS TRIGGER AS $$
DECLARE v_total_debit NUMERIC(18,2); v_total_credit NUMERIC(18,2);
BEGIN
    SELECT COALESCE(SUM(debit), 0), COALESCE(SUM(credit), 0)
    INTO v_total_debit, v_total_credit
    FROM financial.journal_line WHERE journal_id = NEW.journal_id;
    IF v_total_debit <> v_total_credit THEN
        RAISE EXCEPTION 'JOURNAL_UNBALANCED: Debit: % | Credit: %', v_total_debit, v_total_credit;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Financial: Validate journal balance
CREATE OR REPLACE TRIGGER trg_validate_journal_balance
AFTER INSERT OR UPDATE ON financial.journal_line
FOR EACH ROW EXECUTE FUNCTION financial.fn_validate_journal_balance();
