# QA-06 Retail Hospitality — known issues (draft fixture)

Draft / WIP fixtures — not engine-truth. Issues identified by review on PR ledgius-db#36.

## Fixture-side bugs (block promotion)

1. **MA000004 evening loading wrong rate** — Riley's `retail_casual_evening_after_6pm` is $39.83 = $33.19 × **1.20**. MA000004 cl 15.6 evening loading for casuals is **+25%** on the casual rate (i.e. ×1.25), giving $41.49. **Fix:** verify the cited clause in the live award and update the multiplier.

2. **MA000004 Sunday casual rate wrong** — Riley's Sunday casual is $46.46 = $33.19 × **1.40**. MA000004 cl 18.4 currently sets Sunday casual at **175%** of the minimum (not casual-loaded ordinary × 1.40). **Fix:** verify and update — this is the single highest-leverage fix because Sunday penalties are the most-litigated retail-payroll error class.

3. **`AuthorityRefs` strings not traceable to FWC clause numbers** — same pattern as QA-05. Replace bespoke labels with `MA00000X:cl.<N>` references.

4. **`docs/award_sources.md` is 13 lines of placeholder** — the file lists award names but not the FWC publication URLs, operative dates, or specific clauses cited. Flesh out before promotion.

5. **Hours × Rate ≠ Amount throughout** — same root cause as QA-05 #1 (back-derived from weekly_rate at full precision).

6. **GL trial balance does not balance** — D=$458,356.71, C=$575,850.00, off by $117,493.29. Same root cause as QA-05 #4.

7. **Leave balances literal "fixture-cumulative"** — same as QA-05 #3.

## Schema-side gaps

8. **employee.csv schema differs from QA-05/QA-07** — this file's header has `hourly_rate, leave_accrues` only; QA-05 + QA-07 have `weekly_rate, hourly_rate, leave_accrues`. A single typed importer can't load all three without per-tenant schema branching. **Fix:** pick one canonical schema (per-row pay-basis differences are data, not file shape).

9. **STP enum mismatch** — same as QA-05 #6.

## Promotion checklist

- [ ] Fixture-side bugs (#1–#7) fixed
- [ ] Schema unified across the three tenants (#8)
- [ ] Schema-side gap (#9) resolved
- [ ] Engine has matching rules for MA000004 + MA000009 in `pkg/rules/bundles/au/payroll/`
- [ ] QA data loader successfully imports against freshly-provisioned tenant DB
- [ ] Engine-vs-fixture diff test passes
