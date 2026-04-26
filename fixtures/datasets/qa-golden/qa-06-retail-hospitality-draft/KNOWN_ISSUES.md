# QA-06 Retail Hospitality — known issues (draft fixture)

Draft / WIP fixtures — see [README.md](../README.md) for the broader two-layer structure. Issues identified by review on PR ledgius-db#36, with progress tracked here.

## Resolved 2026-04-26

- ✅ **Penalty-rate values verified against FWC PDFs** — `MA000004` (PR786542 ppc 01Jul25) and `MA000009` (PR786547 ppc 01Jul25). The original v1 fixture's casual penalty dollar amounts ($33.19 / $39.83 / $46.46 retail; $32.31 / $38.78 / $64.63 hospitality) are correct: Tables 12 / 14 column 3 are explicitly **"% of minimum (inclusive of casual loading)"** — the casual percentage replaces the loading rather than stacking. The earlier reviewer's "should be casual_rate × 1.25 / × 1.75" interpretation was a misreading.
- ✅ **AuthorityRefs replaced with real FWC clause references** — every penalty-rate row in `pay_items_expected.csv` now cites `MA000004:cl.22.1-Table12-...` or `MA000009:cl.29.2-Table14-...` patterns. See `docs/award_sources.md` for the verification table.
- ✅ **`docs/award_sources.md` rewritten** with full clause-level provenance, FWC publication URLs, variation-determination references, and a per-rate verification table.
- ✅ **Priya Retail Supervisor Level 4 hourly rate corrected $31.64 → $28.12** to match `MA000004` Table 4 (effective 1 July 2025). Cascaded through 52 pay periods + journal + bank file + BAS + GL + reconciliation. All narrow validation checks (`reference/validation_checks.csv`) re-pass.

## Still outstanding (block promotion out of `-draft/`)

- ❌ **`Hours × Rate ≠ Amount` rounding** — fixture-wide pattern; Amount is back-derived from full-precision rates while Rate is printed at 2 dp. Fix: either bump Rate to 4 dp or recompute `Amount = round(Hours × Rate, 2)`. Affects every pay-item row.
- ✅ **GL trial balance** RESOLVED 2026-04-27 — bank GL line corrected to actual closing cash $326,466.83, and `3000 Owner's Capital` $50,000 CR row added (opening cash equity). DR = CR = $625,850.00. New `Trial balance balances (DR equals CR)` row added to `validation_checks.csv`.
- ✅ **Leave balances cumulative computation** RESOLVED 2026-04-27 — `ClosingAnnualLeaveHours` and `ClosingPersonalLeaveHours` now hold proper running cumulative totals. FT employees end FY at ≈152h annual + ≈76h personal (matches NES); PT pro-rata; casuals stay 0.
- ❌ **`employees.csv` schema differs from QA-05/QA-07** — this file's header has `hourly_rate, leave_accrues` only; the others have `weekly_rate, hourly_rate, leave_accrues`. A typed importer can't load all three without per-tenant branching. Pick one canonical schema (per-row pay-basis differences are data, not file shape).
- ✅ **STP enum codes** RESOLVED 2026-04-27 — `SalaryAndWages` → `SAW`, `full_time` → `F`, `part_time` → `P`, `casual` → `C` across all stp_phase2_expected.csv rows. QA-07 special types (full_time_annualised_wage / commission / high_income_guarantee) all map to `F` per ATO Phase 2 enum.
- ✅ **PAYG against NAT 1004 FY2025/26** RESOLVED 2026-04-27 — recomputed every weekly pay using NAT 1004 Scale 2 (TFN, tax-free threshold claimed): tax_basis = floor(weekly_gross) + 0.99, then `a × basis − b`, then round to whole dollar. Annual PAYG total: $16,081.00 (was $16,064.72). Cascaded through pay_runs + STP + journal + bank + BAS quarterly. Bank closing preserved at $326,466.83. All 9 validation checks PASS.

## Promotion checklist

- [x] Fixture-side bugs related to penalty rates + traceability (#1–#3 in original review) → addressed
- [x] Priya rate correctness (newly identified during FWC verification) → fixed
- [x] `docs/award_sources.md` fleshed out → done
- [ ] Hours × Rate rounding (#5)
- [x] GL trial balance fix (#6) + add Trial-balance-balances validation row
- [ ] Leave balances proper cumulative computation (#7)
- [ ] Schema unified across the 3 tenants
- [ ] STP enum mismatch (#9)
- [x] PAYG against NAT 1004 (FY2025/26)
- [ ] Engine has matching rules in `pkg/rules/bundles/au/payroll/MA000004_*` + `MA000009_*` per R-0073
- [ ] QA data loader successfully imports against freshly-provisioned tenant DB (already verified for non-payroll Xero entities — see ledgius-api PR #79)
- [ ] Engine-vs-fixture diff test passes
