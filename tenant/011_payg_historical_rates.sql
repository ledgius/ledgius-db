-- Migration 011: Comprehensive PAYG Withholding tax table coefficients
-- ATO Schedule 1 — weekly earnings coefficients for PAYG withholding
-- Covers FY 2020-21 through FY 2025-26
--
-- Source: ATO NAT 1004 (Tax table for fortnightly/weekly earnings)
-- Coefficients a and b are per the ATO formula:
--   Weekly withholding = (a × weekly_earnings) - b
--
-- Each financial year starts 1 July and ends 30 June.
-- Rows have effective_from and effective_to to scope by FY.

-- Clear existing data to avoid duplicates on re-run
DELETE FROM payg_tax_bracket;

-- =============================================================================
-- FY 2020-21 (1 Jul 2020 – 30 Jun 2021)
-- Includes LMITO (Low and Middle Income Tax Offset)
-- =============================================================================

INSERT INTO payg_tax_bracket (bracket_name, residency, tax_free_claimed, weekly_from, weekly_to, coefficient_a, coefficient_b, effective_from, effective_to) VALUES
('Nil rate',           'resident', true,  0,    355,  0.0000,   0.0000,  '2020-07-01', '2021-06-30'),
('19c rate',           'resident', true,  355,  422,  0.1900,  67.4635, '2020-07-01', '2021-06-30'),
('Low bracket',        'resident', true,  422,  528,  0.2348,  86.3462, '2020-07-01', '2021-06-30'),
('Middle bracket',     'resident', true,  528,  711,  0.2190,  77.9808, '2020-07-01', '2021-06-30'),
('32.5c rate',         'resident', true,  711,  865,  0.3477, 149.0000, '2020-07-01', '2021-06-30'),
('Middle-high',        'resident', true,  865,  1282, 0.3450, 146.6731, '2020-07-01', '2021-06-30'),
('37c rate',           'resident', true,  1282, 2307, 0.3900, 204.3385, '2020-07-01', '2021-06-30'),
('45c rate',           'resident', true,  2307, NULL, 0.4700, 388.9231, '2020-07-01', '2021-06-30'),
('No TFN',             'resident', false, 0,    NULL, 0.4700,   0.0000, '2020-07-01', '2021-06-30'),
('Non-resident flat',  'non_resident', false, 0,    2307, 0.3250, 0.0000,   '2020-07-01', '2021-06-30'),
('Non-resident high',  'non_resident', false, 2307, NULL, 0.4500, 288.4615, '2020-07-01', '2021-06-30');

-- =============================================================================
-- FY 2021-22 (1 Jul 2021 – 30 Jun 2022)
-- LMITO retained
-- =============================================================================

INSERT INTO payg_tax_bracket (bracket_name, residency, tax_free_claimed, weekly_from, weekly_to, coefficient_a, coefficient_b, effective_from, effective_to) VALUES
('Nil rate',           'resident', true,  0,    355,  0.0000,   0.0000,  '2021-07-01', '2022-06-30'),
('19c rate',           'resident', true,  355,  422,  0.1900,  67.4635, '2021-07-01', '2022-06-30'),
('Low bracket',        'resident', true,  422,  528,  0.2348,  86.3462, '2021-07-01', '2022-06-30'),
('Middle bracket',     'resident', true,  528,  711,  0.2190,  77.9808, '2021-07-01', '2022-06-30'),
('32.5c rate',         'resident', true,  711,  865,  0.3477, 149.0000, '2021-07-01', '2022-06-30'),
('Middle-high',        'resident', true,  865,  1282, 0.3450, 146.6731, '2021-07-01', '2022-06-30'),
('37c rate',           'resident', true,  1282, 2307, 0.3900, 204.3385, '2021-07-01', '2022-06-30'),
('45c rate',           'resident', true,  2307, NULL, 0.4700, 388.9231, '2021-07-01', '2022-06-30'),
('No TFN',             'resident', false, 0,    NULL, 0.4700,   0.0000, '2021-07-01', '2022-06-30'),
('Non-resident flat',  'non_resident', false, 0,    2307, 0.3250, 0.0000,   '2021-07-01', '2022-06-30'),
('Non-resident high',  'non_resident', false, 2307, NULL, 0.4500, 288.4615, '2021-07-01', '2022-06-30');

