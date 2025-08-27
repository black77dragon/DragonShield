-- migrate:up
-- Purpose: Add UpdateType table and replace text type columns with foreign keys
-- Assumptions: Existing PortfolioThemeUpdate and PortfolioThemeAssetUpdate tables use string type values
-- Idempotency: creates new table with seed data and rebuilds affected tables
CREATE TABLE IF NOT EXISTS UpdateType (
  id INTEGER PRIMARY KEY,
  code TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL
);
INSERT INTO UpdateType (code, name) VALUES
  ('General','General'),
  ('Research','Research'),
  ('Rebalance','Rebalance'),
  ('Risk','Risk')
ON CONFLICT(code) DO NOTHING;

CREATE TABLE IF NOT EXISTS PortfolioThemeUpdate_new (
  id INTEGER PRIMARY KEY,
  theme_id INTEGER NOT NULL REFERENCES PortfolioTheme(id) ON DELETE CASCADE,
  title TEXT NOT NULL CHECK (LENGTH(title) BETWEEN 1 AND 120),
  body_text TEXT NOT NULL CHECK (LENGTH(body_text) BETWEEN 1 AND 5000),
  body_markdown TEXT NOT NULL CHECK (LENGTH(body_markdown) BETWEEN 1 AND 5000),
  type_id INTEGER NOT NULL REFERENCES UpdateType(id),
  author TEXT NOT NULL,
  pinned INTEGER NOT NULL DEFAULT 0 CHECK (pinned IN (0,1)),
  positions_asof TEXT NULL,
  total_value_chf REAL NULL,
  created_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
  updated_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
  soft_delete INTEGER NOT NULL DEFAULT 0 CHECK (soft_delete IN (0,1)),
  deleted_at TEXT NULL,
  deleted_by TEXT NULL
);
INSERT INTO PortfolioThemeUpdate_new (id, theme_id, title, body_text, body_markdown, type_id, author, pinned, positions_asof, total_value_chf, created_at, updated_at, soft_delete, deleted_at, deleted_by)
  SELECT u.id, u.theme_id, u.title, u.body_text, u.body_markdown, t.id, u.author, u.pinned, u.positions_asof, u.total_value_chf, u.created_at, u.updated_at, u.soft_delete, u.deleted_at, u.deleted_by
  FROM PortfolioThemeUpdate u JOIN UpdateType t ON t.code = u.type;
