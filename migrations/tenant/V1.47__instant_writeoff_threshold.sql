-- Spec references: R-0062, A-0041, T-0029.
--
-- V1.47 — Instant asset write-off thresholds (per financial year)
--
-- Stores the ATO instant asset write-off threshold for each Australian
-- financial year. The fixed-assets acquisition flow (R-0062 AST-009 /
-- T-0030) reads this table to determine whether an asset qualifies for
-- full-cost write-off in the acquisition period.
--
-- Thresholds change annually in the Federal Budget; new FY rows are
-- added via an updated R__11_seed_instant_writeoff_thresholds.sql
-- repeatable migration (idempotent upserts).
--
-- The spec previously proposed making thresholds tenant-scoped (to
-- allow small-business vs general variants). Deferred: the tax-side
-- small-business / pool treatment is owned by R-0074 and will carry
-- its own eligibility model. For R-0062 this table holds the common
-- $20k / FY threshold used at the accounting layer.

CREATE TABLE IF NOT EXISTS instant_writeoff_threshold (
    id              SERIAL PRIMARY KEY,
    fy_start        DATE NOT NULL,
    fy_end          DATE NOT NULL,
    threshold_aud   NUMERIC(20, 2) NOT NULL CHECK (threshold_aud >= 0),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT instant_writeoff_fy_ordered CHECK (fy_end > fy_start),
    CONSTRAINT instant_writeoff_fy_start_unique UNIQUE (fy_start)
);

COMMENT ON TABLE  instant_writeoff_threshold IS 'ATO instant asset write-off threshold per Australian financial year. Read at acquisition time to determine eligibility. R-0062 AST-009a.';
COMMENT ON COLUMN instant_writeoff_threshold.fy_start IS 'Inclusive start of the financial year (typically 1 July).';
COMMENT ON COLUMN instant_writeoff_threshold.fy_end IS 'Inclusive end of the financial year (typically 30 June of the following year).';
COMMENT ON COLUMN instant_writeoff_threshold.threshold_aud IS 'Dollar cap (AUD, ex-GST). An asset qualifies for instant write-off when cost_ex_gst <= threshold. The cap is updated yearly in the Federal Budget.';