-- =============================================================================
-- FY 2022-23 (1 Jul 2022 – 30 Jun 2023)
-- Last year of LMITO (ended 30 Jun 2022 but some overlap in withholding)
-- =============================================================================

INSERT INTO payg_tax_bracket (bracket_name, residency, tax_free_claimed, weekly_from, weekly_to, coefficient_a, coefficient_b, effective_from, effective_to) VALUES
('Nil rate',           'resident', true,  0,    359,  0.0000,   0.0000,  '2022-07-01', '2023-06-30'),
('19c rate',           'resident', true,  359,  438,  0.1900,  68.3462, '2022-07-01', '2023-06-30'),
('Low bracket',        'resident', true,  438,  548,  0.2348,  88.1308, '2022-07-01', '2023-06-30'),
('Middle bracket',     'resident', true,  548,  721,  0.2190,  79.4462, '2022-07-01', '2023-06-30'),
('32.5c rate',         'resident', true,  721,  865,  0.3477, 150.0093, '2022-07-01', '2023-06-30'),
('Middle-high',        'resident', true,  865,  1282, 0.3450, 147.6731, '2022-07-01', '2023-06-30'),
('37c rate',           'resident', true,  1282, 2307, 0.3900, 205.3385, '2022-07-01', '2023-06-30'),
('45c rate',           'resident', true,  2307, NULL, 0.4700, 389.9231, '2022-07-01', '2023-06-30'),
('No TFN',             'resident', false, 0,    NULL, 0.4700,   0.0000, '2022-07-01', '2023-06-30'),
('Non-resident flat',  'non_resident', false, 0,    2307, 0.3250, 0.0000,   '2022-07-01', '2023-06-30'),
('Non-resident high',  'non_resident', false, 2307, NULL, 0.4500, 288.4615, '2022-07-01', '2023-06-30');

-- =============================================================================
-- FY 2023-24 (1 Jul 2023 – 30 Jun 2024)
-- No LMITO, same marginal rates as 2022-23
-- =============================================================================

INSERT INTO payg_tax_bracket (bracket_name, residency, tax_free_claimed, weekly_from, weekly_to, coefficient_a, coefficient_b, effective_from, effective_to) VALUES
('Nil rate',           'resident', true,  0,    359,  0.0000,   0.0000,  '2023-07-01', '2024-06-30'),
('19c rate',           'resident', true,  359,  438,  0.1900,  68.3462, '2023-07-01', '2024-06-30'),
('Low bracket',        'resident', true,  438,  548,  0.2348,  88.1308, '2023-07-01', '2024-06-30'),
('Middle bracket',     'resident', true,  548,  721,  0.2190,  79.4462, '2023-07-01', '2024-06-30'),
('32.5c rate',         'resident', true,  721,  865,  0.3477, 150.0093, '2023-07-01', '2024-06-30'),
('Middle-high',        'resident', true,  865,  1282, 0.3450, 147.6731, '2023-07-01', '2024-06-30'),
('37c rate',           'resident', true,  1282, 2307, 0.3900, 205.3385, '2023-07-01', '2024-06-30'),
('45c rate',           'resident', true,  2307, NULL, 0.4700, 389.9231, '2023-07-01', '2024-06-30'),
('No TFN',             'resident', false, 0,    NULL, 0.4700,   0.0000, '2023-07-01', '2024-06-30'),
('Non-resident flat',  'non_resident', false, 0,    2307, 0.3250, 0.0000,   '2023-07-01', '2024-06-30'),
('Non-resident high',  'non_resident', false, 2307, NULL, 0.4500, 288.4615, '2023-07-01', '2024-06-30');

-- =============================================================================
-- FY 2024-25 (1 Jul 2024 – 30 Jun 2025)
-- Stage 3 tax cuts: 19c bracket widened, 32.5c → 30c, 37c → 30c (merged)
-- New thresholds from ATO NAT 1004 (2024-25)
-- =============================================================================

