-- Spec references: R-0069 (PP-026 through PP-028).
--
-- V1.10 — Add plan inheritance for "Everything in X plus:" display.
-- Supports single-level inheritance: Starter → Business → Growth.

ALTER TABLE pricing_plans
    ADD COLUMN IF NOT EXISTS inherits_from_plan_id INT
        REFERENCES pricing_plans(id);

COMMENT ON COLUMN pricing_plans.inherits_from_plan_id IS
    'Optional parent plan. When set, public display reads '
    '"Everything in {parent} plus:" followed by features unique to this plan. '
    'Single-level only — no grandparent chains. '
    'Example: Business inherits from Starter, Growth inherits from Business.';

-- Set inheritance chain for seeded AU plans (if they exist).
UPDATE pricing_plans
SET inherits_from_plan_id = (SELECT id FROM pricing_plans WHERE slug = 'starter')
WHERE slug = 'business'
  AND inherits_from_plan_id IS NULL;

UPDATE pricing_plans
SET inherits_from_plan_id = (SELECT id FROM pricing_plans WHERE slug = 'business')
WHERE slug = 'growth'
  AND inherits_from_plan_id IS NULL;
