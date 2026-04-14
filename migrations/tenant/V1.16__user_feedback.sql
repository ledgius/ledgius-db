-- Spec references: A-0021.
--
-- V1.16 — User Feedback System
--
-- Creates tables for capturing contextual user feedback, votes, comments,
-- and passive flow pulse signals.
--
--   feedback         — main feedback items (bugs, suggestions, praise, questions)
--   feedback_vote    — one vote per user per feedback item
--   feedback_comment — threaded comments on feedback items
--   feedback_pulse   — lightweight thumbs up/down flow signals

-- =============================================================================
-- 1. Feedback Items
-- =============================================================================

CREATE TABLE IF NOT EXISTS feedback (
    id              SERIAL PRIMARY KEY,
    user_id         TEXT NOT NULL DEFAULT '',
    user_name       TEXT NOT NULL DEFAULT '',
    page_route      TEXT NOT NULL,
    feature_area    TEXT NOT NULL DEFAULT '',
    feedback_type   TEXT NOT NULL CHECK (feedback_type IN ('bug', 'suggestion', 'praise', 'question')),
    title           TEXT NOT NULL,
    body            TEXT NOT NULL DEFAULT '',
    status          TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'acknowledged', 'in_progress', 'resolved', 'wont_fix')),
    vote_count      INT NOT NULL DEFAULT 1,
    action_trail    JSONB NOT NULL DEFAULT '[]',
    browser_info    JSONB NOT NULL DEFAULT '{}',
    screenshot_data TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE feedback IS 'User feedback items with contextual page info, action trail, and optional screenshots';
COMMENT ON COLUMN feedback.action_trail IS 'JSON array of the last 10-15 user actions before submitting feedback (route changes, clicks, form submissions)';
COMMENT ON COLUMN feedback.screenshot_data IS 'Base64-encoded compressed screenshot captured via html2canvas';
COMMENT ON COLUMN feedback.status IS 'open, acknowledged, in_progress, resolved, wont_fix';

CREATE INDEX IF NOT EXISTS idx_feedback_route ON feedback(page_route);
CREATE INDEX IF NOT EXISTS idx_feedback_status ON feedback(status);
CREATE INDEX IF NOT EXISTS idx_feedback_type ON feedback(feedback_type);
CREATE INDEX IF NOT EXISTS idx_feedback_created ON feedback(created_at DESC);

-- =============================================================================
-- 2. Votes
-- =============================================================================

CREATE TABLE IF NOT EXISTS feedback_vote (
    id          SERIAL PRIMARY KEY,
    feedback_id INT NOT NULL REFERENCES feedback(id) ON DELETE CASCADE,
    user_id     TEXT NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (feedback_id, user_id)
);

COMMENT ON TABLE feedback_vote IS 'One vote per user per feedback item — prevents duplicate voting';

-- =============================================================================
-- 3. Comments
-- =============================================================================

CREATE TABLE IF NOT EXISTS feedback_comment (
    id          SERIAL PRIMARY KEY,
    feedback_id INT NOT NULL REFERENCES feedback(id) ON DELETE CASCADE,
    user_id     TEXT NOT NULL DEFAULT '',
    user_name   TEXT NOT NULL DEFAULT '',
    body        TEXT NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE feedback_comment IS 'Threaded comments on feedback items from users and staff';

CREATE INDEX IF NOT EXISTS idx_feedback_comment_item ON feedback_comment(feedback_id);

-- =============================================================================
-- 4. Flow Pulse Signals
-- =============================================================================

CREATE TABLE IF NOT EXISTS feedback_pulse (
    id          SERIAL PRIMARY KEY,
    user_id     TEXT NOT NULL DEFAULT '',
    page_route  TEXT NOT NULL,
    signal      TEXT NOT NULL CHECK (signal IN ('up', 'down')),
    session_id  TEXT NOT NULL DEFAULT '',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE feedback_pulse IS 'Lightweight thumbs up/down signals captured during smooth user flow — provides positive sentiment data';
COMMENT ON COLUMN feedback_pulse.signal IS 'up (positive experience) or down (friction/issue)';
COMMENT ON COLUMN feedback_pulse.session_id IS 'Browser session identifier for deduplication within a session';

CREATE INDEX IF NOT EXISTS idx_feedback_pulse_route ON feedback_pulse(page_route);
CREATE INDEX IF NOT EXISTS idx_feedback_pulse_signal ON feedback_pulse(signal);
CREATE INDEX IF NOT EXISTS idx_feedback_pulse_created ON feedback_pulse(created_at DESC);
