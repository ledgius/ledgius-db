-- Spec references: A-0048 (Money Handling §3.2, §3.3).
--
-- Add explicit precision to all bare NUMERIC columns that hold
-- monetary amounts, rates, hours, quantities, or distances.
-- PostgreSQL bare NUMERIC allows unlimited precision which can
-- cause inconsistent rounding and violates A-0048.
--
-- Categories:
--   NUMERIC(19,4)  — monetary amounts (supports up to $999 trillion with 4dp)
--   NUMERIC(19,6)  — rates/coefficients (hourly rates, tax multipliers)
--   NUMERIC(9,4)   — hours/time quantities
--   NUMERIC(12,2)  — distances (km), odometer readings
--   NUMERIC(5,2)   — percentages (0.00 – 100.00)
--   NUMERIC(9,2)   — ATO cents-per-km rates

-- ══════════════════════════════════════════════════════════════════════
-- bank_transaction (V1.01)
-- ══════════════════════════════════════════════════════════════════════

ALTER TABLE bank_transaction
  ALTER COLUMN amount TYPE NUMERIC(19,4),
  ALTER COLUMN balance TYPE NUMERIC(19,4);

-- ══════════════════════════════════════════════════════════════════════
-- product (V1.06)
-- ══════════════════════════════════════════════════════════════════════

ALTER TABLE product
  ALTER COLUMN sell_price TYPE NUMERIC(19,4),
  ALTER COLUMN buy_price TYPE NUMERIC(19,4);

-- ══════════════════════════════════════════════════════════════════════
-- payroll tables (V1.08)
-- ══════════════════════════════════════════════════════════════════════

ALTER TABLE pay_rate
  ALTER COLUMN base_rate TYPE NUMERIC(19,6),
  ALTER COLUMN overtime_rate TYPE NUMERIC(19,6);

ALTER TABLE leave_balance
  ALTER COLUMN balance_hours TYPE NUMERIC(9,4),
  ALTER COLUMN accrued_hours TYPE NUMERIC(9,4),
  ALTER COLUMN taken_hours TYPE NUMERIC(9,4);

ALTER TABLE pay_run
  ALTER COLUMN total_gross TYPE NUMERIC(19,4),
  ALTER COLUMN total_tax TYPE NUMERIC(19,4),
  ALTER COLUMN total_super TYPE NUMERIC(19,4),
  ALTER COLUMN total_net TYPE NUMERIC(19,4);

ALTER TABLE pay_run_line
  ALTER COLUMN hours_worked TYPE NUMERIC(9,4),
  ALTER COLUMN gross_pay TYPE NUMERIC(19,4),
  ALTER COLUMN tax_withheld TYPE NUMERIC(19,4),
  ALTER COLUMN super_amount TYPE NUMERIC(19,4),
  ALTER COLUMN net_pay TYPE NUMERIC(19,4);

ALTER TABLE payg_tax_bracket
  ALTER COLUMN weekly_from TYPE NUMERIC(19,4),
  ALTER COLUMN weekly_to TYPE NUMERIC(19,4);

ALTER TABLE super_guarantee_rate
  ALTER COLUMN max_quarterly_base TYPE NUMERIC(19,4);

-- ══════════════════════════════════════════════════════════════════════
-- import staging (V1.12)
-- ══════════════════════════════════════════════════════════════════════

ALTER TABLE import_batch_migration
  ALTER COLUMN source_debit_total TYPE NUMERIC(19,4),
  ALTER COLUMN source_credit_total TYPE NUMERIC(19,4),
  ALTER COLUMN target_debit_total TYPE NUMERIC(19,4),
  ALTER COLUMN target_credit_total TYPE NUMERIC(19,4);

ALTER TABLE import_staging_transaction
  ALTER COLUMN amount TYPE NUMERIC(19,4),
  ALTER COLUMN tax_amount TYPE NUMERIC(19,4);

ALTER TABLE import_staging_tax_code
  ALTER COLUMN source_rate TYPE NUMERIC(19,6);

-- ══════════════════════════════════════════════════════════════════════
-- reconciliation (V1.20)
-- ══════════════════════════════════════════════════════════════════════

ALTER TABLE reconciliation_exception
  ALTER COLUMN materiality_amount TYPE NUMERIC(19,4);

ALTER TABLE reconciliation_period
  ALTER COLUMN statement_opening TYPE NUMERIC(19,4),
  ALTER COLUMN statement_closing TYPE NUMERIC(19,4),
  ALTER COLUMN reconciled_amount TYPE NUMERIC(19,4),
  ALTER COLUMN unreconciled_amount TYPE NUMERIC(19,4);

