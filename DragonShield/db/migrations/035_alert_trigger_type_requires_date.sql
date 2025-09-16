-- migrate:up
ALTER TABLE AlertTriggerType ADD COLUMN requires_date INTEGER NOT NULL DEFAULT 0 CHECK (requires_date IN (0,1));
UPDATE AlertTriggerType SET requires_date = 1 WHERE code IN ('date','calendar_event','macro_indicator_threshold');

-- migrate:down
UPDATE AlertTriggerType SET requires_date = 0;
