-- Spec references: A-0021.
--
-- R__seed_super_rates.sql — Superannuation Guarantee Rates (repeatable)
--
-- Seeds the legislated Superannuation Guarantee rates for each financial year
-- from FY2020-21 through FY2025-26. Uses DELETE+INSERT pattern for full
-- idempotency so this script can be re-run when new FY rates are added.
--
-- Source: Superannuation Guarantee (Administration) Act 1992, Schedule 1

DELETE FROM super_guarantee_rate;

INSERT INTO super_guarantee_rate (rate, effective_from, effective_to, max_quarterly_base) VALUES
(0.0950, '2020-07-01', '2021-06-30', 57090),   -- FY 2020-21: 9.5%
(0.1000, '2021-07-01', '2022-06-30', 58920),   -- FY 2021-22: 10.0%
(0.1050, '2022-07-01', '2023-06-30', 60220),   -- FY 2022-23: 10.5%
(0.1100, '2023-07-01', '2024-06-30', 62270),   -- FY 2023-24: 11.0%
(0.1150, '2024-07-01', '2025-06-30', 65070),   -- FY 2024-25: 11.5%
(0.1200, '2025-07-01', '2026-06-30', 67500);   -- FY 2025-26: 12.0%
