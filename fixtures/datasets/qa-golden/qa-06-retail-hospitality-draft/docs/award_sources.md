# Award provenance — QA-06 Retail Hospitality Pty Ltd

This fixture encodes pay rates derived from two FWC-published modern awards. All rates are FY2025/26 (effective 1 July 2025) per the most recent variation determinations.

## MA000004 — General Retail Industry Award 2020

- **Source:** [Fair Work Commission — modern awards search](https://library.fairwork.gov.au/award/?krn=MA000004) · [PDF](https://www.fwc.gov.au/documents/modern_awards/pdf/ma000004.pdf)
- **Variation determination cited:** **PR786542** (varied clause 17.1 + clause 22.1 ppc 01Jul25)
- **Operative date for rates in this fixture:** 1 July 2025

### Minimum rates — clause 17.1, Table 4

| Classification | Weekly | Hourly |
|---|---|---|
| Retail Employee Level 1 | $1,008.90 | $26.55 |
| Retail Employee Level 4 | $1,068.40 | $28.12 |

### Casual loading — clause 11.1

> "An employer must pay a casual employee for each hour worked a loading of 25% on top of the minimum hourly rate otherwise applicable under clause 17—Minimum rates."

### Penalty rates — clause 22.1, Table 12

The casual penalty column is expressed as **"% of minimum hourly rate (inclusive of casual loading)"** — the percentage REPLACES the casual loading rather than stacking on top.

| Time of ordinary hours worked | FT/PT (% of min) | Casual (% of min, incl. loading) |
|---|---|---|
| Monday to Friday — after 6.00 pm | 125% | 150% |
| Saturday — all ordinary hours | 125% | 150% |
| Sunday — all ordinary hours | 150% | 175% |
| Public holiday — all ordinary hours | 225% | 250% |

### Derived rates used in this fixture (Retail Employee Level 1 casual, $26.55 minimum)

| Component | Calculation | Amount | AuthorityRefs |
|---|---|---|---|
| Casual ordinary | $26.55 × 1.25 | $33.19 | `MA000004:cl.17.1-Table4-Level1-min; cl.11.1-casual-loading-25%` |
| Casual evening (after 6pm) | $26.55 × 1.50 | $39.83 | `MA000004:cl.22.1-Table12-Mon-Fri-after-6pm-casual-150%-of-min-incl-loading` |
| Casual Saturday | $26.55 × 1.50 | $39.83 | `MA000004:cl.22.1-Table12-Saturday-casual-150%-of-min-incl-loading` |
| Casual Sunday | $26.55 × 1.75 | $46.46 | `MA000004:cl.22.1-Table12-Sunday-casual-175%-of-min-incl-loading` |

### Retail Employee Level 4 — full-time/part-time (Priya Retail Supervisor)

| Component | Calculation | Amount | AuthorityRefs |
|---|---|---|---|
| Ordinary | $28.12 (Table 4 minimum) | $28.12 | `MA000004:cl.17.1-Table4-Level4-minimum-rate; FWA NES s87-93 paid leave` |

> **Note:** the original v1 fixture had Priya at $31.64/hr — that did not match Table 4. Corrected to $28.12 in the cascade (commit referenced from PR ledgius-db#36).

---

## MA000009 — Hospitality Industry (General) Award 2020

- **Source:** [Fair Work Commission — modern awards search](https://library.fairwork.gov.au/award/?krn=MA000009) · [PDF](https://www.fwc.gov.au/documents/modern_awards/pdf/ma000009.pdf)
- **Variation determination cited:** **PR786547** (varied clause 18 + clause 29.2 ppc 01Jul25)
- **Operative date:** 1 July 2025

### Minimum rates — clause 18, Table 3

| Classification | Weekly | Hourly |
|---|---|---|
| Level 2 (food + beverage attendant grade 2; cook grade 1; etc.) | $982.30 | $25.85 |

### Casual loading — clause 11.2

> "An employer must pay a casual employee for each hour worked a loading of 25% in addition to the ordinary hourly rate."

### Penalty rates — clause 29.2, Table 14

The casual penalty column is expressed as **"% of ordinary hourly rate (inclusive of casual loading)"** — same construction as MA000004.

| Time of ordinary hours worked | FT/PT (% of ord) | Casual (% of ord, incl. loading) |
|---|---|---|
| Mon–Fri 7am–7pm | 100% | 125% |
| Mon–Fri 7pm–midnight | 100% + $2.81/hr | 125% + $2.81/hr |
| Mon–Fri midnight–7am | 100% + $4.22/hr | 125% + $4.22/hr |
| Saturday | 125% | 150% |
| Sunday | 150% | 175% |
| Public holiday | 225% | 250% |

### Derived rates used in this fixture (Level 2)

| Component | Worker | Calculation | Amount | AuthorityRefs |
|---|---|---|---|---|
| Part-time ordinary | Hana | $25.85 (Table 3) | $25.85 | `MA000009:cl.18-Table3-Level2-minimum-rate; FWA NES s87-93 paid leave (pro-rata)` |
| Casual ordinary | Marco | $25.85 × 1.25 | $32.31 | `MA000009:cl.18-Table3-Level2-min; cl.11.2-casual-loading-25%` |
| Casual Saturday | Marco | $25.85 × 1.50 | $38.78 | `MA000009:cl.29.2-Table14-Saturday-casual-150%-of-ordinary-incl-loading` |
| Casual public holiday | Marco | $25.85 × 2.50 | $64.63 | `MA000009:cl.29.2-Table14-Public-holiday-casual-250%-of-ordinary-incl-loading` |

---

## Verification record

The penalty-rate dollar values in the original v1 fixture were checked against the live FWC PDFs on 2026-04-26:
- `MA000004` Table 12 column 3 confirms **% of minimum (inclusive of casual loading)** as the casual basis — fixture's $33.19 / $39.83 / $46.46 values are correct against this construction.
- `MA000009` Table 14 column 3 confirms the same construction — fixture's $32.31 / $38.78 / $64.63 values are correct.
- The earlier reviewer's claim that "Sunday should be casual_rate × 1.75" or "evening should be casual_rate × 1.25" was based on a misreading of the table; the percentages multiply the **minimum** (not the casual rate).
- The only rate-correctness issue identified was Priya's Level 4 hourly at $31.64 (should be $28.12 per Table 4); fixed in this commit.

## NES references used

- **Annual leave**: Fair Work Act s87 — 4 weeks per year (5 weeks for shiftworkers)
- **Personal/carer's leave**: Fair Work Act s95-96 — 10 days per year, accrues progressively
- **Public holidays**: Fair Work Act s115 — 8 national + state-specific
- Pro-rata for part-time per s87(2) (annual leave) and s96(2) (personal leave) — Hana's accruals
- Casuals do not accrue paid leave per s86 (annual leave) and s95 (personal leave) — Riley/Marco no accruals