DROP TABLE PortfolioThemeUpdate;
ALTER TABLE PortfolioThemeUpdate_new RENAME TO PortfolioThemeUpdate;
CREATE INDEX IF NOT EXISTS idx_ptu_theme_active_order ON PortfolioThemeUpdate(theme_id, soft_delete, pinned, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ptu_theme_deleted_order ON PortfolioThemeUpdate(theme_id, soft_delete, deleted_at DESC);

CREATE TABLE IF NOT EXISTS PortfolioThemeAssetUpdate_new (
  id INTEGER PRIMARY KEY,
  theme_id INTEGER NOT NULL REFERENCES PortfolioTheme(id) ON DELETE CASCADE,
  instrument_id INTEGER NOT NULL REFERENCES Instruments(instrument_id) ON DELETE SET NULL,
  title TEXT NOT NULL CHECK (LENGTH(title) BETWEEN 1 AND 120),
  body_text TEXT NOT NULL CHECK (LENGTH(body_text) BETWEEN 1 AND 5000),
  body_markdown TEXT NOT NULL CHECK (LENGTH(body_markdown) BETWEEN 1 AND 5000),
  type_id INTEGER NOT NULL REFERENCES UpdateType(id),
  author TEXT NOT NULL,
  pinned INTEGER NOT NULL DEFAULT 0 CHECK (pinned IN (0,1)),
  positions_asof TEXT NULL,
  value_chf REAL NULL,
  actual_percent REAL NULL,
  created_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
  updated_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now'))
);
INSERT INTO PortfolioThemeAssetUpdate_new (id, theme_id, instrument_id, title, body_text, body_markdown, type_id, author, pinned, positions_asof, value_chf, actual_percent, created_at, updated_at)
  SELECT u.id, u.theme_id, u.instrument_id, u.title, u.body_text, u.body_markdown, t.id, u.author, u.pinned, u.positions_asof, u.value_chf, u.actual_percent, u.created_at, u.updated_at
  FROM PortfolioThemeAssetUpdate u JOIN UpdateType t ON t.code = u.type;
DROP TABLE PortfolioThemeAssetUpdate;
ALTER TABLE PortfolioThemeAssetUpdate_new RENAME TO PortfolioThemeAssetUpdate;
CREATE INDEX IF NOT EXISTS idx_ptau_theme_instr_order ON PortfolioThemeAssetUpdate(theme_id, instrument_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ptau_theme_instr_pinned_order ON PortfolioThemeAssetUpdate(theme_id, instrument_id, pinned DESC, created_at DESC);

-- migrate:down
CREATE TABLE IF NOT EXISTS PortfolioThemeUpdate_old (
  id INTEGER PRIMARY KEY,
  theme_id INTEGER NOT NULL REFERENCES PortfolioTheme(id) ON DELETE CASCADE,
  title TEXT NOT NULL CHECK (LENGTH(title) BETWEEN 1 AND 120),
  body_text TEXT NOT NULL CHECK (LENGTH(body_text) BETWEEN 1 AND 5000),
  body_markdown TEXT NOT NULL CHECK (LENGTH(body_markdown) BETWEEN 1 AND 5000),
  type TEXT NOT NULL CHECK (type IN ('General','Research','Rebalance','Risk')),
  author TEXT NOT NULL,
  pinned INTEGER NOT NULL DEFAULT 0 CHECK (pinned IN (0,1)),
  positions_asof TEXT NULL,
  total_value_chf REAL NULL,
  created_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
  updated_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
  soft_delete INTEGER NOT NULL DEFAULT 0 CHECK (soft_delete IN (0,1)),
  deleted_at TEXT NULL,
  deleted_by TEXT NULL
);
INSERT INTO PortfolioThemeUpdate_old (id, theme_id, title, body_text, body_markdown, type, author, pinned, positions_asof, total_value_chf, created_at, updated_at, soft_delete, deleted_at, deleted_by)
  SELECT u.id, u.theme_id, u.title, u.body_text, u.body_markdown, t.code, u.author, u.pinned, u.positions_asof, u.total_value_chf, u.created_at, u.updated_at, u.soft_delete, u.deleted_at, u.deleted_by
  FROM PortfolioThemeUpdate u JOIN UpdateType t ON t.id = u.type_id;
DROP TABLE PortfolioThemeUpdate;
ALTER TABLE PortfolioThemeUpdate_old RENAME TO PortfolioThemeUpdate;
CREATE INDEX IF NOT EXISTS idx_ptu_theme_active_order ON PortfolioThemeUpdate(theme_id, soft_delete, pinned, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ptu_theme_deleted_order ON PortfolioThemeUpdate(theme_id, soft_delete, deleted_at DESC);

CREATE TABLE IF NOT EXISTS PortfolioThemeAssetUpdate_old (
  id INTEGER PRIMARY KEY,
  theme_id INTEGER NOT NULL REFERENCES PortfolioTheme(id) ON DELETE CASCADE,
  instrument_id INTEGER NOT NULL REFERENCES Instruments(instrument_id) ON DELETE SET NULL,
  title TEXT NOT NULL CHECK (LENGTH(title) BETWEEN 1 AND 120),
  body_text TEXT NOT NULL CHECK (LENGTH(body_text) BETWEEN 1 AND 5000),
  body_markdown TEXT NOT NULL CHECK (LENGTH(body_markdown) BETWEEN 1 AND 5000),
  type TEXT NOT NULL CHECK (type IN ('General','Research','Rebalance','Risk')),
  author TEXT NOT NULL,
  pinned INTEGER NOT NULL DEFAULT 0 CHECK (pinned IN (0,1)),
  positions_asof TEXT NULL,
  value_chf REAL NULL,
  actual_percent REAL NULL,
  created_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
  updated_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now'))
);
INSERT INTO PortfolioThemeAssetUpdate_old (id, theme_id, instrument_id, title, body_text, body_markdown, type, author, pinned, positions_asof, value_chf, actual_percent, created_at, updated_at)
  SELECT u.id, u.theme_id, u.instrument_id, u.title, u.body_text, u.body_markdown, t.code, u.author, u.pinned, u.positions_asof, u.value_chf, u.actual_percent, u.created_at, u.updated_at
  FROM PortfolioThemeAssetUpdate u JOIN UpdateType t ON t.id = u.type_id;
DROP TABLE PortfolioThemeAssetUpdate;
ALTER TABLE PortfolioThemeAssetUpdate_old RENAME TO PortfolioThemeAssetUpdate;
CREATE INDEX IF NOT EXISTS idx_ptau_theme_instr_order ON PortfolioThemeAssetUpdate(theme_id, instrument_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ptau_theme_instr_pinned_order ON PortfolioThemeAssetUpdate(theme_id, instrument_id, pinned DESC, created_at DESC);

DROP TABLE IF EXISTS UpdateType;
