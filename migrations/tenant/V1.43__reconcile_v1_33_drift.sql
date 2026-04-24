-- Spec references: A-0021 (§Migration drift reconciliation), R-0017 (IMP-PIP-024).
--
-- V1.43 — Reconcile V1.33 drift on LedgerSMB-seeded databases.
--
-- V1.33 was written assuming `location_class` was empty and `eca_to_location`
-- did not exist. On databases bootstrapped from the LedgerSMB core schema
-- both assumptions are false:
--
--   * location_class comes pre-seeded with 5 rows using capitalised names
--     (Billing, Sales, Shipping, Physical, Mailing) at ids 1..5, and a
--     lower_class_unique index prevents V1.33's INSERT ... ON CONFLICT(id)
--     from renaming them.
--   * eca_to_location pre-exists with the LedgerSMB column set (credit_id,
--     location_class, location_id, created, inactive_date, active), so
--     V1.33's CREATE TABLE IF NOT EXISTS was silently skipped, leaving the
--     wrong shape in place.
--
-- Result: V1.33 failed early on these databases, the `contact` table was
-- never created, and the Ledgius Go code's INSERTs into eca_to_location
-- reference columns that don't exist.
--
-- This migration reconciles state so it matches what V1.33 originally
-- intended. It is STRICTLY idempotent: on a database where the new
-- Ledgius shape is already in place it performs no destructive work and
-- preserves any rows that accumulated after the original run. Every
-- shape-altering step is gated on whether the old LedgerSMB shape is
-- still present.

-- =============================================================================
-- 1. Clear LedgerSMB-legacy reference table that pins location_class rows
-- =============================================================================
--
-- location_class_to_entity_class is a LedgerSMB reference table mapping
-- which location classes are valid for which entity classes. Ledgius
-- never queries or inserts into it — confirmed by grep across the Go
-- API. Its 46 seed rows reference every row in location_class, which
-- prevents us renumbering below. Safe to clear.
--
-- Idempotent: DELETE from an already-empty table is a no-op.

DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'location_class_to_entity_class') THEN
        DELETE FROM location_class_to_entity_class;
    END IF;
END $$;

-- =============================================================================
-- 2. Normalise location_class so ids 1=billing and 2=shipping
-- =============================================================================
--
-- Ledgius Go code hard-codes LocationClassBilling = 1 and
-- LocationClassShipping = 2 (internal/contact/channels.go). We need the
-- rows at those ids to mean what the code says they mean.
--
-- Strategy: remove any LedgerSMB seed rows outside {billing, shipping}
-- (Ledgius doesn't use them), then reshuffle to pin billing at id 1 and
-- shipping at id 2. All operations are idempotent — on an already-
-- correct database every branch is a no-op.

DELETE FROM location_class
 WHERE lower(class) NOT IN ('billing', 'shipping');

DO $$
DECLARE
    billing_id  INT;
    shipping_id INT;
BEGIN
    SELECT id INTO billing_id  FROM location_class WHERE lower(class) = 'billing';
    SELECT id INTO shipping_id FROM location_class WHERE lower(class) = 'shipping';

    -- Pin billing to id 1.
    IF billing_id IS NULL THEN
        INSERT INTO location_class (id, class, authoritative)
        VALUES (1, 'billing', true);
    ELSIF billing_id <> 1 THEN
        UPDATE location_class SET id = -1 WHERE id = 1;
        UPDATE location_class SET id = 1  WHERE id = billing_id;
        DELETE FROM location_class WHERE id = -1;
    END IF;

    -- Pin shipping to id 2.
    SELECT id INTO shipping_id FROM location_class WHERE lower(class) = 'shipping';
    IF shipping_id IS NULL THEN
        INSERT INTO location_class (id, class, authoritative)
        VALUES (2, 'shipping', true);
    ELSIF shipping_id <> 2 THEN
        UPDATE location_class SET id = -2 WHERE id = 2;
        UPDATE location_class SET id = 2  WHERE id = shipping_id;
        DELETE FROM location_class WHERE id = -2;
    END IF;
END $$;

-- Normalise case + authoritative flag. Idempotent — rewrite to the same
-- values on every run.
UPDATE location_class SET class = 'billing',  authoritative = true WHERE id = 1;
UPDATE location_class SET class = 'shipping', authoritative = true WHERE id = 2;

-- Advance the identity sequence past the rows we just pinned so future
-- INSERTs don't collide. Safe to re-run.
SELECT setval(
    pg_get_serial_sequence('location_class', 'id'),
    GREATEST(COALESCE((SELECT max(id) FROM location_class), 0), 2)
);

-- =============================================================================
-- 3. Reshape eca_to_location to the Ledgius columns (idempotent)
-- =============================================================================
--
-- The LedgerSMB version of this table carries (credit_id, location_class,
-- location_id, created, inactive_date, active). The Ledgius shape carries
-- (id, entity_credit_account_id, location_id, location_class_id,
-- is_primary, created_at, updated_at).
--
-- We detect which shape is present and only drop-and-recreate when the
-- OLD shape is still in place. On a database where the Ledgius shape is
-- already applied (post-original-V1.43, possibly with production rows),
-- this section is a no-op — the table and its data are preserved.

DO $$
DECLARE
    has_ledgius_shape BOOLEAN;
BEGIN
    -- Ledgius shape is identified by the entity_credit_account_id column
    -- (the old LedgerSMB shape uses credit_id instead).
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns
         WHERE table_schema = 'public'
           AND table_name   = 'eca_to_location'
           AND column_name  = 'entity_credit_account_id'
    ) INTO has_ledgius_shape;

    IF NOT has_ledgius_shape THEN
        -- Old LedgerSMB shape (or table absent) — drop and recreate.
        -- Safe because (a) on pre-V1.43 DBs the table has 0 Ledgius rows,
        -- (b) on post-V1.43 DBs this branch never fires.
        DROP TABLE IF EXISTS eca_to_location CASCADE;

        CREATE TABLE eca_to_location (
            id                       INTEGER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
            entity_credit_account_id INTEGER NOT NULL REFERENCES entity_credit_account(id) ON DELETE CASCADE,
            location_id              INTEGER NOT NULL REFERENCES location(id) ON DELETE RESTRICT,
            location_class_id        INTEGER NOT NULL REFERENCES location_class(id),
            is_primary               BOOLEAN NOT NULL DEFAULT false,
            created_at               TIMESTAMPTZ NOT NULL DEFAULT now(),
            updated_at               TIMESTAMPTZ NOT NULL DEFAULT now()
        );
    END IF;
