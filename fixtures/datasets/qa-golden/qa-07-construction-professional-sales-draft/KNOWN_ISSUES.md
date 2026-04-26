# QA-07 Construction Professional Sales — known issues (draft fixture)

Draft / WIP fixtures — not engine-truth. Issues identified by review on PR ledgius-db#36.

## Fixture-side bugs (block promotion)

1. **Allowances incorrectly treated as OTE for super (Ben Builder, MA000020)** — `payroll/pay_items_expected.csv` flags `industry_allowance` ($64.10) and `tool_allowance` ($39.60) with `OTEForSuper=TRUE`, and the matching `pay_runs_expected.csv` row computes SG = 12% × $1,172.10 = $140.65. Per **ATO SG Ruling 2009/2**, tool allowances and industry/disability allowances are generally **not OTE**. Correct SG = 12% × $1,068.40 = $128.21. Repeated weekly = ~$650/yr over-stated super for one employee. **Fix:** flip these rows to `OTEForSuper=FALSE` and recalculate SG.

2. **`pay_items_expected.csv` has literal string "salary" in numeric Rate column for Amara** — same file blanks Hours/Rate for allowance rows. Both will break a row-vs-row engine diff. **Fix:** use NULL for non-applicable Rate (e.g. annualised salary) and decide one consistent representation for allowances (per-row amount vs Hours×Rate).

3. **`employment_type` values violate live schema CHECK constraint** — file uses `full_time_annualised_wage`, `full_time_commission`, `full_time_high_income_guarantee`. `migrations/tenant/V1.08__payroll.sql:30` allows only `('full_time','part_time','casual','contractor')`. Three rows would fail INSERT. **Fix:** decompose into base `employment_type` + a separate `pay_arrangement_type` column, per the EmploymentPayArrangement entity in R-0073 / A-0046 (in flight on ledgius-specs#37). Until that migration lands, fixture rows for Amara/Nina/Grace cannot be inserted.

4. **MA000020 RDO + tool/site/meal allowance traceability** — same `AuthorityRefs` placeholder issue as QA-05/QA-06. Need real FWC clause numbers.

5. **Hours × Rate ≠ Amount throughout** — same root cause as QA-05 #1.

6. **GL trial balance does not balance** — D=$632,671.12, C=$1,032,102.24, off by $399,431.12. The largest of the three; same root cause but more severe because of the larger transactional volume.

7. **Leave balances literal "fixture-cumulative"** — same as QA-05 #3.

## Schema-side gaps

8. **HIG (Grace) needs `HighIncomeGuarantee` entity** — per PAY-AUTH-055 (ledgius-specs#37), HIG status is recognised only when ALL conditions hold: modern-award covered, no EBA, valid written guarantee with retained acceptance evidence, guaranteed earnings > threshold. Today's fixture only encodes `employment_type=full_time_high_income_guarantee` — no acceptance evidence, no threshold reference, no notice-of-non-application date. **Fix:** add a `payroll/hig_declarations.csv` once the entity exists.

9. **Annualised wage true-up (Amara) needs shadow-award reconciliation row** — per PAY-AUTH-022, the engine should every pay period run a shadow award calc + record cumulative comparison, with reconciliation top-up at FY close. The current fixture has annualised salary rows but no shadow-award comparison output; the engine has nothing to assert against. **Fix:** add `payroll/annualised_wage_shadow_calc_expected.csv` with the per-pay shadow + cumulative drift + top-up at year-end.

10. **Variable pay (Nina commission) needs PAYG/SG/STP classification** — per PAY-AUTH-023, commission components are first-class pay-component types with explicit metadata for PAYG (regular vs additional-payment), OTE eligibility, and STP Phase 2 income-type / payment-classification reporting. The current fixture has commission amounts but doesn't specify the classification metadata. **Fix:** add classification columns once the `VariablePayPlan` entity exists.

## Engine-side gaps

11. Same as QA-05 #7 — most expected columns can't currently be produced for comparison; reframe expected-when-shipped.

## Promotion checklist

- [ ] Fixture-side bugs (#1–#7) fixed (especially #1 — incorrect allowance OTE classification is a real-money compliance bug)
- [ ] Schema-side gaps (#8–#10) resolved by either migrations landing or fixture re-shape
- [ ] Engine-side coverage (#11) has matching rules in `pkg/rules/bundles/au/payroll/MA000020_*` + `MA000065_*` + `MA000083_*`
- [ ] HIG / annualised-wage / variable-pay engine paths shipped per R-0073 + supporting migrations
- [ ] QA data loader successfully imports against freshly-provisioned tenant DB
- [ ] Engine-vs-fixture diff test passes (with the corrected #1 OTE treatment)
