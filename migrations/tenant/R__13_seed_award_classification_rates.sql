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

-- =============================================================================
-- T-0041 Slice 3 — four additional awards (FY2025/26 rates).
-- Source bundles in ledgius-api/pkg/rules/bundles/au/payroll/
-- Note: T-0041 originally listed MA000003 for Hospitality, but the actual
-- FWC code is MA000009; aligned here.
-- =============================================================================

-- MA000004 — General Retail Industry Award 2020 (cl 17 Table 4)
INSERT INTO award_classification_rate
    (award_code, classification, hourly_rate, weekly_rate, effective_from, effective_to, authority_ref, bundle_version)
VALUES
    ('MA000004', 'Retail Employee Level 1', 26.55, 1008.90, '2025-07-01', '2026-06-30', 'MA000004 cl 17 Table 4 — Retail Employee Level 1', 'MA000004_general_retail_v2026.7.1'),
    ('MA000004', 'Retail Employee Level 2', 27.16, 1032.08, '2025-07-01', '2026-06-30', 'MA000004 cl 17 Table 4 — Retail Employee Level 2', 'MA000004_general_retail_v2026.7.1'),
    ('MA000004', 'Retail Employee Level 3', 27.51, 1045.38, '2025-07-01', '2026-06-30', 'MA000004 cl 17 Table 4 — Retail Employee Level 3', 'MA000004_general_retail_v2026.7.1'),
    ('MA000004', 'Retail Employee Level 4', 28.12, 1068.40, '2025-07-01', '2026-06-30', 'MA000004 cl 17 Table 4 — Retail Employee Level 4', 'MA000004_general_retail_v2026.7.1'),
    ('MA000004', 'Retail Employee Level 5', 29.43, 1118.34, '2025-07-01', '2026-06-30', 'MA000004 cl 17 Table 4 — Retail Employee Level 5', 'MA000004_general_retail_v2026.7.1'),
    ('MA000004', 'Retail Employee Level 6', 30.04, 1141.52, '2025-07-01', '2026-06-30', 'MA000004 cl 17 Table 4 — Retail Employee Level 6', 'MA000004_general_retail_v2026.7.1'),
    ('MA000004', 'Retail Employee Level 7', 31.83, 1209.54, '2025-07-01', '2026-06-30', 'MA000004 cl 17 Table 4 — Retail Employee Level 7', 'MA000004_general_retail_v2026.7.1'),
    ('MA000004', 'Retail Employee Level 8', 33.46, 1271.48, '2025-07-01', '2026-06-30', 'MA000004 cl 17 Table 4 — Retail Employee Level 8', 'MA000004_general_retail_v2026.7.1');

-- MA000009 — Hospitality Industry (General) Award 2020 (cl 20 Table 5)
INSERT INTO award_classification_rate
    (award_code, classification, hourly_rate, weekly_rate, effective_from, effective_to, authority_ref, bundle_version)
VALUES
    ('MA000009', 'Introductory', 25.30,  961.40, '2025-07-01', '2026-06-30', 'MA000009 cl 20 Table 5 — Introductory', 'MA000009_hospitality_v2026.7.1'),
    ('MA000009', 'Level 1',      25.93,  985.34, '2025-07-01', '2026-06-30', 'MA000009 cl 20 Table 5 — Level 1',      'MA000009_hospitality_v2026.7.1'),
    ('MA000009', 'Level 2',      25.85,  982.30, '2025-07-01', '2026-06-30', 'MA000009 cl 20 Table 5 — Level 2',      'MA000009_hospitality_v2026.7.1'),
    ('MA000009', 'Level 3',      27.51, 1045.38, '2025-07-01', '2026-06-30', 'MA000009 cl 20 Table 5 — Level 3',      'MA000009_hospitality_v2026.7.1'),
    ('MA000009', 'Level 4',      28.74, 1092.12, '2025-07-01', '2026-06-30', 'MA000009 cl 20 Table 5 — Level 4',      'MA000009_hospitality_v2026.7.1'),
    ('MA000009', 'Level 5',      29.43, 1118.34, '2025-07-01', '2026-06-30', 'MA000009 cl 20 Table 5 — Level 5',      'MA000009_hospitality_v2026.7.1'),
    ('MA000009', 'Level 6',      31.83, 1209.54, '2025-07-01', '2026-06-30', 'MA000009 cl 20 Table 5 — Level 6',      'MA000009_hospitality_v2026.7.1');

