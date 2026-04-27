-- Spec references: R-0073, A-0046, T-0041 Slice 7 — Comparator engine.
--
-- Stage 3 of the runtime architecture per A-0046. Adds:
--
--   1. employment_pay_arrangement — per-employee, point-in-time. Records
--      HOW the employee is paid (the variant — hourly / salary-contract /
--      annualised-wage / commission / piece-rate / HIG / mixed) and the
--      parameters of that arrangement.
--
--   2. pay_arrangement_comparator_outcome — per-pay-run-line. Records
--      the shadow-award calculation result, the actual paid amount, and
--      the cumulative position. Used to drive annualised-wage true-up
--      and reconciliation-gate logic.
--
-- The simpler `employee.pay_arrangement_type` column from V1.52 is kept
-- as a fast-path enum for query/UI; this richer table is consulted by the
-- runtime resolver + comparator. The two stay in sync via the API write
-- path (handler creates both rows on employee setup).

-- ── 1. Employment pay arrangement ───────────────────────────────────

CREATE TABLE IF NOT EXISTS employment_pay_arrangement (
    id                       SERIAL PRIMARY KEY,
    employee_id              INT NOT NULL REFERENCES employee(id) ON DELETE CASCADE,
    arrangement_type         TEXT NOT NULL
        CHECK (arrangement_type IN (
            'hourly',
            'salary_contract',
            'annualised_wage_award',
            'annualised_wage_agreement',
            'high_income_guarantee',
            'commission_incentive',
            'commission_only',
            'piece_rate',
            'mixed'
        )),
    annualised_amount        NUMERIC(19,4) NULL,
    commission_rate          NUMERIC(12,8) NULL,
    base_amount              NUMERIC(19,4) NULL,
    piece_rate_amount        NUMERIC(19,6) NULL,
    bought_out_clauses       JSONB NULL,
    reconciliation_period    TEXT NOT NULL DEFAULT 'annual'
        CHECK (reconciliation_period IN ('annual', 'quarterly', 'monthly')),
    effective_from           DATE NOT NULL,
    effective_to             DATE NULL,
    created_at               TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at               TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT employment_pay_arrangement_period_check
        CHECK (effective_to IS NULL OR effective_to >= effective_from)
);

CREATE INDEX IF NOT EXISTS idx_employment_pay_arrangement_employee_active
    ON employment_pay_arrangement (employee_id, effective_from DESC);

COMMENT ON TABLE employment_pay_arrangement IS 'Per-employee, point-in-time record of HOW the employee is paid: arrangement variant + parameters. Drives the comparator engine (which arrangement-specific calc path runs) and the runtime resolver. Distinct from employee.pay_arrangement_type (kept as a fast-path enum for query/UI).';
COMMENT ON COLUMN employment_pay_arrangement.arrangement_type IS 'Per R-0073 / T-0041 Slice 7 nine-variant enum. Drives which calc path the comparator runs.';
COMMENT ON COLUMN employment_pay_arrangement.annualised_amount IS 'Annual salary in dollars. Required for salary_contract, annualised_wage_award, annualised_wage_agreement, high_income_guarantee.';
COMMENT ON COLUMN employment_pay_arrangement.commission_rate IS 'Commission rate as decimal fraction (e.g. 0.05000000 for 5%). Required for commission_incentive, commission_only.';
COMMENT ON COLUMN employment_pay_arrangement.base_amount IS 'Base salary component for commission_incentive (base + commission). NULL for commission_only.';
COMMENT ON COLUMN employment_pay_arrangement.piece_rate_amount IS 'Per-piece amount for piece_rate arrangements.';
COMMENT ON COLUMN employment_pay_arrangement.bought_out_clauses IS 'JSON list of award clauses the salary buys out — e.g. ["overtime", "weekend_penalties", "evening_loadings"]. Used by the salary-offset comparator to determine which entitlements are folded into the salary vs paid separately.';
COMMENT ON COLUMN employment_pay_arrangement.reconciliation_period IS 'How frequently the comparator true-up reconciles. Annual is default per cl 17 of most awards with annualised provisions.';

-- ── 2. Pay-arrangement comparator outcome ───────────────────────────

CREATE TABLE IF NOT EXISTS pay_arrangement_comparator_outcome (
    id                          BIGSERIAL PRIMARY KEY,
    pay_run_line_id             INT NOT NULL REFERENCES pay_run_line(id) ON DELETE CASCADE,
    arrangement_type            TEXT NOT NULL,
    arrangement_id              INT NOT NULL REFERENCES employment_pay_arrangement(id),
    period_start                DATE NOT NULL,
    period_end                  DATE NOT NULL,
    shadow_amount               NUMERIC(19,4) NOT NULL,
    paid_amount                 NUMERIC(19,4) NOT NULL,
    period_delta                NUMERIC(19,4) NOT NULL,
    cumulative_shadow           NUMERIC(19,4) NOT NULL,
    cumulative_paid             NUMERIC(19,4) NOT NULL,
    cumulative_top_up_due       NUMERIC(19,4) NOT NULL DEFAULT 0,
    reconciliation_period_start DATE NOT NULL,
    reconciliation_period_end   DATE NOT NULL,
    created_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT pay_arrangement_comparator_outcome_one_per_line
        UNIQUE (pay_run_line_id),
    CONSTRAINT pay_arrangement_comparator_outcome_period_check
        CHECK (period_end >= period_start),
    CONSTRAINT pay_arrangement_comparator_outcome_recon_period_check
        CHECK (reconciliation_period_end >= reconciliation_period_start)
);

CREATE INDEX IF NOT EXISTS idx_pay_arrangement_comparator_outcome_arrangement_period
    ON pay_arrangement_comparator_outcome (arrangement_id, reconciliation_period_start, period_end);

COMMENT ON TABLE pay_arrangement_comparator_outcome IS 'Per-pay-run-line shadow-award calculation result. shadow_amount = what the award would have paid for this period; paid_amount = what the arrangement actually paid; period_delta = paid − shadow (negative = under-paid). Cumulative columns track running totals across the reconciliation period for annualised-wage true-up. cumulative_top_up_due > 0 blocks reconciliation close until paid out.';
COMMENT ON COLUMN pay_arrangement_comparator_outcome.shadow_amount IS 'NUMERIC(19,4) per A-0048 money calc precision. Value of the award shadow calculation for THIS pay period.';
COMMENT ON COLUMN pay_arrangement_comparator_outcome.cumulative_top_up_due IS 'Running total of (shadow - paid) where positive — i.e. how much extra the employee would be owed if reconciliation closed today. cl 17.4 (typical award annualised-wage clause): any shortfall must be paid within 14 days of reconciliation. The reconciliation-close API path REFUSES to mark closed when this is > 0.';
