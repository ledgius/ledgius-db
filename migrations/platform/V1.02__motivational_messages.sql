-- Motivational messages displayed on the login page.
-- Served randomly via public API to keep the work day fresh and positive.

CREATE TABLE IF NOT EXISTS motivational_messages (
    id      SERIAL PRIMARY KEY,
    message TEXT NOT NULL,
    active  BOOLEAN NOT NULL DEFAULT true
);

COMMENT ON TABLE motivational_messages IS 'Short positive messages shown on the login page. Rotated randomly each session.';
