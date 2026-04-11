-- Migration: User feedback system
-- Captures contextual feedback, votes, comments, screenshots, and flow pulse signals.

-- Main feedback items
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

CREATE INDEX IF NOT EXISTS idx_feedback_route ON feedback(page_route);
CREATE INDEX IF NOT EXISTS idx_feedback_status ON feedback(status);
CREATE INDEX IF NOT EXISTS idx_feedback_type ON feedback(feedback_type);
CREATE INDEX IF NOT EXISTS idx_feedback_created ON feedback(created_at DESC);

COMMENT ON TABLE feedback IS 'User feedback items with contextual page info, action trail, and optional screenshots';
COMMENT ON COLUMN feedback.action_trail IS 'JSON array of the last 10-15 user actions before submitting feedback (route changes, clicks, form submissions)';
COMMENT ON COLUMN feedback.screenshot_data IS 'Base64-encoded compressed screenshot captured via html2canvas';

-- Votes on feedback items (one per user per item)
CREATE TABLE IF NOT EXISTS feedback_vote (
    id          SERIAL PRIMARY KEY,
    feedback_id INT NOT NULL REFERENCES feedback(id) ON DELETE CASCADE,
    user_id     TEXT NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (feedback_id, user_id)
);

-- Comments on feedback items
CREATE TABLE IF NOT EXISTS feedback_comment (
    id          SERIAL PRIMARY KEY,
    feedback_id INT NOT NULL REFERENCES feedback(id) ON DELETE CASCADE,
    user_id     TEXT NOT NULL DEFAULT '',
    user_name   TEXT NOT NULL DEFAULT '',
    body        TEXT NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_feedback_comment_item ON feedback_comment(feedback_id);

-- Flow pulse signals (thumbs up/down captured passively)
CREATE TABLE IF NOT EXISTS feedback_pulse (
    id          SERIAL PRIMARY KEY,
    user_id     TEXT NOT NULL DEFAULT '',
    page_route  TEXT NOT NULL,
    signal      TEXT NOT NULL CHECK (signal IN ('up', 'down')),
    session_id  TEXT NOT NULL DEFAULT '',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_feedback_pulse_route ON feedback_pulse(page_route);
CREATE INDEX IF NOT EXISTS idx_feedback_pulse_signal ON feedback_pulse(signal);
CREATE INDEX IF NOT EXISTS idx_feedback_pulse_created ON feedback_pulse(created_at DESC);

COMMENT ON TABLE feedback_pulse IS 'Lightweight thumbs up/down signals captured during smooth user flow — provides positive sentiment data';
