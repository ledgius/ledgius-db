-- Spec references: R-0073, A-0046, T-0041 Slice 2.
--
-- R__13_seed_award_classification_rates.sql — Modern award classification
-- rate ladders (repeatable). Materialises the per-award go-rules decision
-- tables (e.g. ledgius-api/pkg/rules/bundles/au/payroll/MA000002_clerks_*.json)
-- into SQL for fast lookup by the layered runtime resolver.
--
-- DELETE+INSERT pattern for full idempotency — re-runnable when rates are
-- updated by FWC's annual review.
--
-- Source of truth: the per-award bundle files in ledgius-api. This table
-- is a cache populated from those bundles. Whenever a bundle's rate
-- ladder changes, update both the bundle file AND this seed.

-- Clear existing data to avoid duplicates on re-run.
DELETE FROM award_classification_rate;

-- =============================================================================
-- MA000002 Clerks—Private Sector Award 2020
-- Variation in force at 1 July 2025 (per FWC Annual Wage Review 2024–25)
-- Source bundle: pkg/rules/bundles/au/payroll/MA000002_clerks_decisions_v2026.7.1.json
-- =============================================================================

INSERT INTO award_classification_rate
    (award_code, classification, hourly_rate, weekly_rate, effective_from, effective_to, authority_ref, bundle_version)
VALUES
    ('MA000002', 'Level 1',         25.93, 985.34,  '2025-07-01', '2026-06-30', 'MA000002 cl 16 Table 3 — Level 1',         'MA000002_clerks_v2026.7.1'),
    ('MA000002', 'Level 2 Year 1',  28.12, 1068.40, '2025-07-01', '2026-06-30', 'MA000002 cl 16 Table 3 — Level 2 Year 1',  'MA000002_clerks_v2026.7.1'),
    ('MA000002', 'Level 2 Year 2',  28.74, 1092.12, '2025-07-01', '2026-06-30', 'MA000002 cl 16 Table 3 — Level 2 Year 2',  'MA000002_clerks_v2026.7.1'),
    ('MA000002', 'Level 3',         29.10, 1105.80, '2025-07-01', '2026-06-30', 'MA000002 cl 16 Table 3 — Level 3',         'MA000002_clerks_v2026.7.1'),
    ('MA000002', 'Level 4',         29.74, 1130.12, '2025-07-01', '2026-06-30', 'MA000002 cl 16 Table 3 — Level 4',         'MA000002_clerks_v2026.7.1'),
    ('MA000002', 'Level 5',         31.83, 1209.54, '2025-07-01', '2026-06-30', 'MA000002 cl 16 Table 3 — Level 5',         'MA000002_clerks_v2026.7.1');

-- Future awards (Slice 3) extend below:
--   MA000003 Hospitality
--   MA000004 General Retail
--   MA000020 Building & Construction
--   MA000065 Professional Employees
