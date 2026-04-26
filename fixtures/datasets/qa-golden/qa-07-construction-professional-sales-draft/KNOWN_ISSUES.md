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

- ❌ **Grace HIG salary $180,000/yr is BELOW the FY2025/26 high-income threshold $183,100** — Per FWA s333, the high-income threshold for FY2025/26 is $183,100 (varied annually). Grace's $180,000 guarantee fails the threshold qualification, meaning HIG status would NOT be recognised for her. Either:
  - Increase Grace's guarantee to $183,100+ (or $190,000 to comfortably exceed) — cascade through her 52 pay rows + journal + bank + BAS + GL + reconciliation
  - Or relabel Grace as "HIG-attempted-but-fails-threshold-qualification" and ensure the engine treats her as award-covered (not HIG-out)
- ❌ **`employment_type` values violate live schema CHECK constraint** — file uses `full_time_annualised_wage`, `full_time_commission`, `full_time_high_income_guarantee`. `migrations/tenant/V1.08__payroll.sql:30` only allows `('full_time','part_time','casual','contractor')`. Three rows fail INSERT. Awaits the EmploymentPayArrangement entity per R-0073 / A-0046 (ledgius-specs#37) — until that lands, fixture rows for Amara/Nina/Grace cannot be inserted.
- ❌ **`"salary"` literal in numeric Rate column** for Amara + Grace ordinary rows. Replace with NULL or a defensible numeric (e.g. the implied hourly: $1,730.77 / 38 = $45.55 for Amara, $3,461.54 / 38 = $91.09 for Grace).

## Still outstanding (block promotion)

- ❌ **`Hours × Rate ≠ Amount` rounding** — fixture-wide pattern; Amount back-derived from full-precision rates while Rate is printed at 2 dp.
- ❌ **GL trial balance does not balance** — D vs C off by $399,431.12 (the largest of the three tenants). Same root cause: bank GL line + missing equity row.
- ❌ **Leave balances literal `"fixture-cumulative"` strings**.
- ❌ **STP `IncomeType=SalaryAndWages` / `EmploymentBasis=full_time` long-form** vs schema enum codes.
- ❌ **PAYG against NAT 1004** — cross-tenant issue.

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
- [ ] GL trial balance fix (cross-tenant)
- [ ] Leave balances proper computation (cross-tenant)
- [ ] STP enum mismatch (cross-tenant)
- [ ] PAYG against NAT 1004 (cross-tenant)
- [ ] Engine has matching rules in `pkg/rules/bundles/au/payroll/MA000020_*` + `MA000065_*` + `MA000083_*` per R-0073
- [ ] HIG / annualised-wage / variable-pay engine paths shipped per R-0073 + supporting migrations
- [ ] QA data loader successfully imports against freshly-provisioned tenant DB (already verified for non-payroll Xero entities — see ledgius-api PR #79)
