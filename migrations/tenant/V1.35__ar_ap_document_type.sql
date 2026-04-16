-- Spec references: R-0017 (IMP-PIP-026, §Domain Model Completeness), A-0017 (§Storage / Schema Changes).
--
-- V1.35 — ar / ap document_type column
--
-- Per R-0017 IMP-PIP-026, documents (invoices, bills, credit notes)
-- must be distinguished by an explicit `document_type` column rather
-- than inferred from boolean flags like `is_return`. "Give me all
-- credit notes for this tenant" should be a single WHERE clause
-- against a typed column, not a join-and-decode against `is_return`.
--
-- Strategy: add document_type with CHECK constraint on both ar and ap,
-- backfill from is_return at migration time, retain is_return for
-- backwards compatibility during transition. Follow-up work can
-- deprecate is_return once all readers have migrated to document_type.

-- =============================================================================
-- ar.document_type
-- =============================================================================

ALTER TABLE ar
    ADD COLUMN IF NOT EXISTS document_type TEXT NULL;

-- Backfill from is_return: credit_note when is_return = true, invoice otherwise.
-- Idempotent — only updates rows where document_type is still NULL.
UPDATE ar
   SET document_type = CASE WHEN is_return THEN 'credit_note' ELSE 'invoice' END
 WHERE document_type IS NULL;

-- Once backfilled, make NOT NULL so no new row can land without an
-- explicit type. Adds the CHECK constraint covering known document
-- types (invoice / credit_note for v1; future-expandable).
ALTER TABLE ar
    ALTER COLUMN document_type SET NOT NULL;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.constraint_column_usage
        WHERE table_name = 'ar' AND constraint_name = 'ar_document_type_check'
    ) THEN
        ALTER TABLE ar
            ADD CONSTRAINT ar_document_type_check
            CHECK (document_type IN ('invoice', 'credit_note'));
    END IF;
END $$;

COMMENT ON COLUMN ar.document_type IS
    'Explicit document type — ''invoice'' or ''credit_note''. Replaces implicit decoding via '
    'is_return (retained for backwards compatibility during transition). Per R-0017 IMP-PIP-026, '
    'queries for "all credit notes" shall be a single WHERE clause against this column, not a '
    'join-and-decode against is_return. Populated via backfill in V1.35 from is_return; all '
    'future rows must set it explicitly.';

-- =============================================================================
-- ap.document_type
-- =============================================================================

ALTER TABLE ap
    ADD COLUMN IF NOT EXISTS document_type TEXT NULL;

UPDATE ap
   SET document_type = CASE WHEN is_return THEN 'credit_note' ELSE 'invoice' END
 WHERE document_type IS NULL;

ALTER TABLE ap
    ALTER COLUMN document_type SET NOT NULL;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.constraint_column_usage
        WHERE table_name = 'ap' AND constraint_name = 'ap_document_type_check'
    ) THEN
        ALTER TABLE ap
            ADD CONSTRAINT ap_document_type_check
            CHECK (document_type IN ('invoice', 'credit_note'));
    END IF;
END $$;

COMMENT ON COLUMN ap.document_type IS
    'Explicit document type — ''invoice'' or ''credit_note''. Replaces implicit decoding via '
    'is_return (retained for backwards compatibility during transition). Per R-0017 IMP-PIP-026, '
    'queries for "all credit notes" shall be a single WHERE clause against this column, not a '
    'join-and-decode against is_return. Populated via backfill in V1.35 from is_return; all '
    'future rows must set it explicitly.';

-- =============================================================================
-- Indexes for the query patterns this column enables
-- =============================================================================
--
-- "List all credit notes for tenant" and "list all invoices for
-- tenant" become trivially-indexable queries. Combined with the
-- existing entity_credit_account index these support common drill-
-- downs on a tenant's AR/AP history.

CREATE INDEX IF NOT EXISTS idx_ar_document_type
    ON ar (document_type);

CREATE INDEX IF NOT EXISTS idx_ap_document_type
    ON ap (document_type);

COMMENT ON INDEX idx_ar_document_type IS
    'Supports "list all AR credit notes" / "list all AR invoices" queries without decoding '
    'is_return — per R-0017 IMP-PIP-026.';
COMMENT ON INDEX idx_ap_document_type IS
    'Supports "list all AP credit notes" / "list all AP invoices" queries without decoding '
    'is_return — per R-0017 IMP-PIP-026.';
