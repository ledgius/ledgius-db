# Award provenance — QA-05 Middle Office Cleaning Pty Ltd

This fixture encodes pay rates derived from two FWC-published modern awards. All rates are FY2025/26 (effective 1 July 2025) per the most recent variation determinations.

## MA000002 — Clerks—Private Sector Award 2020

- **Source:** [Fair Work Commission — modern awards search](https://library.fairwork.gov.au/award/?krn=MA000002) · [PDF](https://www.fwc.gov.au/documents/modern_awards/pdf/ma000002.pdf)
- **Variation determination cited:** PR786xxx series (varied clauses 16, 17, 19 ppc 01Jul25 — exact reference is in the PDF's variation history)
- **Operative date for rates in this fixture:** 1 July 2025

### Minimum rates — clause 16.1, Table 3

| Classification | Weekly | Hourly |
|---|---|---|
| Level 2 — Year 1 | $1,068.40 | $28.12 |

### Casual loading — clause 11

> "An employer must pay a casual employee for each hour worked a loading of 25% on top of the minimum hourly rate otherwise applicable under clause 16—Minimum rates."

### Penalty rates — clause 24 (employees other than shiftworkers)

For employees who work outside ordinary hours but are NOT shiftworkers:
- **Saturday** (cl 24.2): 125% of minimum hourly rate
- **Sunday** (cl 24.3): 200% of minimum hourly rate
- **Public holiday** (cl 24.4): 250% of minimum hourly rate

Olivia Office Admin in this fixture works only Monday–Friday ordinary hours, so penalty rates are not exercised. Documented for reference.

### Derived rates used in this fixture

| Worker | Component | Calculation | Amount | AuthorityRefs |
|---|---|---|---|---|
| Olivia Office Admin (FT, monthly) | Ordinary | $28.12 (Table 3 minimum) × 164.67 hrs/month avg | $4,629.73 | `MA000002:cl.16.1-Table3-Level2-Year1-minimum-rate; FWA NES s87-93 paid leave` |

> **Note on amount calculation:** Olivia's Amount column is back-derived from `weekly_rate × 52 / 12 = $1,068.40 × 52 / 12 = $4,629.73` at full precision. Recomputing as `Hours × printed Rate = 164.67 × $28.12 = $4,630.51` produces a $0.78 discrepancy. This is a known fixture-wide pattern (`Hours × Rate ≠ Amount`) tracked in `KNOWN_ISSUES.md`.

---

## MA000022 — Cleaning Services Award 2020

- **Source:** [Fair Work Commission — modern awards search](https://library.fairwork.gov.au/award/?krn=MA000022) · [PDF](https://www.fwc.gov.au/documents/modern_awards/pdf/ma000022.pdf)
- **Variation determination cited:** **PR786560** (varied clauses 15, 17, 19, 20 ppc 01Jul25)
- **Operative date:** 1 July 2025

### Minimum rates — clause 15.1, Table 2

| Classification | Weekly | Hourly |
|---|---|---|
| Cleaning Services Employee Level 1 | $982.20 | $25.85 |

### Casual loading — clause 11.2

> "An employer must pay a casual employee a loading of 25% in addition to the minimum hourly rate specified in column 3 of Table 2—Minimum rates."

### Penalty rates — clause 20.2, Table 7

The casual penalty column is **"% of minimum hourly rate (inclusive of casual loading)"** — the percentage REPLACES the casual loading rather than stacking. Same construction as MA000004 / MA000009 but with cleaning-specific period definitions.

| Period or day | FT (col 2) | PT (col 3, incl PT allowance) | Casual (col 4, incl loading) |
|---|---|---|---|
| Mon–Fri shift starts before 6am or finishes after 6pm | 115% | 130% | 140% |
| After-midnight shift not rotating | 130% | 130% | 155% |
| Mon midnight to midnight Sat | 150% | 165% | 175% |
| Mon midnight Sat to midnight Sun | 200% | 215% | 225% |
| Public holiday | 250% | 265% | 275% |

### Derived rates used in this fixture (Cleaning Services Employee Level 1 casual, $25.85 minimum)

| Component | Calculation | Amount | AuthorityRefs |
|---|---|---|---|
| Casual weekday cleaning | $25.85 × 1.25 | $32.31 | `MA000022:cl.15.1-Table2-Level1-min; cl.11.2-casual-loading-25%` |
| Casual Saturday cleaning | $25.85 × 1.75 | $45.24 | `MA000022:cl.20.2-Table7-Saturday-casual-175%-of-min-incl-loading` |
| Casual public holiday cleaning | $25.85 × 2.75 | $71.09 | `MA000022:cl.20.2-Table7-Public-holiday-casual-275%-of-min-incl-loading` |

---

## Verification record

The penalty-rate dollar values in the original v1 fixture were checked against the live FWC PDFs on 2026-04-26:
- `MA000022` Table 7 column 4 confirms the casual basis as **% of minimum (inclusive of casual loading)**. Fixture values $32.31 / $45.24 / $71.09 are correct.
- `MA000002` Level 2 Year 1 hourly rate $28.12 confirmed against Table 3 (effective 1 July 2025).
- Olivia's Amount has the fixture-wide `Hours × Rate ≠ Amount` rounding (back-derived from weekly), tracked in `KNOWN_ISSUES.md`.

## NES references used

- **Annual leave**: Fair Work Act s87 — 4 weeks per year (Olivia full-time; Charlie casual no accrual per s86)
- **Personal/carer's leave**: Fair Work Act s95–96 — 10 days per year for FT (Olivia)
- **Public holidays**: Fair Work Act s115 — Charlie's PH penalty rate is per MA000022 cl 20.2; entitlement to PH off if not rostered is per s116
- Casuals do not accrue paid leave per s86 (annual leave) and s95 (personal leave) — Charlie no accruals
