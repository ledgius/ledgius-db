-- Spec references: R-0048.
-- SSO authentication provider columns on users table.

ALTER TABLE users ADD COLUMN IF NOT EXISTS auth_provider TEXT DEFAULT 'email'
    CHECK (auth_provider IN ('email', 'google', 'microsoft'));
ALTER TABLE users ADD COLUMN IF NOT EXISTS oauth_id TEXT;

COMMENT ON COLUMN users.auth_provider IS 'How the user authenticates: email (password), google (OAuth), microsoft (OAuth)';
COMMENT ON COLUMN users.oauth_id IS 'External OAuth subject ID from Google/Microsoft. Null for email users.';

CREATE INDEX IF NOT EXISTS idx_users_oauth ON users(auth_provider, oauth_id) WHERE oauth_id IS NOT NULL;
