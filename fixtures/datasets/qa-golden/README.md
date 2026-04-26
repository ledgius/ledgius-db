# Ledgius QA Golden Tenant Dataset — FY2025/26

A comprehensive, reconciliation-guaranteed fixture set covering three QA tenants engineered to exercise the full breadth of Ledgius accounting + payroll + ATO compliance behaviour.

> **Two purposes:**
> 1. **Manual interactive testing** — three pre-populated tenants a human can log into, click around, and see realistic AR/AP/payroll/BAS data in every list and report.
> 2. **Unit-test source-of-truth** — every CEL formula, OPA Rego policy, and go-rules decision-table outcome is asserted against the `*_expected.csv` files. When a payroll-engine change drifts from the expected output, the test fails with a specific row-level diff.

> **Status:** v1 (FY2025/26) — generated 2026-04-25, restructured into ledgius-db 2026-04-26.
> **Coverage gates:** see [Release Gates](#release-gates).
> **Loading:** `make seed-load DATASET=qa-golden && make provision-tenants`.

---

## Three tenants — coverage matrix

| # | Tenant | Slug | Business shape | Pay cycle | Awards | Special-case coverage |
|---|---|---|---|---|---|---|
| **1** | QA-05 Middle Office Cleaning Pty Ltd | `qa-05-middle-office-cleaning` | Office services + cleaning | Monthly | MA000002 Clerks; MA000022 Cleaning | Mixed full-time + casual; contractor-supplier (no payroll) |
| **2** | QA-06 Retail Hospitality Pty Ltd | `qa-06-retail-hospitality` | Retail shop + cafe | Weekly | MA000004 General Retail; MA000009 Hospitality | All four employment types (FT/PT/casual/contractor); Sunday + PH penalties; split shifts |
| **3** | QA-07 Construction Professional Sales Pty Ltd | `qa-07-construction-professional-sales` | Construction + engineering + commercial sales | Weekly | MA000020 Construction; MA000065 Professional; MA000083 Commercial Sales | Annualised wage true-up; HIG candidate; commission earner; on-site allowances; RDO cycle |

The three tenants together exercise **7 modern awards** (covering ~70% of common AU SMB scenarios), all four legal employment types (FT / PT / casual / contractor), the four pay cycles in scope (weekly / fortnightly / monthly are all reachable), every NES entitlement category, and the full set of pay-arrangement variants (hourly / salary contract / annualised wage / commission / HIG).

---

## Tenant identity (full)

Each tenant has a complete production-shaped identity captured in `<tenant>/business_profile.yaml`. This is what `make seed-load` registers in the platform DB and what the assisted-tenant-create flow (Path 3 per R-0074) populates.

| Field | QA-05 Cleaning | QA-06 Retail/Hosp | QA-07 Construction |
|---|---|---|---|
| **Display name** | QA-05 Middle Office Cleaning Pty Ltd | QA-06 Retail Hospitality Pty Ltd | QA-07 Construction Professional Sales Pty Ltd |
| **Trading name** | Middle Office Cleaning | Riley's Retail & Cafe | Builder Pro & Co |
| **ABN** | 53 100 000 005 | 53 100 000 006 | 53 100 000 007 |
| **ACN** | 100 000 005 | 100 000 006 | 100 000 007 |
| **Entity type** | Pty Ltd | Pty Ltd | Pty Ltd |
| **GST registered** | Yes (since 2020-01-01) | Yes | Yes |
| **BAS cadence** | Quarterly (accrual) | Quarterly (accrual) | Quarterly (accrual) |
| **Address** | Level 5, 100 Queen St, Melbourne VIC 3000 | Shop 1, 200 Bourke St, Melbourne VIC 3000 | Unit 7, 300 Collins St, Melbourne VIC 3000 |
| **Primary email** | ops@qa-05-cleaning.test.ledgius.com | ops@qa-06-retail-hosp.test.ledgius.com | ops@qa-07-construction.test.ledgius.com |
| **Primary phone** | 03 9000 0005 | 03 9000 0006 | 03 9000 0007 |
| **Bank** | QA Test Bank · 099-999 · 099999123451 | QA Test Bank · 099-999 · 099999123452 | QA Test Bank · 099-999 · 099999123453 |
| **Default super fund** | AustralianSuper | REST Super | Cbus Super |
| **Pay cycle** | Monthly | Weekly | Weekly |
| **Created via** | admin_assisted | admin_assisted | admin_assisted |
| **Billing mode** | beta (comp) | paid_offline | paid_stripe |
| **Plan** | qa_comp | qa_offline | qa_paid_stripe |
| **Owner user** | owner@qa-05-cleaning.test.ledgius.com | owner@qa-06-retail-hosp.test.ledgius.com | owner@qa-07-construction.test.ledgius.com |

The three tenants intentionally use **three different `billing_mode` values** so the assisted-create flow's Stripe-collect / offline-arrangement / comp-account branches all see live test data.

---

## Workforce per tenant

### QA-05 Middle Office Cleaning

| Worker | Type | Award | Classification | Pay basis | Notes |
|---|---|---|---|---|---|
| Olivia Office Admin | Full-time employee | MA000002 Clerks—Private Sector 2020 | Level 2 Year 1 | $1,068.40/week | Monthly ordinary pay; annual + personal leave accrual |
| Charlie Cleaner | Casual employee | MA000022 Cleaning Services 2020 | Level 1 | $32.31/hr | Weekday + Saturday + PH cleaning shifts; 25% casual loading already in rate |
| Delta IT Services Pty Ltd | Contractor supplier | — | — | per bill | No payroll, no leave, no STP employee event |

### QA-06 Retail Hospitality

| Worker | Type | Award | Classification | Pay basis | Notes |
|---|---|---|---|---|---|
| Riley Retail Casual | Casual employee | MA000004 General Retail 2020 | Level 1 | $33.19/hr | Ordinary + evening + Saturday + Sunday penalties |
| Priya Retail Supervisor | Full-time employee | MA000004 General Retail 2020 | Level 4 | $31.64/hr × 38h | Full-time ordinary + leave accrual |
| Hana Cafe Part-time | Part-time employee | MA000009 Hospitality 2020 | Level 2 | $25.85/hr × 20h | Pro-rata leave accrual |
| Marco Hospitality Casual | Casual employee | MA000009 Hospitality 2020 | Level 2 | $32.31/hr | Ordinary + Saturday + PH shifts; split shifts |
| Peak Local Marketing Pty Ltd | Contractor supplier | — | — | per bill | Supplier bills only |

### QA-07 Construction Professional Sales

| Worker | Type | Award | Classification | Pay basis | Notes |
|---|---|---|---|---|---|
| Ben Builder | Full-time employee | MA000020 Construction General On-site 2020 | CW/ECW 3 | $1,068.40/week | RDO cycle; tool + site + meal allowances |
| Amara Engineer | **Annualised-wage** employee | MA000065 Professional Employees 2020 | Level 2 Experienced | $1,730.77/week salary | Shadow-award reconciliation expected each pay (PAY-AUTH-022) |
| Nina Sales Representative | **Commission** employee | MA000083 Commercial Sales 2020 | Commercial Traveller / Advertising Sales Rep | Base $1,071.90/week + monthly commission | Variable-pay PAYG/SG/STP classification per PAY-AUTH-023 |
| Grace High Income QA | **HIG candidate** | MA000065 Professional Employees 2020 (comparator) | HIG comparator | $3,461.54/week | Tests PAY-AUTH-055 — HIG only recognised when ALL conditions hold |
| Liam Surveying Contractors Pty Ltd | Contractor supplier | — | — | per bill | Supplier bills only |

---

## Shared assumptions (every tenant)

| Area | Assumption |
|---|---|
| **Period** | FY2025/26 — `2025-07-01` → `2026-06-30` |
| **Timezone** | Australia/Melbourne |
| **GST** | Registered, quarterly BAS, accrual basis |
| **PAYG** | ATO Schedule 1 Scale 2 coefficient, resident, tax-free threshold claimed, no STSL/HELP, no Medicare variation, no extra withholding, no offsets |
| **SG rate** | 12% (FY2025/26) |
| **Payroll clearing** | Net wages, PAYG remittance, and SG clearing-house payments are explicit bank withdrawals + GL clearing journals — closes to zero per fixture |
| **Contractor handling** | `award_code = null`, `payroll_enabled = false`, no leave profile, no STP employee event |
| **Bank** | All three on QA Test Bank with sequential account numbers (`099999123451–3`); BSB `099-999` reserved for QA |

---

## File index — what's in each tenant directory

```
qa-XX-<slug>/
├── business_profile.yaml             # Full tenant identity (ABN, plan, billing, owner, super, branding)
├── tenant_metadata.yaml              # Period + bank settings + GST/STP/super config (legacy minimal)
├── README.md                         # Per-tenant readme
│
├── source_snapshot/import_files/     # ← AS IF IMPORTED — Xero/MYOB CSV shape
│   ├── contacts.csv                  # Customers + suppliers
│   ├── invoices.csv                  # AR-side invoices
│   └── bills.csv                     # AP-side supplier bills
│
├── bank_files/
│   └── bank_transactions.csv         # ← Bank feed — all withdrawals/deposits for the FY
│
├── payroll/
│   ├── employees.csv                 # Employee master (incl. award + classification + rates)
│   ├── contractors.csv               # Contractor-supplier master (always payroll_enabled=false)
│   ├── award_declarations.csv        # ← NEW: per-award FWC code + operative + applies-to
│   ├── eba_declarations.csv          # ← NEW: empty by design (no EBAs in QA Golden)
│   ├── ifa_declarations.csv          # ← NEW: empty by design (no IFAs in QA Golden)
│   ├── pay_runs_expected.csv         # Expected pay-run output (gross, PAYG, net, super)
│   ├── pay_items_expected.csv        # Expected per-line breakdown (ordinary/penalty/allowance)
│   ├── super_contributions_expected.csv   # Expected SG amounts
│   ├── stp_phase2_expected.csv       # Expected STP Phase 2 submission shape
│   └── leave_balances_expected.csv   # Expected leave accruals
│
├── accounting/
│   ├── payroll_journal_expected.csv  # Expected GL journal lines from payroll
│   ├── general_ledger_expected_balances.csv  # Expected closing balances per account
│   └── bas_quarterly_expected.csv    # Expected Q1/Q2/Q3/Q4 BAS labels (1A, 1B, W1, W2)
│
├── reconciliation/
│   └── bank_payroll_gl_reconciliation.csv  # Bank ↔ payroll ↔ GL closure proof
│
├── reference/
│   ├── bank_summary.csv              # Bank running balance summary
│   ├── super_funds.csv               # ← NEW: per-employee fund + USI + member number
│   └── validation_checks.csv         # Per-tenant validation pass/fail
│
└── docs/
    ├── award_sources.md              # Award provenance for fixture rates
    └── payg_reference.md             # PAYG method + simplifications
```

The seed runner (`make seed-load DATASET=qa-golden`) reads `tenants.yaml` + `users.yaml` at the dataset root. The per-tenant subdirectories are loaded by the tenant-side data importer (or used directly by unit tests).

---

## Test mapping — fixture → unit test

Every fixture file maps to one or more test categories. Tests assert the engine output equals the fixture's expected output, row by row.

| Fixture | Test category | Engine surface | What it proves |
|---|---|---|---|
| `payroll/pay_runs_expected.csv` | Pay-run integration | CEL `pkg/rules/bundles/payroll_v1.0.0.yaml` (PAYG, SG, gross_pay) + future `au/payroll/<MA-code>_*.yaml` | End-to-end pay-run output matches expected gross / PAYG / net / super |
| `payroll/pay_items_expected.csv` | Per-component award rules | CEL formulas (penalty rates, allowances) + go-rules decision tables (penalty selection by time-of-day) | Each line item has the correct award-driven amount + classification |
| `payroll/super_contributions_expected.csv` | SG calc | CEL `super_guarantee` formula + go-rules `super_guarantee_rate_v1.0.0.json` | OTE × rate = expected SG; correct fund routing per `reference/super_funds.csv` |
| `payroll/stp_phase2_expected.csv` | STP Phase 2 classification | OPA `pkg/rules/bundles/stp_*.rego` (when shipped) | Each pay component carries the right STP income-type + payment-classification |
| `payroll/leave_balances_expected.csv` | Leave accrual | CEL leave-accrual formulas | Annual + personal leave accruing per NES + award-uplift |
| `accounting/payroll_journal_expected.csv` | GL posting | OPA `double_entry.rego` + payroll-posting service | Every payroll line produces the expected balanced journal |
| `accounting/general_ledger_expected_balances.csv` | GL invariants | OPA `double_entry.rego` + reporting service | Trial balance balances; accounts close to expected values |
| `accounting/bas_quarterly_expected.csv` | BAS extraction | OPA + reporting `bas_*` rules | 1A/1B/W1/W2 labels per quarter match expected — drives ATO compliance |
| `reconciliation/bank_payroll_gl_reconciliation.csv` | End-to-end invariant | All of the above | Bank withdrawals = journal credits; clearing accounts close to 0 |
| `payroll/award_declarations.csv` | Award applicability + classification | OPA award rules (per-award `<MA-code>.rego` per A-0046) | Each declared award resolves to the right rule bundle for each employee |
| `payroll/eba_declarations.csv` (empty) | Negative test — no EBA | Stage-2 layer composer (per A-0046) | Resolver falls through to award rule when no EBA declared |
| `payroll/ifa_declarations.csv` (empty) | Negative test — no IFA | Stage-2 layer composer | Resolver skips IFA layer when none active |

### Special-scenario coverage (QA-07 flagship)

| Scenario | Tenant | Employee | Engine proof |
|---|---|---|---|
| **Annualised wage true-up** (PAY-AUTH-022) | QA-07 | Amara Engineer | Shadow award calc each pay; reconciliation top-up at FY-close if shortfall |
| **HIG eligibility gating** (PAY-AUTH-055) | QA-07 | Grace High Income QA | HIG only recognised when all FWA conditions hold + evidence retained |
| **Variable pay PAYG/SG/STP** (PAY-AUTH-023) | QA-07 | Nina Sales | Commission classified for PAYG additional-payment + OTE + STP Phase 2 |
| **Sunday penalty rates** (MA000004 + 2025 variation) | QA-06 | Riley Retail Casual | go-rules decision table picks correct multiplier by day-of-week |
| **Split shifts** (MA000009) | QA-06 | Marco Hospitality Casual | Pay-item lines split with correct minimum-engagement per shift |
| **RDO accrual + tool/site/meal allowances** (MA000020) | QA-07 | Ben Builder | Per-pay accrual + per-day allowance rules |
| **Casual loading** | QA-05, QA-06 | Charlie, Riley, Marco | 25% loading either embedded in rate or added per-pay |
| **Contractor exclusion** | All 3 | Delta IT, Peak Local Marketing, Liam Surveying | No payroll posting, no leave, no STP — supplier bills only |
| **Mixed pay cycles** | QA-05 (monthly) vs QA-06/07 (weekly) | All employees | Cycle-correct accrual + super due dates |

---

## Reconciliation guarantee

Each tenant ships `reconciliation/bank_payroll_gl_reconciliation.csv` and `reference/validation_checks.csv` proving that:

1. **Bank payroll debits = payroll bank journal credits** — every dollar leaving the bank for payroll has an offsetting GL entry.
2. **Net wages bank-row total = expected net wages** from `pay_runs_expected.csv`.
3. **PAYG bank-row total = expected PAYG withholding** from `pay_items_expected.csv`.
4. **Super bank-row total = expected SG liability** from `super_contributions_expected.csv`.
5. **Wages / PAYG / Super clearing accounts close to zero** — no orphaned balances.
6. **Bank closing balance = final running balance** from `bank_files/bank_transactions.csv`.
7. **BAS W2 = sum of payroll PAYG withholding** for the BAS period.
8. **Sum of monthly/weekly gross wages = BAS W1 quarterly totals**.

Confirmed PASS for all three tenants at fixture-generation time (2026-04-25).

---

## Loading

```bash
cd ledgius-db

# Step 1 — Register tenants in platform DB + create users + memberships
make seed-load DATASET=qa-golden

# Step 2 — Provision tenant DBs + run migrations + seed reference data
make provision-tenants

# Optional: load per-tenant transactional data (importer pipeline)
# This is what populates customers/invoices/bills/bank-feed in the
# actual tenant DB. The seed runner does NOT do this today; the
# tenant-side importer needs to be invoked per tenant. See T-0042
# Slice 4 — Go provisioning service — which extends this to include
# tenant-side seeding.
```

After load + provisioning:
- 3 tenants registered as `is_test=true`
- 5 users (3 owners + 1 QA admin + 1 accountant) with cross-tenant memberships
- Multi-tenant login picker shows all three when logging in as `qa-admin@ledgius.com` / `qaqa1234`

---

## Versioning + regeneration policy

This dataset is **frozen against FY2025/26 ATO + FWC rate schedules** (PAYG Schedule 1 Scale 2 effective 2024-07-01; SG rate 12%; modern award rates per FWC 2025-07-01 variations).

**When to regenerate:**

- **Annually (1 July)** — FWC publishes modern-award variations; PAYG schedules may change. Generate a parallel `qa-golden-fy<NN>` dataset rather than mutating this one.
- **Mid-year** if ATO publishes a special schedule (e.g. SG rate change announcement).
- **Never** to "fix" a test failure — if the engine drifts from this fixture, the engine is wrong, not the fixture (unless you can prove a fixture-side bug).

**Regeneration workflow:** the original generator script is not in-tree; the fixtures were authored 2026-04-25 by hand-curated CSV generation. Future regeneration should:

1. Update `business_profile.yaml` rate references to the new FY (SG rate, PAYG basis).
2. Re-derive `pay_runs_expected.csv` + `pay_items_expected.csv` from the new award rates.
3. Re-flow the journal / GL / BAS / reconciliation files.
4. Verify all `validation_checks.csv` rows still PASS.
5. Increment dataset version.

---

## Release gates

A release candidate must fail if **any** of the following:

| # | Gate | What |
|---|---|---|
| 1 | Bank ↔ payroll mismatch | Any tenant's payroll bank withdrawals do not equal payroll bank journal credits |
| 2 | Clearing-account leak | Net wages / PAYG / super clearing balances do not close to zero in fixture |
| 3 | BAS W2 mismatch | BAS W2 ≠ sum of payroll PAYG withholding for the BAS period |
| 4 | Contractor leakage | Any contractor record receives an award, leave accrual, payroll-enabled state, or employee STP event |
| 5 | Sunday penalty drift | MA000004/MA000009 Sunday-shift pay-item amounts drift from expected |
| 6 | Annualised wage drift | QA-07 Amara Engineer FY-close shadow-award reconciliation produces the wrong top-up (or no top-up) |
| 7 | HIG misapplication | QA-07 Grace HIG candidate's HIG status applies without all PAY-AUTH-055 conditions met |
| 8 | Super fund mismatch | Per-employee super contributions route to a fund other than `reference/super_funds.csv` declares |
| 9 | NES floor breach | Any per-pay calculation produces less than the NES minimum on annual leave / personal leave / public holiday pay |

Tests should fail-loud per gate — never aggregate failures into "X of Y tests passed" without per-gate detail.

---

## Reference docs (per tenant)

- `docs/award_sources.md` — award identifiers + provenance for fixture rates
- `docs/payg_reference.md` — PAYG method + fixture simplifications (resident, TFT-claimed, no STSL)

These document why the fixture's rates are what they are. When ATO/FWC publish new rates, update these doc files alongside the data.

---

## Related specs

- **R-0073 / A-0046 / T-0041** — Payroll Authority Knowledge Pipeline (the spec the QA-07 fixture exercises)
- **R-0074 / A-0047 / T-0042** — Tenant Database Provisioning Pipeline (how the dataset gets loaded)
- **R-0007** — PAYG Withholding Engine (validated against `payroll/pay_items_expected.csv` PAYG columns)
- **R-0006** — Superannuation Guarantee (validated against `payroll/super_contributions_expected.csv`)
- **R-0005** — STP Phase 2 (validated against `payroll/stp_phase2_expected.csv`)
- **R-0008** — Knowledge Pipeline (the help-articles framework the awards are surfaced through)
