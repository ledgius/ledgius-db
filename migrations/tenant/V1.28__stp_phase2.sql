-- R-0005: Single Touch Payroll (STP) Phase 2 reporting.
-- Adds STP submission tracking, per-employee YTD aggregates, employer reporting
-- config, and the STP-specific employee fields required for Phase 2 payloads.

-- =============================================================================
-- 1. Employee — STP Phase 2 fields
-- =============================================================================

ALTER TABLE employee
    ADD COLUMN IF NOT EXISTS income_type TEXT NOT NULL DEFAULT 'SAW'
        CHECK (income_type IN ('SAW', 'CHP', 'IAA', 'WHM', 'SWP', 'LAB', 'VOL'));

COMMENT ON COLUMN employee.income_type IS
    'STP Phase 2 income type code: SAW=Salary/Wages, CHP=Closely Held Payee, '
    'IAA=Inbound Assignee, WHM=Working Holiday Maker, SWP=Seasonal Worker, '
    'LAB=Labour Hire, VOL=Voluntary Agreement.';

ALTER TABLE employee
    ADD COLUMN IF NOT EXISTS employment_basis TEXT NOT NULL DEFAULT 'F'
        CHECK (employment_basis IN ('F', 'P', 'C', 'L', 'V', 'D', 'N'));

COMMENT ON COLUMN employee.employment_basis IS
    'STP Phase 2 employment basis: F=Full-time, P=Part-time, C=Casual, '
    'L=Labour hire, V=Voluntary agreement, D=Death beneficiary, N=Non-employee.';

-- =============================================================================
-- 2. Employer reporting configuration
-- =============================================================================

CREATE TABLE IF NOT EXISTS stp_employer_config (
    id              SERIAL PRIMARY KEY,
    abn             TEXT NOT NULL,
    branch_number   TEXT NOT NULL DEFAULT '001',
    contact_name    TEXT NOT NULL,
    contact_email   TEXT NOT NULL,
    contact_phone   TEXT NULL,
    sbr_provider    TEXT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE stp_employer_config IS
    'Employer-level STP reporting configuration. Single row expected per tenant; '
    'multi-ABN reporting is out of scope for R-0005.';
COMMENT ON COLUMN stp_employer_config.branch_number IS
    'ATO branch number — defaults to 001 for single-branch employers.';
COMMENT ON COLUMN stp_employer_config.sbr_provider IS
    'Identifier of the SBR intermediary used for transmission (e.g. "messagexchange").';

-- =============================================================================
-- 3. Employee year-to-date totals
-- =============================================================================

CREATE TABLE IF NOT EXISTS employee_ytd (
    id                    SERIAL PRIMARY KEY,
    employee_id           INT NOT NULL REFERENCES employee(id),
    financial_year        TEXT NOT NULL,
    gross_ytd             NUMERIC NOT NULL DEFAULT 0,
    salary_wages_ytd      NUMERIC NOT NULL DEFAULT 0,
    overtime_ytd          NUMERIC NOT NULL DEFAULT 0,
    bonus_ytd             NUMERIC NOT NULL DEFAULT 0,
    allowances_ytd        JSONB NOT NULL DEFAULT '[]'::jsonb,
    payg_withheld_ytd     NUMERIC NOT NULL DEFAULT 0,
    super_guarantee_ytd   NUMERIC NOT NULL DEFAULT 0,
    salary_sacrifice_ytd  NUMERIC NOT NULL DEFAULT 0,
    deductions_ytd        JSONB NOT NULL DEFAULT '[]'::jsonb,
    leave_balances        JSONB NOT NULL DEFAULT '{}'::jsonb,
    tax_ready             BOOLEAN NOT NULL DEFAULT false,
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (employee_id, financial_year)
);

COMMENT ON TABLE employee_ytd IS
    'Per-employee YTD aggregates that drive STP payloads. STP reports YTD totals '
    '(not per-pay amounts) so this table is the source of truth for submissions.';
COMMENT ON COLUMN employee_ytd.financial_year IS
    'Financial year ending — e.g. "2026" denotes FY 2025-2026 ending 30 June 2026.';
COMMENT ON COLUMN employee_ytd.allowances_ytd IS
    'Categorised allowance YTD: [{"type": "RD", "amount": 123.45}, ...]. '
    'Type codes per ATO Phase 2 allowance schedule (CD, AD, LD, MD, RD, TD, OD).';
COMMENT ON COLUMN employee_ytd.deductions_ytd IS
    'Categorised deductions YTD: [{"type": "union", "amount": 25.00}, ...].';
COMMENT ON COLUMN employee_ytd.leave_balances IS
    'Snapshot of leave balances at last submission: {"annual": h, "personal": h, "long_service": h}.';
COMMENT ON COLUMN employee_ytd.tax_ready IS
    'Set true by EOFY finalisation; allows employee myGov access.';

CREATE INDEX IF NOT EXISTS idx_employee_ytd_emp_fy
    ON employee_ytd(employee_id, financial_year);

-- =============================================================================
-- 4. STP submissions
-- =============================================================================

CREATE TABLE IF NOT EXISTS stp_submission (
    id                  SERIAL PRIMARY KEY,
    pay_run_id          INT NULL REFERENCES pay_run(id),
    event_type          TEXT NOT NULL
        CHECK (event_type IN ('pay_event', 'update', 'finalisation')),
    financial_year      TEXT NOT NULL,
    payload             JSONB NOT NULL,
    status              TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'submitted', 'accepted', 'rejected', 'error')),
    receipt_id          TEXT NULL,
    response_payload    JSONB NULL,
    submitted_at        TIMESTAMPTZ NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE stp_submission IS
    'Immutable audit record of every STP submission (pay event, update, EOFY '
    'finalisation). Updates only allowed for status, receipt_id, response_payload '
    'and submitted_at — payload is frozen at generation time.';
COMMENT ON COLUMN stp_submission.event_type IS
    'pay_event = post-pay-run submission; update = correction to prior data; '
    'finalisation = EOFY tax-ready event.';
COMMENT ON COLUMN stp_submission.payload IS
    'Full STP Phase 2 payload as generated. Includes employer block, per-employee '
    'YTD totals, allowance/deduction breakdown, leave balances, employment basis.';

CREATE INDEX IF NOT EXISTS idx_stp_submission_status
    ON stp_submission(status);
CREATE INDEX IF NOT EXISTS idx_stp_submission_fy
    ON stp_submission(financial_year, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_stp_submission_pay_run
    ON stp_submission(pay_run_id);
