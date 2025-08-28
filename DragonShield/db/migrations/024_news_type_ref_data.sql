-- migrate:up
-- Purpose: Introduce NewsType reference table and seed initial types
-- Idempotent: CREATE TABLE IF NOT EXISTS; inserts use INSERT OR IGNORE

CREATE TABLE IF NOT EXISTS NewsType (
  id           INTEGER PRIMARY KEY,
  code         TEXT    NOT NULL UNIQUE,
  display_name TEXT    NOT NULL,
  sort_order   INTEGER NOT NULL,
  active       INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0,1)),
  color        TEXT    NULL,
  icon         TEXT    NULL,
  created_at   TEXT    NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
  updated_at   TEXT    NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_news_type_code ON NewsType(code);
CREATE INDEX IF NOT EXISTS idx_news_type_active_order ON NewsType(active, sort_order);

-- Seed initial types matching current enum/raw values
INSERT OR IGNORE INTO NewsType (code, display_name, sort_order, active)
VALUES
  ('General',     'General',     1, 1),
  ('Research',    'Research',    2, 1),
  ('Rebalance',   'Rebalance',   3, 1),
  ('Risk',        'Risk',        4, 1),
  ('Investment',  'Investment',  5, 1);

-- migrate:down
DROP INDEX IF EXISTS idx_news_type_active_order;
DROP INDEX IF EXISTS idx_news_type_code;
DROP TABLE IF EXISTS NewsType;

