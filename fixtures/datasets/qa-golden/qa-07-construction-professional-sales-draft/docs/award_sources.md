# Award provenance — QA-07 Construction Professional Sales Pty Ltd

This fixture encodes pay rates derived from three FWC-published modern awards. All rates are FY2025/26 (effective 1 July 2025) per the most recent variation determinations.

## MA000020 — Building and Construction General On-site Award 2020

- **Source:** [Fair Work Commission — modern awards search](https://library.fairwork.gov.au/award/?krn=MA000020) · [PDF](https://www.fwc.gov.au/documents/modern_awards/pdf/ma000020.pdf)
- **Variation determinations cited:** **PR786558** (cl 19, 22, 23 minimum rates + industry allowance) and **PR786723** (cl 21 tools + protective + meal allowances), both ppc 01Jul25
- **Operative date:** 1 July 2025

### Minimum rates — clause 19.1, Table 5

| Classification | Weekly | Hourly |
|---|---|---|
| Level 3 (CW/ECW 3) | $1,068.40 | $28.12 |

### Industry allowance — clause 22.1(a) + cl 22.3 (for all purposes)

> "General building and construction industry, civil construction industry and metal and engineering construction industry — an allowance of $64.10 per week" (cl 22.1(a))
> "The industry allowances payable under clause 22 are to be paid for all purposes of the award." (cl 22.3)

**OTE classification:** Industry allowance is "for all purposes" → forms part of `ordinary hourly rate` per cl 4 → **IS OTE** for super per ATO SGR 2009/2 ¶24-25 (allowances forming part of ordinary time pay are within OTE).

### Tool allowance — clause 21.1(a) (for all purposes)

> "An allowance in recognition of the maintenance and provision of the standard tools of trade must be paid for all purposes of the award..." (cl 21.1(a))

For carpenter/joiner/etc. classifications: **$39.60/week**.

**OTE classification:** Same logic as industry allowance — tool allowance is "for all purposes" → part of ordinary hourly rate → **IS OTE**.

### Overtime meal allowance — clause 21.2(a) (NOT for all purposes)

> "An employee required to work overtime for at least 1.5 hours after working ordinary hours...must be paid by the employer an amount of $19.00 to meet the cost of a meal."

**OTE classification:** Paid as **expense reimbursement** "to meet the cost of a meal" — not designated "for all purposes". Per ATO SGR 2009/2 ¶28(a), expense allowances are NOT OTE. The fixture's previous `OTEForSuper=TRUE` was wrong; corrected to FALSE in the 2026-04-26 cascade.

### Casual loading — clause 11.5(a)

25% loading on top of minimum hourly rate.

### Penalty rates — clause 33

Substantial table covering Saturday / Sunday / public holiday / overtime under varying conditions (project, daily-hire, weekly-hire structures). Ben Builder works ordinary Mon–Fri so penalty rates aren't exercised in this fixture; documented for reference.

### Derived rates used in this fixture (Ben Builder, CW/ECW 3 full-time, $28.12 minimum)

| Component | Calculation | Amount | OTE | AuthorityRefs |
|---|---|---|---|---|
| Ordinary | $28.12 × 38h | $1,068.40 | TRUE | `MA000020:cl.19.1-Table5-Level3-CW-ECW3-minimum-rate` |
| Industry allowance | flat $64.10/wk | $64.10 | **TRUE** | `MA000020:cl.22.1(a)-industry-allowance-$64.10/wk; cl.22.3-for-all-purposes-(OTE per ATO SGR 2009/2)` |
| Tool allowance | flat $39.60/wk | $39.60 | **TRUE** | `MA000020:cl.21.1(a)-tool-allowance-carpenter-$39.60/wk-for-all-purposes-(OTE per ATO SGR 2009/2)` |
| Overtime meal allowance (when applicable) | flat $19.00/occurrence | $19.00 | **FALSE** | `MA000020:cl.21.2(a)-meal-allowance-$19.00-expense-reimbursement-(NOT OTE per ATO SGR 2009/2 paragraph 28)` |

> **Note on the original review's claim:** PR ledgius-db#36 review asserted that industry + tool allowances are "generally not OTE per ATO SGR 2009/2". The actual ATO position depends on the award's structure. MA000020's explicit "for all purposes" designation for both allowances means they form part of ordinary hourly rate per the award's cl 4 definition, and therefore ARE within OTE per ATO SGR 2009/2 ¶24-25. The fixture's `OTEForSuper=TRUE` for these is correct. The reviewer's claim DID hold for the overtime meal allowance — that one is correctly fixed to FALSE.

---

## MA000065 — Professional Employees Award 2020

- **Source:** [Fair Work Commission](https://library.fairwork.gov.au/award/?krn=MA000065) · [PDF](https://www.fwc.gov.au/documents/modern_awards/pdf/ma000065.pdf)
- **Operative date:** 1 July 2025

### Minimum rates — clause 14.1, Table 2

This award uses **annual** minimum wages (not weekly), reflecting that professional employees commonly work on annualised salaries.

| Classification | Annual minimum |
|---|---|
| Level 2 — Experienced professional / quality auditor / experienced medical research employee | $75,261 |

Hourly rate: $75,261 × 6/313 / 38 = $37.97 (per cl 14.2 formula).

### Annualised wage arrangement — clause 17

> "An employer and an employee may enter into an annualised wage arrangement..." (cl 17.1)

Subject to: written record of included entitlements, outer-limit hours per pay period, reconciliation cadence, top-up if shadow-award calc exceeds salary in any reconciliation period.

### Derived rates used in this fixture

| Worker | Type | Calculation | Amount | OTE | AuthorityRefs |
|---|---|---|---|---|---|
| Amara Engineer | Annualised wage (above-award $90,000/yr) | $1,730.77/wk | $1,730.77 | TRUE | `MA000065:cl.14.1-Table2-Level2-Experienced-min-$75,261/yr-($37.97/hr); cl.17-annualised-wage-arrangement-($90,000/yr-above-award)` |
| Grace HIG candidate | High-income guarantee at $180,000/yr | $3,461.54/wk | $3,461.54 | TRUE | `MA000065:cl.14.1-Table2-Level2-Experienced-comparator; FWA s328-330-high-income-guarantee` |

> **Important note on Grace's HIG status:** Grace's fixture salary is **$180,000/yr**, but the FY2025/26 high-income threshold (FWA s333) is **$183,100**. As written, Grace **fails to qualify for HIG status** for FY2025/26 — her guarantee is below the threshold. Either:
> - Grace's guarantee should be increased to $183,100+ (or $190,000 to comfortably exceed it)
> - Or Grace's fixture status should be marked "HIG-attempted-but-fails-threshold-qualification"
>
> Tracked in `KNOWN_ISSUES.md`. The PAY-AUTH-055 spec (R-0073, in flight on ledgius-specs#37) requires ALL of the following to hold for HIG to be recognised: modern-award covered, no EBA, valid written guarantee with retained acceptance evidence, **guaranteed earnings exceed the applicable high-income threshold**. Grace fails the last condition as currently fixtured.

---

## MA000083 — Commercial Sales Award 2020

- **Source:** [Fair Work Commission](https://library.fairwork.gov.au/award/?krn=MA000083) · [PDF](https://www.fwc.gov.au/documents/modern_awards/pdf/ma000083.pdf)
- **Variation determination cited:** **PR795708** series (clause 15 minimum rates + clause 20 commission, ppc 01Jul25)
- **Operative date:** 1 July 2025

### Minimum rates — clause 15.1, Table 5

| Classification | Weekly | Hourly |
|---|---|---|
| Commercial Traveller / Advertising Sales Representative | $1,071.90 | $28.21 |

### Commission/incentive — clause 20

Commission/incentive payments are addressable per individual arrangements between employer and employee, in addition to the minimum award wage. ATO classification for PAYG/SG/STP follows NAT 3348 Schedule 5 (additional payments + bonuses + commissions): typically OTE because paid for ordinary-hour work performance.

### Derived rates used in this fixture (Nina Sales)

| Component | Calculation | Amount | OTE | AuthorityRefs |
|---|---|---|---|---|
| Ordinary | $28.21 × 38h | $1,071.90 | TRUE | `MA000083:cl.15.1-Table5-Commercial-Traveller-min-rate-$1071.90/wk-$28.21/hr` |
| Monthly commission | flat $1,200/month | $1,200.00 | TRUE | `MA000083:cl.20-commission/incentive-payments; ATO-NAT-3348-schedule-5-additional-payments-classification-required` |

---

## Verification record

The penalty + allowance values in the original v1 fixture were checked against the live FWC PDFs on 2026-04-26:
- **MA000020 Level 3 (CW/ECW 3) hourly rate $28.12 ✓** matches Table 5 (PR786558)
- **MA000020 industry allowance $64.10/wk ✓** matches cl 22.1(a)
- **MA000020 tool allowance $39.60/wk ✓** matches cl 21.1(a) for carpenter classification
- **MA000020 industry + tool allowance OTE=TRUE ✓** correct per cl 22.3 + cl 21.1(a) "for all purposes" + ATO SGR 2009/2 ¶24-25 (the original PR review was wrong on this)
- **MA000020 overtime meal allowance OTE=FALSE ✓** corrected from TRUE; cl 21.2(a) is expense reimbursement per ATO SGR 2009/2 ¶28
- **MA000065 Level 2 Experienced annual minimum $75,261 / $37.97/hr ✓** matches Table 2; Amara's $90,000 is above-award annualised wage (cl 17)
- **MA000065 Grace HIG $180,000/yr fails FY2025/26 threshold $183,100** — fixture-side bug, see KNOWN_ISSUES
- **MA000083 Commercial Traveller $1,071.90 / $28.21 ✓** matches Table 5

## NES references used

- **Annual leave**: Fair Work Act s87 — 4 weeks per year (Ben + Amara + Nina + Grace full-time)
- **Personal/carer's leave**: Fair Work Act s95-96 — 10 days per year for FT
- **Public holidays**: Fair Work Act s115
- **High-income guarantee**: Fair Work Act s328-330 (threshold) + s47 (notice that award doesn't apply)
- Contractors (Liam Surveying) per s12 + s86 — not employees; no leave accrual, no STP employee event