-- MA000020 — Building & Construction General On-site Award 2020 (cl 19 Table 5)
INSERT INTO award_classification_rate
    (award_code, classification, hourly_rate, weekly_rate, effective_from, effective_to, authority_ref, bundle_version)
VALUES
    ('MA000020', 'CW/ECW 1', 26.18,  994.84, '2025-07-01', '2026-06-30', 'MA000020 cl 19 Table 5 — CW/ECW 1', 'MA000020_construction_v2026.7.1'),
    ('MA000020', 'CW/ECW 2', 27.16, 1032.08, '2025-07-01', '2026-06-30', 'MA000020 cl 19 Table 5 — CW/ECW 2', 'MA000020_construction_v2026.7.1'),
    ('MA000020', 'CW/ECW 3', 28.12, 1068.40, '2025-07-01', '2026-06-30', 'MA000020 cl 19 Table 5 — CW/ECW 3', 'MA000020_construction_v2026.7.1'),
    ('MA000020', 'CW/ECW 4', 29.13, 1106.94, '2025-07-01', '2026-06-30', 'MA000020 cl 19 Table 5 — CW/ECW 4', 'MA000020_construction_v2026.7.1'),
    ('MA000020', 'CW/ECW 5', 30.04, 1141.52, '2025-07-01', '2026-06-30', 'MA000020 cl 19 Table 5 — CW/ECW 5', 'MA000020_construction_v2026.7.1'),
    ('MA000020', 'CW/ECW 6', 31.83, 1209.54, '2025-07-01', '2026-06-30', 'MA000020 cl 19 Table 5 — CW/ECW 6', 'MA000020_construction_v2026.7.1'),
    ('MA000020', 'CW/ECW 7', 33.46, 1271.48, '2025-07-01', '2026-06-30', 'MA000020 cl 19 Table 5 — CW/ECW 7', 'MA000020_construction_v2026.7.1'),
    ('MA000020', 'CW/ECW 8', 35.28, 1340.64, '2025-07-01', '2026-06-30', 'MA000020 cl 19 Table 5 — CW/ECW 8', 'MA000020_construction_v2026.7.1');

-- MA000065 — Professional Employees Award 2020 (cl 16 Table 1)
-- Hourly = annual ÷ 1976 per A-0048; weekly = annual ÷ 52.
-- Both bare ("Level N") and descriptive ("Level N — Foo professional")
-- forms seeded so the resolver matches whichever the operator records.
INSERT INTO award_classification_rate
    (award_code, classification, hourly_rate, weekly_rate, effective_from, effective_to, authority_ref, bundle_version)
VALUES
    ('MA000065', 'Level 1',                              32.21, 1224.00, '2025-07-01', '2026-06-30', 'MA000065 cl 16 Table 1 — Level 1',                            'MA000065_professional_v2026.7.1'),
    ('MA000065', 'Level 1 — Graduate professional',      32.21, 1224.00, '2025-07-01', '2026-06-30', 'MA000065 cl 16 Table 1 — Level 1 Graduate',                   'MA000065_professional_v2026.7.1'),
    ('MA000065', 'Level 2',                              38.09, 1447.33, '2025-07-01', '2026-06-30', 'MA000065 cl 16 Table 1 — Level 2',                            'MA000065_professional_v2026.7.1'),
    ('MA000065', 'Level 2 — Experienced professional',   38.09, 1447.33, '2025-07-01', '2026-06-30', 'MA000065 cl 16 Table 1 — Level 2 Experienced',                'MA000065_professional_v2026.7.1'),
    ('MA000065', 'Level 3',                              46.51, 1767.50, '2025-07-01', '2026-06-30', 'MA000065 cl 16 Table 1 — Level 3',                            'MA000065_professional_v2026.7.1'),
    ('MA000065', 'Level 3 — Project leadership',         46.51, 1767.50, '2025-07-01', '2026-06-30', 'MA000065 cl 16 Table 1 — Level 3 Project Leadership',         'MA000065_professional_v2026.7.1'),
    ('MA000065', 'Level 4',                              52.54, 1996.62, '2025-07-01', '2026-06-30', 'MA000065 cl 16 Table 1 — Level 4',                            'MA000065_professional_v2026.7.1'),
    ('MA000065', 'Level 4 — Principal professional',     52.54, 1996.62, '2025-07-01', '2026-06-30', 'MA000065 cl 16 Table 1 — Level 4 Principal',                  'MA000065_professional_v2026.7.1');
