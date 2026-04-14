-- Move receipt storage from DB TEXT columns to filesystem paths.
-- thumbnail_data stays in DB for list-view performance.

ALTER TABLE captured_receipt ADD COLUMN IF NOT EXISTS image_path TEXT;
ALTER TABLE captured_receipt ADD COLUMN IF NOT EXISTS pdf_path TEXT;

COMMENT ON COLUMN captured_receipt.image_path IS 'Filesystem path to the compressed receipt image, e.g. /data/acme_cons_a7f2d/fy26/receipts/42.jpg';
COMMENT ON COLUMN captured_receipt.pdf_path IS 'Filesystem path to the generated PDF (image + OCR text), e.g. /data/acme_cons_a7f2d/fy26/receipts/42.pdf';

-- Make image_data nullable — new uploads write to filesystem instead.
-- Existing rows keep their data; a future cleanup migration can drop this column.
ALTER TABLE captured_receipt ALTER COLUMN image_data DROP NOT NULL;
