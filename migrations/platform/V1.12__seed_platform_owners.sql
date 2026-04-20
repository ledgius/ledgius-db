-- Spec references: R-0068 (PA-020, PA-070).
--
-- V1.12 — Seed mandatory platform owner users.
-- These are the Ledgius team accounts that administer the platform.
-- Passwords are bcrypt-hashed placeholders — users reset via auth flow.

INSERT INTO users (id, email, password_hash, display_name, is_platform_admin, status)
VALUES
  (gen_random_uuid(), 'matt@ledgius.com',
   -- Placeholder hash (password: 'changeme'). Must be reset via login flow.
   '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy',
   'Matt Bush', true, 'active'),
  (gen_random_uuid(), 'ziryan@ledgius.com',
   '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy',
   'Ziryan', true, 'active')
ON CONFLICT (email) DO UPDATE SET
  is_platform_admin = true,
  display_name = EXCLUDED.display_name,
  updated_at = now();

COMMENT ON TABLE users IS
    'Platform user accounts. Authentication is centralised; authorisation is per-tenant via tenant_memberships.';
