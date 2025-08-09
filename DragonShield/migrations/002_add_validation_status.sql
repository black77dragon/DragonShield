-- migrate:up
ALTER TABLE ClassTargets
  ADD COLUMN validation_status TEXT NOT NULL DEFAULT 'warning'
    CHECK(validation_status IN('compliant','warning','error'));

ALTER TABLE SubClassTargets
  ADD COLUMN validation_status TEXT NOT NULL DEFAULT 'warning'
    CHECK(validation_status IN('compliant','warning','error'));
-- migrate:down
-- (no down; once added, we’ll keep these columns)
