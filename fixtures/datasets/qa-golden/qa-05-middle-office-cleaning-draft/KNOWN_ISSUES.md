# QA-05 Middle Office Cleaning — known issues (draft fixture)

Draft / WIP fixtures — see [README.md](../README.md). Issues identified by review on PR ledgius-db#36, with progress tracked here.

## Resolved 2026-04-26

- ✅ **Penalty-rate values verified against FWC PDFs** — `MA000002` (Clerks Private Sector) and `MA000022` (PR786560 ppc 01Jul25, Cleaning Services). All Charlie's casual penalty dollar amounts ($32.31 / $45.24 / $71.09) check out against MA000022 Table 7 column 4. Olivia's $28.12 ordinary rate matches MA000002 Table 3 Level 2 Year 1.
- ✅ **AuthorityRefs replaced with real FWC clause references** — every pay-item row in `pay_items_expected.csv` now cites `MA000002:cl.16.1-Table3-...` or `MA000022:cl.20.2-Table7-...` patterns instead of bespoke labels.
- ✅ **`docs/award_sources.md` rewritten** with full clause-level provenance, FWC publication URLs, variation-determination references (PR786560 confirmed for MA000022; MA000002 PR ref noted as in-PDF history), per-rate verification tables, and NES references for Olivia's leave accruals.

## Still outstanding (block promotion out of `-draft/`)

- ❌ **`Hours × Rate ≠ Amount` rounding** — fixture-wide pattern. Olivia's monthly Amount $4,629.73 is back-derived from `weekly_rate × 52 / 12` at full precision; recomputing as `printed Rate × printed Hours = $28.12 × 164.67` produces $4,630.51 (a $0.78 discrepancy). Fix: either bump Rate to 4 dp or recompute Amount = `round(Hours × Rate, 2)` and accept the $0.78 deviation across the year.
- ❌ **GL trial balance does not balance** — D vs C off by $23,977.60. Same root cause as QA-06: `1000 Bank Operating Account` GL is computed as "closing bank − payroll outflows" rather than actual closing cash, and there's no equity / opening retained earnings row. Add a `Trial balance balances` row to `validation_checks.csv` so a regression here can't pass silently.
- ❌ **Leave balances literal `"fixture-cumulative"` strings** in `payroll/leave_balances_expected.csv`. Either compute the cumulative balance per pay row from accrual rates or remove the columns. Today this file proves nothing the engine could be measured against.
- ❌ **STP `IncomeType=SalaryAndWages` / `EmploymentBasis=full_time` long-form values** vs schema enum codes (`SAW` / `F`, `P`, `C`) per `migrations/tenant/V1.28__stp_phase2.sql`. Fix: substitute long-form with ATO codes.
- ❌ **PAYG values don't match standard NAT 1004 coefficients** — same as QA-06; tracked as fixture-wide issue.

## Promotion checklist

- [x] Penalty-rate values verified against live FWC sources
- [x] AuthorityRefs replaced with real clause references
- [x] `docs/award_sources.md` fleshed out with proper provenance
- [ ] Hours × Rate rounding
- [ ] GL trial balance fix + add Trial-balance-balances validation row
- [ ] Leave balances proper cumulative computation
- [ ] STP enum mismatch
- [ ] PAYG against NAT 1004 (FY2025/26)
- [ ] Engine has matching rules in `pkg/rules/bundles/au/payroll/MA000002_*` + `MA000022_*` per R-0073
- [ ] QA data loader successfully imports against freshly-provisioned tenant DB (already verified for non-payroll Xero entities)
- [ ] Engine-vs-fixture diff test passes
