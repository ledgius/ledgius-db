-- Spec references: R-0073, A-0046, T-0041 Slice 2 — schema follow-up.
--
-- Adds the workplace-relations data model so the layered runtime resolver
-- can look up an employee's award + classification + worker type and
-- derive their ordinary hourly rate against the per-award rate ladder.
--
-- All money columns conform to A-0048 (Money handling — decimal precision):
--   hourly_rate  NUMERIC(19,6)  — per-rate precision
--   weekly_rate  NUMERIC(19,4)  — money calculation precision
--
-- This migration is purely additive — no existing rows or behaviour change
-- until the resolver lands and consumes the new columns.

-- ── 1. Employee column additions ────────────────────────────────────

ALTER TABLE employee
    ADD COLUMN IF NOT EXISTS award_code             TEXT NULL,
    ADD COLUMN IF NOT EXISTS classification         TEXT NULL,
    ADD COLUMN IF NOT EXISTS worker_type            TEXT NULL,
    ADD COLUMN IF NOT EXISTS pay_arrangement_type   TEXT NULL,
    ADD COLUMN IF NOT EXISTS is_long_term_casual    BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS is_shift_worker_s87    BOOLEAN NOT NULL DEFAULT FALSE;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'employee_worker_type_check'
    ) THEN
        ALTER TABLE employee
            ADD CONSTRAINT employee_worker_type_check
                CHECK (worker_type IS NULL OR worker_type IN ('employee', 'casual', 'contractor'));
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'employee_pay_arrangement_type_check'
    ) THEN
        ALTER TABLE employee
            ADD CONSTRAINT employee_pay_arrangement_type_check
                CHECK (pay_arrangement_type IS NULL OR pay_arrangement_type IN (
                    'ordinary',
                    'annualised_wage',
                    'commission',
                    'high_income_guarantee'
                ));
    END IF;
END $$;

COMMENT ON COLUMN employee.award_code IS 'FWC modern award code (e.g. MA000002). NULL = no award (out-of-scope or contract-only employment).';
COMMENT ON COLUMN employee.classification IS 'Award-specific classification level (e.g. "Level 2 Year 1" for MA000002). Validated by ledgius.MA000002_clerks.valid_classification (or per-award equivalent) when set.';
COMMENT ON COLUMN employee.worker_type IS 'employee | casual | contractor. Distinct from employment_type — a casual employment_type maps to worker_type=casual; permanent (full_time/part_time) maps to worker_type=employee.';
COMMENT ON COLUMN employee.pay_arrangement_type IS 'Per R-0073: ordinary | annualised_wage | commission | high_income_guarantee. Determines which engine path applies. Slice 7 (comparator engine) wires in the variant logic.';
COMMENT ON COLUMN employee.is_long_term_casual IS 'Per FWA s67: a long-term casual with a reasonable expectation of continuing engagement qualifies for parental leave + flexible-work request rights.';
COMMENT ON COLUMN employee.is_shift_worker_s87 IS 'Per FWA s87(3): qualifies for the 5-week annual-leave accrual instead of 4-week. Requires both a continuous 24/7 roster AND the applicable instrument designating shift-worker status — see article NES-ANNUAL-LEAVE.';

-- ── 2. Award classification rate ladder ─────────────────────────────

CREATE TABLE IF NOT EXISTS award_classification_rate (
    id                  SERIAL PRIMARY KEY,
    award_code          TEXT NOT NULL,
    classification      TEXT NOT NULL,
    hourly_rate         NUMERIC(19,6) NOT NULL,
    weekly_rate         NUMERIC(19,4) NOT NULL,
    effective_from      DATE NOT NULL,
    effective_to        DATE NULL,
    authority_ref       TEXT NOT NULL,
    bundle_version      TEXT NOT NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT award_classification_rate_positive_check
        CHECK (hourly_rate > 0 AND weekly_rate > 0),
    CONSTRAINT award_classification_rate_period_check
        CHECK (effective_to IS NULL OR effective_to >= effective_from)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_award_classification_rate_lookup
    ON award_classification_rate (award_code, classification, effective_from);

COMMENT ON TABLE award_classification_rate IS 'Per-award per-classification minimum rate ladder. Mirror of the per-award go-rules decision table (e.g. MA000002_clerks_decisions_v2026.7.1.json) materialised for fast SQL lookup. Source-of-truth remains the bundle file; this table is a cache populated by R__seed_award_rates.sql.';
COMMENT ON COLUMN award_classification_rate.hourly_rate IS 'Minimum hourly rate per A-0048: NUMERIC(19,6) for rate precision.';
COMMENT ON COLUMN award_classification_rate.weekly_rate IS 'Weekly rate (38h × hourly) per A-0048: NUMERIC(19,4) for money calculation precision.';
COMMENT ON COLUMN award_classification_rate.authority_ref IS 'Citation back to the FWC clause + table that authorises this rate (e.g. "MA000002 cl 16 Table 3 — Level 2 Year 1").';
COMMENT ON COLUMN award_classification_rate.bundle_version IS 'Workplace-relations bundle version stamp this rate was derived from (e.g. "MA000002_clerks_v2026.7.1"). Per A-0046, bundle versions track FWA-as-amended dates.';

-- ── 3. Backfill — link existing employees to their fixture-recorded award ──

-- Where employees are already loaded with the QA-Golden fixtures, the
-- award_code + classification + worker_type are recorded in the fixture
-- CSV. The QA loader (cmd/qa-data-loader) and any future fixture-import
-- path should populate these columns at row-insert time.
--
-- This migration is intentionally additive: no data backfill here, since
-- the live tenant schema may have rows that predate the fixture loader.
-- Operators on existing tenants will set award + classification per
-- employee via the Employee detail page (Slice-2 web-app follow-up PR).
