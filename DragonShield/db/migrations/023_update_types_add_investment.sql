-- migrate:up
-- Purpose: Allow new update/news type 'Investment' by updating CHECK constraints

-- PortfolioThemeUpdate: recreate table with expanded CHECK
CREATE TABLE IF NOT EXISTS PortfolioThemeUpdate_new (
  id INTEGER PRIMARY KEY,
  theme_id INTEGER NOT NULL REFERENCES PortfolioTheme(id) ON DELETE CASCADE,
  title TEXT NOT NULL CHECK (LENGTH(title) BETWEEN 1 AND 120),
  body_text TEXT NOT NULL CHECK (LENGTH(body_text) BETWEEN 1 AND 5000),
  body_markdown TEXT NOT NULL CHECK (LENGTH(body_markdown) BETWEEN 1 AND 5000),
  type TEXT NOT NULL CHECK (type IN ('General','Research','Rebalance','Risk','Investment')),
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
INSERT INTO PortfolioThemeUpdate_new (id, theme_id, title, body_text, body_markdown, type, author, pinned, positions_asof, total_value_chf, created_at, updated_at, soft_delete, deleted_at, deleted_by)
  SELECT id, theme_id, title, body_text, COALESCE(body_markdown, COALESCE(body_text, '')),
         type, author, COALESCE(pinned, 0), positions_asof, total_value_chf,
         created_at, updated_at, COALESCE(soft_delete, 0), deleted_at, deleted_by
  FROM PortfolioThemeUpdate;
DROP TABLE PortfolioThemeUpdate;
ALTER TABLE PortfolioThemeUpdate_new RENAME TO PortfolioThemeUpdate;
CREATE INDEX IF NOT EXISTS idx_ptu_theme_active_order ON PortfolioThemeUpdate(theme_id, soft_delete, pinned, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ptu_theme_deleted_order ON PortfolioThemeUpdate(theme_id, soft_delete, deleted_at DESC);

-- PortfolioThemeAssetUpdate: recreate table with expanded CHECK
CREATE TABLE IF NOT EXISTS PortfolioThemeAssetUpdate_new (
  id               INTEGER PRIMARY KEY,
  theme_id         INTEGER NOT NULL REFERENCES PortfolioTheme(id) ON DELETE CASCADE,
  instrument_id    INTEGER NOT NULL REFERENCES Instruments(instrument_id) ON DELETE SET NULL,
  title            TEXT    NOT NULL CHECK (LENGTH(title) BETWEEN 1 AND 120),
  body_text        TEXT    NOT NULL CHECK (LENGTH(body_text) BETWEEN 1 AND 5000),
  body_markdown    TEXT    NOT NULL CHECK (LENGTH(body_markdown) BETWEEN 1 AND 5000),
  type             TEXT    NOT NULL CHECK (type IN ('General','Research','Rebalance','Risk','Investment')),
  author           TEXT    NOT NULL,
  pinned           INTEGER NOT NULL DEFAULT 0 CHECK (pinned IN (0,1)),
  positions_asof   TEXT    NULL,
  value_chf        REAL    NULL,
  actual_percent   REAL    NULL,
  created_at       TEXT    NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
  updated_at       TEXT    NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now'))
);
INSERT INTO PortfolioThemeAssetUpdate_new (id, theme_id, instrument_id, title, body_text, body_markdown, type, author, pinned, positions_asof, value_chf, actual_percent, created_at, updated_at)
  SELECT id, theme_id, instrument_id, title, body_text,
         COALESCE(body_markdown, COALESCE(body_text, '')),
         type, author, COALESCE(pinned, 0), positions_asof, value_chf, actual_percent, created_at, updated_at
  FROM PortfolioThemeAssetUpdate;
DROP TABLE PortfolioThemeAssetUpdate;
ALTER TABLE PortfolioThemeAssetUpdate_new RENAME TO PortfolioThemeAssetUpdate;
CREATE INDEX IF NOT EXISTS idx_ptau_theme_instr_order ON PortfolioThemeAssetUpdate(theme_id, instrument_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ptau_theme_instr_pinned_order ON PortfolioThemeAssetUpdate(theme_id, instrument_id, pinned DESC, created_at DESC);

-- migrate:down
-- Recreate tables without 'Investment' in CHECK constraints

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
  SELECT id, theme_id, title, body_text, body_markdown, type, author, pinned, positions_asof, total_value_chf, created_at, updated_at, soft_delete, deleted_at, deleted_by
  FROM PortfolioThemeUpdate
  WHERE type IN ('General','Research','Rebalance','Risk');
DROP TABLE PortfolioThemeUpdate;
ALTER TABLE PortfolioThemeUpdate_old RENAME TO PortfolioThemeUpdate;
CREATE INDEX IF NOT EXISTS idx_ptu_theme_active_order ON PortfolioThemeUpdate(theme_id, soft_delete, pinned, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ptu_theme_deleted_order ON PortfolioThemeUpdate(theme_id, soft_delete, deleted_at DESC);

CREATE TABLE IF NOT EXISTS PortfolioThemeAssetUpdate_old (
  id               INTEGER PRIMARY KEY,
  theme_id         INTEGER NOT NULL REFERENCES PortfolioTheme(id) ON DELETE CASCADE,
  instrument_id    INTEGER NOT NULL REFERENCES Instruments(instrument_id) ON DELETE SET NULL,
  title            TEXT    NOT NULL CHECK (LENGTH(title) BETWEEN 1 AND 120),
  body_text        TEXT    NOT NULL CHECK (LENGTH(body_text) BETWEEN 1 AND 5000),
  body_markdown    TEXT    NOT NULL CHECK (LENGTH(body_markdown) BETWEEN 1 AND 5000),
  type             TEXT    NOT NULL CHECK (type IN ('General','Research','Rebalance','Risk')),
  author           TEXT    NOT NULL,
  pinned           INTEGER NOT NULL DEFAULT 0 CHECK (pinned IN (0,1)),
  positions_asof   TEXT    NULL,
  value_chf        REAL    NULL,
  actual_percent   REAL    NULL,
  created_at       TEXT    NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
  updated_at       TEXT    NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now'))
);
INSERT INTO PortfolioThemeAssetUpdate_old (id, theme_id, instrument_id, title, body_text, body_markdown, type, author, pinned, positions_asof, value_chf, actual_percent, created_at, updated_at)
  SELECT id, theme_id, instrument_id, title, body_text, body_markdown, type, author, pinned, positions_asof, value_chf, actual_percent, created_at, updated_at
  FROM PortfolioThemeAssetUpdate
  WHERE type IN ('General','Research','Rebalance','Risk');
DROP TABLE PortfolioThemeAssetUpdate;
ALTER TABLE PortfolioThemeAssetUpdate_old RENAME TO PortfolioThemeAssetUpdate;
CREATE INDEX IF NOT EXISTS idx_ptau_theme_instr_order ON PortfolioThemeAssetUpdate(theme_id, instrument_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ptau_theme_instr_pinned_order ON PortfolioThemeAssetUpdate(theme_id, instrument_id, pinned DESC, created_at DESC);

