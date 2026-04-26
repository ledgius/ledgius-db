# QA-07 Construction Professional Sales QA Pty Ltd

Construction, professional engineering, and commercial sales context with salary/annualised wage, commission, allowances, and contractor supplier handling.

This QA tenant fixture contains accounting source data, bank transactions, payroll employees, expected pay runs, journal postings, GL balances, BAS summaries, STP summaries, and reconciliation checks.

All payroll bank withdrawals have matching journal postings. Net wages, PAYG remittance, and SG clearing-house payments are all represented as explicit bank rows and clearing journals so the payroll subledger, GL, and bank feed reconcile deterministically.

Period: FY2025/26 (01/07/2025 to 30/06/2026).
Timezone: Australia/Melbourne.
PAYG fixture method: ATO Schedule 1 Scale 2 coefficient formula, tax-free threshold claimed, no STSL/HELP, no Medicare variation.
Super fixture rate: 12%.
