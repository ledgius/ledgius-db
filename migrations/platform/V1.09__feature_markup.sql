-- Spec references: R-0069 (PP-020).
--
-- V1.09 — Add markup description to features table.
-- Supports rich content rendering on the pricing page.

ALTER TABLE features
    ADD COLUMN IF NOT EXISTS markup_description TEXT;

COMMENT ON COLUMN features.markup_description IS
    'Rich markup description for the pricing page. '
    'Supports **bold**, - bullets, [links](url). '
    'Plain description used as fallback if markup is null.';
