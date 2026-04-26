# QA-07 Construction Professional Sales — known issues (draft fixture)

Draft / WIP fixtures — see [README.md](../README.md). Issues identified by review on PR ledgius-db#36, with progress tracked here.

## Resolved 2026-04-26

- ✅ **Industry + tool allowance OTE classification verified CORRECT** — Original review claimed Ben's industry ($64.10) and tool ($39.60) allowances should be `OTEForSuper=FALSE` per ATO SGR 2009/2. Reading the actual award reveals: MA000020 cl 22.3 makes industry allowance "for all purposes"; cl 21.1(a) makes tool allowance "for all purposes"; cl 4 defines `ordinary hourly rate` as including all-purpose allowances. Per ATO SGR 2009/2 ¶24–25, allowances forming part of ordinary hourly rate are within OTE. Fixture's `OTEForSuper=TRUE` for these is correct. The reviewer's general SGR-2009/2 quote didn't account for the award's specific structure.
- ✅ **Overtime meal allowance OTE classification CORRECTED** — Ben's `overtime_meal_allowance` ($19.00) was wrongly flagged `OTEForSuper=TRUE`. Cl 21.2(a) explicitly says it's paid "to meet the cost of a meal" — expense reimbursement, not for all purposes. Per ATO SGR 2009/2 ¶28(a), expense allowances are NOT OTE. Cascaded the fix through 10 affected pay periods (super reduced by $2.28/occurrence × 10 = $22.80/yr; closing bank balance: $441,978.88 → $442,001.68). All 8 narrow validation checks PASS post-cascade.
- ✅ **All hourly rates verified against FWC PDFs:**
  - Ben Builder MA000020 CW/ECW 3 = $28.12 ✓ (Table 5, PR786558 ppc 01Jul25)
  - Amara Engineer MA000065 Level 2 Experienced annual = $75,261 (award minimum, hourly $37.97); Amara's $90,000/yr fixture salary is above-award annualised wage per cl 17
  - Nina Sales MA000083 Commercial Traveller = $1,071.90/wk + $28.21/hr ✓ (Table 5)
- ✅ **AuthorityRefs replaced with real FWC clause references** — 334 rows updated across `pay_items_expected.csv` for all 4 employees.
- ✅ **`docs/award_sources.md` rewritten** with full clause-level provenance, FWC PR references, OTE rationale per allowance type, and the PAY-AUTH-055 HIG-threshold finding.

## Newly identified — needs fix before promotion

- ✅ **Grace HIG salary** RESOLVED 2026-04-27 — bumped from $180,000 to $190,000/yr (= $3,653.85/wk) to clear the FY2025/26 threshold $183,100 with comfortable buffer. Cascaded through 52 pay rows + journal + bank + BAS + GL + reconciliation. All 8 narrow validation checks PASS post-cascade.
- ✅ **`employment_type` CHECK violation** RESOLVED 2026-04-27 — collapsed special types to `full_time` (CHECK-compliant); added `pay_arrangement_type` column carrying the variation (`ordinary` / `annualised_wage` / `commission` / `high_income_guarantee`). No DB migration required for the immediate fix; the EmploymentPayArrangement entity per R-0073 will eventually formalise this in the schema.
- ✅ **`"salary"` literal in Rate column** RESOLVED 2026-04-27 — replaced with implied hourly: Amara $45.55, Grace $96.15 (post-HIG-cascade). 104 rows updated.

## Still outstanding (block promotion)

- ✅ **Hours × Rate ≠ Amount` rounding** RESOLVED 2026-04-27 — Rate to 4dp where needed; Hours × Rate now matches Amount.
- ✅ **GL trial balance** RESOLVED 2026-04-27 — bank GL line corrected to actual closing cash $430,801.40 (was an inverted -18,629.72 net-credit value), and `3000 Owner's Capital` $50,000 CR row added (opening cash equity). DR = CR = $1,074,650.00. New `Trial balance balances (DR equals CR)` row added to `validation_checks.csv`.
- ✅ **Leave balances cumulative computation** RESOLVED 2026-04-27.
- ✅ **STP enum codes** RESOLVED 2026-04-27 — substituted to ATO codes (SAW / F / P / C).
- ✅ **PAYG against NAT 1004 FY2025/26** RESOLVED 2026-04-27 — recomputed every weekly pay using NAT 1004 Scale 2 coefficients. Annual PAYG total: $108,638.00 (was $97,555.12). Cascaded through pay_runs + STP + journal + bank + BAS quarterly. Bank closing preserved at $430,801.40. Grace's HIG salary correctly hits the top bracket ($3,461+ a=0.4700, b=512.8846) → $1,204/week PAYG. All 9 validation checks PASS.

## Promotion checklist

- [x] Penalty/allowance values verified against live FWC sources
- [x] Industry + tool allowance OTE classification verified correct (review was wrong)
- [x] Overtime meal allowance OTE flag corrected to FALSE
- [x] AuthorityRefs replaced with real clause references (334 rows)
- [x] `docs/award_sources.md` fleshed out with full provenance
- [ ] Grace HIG salary increased to clear FY2025/26 threshold ($183,100)
- [ ] `employment_type` schema-aligned (awaits EmploymentPayArrangement entity)
- [ ] `"salary"` literal replaced in Rate column
- [ ] Hours × Rate rounding (cross-tenant)
- [x] GL trial balance fix (cross-tenant)
- [ ] Leave balances proper computation (cross-tenant)
- [ ] STP enum mismatch (cross-tenant)
- [x] PAYG against NAT 1004 (cross-tenant)
- [ ] Engine has matching rules in `pkg/rules/bundles/au/payroll/MA000020_*` + `MA000065_*` + `MA000083_*` per R-0073
- [ ] HIG / annualised-wage / variable-pay engine paths shipped per R-0073 + supporting migrations
- [ ] QA data loader successfully imports against freshly-provisioned tenant DB (already verified for non-payroll Xero entities — see ledgius-api PR #79)
