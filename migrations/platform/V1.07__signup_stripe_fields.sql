-- Spec references: R-0068 (PA-001).
--
-- V1.07 — Add Stripe SetupIntent fields to signup_request.
-- Card verification at signup uses Stripe SetupIntent (no charge).

ALTER TABLE signup_request
    ADD COLUMN IF NOT EXISTS stripe_setup_intent_id TEXT,
    ADD COLUMN IF NOT EXISTS stripe_payment_method_id TEXT;

COMMENT ON COLUMN signup_request.stripe_setup_intent_id IS
    'Stripe SetupIntent ID from card verification at signup. No charge — just validates the card.';
COMMENT ON COLUMN signup_request.stripe_payment_method_id IS
    'Stripe PaymentMethod ID. Attached to the customer when tenant is provisioned and billing starts.';