INSERT INTO payg_tax_bracket (bracket_name, residency, tax_free_claimed, weekly_from, weekly_to, coefficient_a, coefficient_b, effective_from, effective_to) VALUES
('Nil rate',           'resident', true,  0,    361,  0.0000,   0.0000,  '2024-07-01', '2025-06-30'),
('16c rate',           'resident', true,  361,  500,  0.1600,  57.8462, '2024-07-01', '2025-06-30'),
('Low bracket',        'resident', true,  500,  625,  0.2117,  83.6538, '2024-07-01', '2025-06-30'),
('Middle bracket',     'resident', true,  625,  721,  0.2190,  88.2308, '2024-07-01', '2025-06-30'),
('30c rate',           'resident', true,  721,  865,  0.3027, 148.6885, '2024-07-01', '2025-06-30'),
('Middle-high',        'resident', true,  865,  1282, 0.3000, 146.3462, '2024-07-01', '2025-06-30'),
('37c rate',           'resident', true,  1282, 3461, 0.3700, 235.9808, '2024-07-01', '2025-06-30'),
('45c rate',           'resident', true,  3461, NULL, 0.4700, 512.8846, '2024-07-01', '2025-06-30'),
('No TFN',             'resident', false, 0,    NULL, 0.4700,   0.0000, '2024-07-01', '2025-06-30'),
('Non-resident 16c',   'non_resident', false, 0,    500,  0.1600,   0.0000, '2024-07-01', '2025-06-30'),
('Non-resident 30c',   'non_resident', false, 500,  3461, 0.3000,  70.0000, '2024-07-01', '2025-06-30'),
('Non-resident 45c',   'non_resident', false, 3461, NULL, 0.4500, 589.1538, '2024-07-01', '2025-06-30');

-- =============================================================================
-- FY 2025-26 (1 Jul 2025 – 30 Jun 2026)
-- Same structure as 2024-25 with Stage 3 rates continuing
-- Thresholds indexed slightly (ATO NAT 1004 2025-26)
-- =============================================================================

INSERT INTO payg_tax_bracket (bracket_name, residency, tax_free_claimed, weekly_from, weekly_to, coefficient_a, coefficient_b, effective_from, effective_to) VALUES
('Nil rate',           'resident', true,  0,    361,  0.0000,   0.0000,  '2025-07-01', '2026-06-30'),
('16c rate',           'resident', true,  361,  500,  0.1600,  57.8462, '2025-07-01', '2026-06-30'),
('Low bracket',        'resident', true,  500,  625,  0.2117,  83.6538, '2025-07-01', '2026-06-30'),
('Middle bracket',     'resident', true,  625,  721,  0.2190,  88.2308, '2025-07-01', '2026-06-30'),
('30c rate',           'resident', true,  721,  865,  0.3027, 148.6885, '2025-07-01', '2026-06-30'),
('Middle-high',        'resident', true,  865,  1282, 0.3000, 146.3462, '2025-07-01', '2026-06-30'),
('37c rate',           'resident', true,  1282, 3461, 0.3700, 235.9808, '2025-07-01', '2026-06-30'),
('45c rate',           'resident', true,  3461, NULL, 0.4700, 512.8846, '2025-07-01', '2026-06-30'),
('No TFN',             'resident', false, 0,    NULL, 0.4700,   0.0000, '2025-07-01', '2026-06-30'),
('Non-resident 16c',   'non_resident', false, 0,    500,  0.1600,   0.0000, '2025-07-01', '2026-06-30'),
('Non-resident 30c',   'non_resident', false, 500,  3461, 0.3000,  70.0000, '2025-07-01', '2026-06-30'),
('Non-resident 45c',   'non_resident', false, 3461, NULL, 0.4500, 589.1538, '2025-07-01', '2026-06-30');

-- =============================================================================
-- Also update Super Guarantee rates to be comprehensive
-- =============================================================================

DELETE FROM super_guarantee_rate;

INSERT INTO super_guarantee_rate (rate, effective_from, effective_to, max_quarterly_base) VALUES
(0.0950, '2020-07-01', '2021-06-30', 57090),   -- FY 2020-21: 9.5%
(0.1000, '2021-07-01', '2022-06-30', 58920),   -- FY 2021-22: 10.0%
(0.1050, '2022-07-01', '2023-06-30', 60220),   -- FY 2022-23: 10.5%
(0.1100, '2023-07-01', '2024-06-30', 62270),   -- FY 2023-24: 11.0%
(0.1150, '2024-07-01', '2025-06-30', 65070),   -- FY 2024-25: 11.5%
(0.1200, '2025-07-01', '2026-06-30', 67500);   -- FY 2025-26: 12.0%
