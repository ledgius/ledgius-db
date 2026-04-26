# QA-05 Middle Office Cleaning — known issues (draft fixture)

These per-tenant CSVs are **draft / work-in-progress fixtures**. They are not loaded by `make seed-load` and they are not yet engine-truth. Issues identified by review on PR ledgius-db#36 — must be resolved before promoting these out of `-draft/`.

## Fixture-side bugs (block promotion)

1. **Hours × Rate ≠ Amount throughout** — e.g. row 2 of `payroll/pay_items_expected.csv`: Hours=164.67, Rate=28.12, Amount=4,629.73, but 164.67 × 28.12 = 4,630.51. Amount is back-derived from `weekly_rate × 52 / 12` at full precision while Rate is printed at 2 dp. **Fix:** either match Amount to printed Rate × Hours, or print Rate at 4 dp, or stop publishing Hours/Rate when the source of truth is the salary.

2. **MA000022 cleaning Saturday penalty rate not traced to FWC clause** — `AuthorityRefs` strings (e.g. `MA000022:CSE1-casual-saturday-rate`) are bespoke labels with no mapping to actual FWC clause numbers. Verify Charlie's Saturday/PH rates against the live MA000022 instrument and replace with `MA000022:cl.<N>` references.

3. **Leave balances column literal "fixture-cumulative"** — `payroll/leave_balances_expected.csv` has the string `fixture-cumulative` in `ClosingAnnualLeaveHours` / `ClosingPersonalLeaveHours` for every row. Either compute the cumulative balance per pay (the actual asserted behaviour) or remove the columns. Today the file proves nothing the engine could be measured against.

4. **GL trial balance does not balance** — D=$235,072.40, C=$259,050.00, off by $23,977.60. The bank line in `accounting/general_ledger_expected_balances.csv` is computed as "closing bank − payroll outflows" (not actual closing cash); no equity / opening retained earnings row. Add a `Trial balance balances` check row to `reference/validation_checks.csv` so this cannot regress unnoticed.

## Schema-side gaps (resolve when targeted at the live schema)

5. **employee.award_code / classification columns don't exist** — these CSVs encode award + classification per employee, but the live tenant schema (`migrations/tenant/V1.08__payroll.sql`) doesn't have those columns. Per-pay-component rows have nowhere to land — `pay_run_line.details_json` is a single JSONB blob. The fixtures await a migration that adds these (per R-0073 / A-0046, in flight on `ledgius-specs#37`).

6. **STP `IncomeType` / `EmploymentBasis` don't match schema enums** — fixtures use `SalaryAndWages` / `full_time` (long form). `migrations/tenant/V1.28__stp_phase2.sql` requires the ATO codes (`SAW` / `F`, `P`, `C`, …). Engine tests would fail every row of this fixture against current schema.

## Engine-side gaps (acknowledged, not a fixture bug)

7. **README's "every CEL/Rego/go-rules outcome asserted" is aspirational** — the live `pkg/rules/bundles/payroll_v1.0.0.yaml` defines six formulas only (`gross_pay_hourly`, `gross_pay_annual`, `payg_coefficient`, `super_guarantee`, `net_pay`, `no_tfn_withholding`). Award penalty rates, casual loading, allowances, leave accrual, RDO, HIG, annualised-wage, STP Phase 2 classification — none have rules in the bundles yet. These fixtures are the **target output** the engine must produce once the matching rules ship per R-0073 / T-0041 (ledgius-specs#37). Reframe as expected-when-shipped, not validated-today.

## Promotion checklist (out of `-draft/`)

Before moving this directory to `qa-05-middle-office-cleaning/`:

- [ ] All fixture-side bugs (#1–#4 above) fixed
- [ ] Schema-side gaps (#5–#6) resolved by either migration landing or fixtures re-shaped to current schema
- [ ] Engine-side coverage (#7) has matching rules in `pkg/rules/bundles/au/payroll/MA000002_*` + `MA000022_*`
- [ ] QA data loader (`ledgius-api/cmd/qa-data-loader`) successfully imports this fixture against a freshly-provisioned tenant DB
- [ ] At least one engine-vs-fixture diff test passes against this tenant's pay_runs_expected
