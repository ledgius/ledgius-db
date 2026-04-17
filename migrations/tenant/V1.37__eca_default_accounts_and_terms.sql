-- Spec references: R-0017 (§Domain Model Completeness), domain-model-gap-analysis.md (Contact entity).
--
-- V1.37 — entity_credit_account default accounts, tax codes, and payment terms type
--
-- The gap analysis (justified by J-IMP from MYOB AO + J-EXP from Xero)
-- identified five fields that both MYOB and Xero carry on every
-- customer/vendor but Ledgius had no column for:
--
--   1. default_sales_account_id    — default income account for this customer
--   2. default_purchase_account_id — default expense account for this vendor
--   3. default_sales_tax_code_id   — default tax code for sales to this customer
--   4. default_purchase_tax_code_id — default tax code for purchases from this vendor
--   5. payment_terms_type          — structured payment terms (MYOB's PaymentIsDue
--                                    enum: days after invoice, days after EOM, etc.)
--
-- All nullable. The existing `terms` INT column is retained as the N-days
-- value; payment_terms_type specifies the interpretation of that integer.

-- =============================================================================
-- 1. Default sales/purchase account FKs
-- =============================================================================

ALTER TABLE entity_credit_account
    ADD COLUMN IF NOT EXISTS default_sales_account_id INTEGER;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE table_name = 'entity_credit_account'
          AND constraint_name = 'eca_default_sales_account_fkey'
    ) THEN
        ALTER TABLE entity_credit_account
            ADD CONSTRAINT eca_default_sales_account_fkey
            FOREIGN KEY (default_sales_account_id) REFERENCES account(id) ON DELETE SET NULL;
    END IF;
END $$;

COMMENT ON COLUMN entity_credit_account.default_sales_account_id IS
    'Default income/revenue GL account for this customer. When creating an invoice for this '
    'contact, line items default to this account unless overridden. FK to account(id). '
    'J-IMP: MYOB SellingDetails.IncomeAccount; Xero SalesDetails.AccountCode. Nullable — '
    'not every contact has a default.';

ALTER TABLE entity_credit_account
    ADD COLUMN IF NOT EXISTS default_purchase_account_id INTEGER;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE table_name = 'entity_credit_account'
          AND constraint_name = 'eca_default_purchase_account_fkey'
    ) THEN
        ALTER TABLE entity_credit_account
            ADD CONSTRAINT eca_default_purchase_account_fkey
            FOREIGN KEY (default_purchase_account_id) REFERENCES account(id) ON DELETE SET NULL;
    END IF;
END $$;

COMMENT ON COLUMN entity_credit_account.default_purchase_account_id IS
    'Default expense GL account for this vendor. When creating a bill for this contact, '
    'line items default to this account unless overridden. FK to account(id). '
    'J-IMP: MYOB BuyingDetails.ExpenseAccount; Xero PurchasesDetails.AccountCode.';

-- =============================================================================
-- 2. Default sales/purchase tax code FKs
-- =============================================================================

ALTER TABLE entity_credit_account
    ADD COLUMN IF NOT EXISTS default_sales_tax_code_id INTEGER;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE table_name = 'entity_credit_account'
          AND constraint_name = 'eca_default_sales_tax_code_fkey'
    ) THEN
        ALTER TABLE entity_credit_account
            ADD CONSTRAINT eca_default_sales_tax_code_fkey
            FOREIGN KEY (default_sales_tax_code_id) REFERENCES tax_code(id) ON DELETE SET NULL;
    END IF;
END $$;

COMMENT ON COLUMN entity_credit_account.default_sales_tax_code_id IS
    'Default tax code for sales to this customer. Drives the default LineItem.TaxType on '
    'new invoices. FK to tax_code(id). J-IMP + J-EXP: MYOB SellingDetails.TaxCode; '
    'Xero SalesDetails.TaxType.';

ALTER TABLE entity_credit_account
    ADD COLUMN IF NOT EXISTS default_purchase_tax_code_id INTEGER;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE table_name = 'entity_credit_account'
          AND constraint_name = 'eca_default_purchase_tax_code_fkey'
    ) THEN
        ALTER TABLE entity_credit_account
            ADD CONSTRAINT eca_default_purchase_tax_code_fkey
            FOREIGN KEY (default_purchase_tax_code_id) REFERENCES tax_code(id) ON DELETE SET NULL;
    END IF;
END $$;

COMMENT ON COLUMN entity_credit_account.default_purchase_tax_code_id IS
    'Default tax code for purchases from this vendor. Drives the default LineItem.TaxType on '
    'new bills. FK to tax_code(id). J-IMP: MYOB BuyingDetails.TaxCode; '
    'Xero PurchasesDetails.TaxType.';

-- =============================================================================
-- 3. Structured payment terms type
-- =============================================================================
-- The existing `terms` INT column stores the N-days value. This new column
-- specifies how to interpret that integer — "30 days after invoice date"
-- vs "30 days after end of month" vs "day 15 of next month" etc.
-- When NULL, the legacy behaviour is preserved: terms = days after invoice date.

ALTER TABLE entity_credit_account
    ADD COLUMN IF NOT EXISTS payment_terms_type TEXT;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.constraint_column_usage
        WHERE table_name = 'entity_credit_account'
          AND constraint_name = 'eca_payment_terms_type_check'
    ) THEN
        ALTER TABLE entity_credit_account
            ADD CONSTRAINT eca_payment_terms_type_check
            CHECK (payment_terms_type IS NULL OR payment_terms_type IN (
                'days_after_invoice_date',
                'days_after_eom',
                'day_of_next_month',
                'immediate'
            ));
    END IF;
END $$;

COMMENT ON COLUMN entity_credit_account.payment_terms_type IS
    'How to interpret the `terms` integer: days_after_invoice_date (default when NULL), '
    'days_after_eom (N days after end of invoice month), day_of_next_month (day N of the '
    'following month), immediate (terms value ignored, due on invoice date). J-IMP: MYOB '
    'SellingDetails.Terms.PaymentIsDue / BuyingDetails.Terms.PaymentIsDue carry structured '
    'terms that a single integer cannot express. Example: "EOM + 30" = payment_terms_type='
    '''days_after_eom'', terms=30.';
