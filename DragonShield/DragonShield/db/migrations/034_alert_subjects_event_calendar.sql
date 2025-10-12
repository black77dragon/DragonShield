-- migrate:up
-- Purpose: Extend alerts with subject abstraction and introduce EventCalendar reference table.
-- Notes: Adds subject_type/subject_reference columns and initial event catalog storage.

ALTER TABLE Alert ADD COLUMN subject_type TEXT NULL;
ALTER TABLE Alert ADD COLUMN subject_reference TEXT NULL;

UPDATE Alert SET subject_type = scope_type WHERE subject_type IS NULL;
UPDATE Alert SET subject_reference = CAST(scope_id AS TEXT) WHERE subject_reference IS NULL;

CREATE INDEX IF NOT EXISTS idx_alert_subject ON Alert(subject_type, subject_reference);

CREATE TABLE IF NOT EXISTS EventCalendar (
  id             INTEGER PRIMARY KEY,
  code           TEXT    NOT NULL UNIQUE,
  title          TEXT    NOT NULL,
  category       TEXT    NOT NULL,
  event_date     TEXT    NOT NULL, -- YYYY-MM-DD (local date)
  event_time     TEXT    NULL,      -- HH:MM (24h, local)
  timezone       TEXT    NULL,
  status         TEXT    NOT NULL DEFAULT 'scheduled', -- scheduled|tentative|confirmed|actual
  source         TEXT    NULL,
  notes          TEXT    NULL,
  created_at     TEXT    NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
  updated_at     TEXT    NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE INDEX IF NOT EXISTS idx_event_calendar_date ON EventCalendar(event_date, category);

-- migrate:down
DROP INDEX IF EXISTS idx_event_calendar_date;
DROP TABLE IF EXISTS EventCalendar;
DROP INDEX IF EXISTS idx_alert_subject;
UPDATE Alert SET subject_reference = NULL;
UPDATE Alert SET subject_type = NULL;
