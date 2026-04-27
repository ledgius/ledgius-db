-- Spec references: R-0073, A-0046, T-0041 Slice 5 — Individual Flexibility Arrangement.
--
-- Adds the per-employee IFA layer per A-0046 §Runtime Architecture.
-- Layer stack precedence (high → low): contract → IFA → EBA → award → NES → federal.
-- IFAs sit ABOVE EBAs — an IFA can vary EBA terms (subject to BOOT) just
-- as it can vary award terms. IFAs are individually signed and per
-- FWA s144 may only vary specific permitted terms.
--
-- All money columns conform to A-0048:
--   hourly_rate  NUMERIC(19,6)
--   weekly_rate  NUMERIC(19,4)
--   multiplier   NUMERIC(10,4)

-- ── 1. IFA declaration (employee-scoped) ───────────────────────────

CREATE TABLE IF NOT EXISTS ifa_declaration (
    id                          SERIAL PRIMARY KEY,
    employee_id                 INT NOT NULL REFERENCES employee(id) ON DELETE CASCADE,
    varies_under                TEXT NOT NULL DEFAULT 'award'
        CHECK (varies_under IN ('award', 'eba', 'both')),
    signed_at                   DATE NOT NULL,
    genuine_choice_declared     BOOLEAN NOT NULL DEFAULT FALSE,
    genuine_choice_declared_by  TEXT NULL,
    genuine_choice_declared_at  TIMESTAMPTZ NULL,
    boot_pass_declared          BOOLEAN NOT NULL DEFAULT FALSE,
    boot_pass_declared_by       TEXT NULL,
    boot_pass_declared_at       TIMESTAMPTZ NULL,
    termination_notice_at       DATE NULL,
    terminated_at               DATE NULL,
    status                      TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'terminated', 'expired')),
    created_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT ifa_declaration_termination_order_check
        CHECK (terminated_at IS NULL OR termination_notice_at IS NULL OR terminated_at >= termination_notice_at)
);

CREATE INDEX IF NOT EXISTS idx_ifa_declaration_employee_status
    ON ifa_declaration (employee_id, status);

CREATE INDEX IF NOT EXISTS idx_ifa_declaration_lifecycle
    ON ifa_declaration (employee_id, signed_at, terminated_at);

COMMENT ON TABLE ifa_declaration IS 'Per-employee Individual Flexibility Arrangement under FWA s144. An IFA may vary specific permitted terms of the applicable award or EBA. Each employee may have at most one active IFA. Termination requires written notice; per FWA s203(6) (as amended by Closing Loopholes 2 from Dec 2023) the notice period is 13 weeks for new IFAs.';
COMMENT ON COLUMN ifa_declaration.employee_id IS 'IFA is employee-scoped — distinguishes IFA from EBA which is tenant-scoped.';
COMMENT ON COLUMN ifa_declaration.varies_under IS 'Indicates whether the IFA varies an award term, an EBA term, or both. Drives the BOOT comparator base.';
COMMENT ON COLUMN ifa_declaration.genuine_choice_declared IS 'Operator-declared per FWA s203(2): the IFA was made without coercion. Required tick before runtime application.';
COMMENT ON COLUMN ifa_declaration.boot_pass_declared IS 'Operator-declared per FWA s203(4): the IFA leaves the employee Better Off Overall vs the displaced award/EBA terms. Required tick.';
COMMENT ON COLUMN ifa_declaration.termination_notice_at IS 'Date written notice of termination was given. The IFA continues to apply for 13 weeks from this date per FWA s203(6) (post-Dec 2023). The runtime resolver computes effective terminated_at = termination_notice_at + 13 weeks if terminated_at is NULL.';
COMMENT ON COLUMN ifa_declaration.terminated_at IS 'Effective termination date — IFA no longer applies on or after this date. Set when notice period expires (or earlier by mutual agreement).';

-- ── 2. IFA rate override (per-classification, per-employee via FK) ─

CREATE TABLE IF NOT EXISTS ifa_rate_override (
    id                  SERIAL PRIMARY KEY,
    ifa_declaration_id  INT NOT NULL REFERENCES ifa_declaration(id) ON DELETE CASCADE,
    classification      TEXT NOT NULL,
    hourly_rate         NUMERIC(19,6) NOT NULL,
    weekly_rate         NUMERIC(19,4) NOT NULL,
    effective_from      DATE NOT NULL,
    effective_to        DATE NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT ifa_rate_override_positive_check
        CHECK (hourly_rate > 0 AND weekly_rate > 0),
    CONSTRAINT ifa_rate_override_period_check
        CHECK (effective_to IS NULL OR effective_to >= effective_from)
);

CREATE INDEX IF NOT EXISTS idx_ifa_rate_override_lookup
    ON ifa_rate_override (ifa_declaration_id, classification, effective_from);

COMMENT ON TABLE ifa_rate_override IS 'IFA layer rate override (rare for IFAs — most IFAs vary work patterns or allowance treatment, not base rates). Per s203(4) BOOT the IFA rate must leave the employee better off vs the displaced award/EBA rate.';

-- ── 3. IFA penalty override ────────────────────────────────────────

CREATE TABLE IF NOT EXISTS ifa_penalty_override (
    id                  SERIAL PRIMARY KEY,
    ifa_declaration_id  INT NOT NULL REFERENCES ifa_declaration(id) ON DELETE CASCADE,
    day_kind            TEXT NOT NULL
        CHECK (day_kind IN ('weekday', 'saturday', 'sunday', 'public_holiday')),
    time_band           TEXT NOT NULL DEFAULT 'ordinary',
    multiplier          NUMERIC(10,4) NOT NULL,
    effective_from      DATE NOT NULL,
    effective_to        DATE NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT ifa_penalty_override_positive_check
        CHECK (multiplier > 0),
    CONSTRAINT ifa_penalty_override_period_check
        CHECK (effective_to IS NULL OR effective_to >= effective_from)
);

CREATE INDEX IF NOT EXISTS idx_ifa_penalty_override_lookup
    ON ifa_penalty_override (ifa_declaration_id, day_kind, time_band, effective_from);

COMMENT ON TABLE ifa_penalty_override IS 'IFA layer penalty multiplier override. Common pattern: an IFA where the employee agrees their ordinary work pattern includes Saturday morning, removing the Saturday penalty for those hours. Per s203(4) BOOT — the IFA must leave the employee better off vs the displaced award/EBA penalty (e.g. compensated with a higher base rate or other benefit). No worker_type column — IFAs are per-employee so worker type is implicit.';
