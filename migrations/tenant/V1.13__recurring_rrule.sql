-- Spec references: A-0021.
--
-- V1.13 — Recurring Schedule RRULE Support
--
-- Adds RFC 5545 RRULE support to recurring_schedule, replacing the hardcoded
-- frequency enum as the source-of-truth for recurrence.
--
-- Steps:
--   1. Add rrule column (nullable initially for backfill)
--   2. Backfill existing rows by mapping frequency → RRULE string
--   3. Set NOT NULL after backfill
--   4. Drop the old CHECK constraint on frequency (it becomes a display label)

-- 1. Add rrule column (nullable initially for backfill).
ALTER TABLE recurring_schedule ADD COLUMN IF NOT EXISTS rrule TEXT;

-- 2. Backfill existing rows by mapping frequency to RRULE strings.
UPDATE recurring_schedule SET rrule = CASE frequency
    WHEN 'weekly'      THEN 'FREQ=WEEKLY;INTERVAL=1'
    WHEN 'fortnightly' THEN 'FREQ=WEEKLY;INTERVAL=2'
    WHEN 'monthly'     THEN 'FREQ=MONTHLY;INTERVAL=1'
    WHEN 'quarterly'   THEN 'FREQ=MONTHLY;INTERVAL=3'
    WHEN 'annually'    THEN 'FREQ=YEARLY;INTERVAL=1'
    ELSE 'FREQ=MONTHLY;INTERVAL=1'
END
WHERE rrule IS NULL;

-- 3. Set NOT NULL after backfill.
ALTER TABLE recurring_schedule ALTER COLUMN rrule SET NOT NULL;

-- 4. Drop the old CHECK constraint on frequency (it becomes a display label only).
ALTER TABLE recurring_schedule DROP CONSTRAINT IF EXISTS recurring_schedule_frequency_check;

-- 5. Add comments.
COMMENT ON COLUMN recurring_schedule.rrule IS 'RFC 5545 RRULE string (e.g. FREQ=MONTHLY;INTERVAL=1;BYDAY=MO). Source of truth for recurrence.';
COMMENT ON COLUMN recurring_schedule.frequency IS 'Human-readable frequency label derived from rrule (e.g. weekly, monthly, custom). No longer enforced by CHECK constraint.';
