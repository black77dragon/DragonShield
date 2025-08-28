-- migrate:up
-- Purpose: Add type_id FK to reference NewsType, backfill existing rows,
--          add indexes and dual-write triggers to keep type and type_id in sync.

-- 1) Add type_id columns (nullable during transition)
ALTER TABLE PortfolioThemeUpdate ADD COLUMN type_id INTEGER NULL REFERENCES NewsType(id);
ALTER TABLE PortfolioThemeAssetUpdate ADD COLUMN type_id INTEGER NULL REFERENCES NewsType(id);

-- 2) Backfill from existing type codes
UPDATE PortfolioThemeUpdate
SET type_id = (SELECT id FROM NewsType WHERE code = PortfolioThemeUpdate.type)
WHERE type_id IS NULL;

UPDATE PortfolioThemeAssetUpdate
SET type_id = (SELECT id FROM NewsType WHERE code = PortfolioThemeAssetUpdate.type)
WHERE type_id IS NULL;

-- 3) Indexes for future joins/filters
CREATE INDEX IF NOT EXISTS idx_ptu_type_id ON PortfolioThemeUpdate(type_id);
CREATE INDEX IF NOT EXISTS idx_ptau_type_id ON PortfolioThemeAssetUpdate(type_id);

-- 4) Dual-write triggers: prefer to fill the missing side; keep values consistent

-- Theme updates: AFTER INSERT/UPDATE, set missing or mismatched fields
CREATE TRIGGER IF NOT EXISTS ptu_ai_type_sync
AFTER INSERT ON PortfolioThemeUpdate
FOR EACH ROW
BEGIN
  -- If type_id missing but type provided, backfill id
  UPDATE PortfolioThemeUpdate
    SET type_id = (SELECT id FROM NewsType WHERE code = NEW.type)
    WHERE id = NEW.id AND NEW.type_id IS NULL AND NEW.type IS NOT NULL;

  -- If both present but code mismatched, normalize type to match id
  UPDATE PortfolioThemeUpdate
    SET type = (SELECT code FROM NewsType WHERE id = NEW.type_id)
    WHERE id = NEW.id AND NEW.type_id IS NOT NULL AND NEW.type IS NOT NULL
      AND EXISTS (SELECT 1 FROM NewsType WHERE id = NEW.type_id AND code <> NEW.type);
END;

CREATE TRIGGER IF NOT EXISTS ptu_au_type_sync
AFTER UPDATE OF type, type_id ON PortfolioThemeUpdate
FOR EACH ROW
BEGIN
  -- If type_id now NULL but type set, backfill id
  UPDATE PortfolioThemeUpdate
    SET type_id = (SELECT id FROM NewsType WHERE code = NEW.type)
    WHERE id = NEW.id AND NEW.type_id IS NULL AND NEW.type IS NOT NULL;

  -- If both present but code mismatched, normalize type to match id
  UPDATE PortfolioThemeUpdate
    SET type = (SELECT code FROM NewsType WHERE id = NEW.type_id)
    WHERE id = NEW.id AND NEW.type_id IS NOT NULL AND NEW.type IS NOT NULL
      AND EXISTS (SELECT 1 FROM NewsType WHERE id = NEW.type_id AND code <> NEW.type);
END;

-- Asset updates: AFTER INSERT/UPDATE, set missing or mismatched fields
CREATE TRIGGER IF NOT EXISTS ptau_ai_type_sync
AFTER INSERT ON PortfolioThemeAssetUpdate
FOR EACH ROW
BEGIN
  -- If type_id missing but type provided, backfill id
  UPDATE PortfolioThemeAssetUpdate
    SET type_id = (SELECT id FROM NewsType WHERE code = NEW.type)
    WHERE id = NEW.id AND NEW.type_id IS NULL AND NEW.type IS NOT NULL;

  -- If both present but code mismatched, normalize type to match id
  UPDATE PortfolioThemeAssetUpdate
    SET type = (SELECT code FROM NewsType WHERE id = NEW.type_id)
    WHERE id = NEW.id AND NEW.type_id IS NOT NULL AND NEW.type IS NOT NULL
      AND EXISTS (SELECT 1 FROM NewsType WHERE id = NEW.type_id AND code <> NEW.type);
END;

CREATE TRIGGER IF NOT EXISTS ptau_au_type_sync
AFTER UPDATE OF type, type_id ON PortfolioThemeAssetUpdate
FOR EACH ROW
BEGIN
  -- If type_id now NULL but type set, backfill id
  UPDATE PortfolioThemeAssetUpdate
    SET type_id = (SELECT id FROM NewsType WHERE code = NEW.type)
    WHERE id = NEW.id AND NEW.type_id IS NULL AND NEW.type IS NOT NULL;

  -- If both present but code mismatched, normalize type to match id
  UPDATE PortfolioThemeAssetUpdate
    SET type = (SELECT code FROM NewsType WHERE id = NEW.type_id)
    WHERE id = NEW.id AND NEW.type_id IS NOT NULL AND NEW.type IS NOT NULL
      AND EXISTS (SELECT 1 FROM NewsType WHERE id = NEW.type_id AND code <> NEW.type);
END;

-- migrate:down
-- Best-effort rollback: drop triggers and indexes. Columns will remain.
DROP TRIGGER IF EXISTS ptau_au_type_sync;
DROP TRIGGER IF EXISTS ptau_ai_type_sync;
DROP TRIGGER IF EXISTS ptu_au_type_sync;
DROP TRIGGER IF EXISTS ptu_ai_type_sync;

DROP INDEX IF EXISTS idx_ptau_type_id;
DROP INDEX IF EXISTS idx_ptu_type_id;

