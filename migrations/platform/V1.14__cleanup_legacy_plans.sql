-- Spec references: R-0069.
--
-- V1.14 — Archive legacy plans (essential, professional) and fix inheritance.
-- The old R__01 seed created starter/essential/professional/business.
-- V1.11 introduced the new plan set: starter/business/growth/partner.
-- This migration archives the orphaned legacy plans and corrects
-- the inheritance chain to: Starter → Business → Growth.

-- Archive legacy plans that are no longer in the active set.
UPDATE pricing_plans SET status = 'archived'
WHERE slug IN ('essential', 'professional')
  AND status = 'active';

-- Fix inheritance chain using slugs (not IDs).
UPDATE pricing_plans
SET inherits_from_plan_id = (SELECT id FROM pricing_plans WHERE slug = 'starter')
WHERE slug = 'business';

UPDATE pricing_plans
SET inherits_from_plan_id = (SELECT id FROM pricing_plans WHERE slug = 'business')
WHERE slug = 'growth';

-- Ensure base plans have no parent.
UPDATE pricing_plans
SET inherits_from_plan_id = NULL
WHERE slug IN ('starter', 'partner', 'essential', 'professional');

-- Fix sort order so active plans are contiguous.
UPDATE pricing_plans SET sort_order = 1 WHERE slug = 'starter';
UPDATE pricing_plans SET sort_order = 2 WHERE slug = 'business';
UPDATE pricing_plans SET sort_order = 3 WHERE slug = 'growth';
UPDATE pricing_plans SET sort_order = 4 WHERE slug = 'partner';
UPDATE pricing_plans SET sort_order = 90 WHERE slug = 'essential';
UPDATE pricing_plans SET sort_order = 91 WHERE slug = 'professional';
