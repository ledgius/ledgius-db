-- Spec references: R-0062, T-0029.
--
-- R__11_seed_instant_writeoff_thresholds.sql — Instant asset write-off
-- thresholds per Australian financial year (repeatable seed).
--
-- ATO instant asset write-off cap for eligible small businesses. Updated
-- each Federal Budget — add new FY rows to this file when the Budget
-- announces the next year's threshold.
--
-- Scope note: this is the *accounting-layer* threshold used by R-0062's
-- acquisition flow to optionally fully depreciate an asset in its
-- acquisition period. Tax-side simplified depreciation / small business
-- pool eligibility is owned by R-0074 (forthcoming) and has its own
-- policy layer.
--
-- Idempotent: ON CONFLICT (fy_start) DO NOTHING.

INSERT INTO instant_writeoff_threshold (fy_start, fy_end, threshold_aud)
VALUES
    -- FY 2022–23: temporary full expensing era ended 30 Jun 2023; the
    -- fallback SBE threshold reverted to $20,000 for purchases on or
    -- after 1 Jul 2023. For asset captures dated in FY22/23 we seed the
    -- $20k fallback — tenants on temporary full expensing must set their
    -- method to instant_writeoff regardless of this cap during that FY.
    ('2022-07-01'::date, '2023-06-30'::date, 20000.00),

    -- FY 2023–24: SBE instant asset write-off $20,000 (Federal Budget 2023–24).
    ('2023-07-01'::date, '2024-06-30'::date, 20000.00),

    -- FY 2024–25: SBE instant asset write-off $20,000 (Federal Budget 2024–25).
    ('2024-07-01'::date, '2025-06-30'::date, 20000.00),

    -- FY 2025–26: SBE instant asset write-off $20,000 (Federal Budget 2025–26).
    ('2025-07-01'::date, '2026-06-30'::date, 20000.00),

    -- FY 2026–27: placeholder at $20,000 until Budget 2026–27 announcement.
    -- Update this row with the announced threshold once legislation passes.
    ('2026-07-01'::date, '2027-06-30'::date, 20000.00)
ON CONFLICT (fy_start) DO NOTHING;
