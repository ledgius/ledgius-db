-- Spec references: R-0073, A-0046, T-0041 Slice 4 — Enterprise Bargaining Agreement.
--
-- Adds the workplace-relations EBA layer per A-0046 §Runtime Architecture.
-- Layer stack precedence (high → low): contract → IFA → EBA → award → NES → federal.
-- This migration adds the EBA tables; the runtime resolver consumes them
-- when the tenant has registered an EBA covering the employee's award.
--
-- All money columns conform to A-0048:
--   hourly_rate  NUMERIC(19,6)  rate precision
--   weekly_rate  NUMERIC(19,4)  money calculation precision

-- ── 1. EBA declaration (tenant-level identity of the agreement) ────

CREATE TABLE IF NOT EXISTS eba_declaration (
    id                          SERIAL PRIMARY KEY,
    eba_code                    TEXT NOT NULL,
    eba_name                    TEXT NOT NULL,
    covers_award_code           TEXT NOT NULL,
    approved_by_fwc_at          DATE NOT NULL,
    nominal_expiry_at           DATE NOT NULL,
    boot_pass_declared          BOOLEAN NOT NULL DEFAULT FALSE,
    boot_pass_declared_by       TEXT NULL,
    boot_pass_declared_at       TIMESTAMPTZ NULL,
    document_url                TEXT NULL,
    status                      TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'expired', 'withdrawn', 'replaced')),
    created_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT eba_declaration_period_check
        CHECK (nominal_expiry_at >= approved_by_fwc_at)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_eba_declaration_code
    ON eba_declaration (eba_code);

CREATE INDEX IF NOT EXISTS idx_eba_declaration_award_status
    ON eba_declaration (covers_award_code, status);

COMMENT ON TABLE eba_declaration IS 'Per-tenant Enterprise Bargaining Agreement registration. Each tenant may have at most one active EBA per covered award. Override tables (eba_rate_override, eba_penalty_override) hang off this row.';
COMMENT ON COLUMN eba_declaration.eba_code IS 'FWC-issued EBA identifier (e.g. AE523456).';
COMMENT ON COLUMN eba_declaration.covers_award_code IS 'The modern award this EBA layers over (e.g. MA000004). Must match the employee.award_code for the EBA to apply at runtime.';
COMMENT ON COLUMN eba_declaration.boot_pass_declared IS 'Operator-declared: this EBA passes the Better Off Overall Test per FWA s193. Required tick before the EBA is considered valid for runtime application. Audit fields capture who declared and when.';
COMMENT ON COLUMN eba_declaration.nominal_expiry_at IS 'EBA nominal expiry date. The runtime resolver warns 60 days before this date and refuses silent application of overrides after expiry — operator must explicitly extend / replace.';
COMMENT ON COLUMN eba_declaration.document_url IS 'Reference to the EBA PDF in object storage (tenant document store). Optional — operator may register an EBA without uploading the document, but the FWO + FWC reference URL or similar must be captured for audit.';

-- ── 2. EBA rate override (replaces award classification rate) ──────

CREATE TABLE IF NOT EXISTS eba_rate_override (
    id                  SERIAL PRIMARY KEY,
    eba_declaration_id  INT NOT NULL REFERENCES eba_declaration(id) ON DELETE CASCADE,
    classification      TEXT NOT NULL,
    hourly_rate         NUMERIC(19,6) NOT NULL,
    weekly_rate         NUMERIC(19,4) NOT NULL,
    effective_from      DATE NOT NULL,
    effective_to        DATE NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT eba_rate_override_positive_check
        CHECK (hourly_rate > 0 AND weekly_rate > 0),
    CONSTRAINT eba_rate_override_period_check
        CHECK (effective_to IS NULL OR effective_to >= effective_from)
);

CREATE INDEX IF NOT EXISTS idx_eba_rate_override_lookup
    ON eba_rate_override (eba_declaration_id, classification, effective_from);

COMMENT ON TABLE eba_rate_override IS 'EBA layer override for the award classification rate ladder. When present, replaces the award_classification_rate row at runtime. Per BOOT s193 — EBA rates may only IMPROVE on the award; checked at upload time, not enforced by this constraint.';

-- ── 3. EBA penalty override (replaces award penalty multiplier) ────

CREATE TABLE IF NOT EXISTS eba_penalty_override (
    id                  SERIAL PRIMARY KEY,
    eba_declaration_id  INT NOT NULL REFERENCES eba_declaration(id) ON DELETE CASCADE,
    day_kind            TEXT NOT NULL
        CHECK (day_kind IN ('weekday', 'saturday', 'sunday', 'public_holiday')),
    time_band           TEXT NOT NULL DEFAULT 'ordinary',
    worker_type         TEXT NULL,
    multiplier          NUMERIC(10,4) NOT NULL,
    effective_from      DATE NOT NULL,
    effective_to        DATE NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT eba_penalty_override_positive_check
        CHECK (multiplier > 0),
    CONSTRAINT eba_penalty_override_period_check
        CHECK (effective_to IS NULL OR effective_to >= effective_from)
);

CREATE INDEX IF NOT EXISTS idx_eba_penalty_override_lookup
    ON eba_penalty_override (eba_declaration_id, day_kind, time_band, effective_from);

COMMENT ON TABLE eba_penalty_override IS 'EBA layer override for award penalty multipliers (cl 22/26/28/29 etc.). When matched, replaces the award decision-table lookup at runtime. worker_type NULL = applies to both permanent and casual; otherwise specific to that worker type.';
COMMENT ON COLUMN eba_penalty_override.multiplier IS 'NUMERIC(10,4) — sufficient precision for fractional multipliers like 1.7500.';
