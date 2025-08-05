CREATE TABLE ClassTargets (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  asset_class_id INTEGER NOT NULL REFERENCES AssetClasses(class_id),
  target_kind TEXT NOT NULL CHECK(target_kind IN('percent','amount')),
  target_percent REAL DEFAULT 0,
  target_amount_chf REAL DEFAULT 0,
  tolerance_percent REAL DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT ck_class_nonneg CHECK(target_percent >= 0 AND target_amount_chf >= 0),
  CONSTRAINT uq_class UNIQUE(asset_class_id)
);

CREATE TABLE SubClassTargets (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  class_target_id INTEGER NOT NULL REFERENCES ClassTargets(id) ON DELETE CASCADE,
  asset_sub_class_id INTEGER NOT NULL REFERENCES AssetSubClasses(sub_class_id),
  target_kind TEXT NOT NULL CHECK(target_kind IN('percent','amount')),
  target_percent REAL DEFAULT 0,
  target_amount_chf REAL DEFAULT 0,
  tolerance_percent REAL DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT ck_sub_nonneg CHECK(target_percent >= 0 AND target_amount_chf >= 0),
  CONSTRAINT uq_sub UNIQUE(class_target_id, asset_sub_class_id)
);

CREATE TABLE TargetChangeLog (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  target_type TEXT NOT NULL CHECK(target_type IN('class','subclass')),
  target_id INTEGER NOT NULL,
  field_name TEXT NOT NULL,
  old_value TEXT,
  new_value TEXT,
  changed_by TEXT,
  changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO ClassTargets (asset_class_id, target_kind, target_percent, target_amount_chf, tolerance_percent, created_at, updated_at)
SELECT asset_class_id,
       CASE WHEN target_kind IS NOT NULL THEN target_kind
            WHEN target_percent IS NOT NULL THEN 'percent'
            ELSE 'amount' END,
       COALESCE(target_percent,0),
       COALESCE(target_amount_chf,0),
       COALESCE(tolerance_percent,0),
       COALESCE(updated_at,CURRENT_TIMESTAMP),
       COALESCE(updated_at,CURRENT_TIMESTAMP)
FROM TargetAllocation
WHERE sub_class_id IS NULL;

INSERT INTO TargetChangeLog (target_type, target_id, field_name, old_value, new_value, changed_by)
SELECT 'class', id, 'migration', NULL, 'backfill', 'script'
FROM ClassTargets;

INSERT INTO SubClassTargets (class_target_id, asset_sub_class_id, target_kind, target_percent, target_amount_chf, tolerance_percent, created_at, updated_at)
SELECT ct.id, ta.sub_class_id,
       CASE WHEN ta.target_kind IS NOT NULL THEN ta.target_kind
            WHEN ta.target_percent IS NOT NULL THEN 'percent'
            ELSE 'amount' END,
       COALESCE(ta.target_percent,0),
       COALESCE(ta.target_amount_chf,0),
       COALESCE(ta.tolerance_percent,0),
       COALESCE(ta.updated_at,CURRENT_TIMESTAMP),
       COALESCE(ta.updated_at,CURRENT_TIMESTAMP)
FROM TargetAllocation ta
JOIN ClassTargets ct ON ct.asset_class_id = ta.asset_class_id
WHERE ta.sub_class_id IS NOT NULL;

INSERT INTO TargetChangeLog (target_type, target_id, field_name, old_value, new_value, changed_by)
SELECT 'subclass', id, 'migration', NULL, 'backfill', 'script'
FROM SubClassTargets;

DROP TABLE TargetAllocation;
