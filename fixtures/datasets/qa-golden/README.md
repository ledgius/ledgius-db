# Ledgius QA Golden Tenant Dataset — FY2025/26

QA tenant manifest (production-shaped) plus draft per-tenant fixtures targeted at upcoming engine + schema work.

> **Status (2026-04-26):** **Manifest layer authoritative; per-tenant CSVs in `-draft/` directories** pending the QA data loader (in flight on `ledgius-api`) + the schema/rules-engine work that will give them a target to load into. The original PR (ledgius-db#36) was reviewed and substantive accounting/award correctness issues were identified — see each `-draft/KNOWN_ISSUES.md`.

---

## Two-layer structure

```
fixtures/datasets/qa-golden/
├── tenants.yaml                    # ✅ AUTHORITATIVE — registers 3 tenants
├── users.yaml                      # ✅ AUTHORITATIVE — 5 users + memberships
├── config.yaml                     # ✅ Dataset metadata
├── README.md                       # ✅ This file
│
├── qa-05-middle-office-cleaning-draft/      # ⚠️ DRAFT — see KNOWN_ISSUES.md
├── qa-06-retail-hospitality-draft/          # ⚠️ DRAFT — see KNOWN_ISSUES.md
└── qa-07-construction-professional-sales-draft/  # ⚠️ DRAFT — see KNOWN_ISSUES.md
```

### What "manifest layer" means

`tenants.yaml` + `users.yaml` are the only files **`make seed-load DATASET=qa-golden` actually consumes today**. They register the three QA tenants in `ledgius_platform.tenants` plus the 5 users (3 per-tenant owners + 1 cross-tenant QA admin + 1 accountant) and their memberships. After running:

```bash
make seed-load DATASET=qa-golden     # Step 1 — register tenants + users
make provision-tenants               # Step 2 — create tenant DBs + run Flyway migrations
```

…you can log in as `qa-admin@ledgius.com` / `qaqa1234`, see the tenant picker with all three tenants, and switch into any of them. Each tenant DB is a clean migrated empty tenant — **no per-tenant transactional data is loaded** by these manifests.

### What `-draft/` means

The per-tenant directories contain authored CSVs (employees, contractors, expected pay runs, expected pay items, expected super, expected STP, expected leave balances, expected payroll journal, expected GL balances, expected BAS, reconciliation, validation checks, source-snapshot Xero imports). They are the **target shape** for what a future loader will populate into each tenant DB and what a future engine-vs-fixture test suite will diff engine output against.

They are **not loaded by anything today**. Consuming them requires:

1. **The QA data loader** — `ledgius-api/cmd/qa-data-loader/` (in flight) — uses the existing Xero file-import API endpoint (`POST /api/v1/import/batches/...`) to push the per-tenant `source_snapshot/import_files/*.csv` into each tenant.
2. **The Payroll Authority engine work** — per R-0073 / A-0046 / T-0041 (in flight on `ledgius-specs#37`) — produces the CEL formulas, OPA Rego policies, and go-rules decision tables that turn employees + bank transactions into pay runs / super / STP / journal entries that match the `*_expected.csv` files.
3. **Schema migrations** — the live schema doesn't yet model award_code, classification, EmploymentPayArrangement, HighIncomeGuarantee, VariablePayPlan, DeterminationTrace etc. — see each tenant's `KNOWN_ISSUES.md` for the specifics.

Until the loader + engine + schema land, the per-tenant CSVs sit in `-draft/` so reviewers don't read them as engine-truth and so a future Trial-balance-balances test cannot land prematurely against unbalanced GLs.

---

## Three tenants — coverage matrix

| # | Tenant | Slug | Pay cycle | Awards | Billing-mode | Loaded? |
|---|---|---|---|---|---|---|
| **1** | QA-05 Middle Office Cleaning Pty Ltd | `qa-05-middle-office-cleaning` | Monthly | MA000002 + MA000022 | beta (comp) | Manifests ✅ · Data ⚠️ draft |
| **2** | QA-06 Retail Hospitality Pty Ltd | `qa-06-retail-hospitality` | Weekly | MA000004 + MA000009 | paid_offline | Manifests ✅ · Data ⚠️ draft |
| **3** | QA-07 Construction Professional Sales Pty Ltd | `qa-07-construction-professional-sales` | Weekly | MA000020 + MA000065 + MA000083 | paid_stripe | Manifests ✅ · Data ⚠️ draft |

The three intentionally use **three different `billing_mode` values** so the upcoming admin-assisted-create flow's branches each get live test data. The `billing_mode` field doesn't exist in the platform schema yet — it's added by the migration in T-0042 Slice 2 + the assisted-create endpoint per R-0074 (in flight on `ledgius-specs#38`). Until then, the tenants are seeded as plain `is_test=true` records.

---

## Workforce per tenant

### QA-05 Middle Office Cleaning

| Worker | Type | Award | Classification | Notes |
|---|---|---|---|---|
| Olivia Office Admin | Full-time employee | MA000002 Clerks—Private Sector 2020 | Level 2 Year 1 | Monthly ordinary pay |
| Charlie Cleaner | Casual employee | MA000022 Cleaning Services 2020 | Level 1 | Weekday + Saturday + PH cleaning shifts |
| Delta IT Services Pty Ltd | Contractor supplier | — | — | No payroll |

### QA-06 Retail Hospitality

| Worker | Type | Award | Classification | Notes |
|---|---|---|---|---|
| Riley Retail Casual | Casual employee | MA000004 General Retail 2020 | Level 1 | Ordinary + evening + Saturday + Sunday |
| Priya Retail Supervisor | Full-time employee | MA000004 General Retail 2020 | Level 4 | Full-time + leave accrual |
| Hana Cafe Part-time | Part-time employee | MA000009 Hospitality 2020 | Level 2 | Pro-rata leave |
| Marco Hospitality Casual | Casual employee | MA000009 Hospitality 2020 | Level 2 | Ordinary + Saturday + PH |
| Peak Local Marketing Pty Ltd | Contractor supplier | — | — | No payroll |

### QA-07 Construction Professional Sales

| Worker | Type | Award | Classification | Notes |
|---|---|---|---|---|
| Ben Builder | Full-time employee | MA000020 Construction 2020 | CW/ECW 3 | RDO + tool/site/meal allowances |
| Amara Engineer | Annualised-wage employee | MA000065 Professional 2020 | Level 2 Experienced | Shadow-award reconciliation |
| Nina Sales Representative | Commission employee | MA000083 Commercial Sales 2020 | Commercial Traveller | Base + monthly commission |
| Grace High Income QA | HIG candidate | MA000065 Professional 2020 (comparator) | HIG comparator | All FWA HIG conditions must hold |
| Liam Surveying Contractors Pty Ltd | Contractor supplier | — | — | No payroll |

---

## Shared assumptions

| Area | Assumption |
|---|---|
| **Period** | FY2025/26 — `2025-07-01` → `2026-06-30` |
| **Timezone** | Australia/Melbourne |
| **GST** | Registered, quarterly BAS, accrual basis |
| **PAYG** | ATO Schedule 1 Scale 2 coefficient, resident, tax-free threshold claimed |
| **SG rate** | 12% (FY2025/26) |
| **Bank** | All three on QA Test Bank with sequential account numbers (`099999123451–3`); BSB `099-999` reserved for QA |
| **Customer/supplier ABNs** | All customers `11 111 111 111`; all suppliers `22 222 222 222`. **Algorithm-invalid by design** — flag for any future ABN-uniqueness validator |

---

## Loading

```bash
cd ledgius-db

# Step 1 — Register tenants + users + memberships in platform DB
make seed-load DATASET=qa-golden

# Step 2 — Create tenant DBs + run Flyway migrations + repeatable seeds
make provision-tenants
```

After load: `qa-admin@ledgius.com` / `qaqa1234` logs in with cross-tenant memberships; multi-tenant picker shows all three.

**Per-tenant transactional data:** see [the QA data loader README](https://github.com/ledgius/ledgius-api) (separate PR) once shipped. It uses the existing Xero file-import endpoint to push the `-draft/qa-XX/*/source_snapshot/import_files/*.csv` files into each provisioned tenant DB.

---

## Spec context (in-flight)

The fixtures reference several specs currently in pull-request review on `ledgius-specs`:

- **R-0073 / A-0046 / T-0041** — Payroll Authority Knowledge Pipeline (PR `ledgius-specs#37`) — defines per-award rule bundles, EmploymentPayArrangement, VariablePayPlan, PayrollException, DeterminationTrace, HighIncomeGuarantee, EBAComparator, DeductionAuthority. The PAY-AUTH-* requirement IDs cited in `KNOWN_ISSUES.md` files come from this spec set.
- **R-0074 / A-0047 / T-0042** — Tenant Database Provisioning Pipeline (PR `ledgius-specs#38`) — defines the assisted-create flow + the `tenant_assisted_create_log` audit trail + the `billing_mode` / `created_via` columns the QA tenants intend to exercise.

These specs are not yet on `ledgius-specs` master; the citations in this dataset are forward-references. When the specs merge, the inline links in `KNOWN_ISSUES.md` files should be updated to the merged spec URLs.

---

## Reviewer-acknowledged issues

The original PR (ledgius-db#36) review identified substantive correctness issues across the per-tenant CSVs:

- **Fixture bugs:** Hours×Rate≠Amount (rounding); MA000004/MA000022 penalty rates not traceable to FWC clauses (Riley evening 20% vs cl 15.6 +25%; Sunday casual 1.40 vs cl 18.4 175%); leave balances literal `fixture-cumulative` strings; GL trial balances don't balance for any tenant; QA-07 allowances incorrectly flagged OTE for super (over-states super by ~$650/yr per Ben).
- **Schema gaps:** `employee.award_code` / `classification` columns don't exist; QA-07 `employment_type` values violate `V1.08__payroll.sql` CHECK constraint; STP `IncomeType` long form vs schema enum codes; `business_profile.yaml` has 30+ fields with no platform-DB column.
- **Engine gaps:** `pkg/rules/bundles/payroll_v1.0.0.yaml` defines six formulas (PAYG / SG / gross / net / no_TFN); award penalty rates, casual loading, allowances, RDO, leave accrual, HIG, annualised-wage, STP Phase 2 classification — none have rules in the bundles yet. The fixtures are the **target output** the engine must produce once those rules ship.

Each tenant directory's `KNOWN_ISSUES.md` lists the specifics + a per-tenant promotion checklist. **Do not promote a directory out of `-draft/` until all checklist items pass.**

---

## Dataset versioning

Frozen against FY2025/26 ATO + FWC rate schedules. Future financial-year fixtures should be added as parallel datasets (`qa-golden-fy27`, etc.), not by mutating this one — historical pay-runs need to remain reproducible against the rate set in effect when they were posted.
