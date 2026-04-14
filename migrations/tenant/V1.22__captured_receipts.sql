-- Captured receipts — photos of paper receipts uploaded from the mobile app.
-- OCR extraction populates vendor/amount/date fields; user can correct.

CREATE TABLE IF NOT EXISTS captured_receipt (
    id              SERIAL PRIMARY KEY,
    image_data      TEXT NOT NULL,
    thumbnail_data  TEXT,
    file_name       TEXT NOT NULL DEFAULT 'receipt.jpg',
    mime_type       TEXT NOT NULL DEFAULT 'image/jpeg',
    file_size_bytes INT NOT NULL DEFAULT 0,

    -- OCR-extracted fields (nullable until processing completes)
    ocr_vendor      TEXT,
    ocr_amount      NUMERIC,
    ocr_date        DATE,
    ocr_currency    TEXT DEFAULT 'AUD',
    ocr_description TEXT,
    ocr_raw_text    TEXT,

    -- User-corrected fields (override OCR values)
    vendor          TEXT,
    amount          NUMERIC,
    receipt_date    DATE,
    currency        TEXT DEFAULT 'AUD',
    description     TEXT,
    category        TEXT,

    -- Linking
    bank_transaction_id INT,
    expense_account_id  INT,

    -- Status: uploaded, processing, ready, matched, archived
    status          TEXT NOT NULL DEFAULT 'uploaded'
        CHECK (status IN ('uploaded', 'processing', 'ready', 'matched', 'archived')),

    notes           TEXT,
    uploaded_by     TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE captured_receipt IS 'Receipt photos captured via mobile app. OCR extracts vendor/amount/date; user can correct before matching.';
COMMENT ON COLUMN captured_receipt.image_data IS 'Base64-encoded image data (JPEG/PNG). Typically 50-300KB compressed.';
COMMENT ON COLUMN captured_receipt.thumbnail_data IS 'Base64-encoded thumbnail for list views (~10KB).';
COMMENT ON COLUMN captured_receipt.ocr_vendor IS 'Vendor/merchant name extracted by OCR engine.';
COMMENT ON COLUMN captured_receipt.ocr_amount IS 'Total amount extracted by OCR engine.';
COMMENT ON COLUMN captured_receipt.ocr_date IS 'Receipt date extracted by OCR engine.';
COMMENT ON COLUMN captured_receipt.ocr_raw_text IS 'Full OCR text output for debugging and re-extraction.';
COMMENT ON COLUMN captured_receipt.vendor IS 'User-confirmed or corrected vendor name.';
COMMENT ON COLUMN captured_receipt.amount IS 'User-confirmed or corrected amount.';
COMMENT ON COLUMN captured_receipt.receipt_date IS 'User-confirmed or corrected receipt date.';
COMMENT ON COLUMN captured_receipt.bank_transaction_id IS 'FK to bank_transaction if matched to a bank feed entry.';
COMMENT ON COLUMN captured_receipt.expense_account_id IS 'FK to chart of accounts — the expense account for this receipt.';
COMMENT ON COLUMN captured_receipt.status IS 'Lifecycle: uploaded → processing → ready → matched → archived';

CREATE INDEX IF NOT EXISTS idx_captured_receipt_status ON captured_receipt(status);
CREATE INDEX IF NOT EXISTS idx_captured_receipt_created ON captured_receipt(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_captured_receipt_bank_tx ON captured_receipt(bank_transaction_id) WHERE bank_transaction_id IS NOT NULL;
