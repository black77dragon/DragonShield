-- migrate:up
-- Purpose: Introduce Alerts schema (Alert, AlertEvent, AlertAttachment), Trigger Types, and Tags
-- Notes: SQLite dialect. Timestamps stored as ISO8601 UTC strings.

-- Reference table for alert trigger types
CREATE TABLE IF NOT EXISTS AlertTriggerType (
  id           INTEGER PRIMARY KEY,
  code         TEXT    NOT NULL UNIQUE,   -- e.g., 'date', 'price', 'holding_abs', 'holding_pct'
  display_name TEXT    NOT NULL,
  description  TEXT    NULL,
  sort_order   INTEGER NOT NULL DEFAULT 0,
  active       INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0,1)),
  created_at   TEXT    NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
  updated_at   TEXT    NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_alert_trigger_type_code ON AlertTriggerType(code);
CREATE INDEX IF NOT EXISTS idx_alert_trigger_type_active ON AlertTriggerType(active, sort_order);

-- Main Alert table
CREATE TABLE IF NOT EXISTS Alert (
  id                 INTEGER PRIMARY KEY,
  name               TEXT    NOT NULL,
  enabled            INTEGER NOT NULL DEFAULT 1 CHECK (enabled IN (0,1)),
  severity           TEXT    NOT NULL CHECK (severity IN ('info','warning','critical')),
  scope_type         TEXT    NOT NULL CHECK (scope_type IN ('Instrument','PortfolioTheme','AssetClass','Portfolio','Account')),
  scope_id           INTEGER NOT NULL,
  trigger_type_code  TEXT    NOT NULL REFERENCES AlertTriggerType(code) ON UPDATE CASCADE,
  params_json        TEXT    NOT NULL DEFAULT '{}',
  near_value         REAL    NULL,
  near_unit          TEXT    NULL CHECK (near_unit IN ('pct','abs')),
  hysteresis_value   REAL    NULL,
  hysteresis_unit    TEXT    NULL CHECK (hysteresis_unit IN ('pct','abs')),
  cooldown_seconds   INTEGER NULL,
  mute_until         TEXT    NULL,
  schedule_start     TEXT    NULL,
  schedule_end       TEXT    NULL,
  notes              TEXT    NULL,
  created_by         TEXT    NULL,
  created_at         TEXT    NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
  updated_at         TEXT    NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE INDEX IF NOT EXISTS idx_alert_enabled_type ON Alert(enabled, trigger_type_code);
CREATE INDEX IF NOT EXISTS idx_alert_scope ON Alert(scope_type, scope_id);
CREATE INDEX IF NOT EXISTS idx_alert_severity ON Alert(severity);

-- Event/audit table for alert occurrences
CREATE TABLE IF NOT EXISTS AlertEvent (
  id            INTEGER PRIMARY KEY,
  alert_id      INTEGER NOT NULL REFERENCES Alert(id) ON DELETE CASCADE,
  occurred_at   TEXT    NOT NULL,
  status        TEXT    NOT NULL CHECK (status IN ('triggered','acknowledged','snoozed','resolved')),
  message       TEXT    NULL,
  measured_json TEXT    NULL,
  ack_by        TEXT    NULL,
  ack_at        TEXT    NULL,
  snooze_until  TEXT    NULL,
  created_at    TEXT    NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE INDEX IF NOT EXISTS idx_alert_event_alert ON AlertEvent(alert_id, occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_alert_event_status ON AlertEvent(status);

-- Attachment linking
CREATE TABLE IF NOT EXISTS AlertAttachment (
  id            INTEGER PRIMARY KEY,
  alert_id      INTEGER NOT NULL REFERENCES Alert(id) ON DELETE CASCADE,
  attachment_id INTEGER NOT NULL REFERENCES Attachment(id) ON DELETE RESTRICT,
  created_at    TEXT    NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE INDEX IF NOT EXISTS idx_alert_attachment_alert ON AlertAttachment(alert_id);
CREATE INDEX IF NOT EXISTS idx_alert_attachment_attachment ON AlertAttachment(attachment_id);

-- Tagging
CREATE TABLE IF NOT EXISTS Tag (
  id           INTEGER PRIMARY KEY,
  code         TEXT    NOT NULL UNIQUE,
  display_name TEXT    NOT NULL,
  color        TEXT    NULL,
  sort_order   INTEGER NOT NULL DEFAULT 0,
  active       INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0,1)),
  created_at   TEXT    NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
  updated_at   TEXT    NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_tag_code ON Tag(code);
CREATE INDEX IF NOT EXISTS idx_tag_active ON Tag(active, sort_order);

CREATE TABLE IF NOT EXISTS AlertTag (
  id       INTEGER PRIMARY KEY,
  alert_id INTEGER NOT NULL REFERENCES Alert(id) ON DELETE CASCADE,
  tag_id   INTEGER NOT NULL REFERENCES Tag(id) ON DELETE RESTRICT,
  created_at TEXT  NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
  UNIQUE(alert_id, tag_id)
);

CREATE INDEX IF NOT EXISTS idx_alert_tag_alert ON AlertTag(alert_id);
CREATE INDEX IF NOT EXISTS idx_alert_tag_tag ON AlertTag(tag_id);

-- Seed initial trigger types
INSERT OR IGNORE INTO AlertTriggerType (code, display_name, description, sort_order, active)
VALUES
  ('date',         'Date',                 'Fires on a specific date; supports warnings and recurrence (later).', 1, 1),
  ('price',        'Price Level',          'Fires when price crosses a threshold or exits a band.',               2, 1),
  ('holding_abs',  'Holding Value (Abs)',  'Fires when exposure exceeds/falls below an absolute value.',          3, 1),
  ('holding_pct',  'Holding Share (%)',    'Fires when holding share (%) crosses a threshold.',                   4, 1);

-- migrate:down
DROP TABLE IF EXISTS AlertTag;
DROP TABLE IF EXISTS Tag;
DROP TABLE IF EXISTS AlertAttachment;
DROP INDEX IF EXISTS idx_alert_event_status;
DROP INDEX IF EXISTS idx_alert_event_alert;
DROP TABLE IF EXISTS AlertEvent;
DROP INDEX IF EXISTS idx_alert_severity;
DROP INDEX IF EXISTS idx_alert_scope;
DROP INDEX IF EXISTS idx_alert_enabled_type;
DROP TABLE IF EXISTS Alert;
DROP INDEX IF EXISTS idx_alert_trigger_type_active;
DROP INDEX IF EXISTS idx_alert_trigger_type_code;
DROP TABLE IF EXISTS AlertTriggerType;