-- ══════════════════════════════════════════════════════════════════════
-- quotes (V1.21)
-- ══════════════════════════════════════════════════════════════════════

ALTER TABLE quote
  ALTER COLUMN subtotal TYPE NUMERIC(19,4),
  ALTER COLUMN tax_total TYPE NUMERIC(19,4),
  ALTER COLUMN total TYPE NUMERIC(19,4);

ALTER TABLE quote_line
  ALTER COLUMN quantity TYPE NUMERIC(19,4),
  ALTER COLUMN unit_price TYPE NUMERIC(19,4),
  ALTER COLUMN line_total TYPE NUMERIC(19,4);

-- ══════════════════════════════════════════════════════════════════════
-- captured receipts (V1.22)
-- ══════════════════════════════════════════════════════════════════════

ALTER TABLE captured_receipt
  ALTER COLUMN ocr_amount TYPE NUMERIC(19,4),
  ALTER COLUMN amount TYPE NUMERIC(19,4);

-- ══════════════════════════════════════════════════════════════════════
-- vehicle mileage (V1.24)
-- ══════════════════════════════════════════════════════════════════════

ALTER TABLE vehicle
  ALTER COLUMN current_odometer TYPE NUMERIC(12,2);

ALTER TABLE logbook_period
  ALTER COLUMN total_business_km TYPE NUMERIC(12,2),
  ALTER COLUMN total_personal_km TYPE NUMERIC(12,2),
  ALTER COLUMN total_km TYPE NUMERIC(12,2),
  ALTER COLUMN business_use_pct TYPE NUMERIC(5,2);

ALTER TABLE trip_log
  ALTER COLUMN start_odometer TYPE NUMERIC(12,2),
  ALTER COLUMN end_odometer TYPE NUMERIC(12,2),
  ALTER COLUMN distance_km TYPE NUMERIC(12,2);

ALTER TABLE fuel_log
  ALTER COLUMN litres TYPE NUMERIC(9,4),
  ALTER COLUMN cost TYPE NUMERIC(19,4),
  ALTER COLUMN odometer_reading TYPE NUMERIC(12,2);

ALTER TABLE mileage_rate
  ALTER COLUMN cents_per_km TYPE NUMERIC(9,2);

-- ══════════════════════════════════════════════════════════════════════
-- payment links (V1.25)
-- ══════════════════════════════════════════════════════════════════════

ALTER TABLE payment_link
  ALTER COLUMN amount TYPE NUMERIC(19,4);

-- ══════════════════════════════════════════════════════════════════════
-- STP Phase 2 YTD (V1.28)
-- ══════════════════════════════════════════════════════════════════════

ALTER TABLE employee_ytd
  ALTER COLUMN gross_ytd TYPE NUMERIC(19,4),
  ALTER COLUMN salary_wages_ytd TYPE NUMERIC(19,4),
  ALTER COLUMN overtime_ytd TYPE NUMERIC(19,4),
  ALTER COLUMN bonus_ytd TYPE NUMERIC(19,4),
  ALTER COLUMN payg_withheld_ytd TYPE NUMERIC(19,4),
  ALTER COLUMN super_guarantee_ytd TYPE NUMERIC(19,4),
  ALTER COLUMN salary_sacrifice_ytd TYPE NUMERIC(19,4);

-- ══════════════════════════════════════════════════════════════════════
-- import staging account (V1.36)
-- ══════════════════════════════════════════════════════════════════════

ALTER TABLE import_staging_account
  ALTER COLUMN opening_balance TYPE NUMERIC(19,4);

-- ══════════════════════════════════════════════════════════════════════
-- reconciliation allocation (V1.41)
-- ══════════════════════════════════════════════════════════════════════

ALTER TABLE recon_allocation
  ALTER COLUMN total_amount TYPE NUMERIC(19,4);

ALTER TABLE recon_allocation_line
  ALTER COLUMN amount TYPE NUMERIC(19,4);

-- ══════════════════════════════════════════════════════════════════════
-- Xero import staging documents (V1.50)
-- ══════════════════════════════════════════════════════════════════════

ALTER TABLE import_staging_invoice
  ALTER COLUMN source_quantity TYPE NUMERIC(19,4),
  ALTER COLUMN source_unit_amount TYPE NUMERIC(19,4);

ALTER TABLE import_staging_bill
  ALTER COLUMN source_quantity TYPE NUMERIC(19,4),
  ALTER COLUMN source_unit_amount TYPE NUMERIC(19,4);

ALTER TABLE import_staging_credit_note
  ALTER COLUMN source_quantity TYPE NUMERIC(19,4),
  ALTER COLUMN source_unit_amount TYPE NUMERIC(19,4);
