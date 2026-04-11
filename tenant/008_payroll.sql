-- WP7: Payroll — employees, pay runs, PAYG withholding, superannuation, leave.

-- =============================================================================
-- 1. Employees
-- =============================================================================

CREATE TABLE IF NOT EXISTS employee (
    id                  SERIAL PRIMARY KEY,
    entity_id           INT NULL REFERENCES entity(id),
    first_name          TEXT NOT NULL,
    last_name           TEXT NOT NULL,
    email               TEXT NULL,
    phone               TEXT NULL,
    date_of_birth       DATE NULL,
    start_date          DATE NOT NULL,
    end_date            DATE NULL,
    employment_type     TEXT NOT NULL DEFAULT 'full_time'
        CHECK (employment_type IN ('full_time', 'part_time', 'casual', 'contractor')),
    residency_status    TEXT NOT NULL DEFAULT 'resident'
        CHECK (residency_status IN ('resident', 'non_resident', 'working_holiday')),
    tfn_encrypted       TEXT NULL,
    tfn_provided        BOOLEAN NOT NULL DEFAULT false,
    tax_free_threshold  BOOLEAN NOT NULL DEFAULT true,
    help_debt           BOOLEAN NOT NULL DEFAULT false,
    sfss_debt           BOOLEAN NOT NULL DEFAULT false,
    super_fund_name     TEXT NULL,
    super_fund_abn      TEXT NULL,
    super_fund_usi      TEXT NULL,
    super_member_number TEXT NULL,
    bank_bsb            TEXT NULL,
    bank_account_number TEXT NULL,
    bank_account_name   TEXT NULL,
    active              BOOLEAN NOT NULL DEFAULT true,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE employee IS 'Employee register with ATO-required fields for PAYG and super';
COMMENT ON COLUMN employee.tfn_encrypted IS 'Tax File Number — encrypted at rest. Never expose via API.';
COMMENT ON COLUMN employee.residency_status IS 'Determines which ATO PAYG tax table to apply';
COMMENT ON COLUMN employee.tax_free_threshold IS 'Whether employee has claimed the tax-free threshold with this employer';
COMMENT ON COLUMN employee.help_debt IS 'Higher Education Loan Program — additional withholding required';
COMMENT ON COLUMN employee.sfss_debt IS 'Student Financial Supplement Scheme — additional withholding';

CREATE INDEX IF NOT EXISTS idx_employee_active ON employee(active);

-- =============================================================================
-- 2. Pay Rates
-- =============================================================================

CREATE TABLE IF NOT EXISTS pay_rate (
    id              SERIAL PRIMARY KEY,
    employee_id     INT NOT NULL REFERENCES employee(id),
    rate_type       TEXT NOT NULL DEFAULT 'annual'
        CHECK (rate_type IN ('annual', 'hourly')),
    base_rate       NUMERIC NOT NULL,
    overtime_rate   NUMERIC NULL,
    effective_from  DATE NOT NULL,
    effective_to    DATE NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE pay_rate IS 'Employee pay rates with effective date ranges';

CREATE INDEX IF NOT EXISTS idx_pay_rate_employee ON pay_rate(employee_id, effective_from DESC);

-- =============================================================================
-- 3. Leave Balances
-- =============================================================================

CREATE TABLE IF NOT EXISTS leave_balance (
    id              SERIAL PRIMARY KEY,
    employee_id     INT NOT NULL REFERENCES employee(id),
    leave_type      TEXT NOT NULL CHECK (leave_type IN ('annual', 'personal', 'long_service')),
    balance_hours   NUMERIC NOT NULL DEFAULT 0,
    accrued_hours   NUMERIC NOT NULL DEFAULT 0,
    taken_hours     NUMERIC NOT NULL DEFAULT 0,
    as_at_date      DATE NOT NULL,
    UNIQUE (employee_id, leave_type)
);

COMMENT ON TABLE leave_balance IS 'Current leave balances per employee per leave type';

-- =============================================================================
-- 4. Pay Runs
-- =============================================================================

CREATE TABLE IF NOT EXISTS pay_run (
    id              SERIAL PRIMARY KEY,
    pay_period_start DATE NOT NULL,
    pay_period_end   DATE NOT NULL,
    payment_date     DATE NOT NULL,
    status           TEXT NOT NULL DEFAULT 'draft'
        CHECK (status IN ('draft', 'processed', 'approved', 'paid')),
    total_gross      NUMERIC NOT NULL DEFAULT 0,
    total_tax        NUMERIC NOT NULL DEFAULT 0,
    total_super      NUMERIC NOT NULL DEFAULT 0,
    total_net        NUMERIC NOT NULL DEFAULT 0,
    employee_count   INT NOT NULL DEFAULT 0,
    transaction_id   INT NULL,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE pay_run IS 'Payroll run header — one per pay period';
COMMENT ON COLUMN pay_run.transaction_id IS 'GL transaction ID when pay run is processed';

CREATE TABLE IF NOT EXISTS pay_run_line (
    id              SERIAL PRIMARY KEY,
    pay_run_id      INT NOT NULL REFERENCES pay_run(id),
    employee_id     INT NOT NULL REFERENCES employee(id),
    hours_worked    NUMERIC NOT NULL DEFAULT 0,
    gross_pay       NUMERIC NOT NULL DEFAULT 0,
    tax_withheld    NUMERIC NOT NULL DEFAULT 0,
    super_amount    NUMERIC NOT NULL DEFAULT 0,
    net_pay         NUMERIC NOT NULL DEFAULT 0,
    details_json    JSONB NULL,
    UNIQUE (pay_run_id, employee_id)
);

COMMENT ON TABLE pay_run_line IS 'Individual employee pay calculation within a pay run';
COMMENT ON COLUMN pay_run_line.details_json IS 'Breakdown: base pay, overtime, allowances, deductions, HELP, Medicare';

CREATE INDEX IF NOT EXISTS idx_pay_run_line_run ON pay_run_line(pay_run_id);
CREATE INDEX IF NOT EXISTS idx_pay_run_line_employee ON pay_run_line(employee_id);

-- =============================================================================
-- 5. PAYG Withholding Tax Tables (simplified — coefficients for weekly)
-- =============================================================================

CREATE TABLE IF NOT EXISTS payg_tax_bracket (
    id              SERIAL PRIMARY KEY,
    bracket_name    TEXT NOT NULL,
    residency       TEXT NOT NULL CHECK (residency IN ('resident', 'non_resident', 'working_holiday')),
    tax_free_claimed BOOLEAN NOT NULL,
    weekly_from     NUMERIC NOT NULL,
    weekly_to       NUMERIC NULL,
    coefficient_a   NUMERIC(10,4) NOT NULL,
    coefficient_b   NUMERIC(10,4) NOT NULL,
    effective_from  DATE NOT NULL DEFAULT '2024-07-01',
    effective_to    DATE NULL
);

COMMENT ON TABLE payg_tax_bracket IS 'ATO PAYG withholding tax table coefficients (Schedule 1)';
COMMENT ON COLUMN payg_tax_bracket.coefficient_a IS 'Tax = (a × weekly_earnings) - b (ATO coefficient method)';

-- Seed FY2025 resident tax-free threshold claimed brackets (simplified).
INSERT INTO payg_tax_bracket (bracket_name, residency, tax_free_claimed, weekly_from, weekly_to, coefficient_a, coefficient_b, effective_from)
VALUES
    ('Nil rate', 'resident', true, 0, 359, 0.0000, 0.0000, '2024-07-01'),
    ('19c rate', 'resident', true, 359, 438, 0.1900, 68.3462, '2024-07-01'),
    ('Low bracket', 'resident', true, 438, 548, 0.2348, 88.1308, '2024-07-01'),
    ('Middle bracket', 'resident', true, 548, 721, 0.2190, 79.4462, '2024-07-01'),
    ('32.5c rate', 'resident', true, 721, 865, 0.3477, 150.0093, '2024-07-01'),
    ('Middle-high', 'resident', true, 865, 1282, 0.3450, 147.6731, '2024-07-01'),
    ('37c rate', 'resident', true, 1282, 2307, 0.3900, 205.3385, '2024-07-01'),
    ('45c rate', 'resident', true, 2307, NULL, 0.4700, 389.9231, '2024-07-01'),
    ('No TFN', 'resident', false, 0, NULL, 0.4700, 0.0000, '2024-07-01'),
    ('Non-resident flat', 'non_resident', false, 0, 2307, 0.3250, 0.0000, '2024-07-01'),
    ('Non-resident high', 'non_resident', false, 2307, NULL, 0.4500, 288.6538, '2024-07-01')
ON CONFLICT DO NOTHING;

-- =============================================================================
-- 6. Super Guarantee Rates
-- =============================================================================

CREATE TABLE IF NOT EXISTS super_guarantee_rate (
    id              SERIAL PRIMARY KEY,
    rate            NUMERIC(5,4) NOT NULL,
    effective_from  DATE NOT NULL,
    effective_to    DATE NULL,
    max_quarterly_base NUMERIC NULL
);

COMMENT ON TABLE super_guarantee_rate IS 'Superannuation Guarantee rates by financial year';

INSERT INTO super_guarantee_rate (rate, effective_from, effective_to, max_quarterly_base)
VALUES
    (0.1100, '2023-07-01', '2024-06-30', 62270),
    (0.1150, '2024-07-01', '2025-06-30', 65070),
    (0.1200, '2025-07-01', NULL, NULL)
ON CONFLICT DO NOTHING;
