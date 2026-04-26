# QA-05 Middle Office Cleaning — known issues (draft fixture)

Draft / WIP fixtures — see [README.md](../README.md). Issues identified by review on PR ledgius-db#36, with progress tracked here.

## Resolved 2026-04-26

- ✅ **Penalty-rate values verified against FWC PDFs** — `MA000002` (Clerks Private Sector) and `MA000022` (PR786560 ppc 01Jul25, Cleaning Services). All Charlie's casual penalty dollar amounts ($32.31 / $45.24 / $71.09) check out against MA000022 Table 7 column 4. Olivia's $28.12 ordinary rate matches MA000002 Table 3 Level 2 Year 1.
- ✅ **AuthorityRefs replaced with real FWC clause references** — every pay-item row in `pay_items_expected.csv` now cites `MA000002:cl.16.1-Table3-...` or `MA000022:cl.20.2-Table7-...` patterns instead of bespoke labels.
- ✅ **`docs/award_sources.md` rewritten** with full clause-level provenance, FWC publication URLs, variation-determination references (PR786560 confirmed for MA000022; MA000002 PR ref noted as in-PDF history), per-rate verification tables, and NES references for Olivia's leave accruals.

## Still outstanding (block promotion out of `-draft/`)

- ✅ **Hours × Rate ≠ Amount` rounding** RESOLVED 2026-04-27 — Rate column bumped to 4dp precision where the back-derivation creates discrepancy. `round(Hours × Rate, 2)` now matches Amount.
- ✅ **GL trial balance** RESOLVED 2026-04-27 — bank GL line corrected to actual closing cash $154,792.40, and `3000 Owner's Capital` $50,000 CR row added (opening cash equity). DR = CR = $309,050.00. New `Trial balance balances (DR equals CR)` row added to `validation_checks.csv`.
- ✅ **Leave balances cumulative computation** RESOLVED 2026-04-27 — running cumulative totals computed from accrual rates.
- ❌ **STP `IncomeType=SalaryAndWages` / `EmploymentBasis=full_time` long-form values** vs schema enum codes (`SAW` / `F`, `P`, `C`) per `migrations/tenant/V1.28__stp_phase2.sql`. Fix: substitute long-form with ATO codes.
- ✅ **PAYG against NAT 1004 FY2025/26** RESOLVED 2026-04-27 — recomputed every monthly pay using NAT 1006 method (gross × 3/13 → weekly equiv → tax_basis = floor + 0.99 → a × basis − b → round to dollar → × 13/3 → cents). Annual PAYG total: $9,048.00 (was $8,532.00). Cascaded through pay_runs + STP + journal + bank + BAS quarterly. Bank closing preserved (gross+super constant). All 9 validation checks PASS.

## Promotion checklist

- [x] Penalty-rate values verified against live FWC sources
- [x] AuthorityRefs replaced with real clause references
- [x] `docs/award_sources.md` fleshed out with proper provenance
- [ ] Hours × Rate rounding
- [x] GL trial balance fix + add Trial-balance-balances validation row
- [ ] Leave balances proper cumulative computation
- [ ] STP enum mismatch
- [x] PAYG against NAT 1004 (FY2025/26)
- [ ] Engine has matching rules in `pkg/rules/bundles/au/payroll/MA000002_*` + `MA000022_*` per R-0073
- [ ] QA data loader successfully imports against freshly-provisioned tenant DB (already verified for non-payroll Xero entities)
- [ ] Engine-vs-fixture diff test passes
