ALTER TABLE TargetAllocation
  ADD COLUMN target_kind TEXT NOT NULL DEFAULT 'percent' CHECK(target_kind IN('percent','amount'));

ALTER TABLE TargetAllocation
  ADD COLUMN tolerance_percent REAL NOT NULL DEFAULT 5.0;