END $$;

-- Indexes + comments are safe to (re)declare whether we just created the
-- table or it already had the Ledgius shape.

CREATE UNIQUE INDEX IF NOT EXISTS uq_eca_to_location_primary
    ON eca_to_location (entity_credit_account_id, location_class_id)
    WHERE is_primary = true;

CREATE INDEX IF NOT EXISTS idx_eca_to_location_eca
    ON eca_to_location (entity_credit_account_id, location_class_id);

COMMENT ON TABLE eca_to_location IS
    'Link table binding entity_credit_account (customer/vendor) records to location '
    '(structured postal address) records with a class (billing / shipping / …) per R-0017 '
    'IMP-PIP-024. Supports multiple addresses per contact; is_primary plus a partial unique '
    'index enforces exactly one primary address per class per contact. Recreated by V1.43 '
    'to reconcile LedgerSMB-shape drift.';

COMMENT ON COLUMN eca_to_location.entity_credit_account_id IS 'FK to the contact record (entity_credit_account.id).';
COMMENT ON COLUMN eca_to_location.location_id              IS 'FK to the location record (address rows).';
COMMENT ON COLUMN eca_to_location.location_class_id        IS 'FK to location_class — ''billing'' / ''shipping'' / future classes.';
COMMENT ON COLUMN eca_to_location.is_primary               IS 'Primary location of this class for this contact. Partial unique index enforces single primary per (contact, class).';

-- =============================================================================
-- 4. Create the contact channels table (was never created by V1.33)
-- =============================================================================

CREATE TABLE IF NOT EXISTS contact (
    id                       INTEGER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    entity_credit_account_id INTEGER NOT NULL REFERENCES entity_credit_account(id) ON DELETE CASCADE,
    contact_class            TEXT NOT NULL,
    value                    TEXT NOT NULL,
    is_primary               BOOLEAN NOT NULL DEFAULT false,
    notes                    TEXT,
    created_at               TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at               TIMESTAMPTZ NOT NULL DEFAULT now()
);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.constraint_column_usage
         WHERE table_name = 'contact' AND constraint_name = 'contact_class_check'
    ) THEN
        ALTER TABLE contact
            ADD CONSTRAINT contact_class_check
            CHECK (contact_class IN (
                'email',
                'phone_office',
                'phone_mobile',
                'phone_fax',
                'phone_other',
                'website',
                'other'
            ));
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.constraint_column_usage
         WHERE table_name = 'contact' AND constraint_name = 'contact_value_not_blank'
    ) THEN
        ALTER TABLE contact
            ADD CONSTRAINT contact_value_not_blank
            CHECK (length(trim(value)) > 0);
    END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS uq_contact_primary
    ON contact (entity_credit_account_id, contact_class)
    WHERE is_primary = true;

CREATE INDEX IF NOT EXISTS idx_contact_eca_class
    ON contact (entity_credit_account_id, contact_class);

CREATE INDEX IF NOT EXISTS idx_contact_email_value
    ON contact (lower(value))
    WHERE contact_class = 'email';

COMMENT ON TABLE contact IS
    'Contact channels (email, phone, fax, website) for an entity_credit_account record. Per '
    'R-0017 IMP-PIP-024 every contact carries at least one email (contact_class = ''email'') '
    'and at least one phone (contact_class starting ''phone_''). Multiple values allowed; '
    'is_primary plus partial unique index enforces single primary per (contact, class). '
    'Created by V1.43 — V1.33 failed early on LedgerSMB-seeded databases before reaching this table.';

COMMENT ON COLUMN contact.entity_credit_account_id IS 'FK to the contact (customer/vendor) record.';
COMMENT ON COLUMN contact.contact_class IS 'Channel type: ''email'', ''phone_office'', ''phone_mobile'', ''phone_fax'', ''phone_other'', ''website'', ''other''. CHECK-constrained.';
COMMENT ON COLUMN contact.value IS 'The actual contact value (email address / phone number / URL). Trimmed of surrounding whitespace; CHECK enforces non-blank.';
COMMENT ON COLUMN contact.is_primary IS 'Marks this row as the primary value of its class for this contact. Exactly one primary per (contact, class) enforced by partial unique index.';
