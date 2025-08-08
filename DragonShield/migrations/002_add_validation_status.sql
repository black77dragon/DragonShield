-- migrate:up
ALTER TABLE ClassTargets ADD COLUMN validation_status TEXT NOT NULL DEFAULT 'warning' CHECK(validation_status IN('compliant','warning','error'));
ALTER TABLE SubClassTargets ADD COLUMN validation_status TEXT NOT NULL DEFAULT 'warning' CHECK(validation_status IN('compliant','warning','error'));

UPDATE ClassTargets
SET validation_status =
  CASE
    WHEN ABS((SELECT SUM(target_percent) FROM ClassTargets) - 100.0) <= tolerance_percent THEN 'compliant'
    WHEN ABS((SELECT SUM(target_percent) FROM ClassTargets) - 100.0) <= tolerance_percent*2 THEN 'warning'
    ELSE 'error'
  END;

UPDATE SubClassTargets
SET validation_status =
  CASE
    WHEN ABS((
      SELECT SUM(target_percent)
      FROM SubClassTargets
      WHERE class_target_id=SubClassTargets.class_target_id
    ) - 100.0) <= (
      SELECT tolerance_percent
      FROM ClassTargets
      WHERE id=SubClassTargets.class_target_id
    ) THEN 'compliant'
    WHEN ABS((
      SELECT SUM(target_percent)
      FROM SubClassTargets
      WHERE class_target_id=SubClassTargets.class_target_id
    ) - 100.0) <= (
      SELECT tolerance_percent
      FROM ClassTargets
      WHERE id=SubClassTargets.class_target_id
    )*2 THEN 'warning'
    ELSE 'error'
  END;

UPDATE Configuration SET value='4.22' WHERE key='db_version';

-- migrate:down
ALTER TABLE SubClassTargets DROP COLUMN validation_status;
ALTER TABLE ClassTargets    DROP COLUMN validation_status;
UPDATE Configuration SET value='4.21' WHERE key='db_version';
