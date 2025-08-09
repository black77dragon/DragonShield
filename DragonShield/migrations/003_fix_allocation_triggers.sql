-- migrate:up
-- Ensure trigger recursion won't cascade unexpectedly
PRAGMA recursive_triggers = OFF;

-- 0) Drop any old/buggy triggers if present (cover prior names)
DROP TRIGGER IF EXISTS trg_validate_class_targets_insert;
DROP TRIGGER IF EXISTS trg_validate_class_targets_update;
DROP TRIGGER IF EXISTS trg_validate_subclass_targets_insert;
DROP TRIGGER IF EXISTS trg_validate_subclass_targets_update;
DROP TRIGGER IF EXISTS trg_ct_after_aiu;
DROP TRIGGER IF EXISTS trg_sct_after_aiu;

----------------------------------------------------------------------
-- 1) ClassTargets validation & logging
--    We must create two triggers (INSERT / UPDATE). SQLite doesn’t allow
--    "AFTER INSERT OR UPDATE" in a single trigger.
----------------------------------------------------------------------

-- AFTER INSERT on ClassTargets
CREATE TRIGGER trg_ct_after_insert
AFTER INSERT ON ClassTargets
BEGIN
  -- Log global portfolio % drift if off by > ±0.10%
  INSERT INTO TargetChangeLog(target_type, target_id, field_name, old_value, new_value, changed_by)
  SELECT 'class', NEW.id, 'portfolio_class_percent_sum',
         NULL,
         printf('%.4f', (SELECT COALESCE(SUM(ct2.target_percent), 0.0) FROM ClassTargets ct2)),
         'trigger'
  WHERE ABS((SELECT COALESCE(SUM(ct2.target_percent), 0.0) FROM ClassTargets ct2) - 100.0) > 0.1;

  -- Update this row’s validation_status:
  --   error    -> any negative (defensive; CHECK should prevent)
  --   warning  -> portfolio % sum drift > ±0.10%
  --   compliant otherwise
  UPDATE ClassTargets
  SET validation_status =
      CASE
        WHEN NEW.target_percent    < 0.0 OR NEW.target_amount_chf < 0.0 THEN 'error'
        WHEN ABS((SELECT COALESCE(SUM(ct3.target_percent), 0.0) FROM ClassTargets ct3) - 100.0) > 0.1 THEN 'warning'
        ELSE 'compliant'
      END,
      updated_at = CURRENT_TIMESTAMP
  WHERE id = NEW.id;
END;

-- AFTER UPDATE on ClassTargets
CREATE TRIGGER trg_ct_after_update
AFTER UPDATE ON ClassTargets
BEGIN
  -- Log global portfolio % drift if off by > ±0.10%
  INSERT INTO TargetChangeLog(target_type, target_id, field_name, old_value, new_value, changed_by)
  SELECT 'class', NEW.id, 'portfolio_class_percent_sum',
         NULL,
         printf('%.4f', (SELECT COALESCE(SUM(ct2.target_percent), 0.0) FROM ClassTargets ct2)),
         'trigger'
  WHERE ABS((SELECT COALESCE(SUM(ct2.target_percent), 0.0) FROM ClassTargets ct2) - 100.0) > 0.1;

  -- Update this row’s validation_status
  UPDATE ClassTargets
  SET validation_status =
      CASE
        WHEN NEW.target_percent    < 0.0 OR NEW.target_amount_chf < 0.0 THEN 'error'
        WHEN ABS((SELECT COALESCE(SUM(ct3.target_percent), 0.0) FROM ClassTargets ct3) - 100.0) > 0.1 THEN 'warning'
        ELSE 'compliant'
      END,
      updated_at = CURRENT_TIMESTAMP
  WHERE id = NEW.id;
END;

----------------------------------------------------------------------
-- 2) SubClassTargets validation & logging
--    Two triggers (INSERT / UPDATE). Bubble warnings up to parent class
--    if child % sum deviates beyond parent tolerance.
----------------------------------------------------------------------

-- AFTER INSERT on SubClassTargets
CREATE TRIGGER trg_sct_after_insert
AFTER INSERT ON SubClassTargets
BEGIN
  -- Log child % sum vs tolerance (non-blocking)
  INSERT INTO TargetChangeLog(target_type, target_id, field_name, old_value, new_value, changed_by)
  SELECT 'class', NEW.class_target_id, 'child_percent_sum_vs_tol',
         NULL,
         printf('sum=%.4f tol=%.4f',
                (SELECT COALESCE(SUM(sct2.target_percent), 0.0)
                   FROM SubClassTargets sct2
                  WHERE sct2.class_target_id = NEW.class_target_id),
                (SELECT COALESCE(ct2.tolerance_percent, 0.0)
                   FROM ClassTargets ct2
                  WHERE ct2.id = NEW.class_target_id)),
         'trigger'
  WHERE ABS(
          (SELECT COALESCE(SUM(sct3.target_percent), 0.0)
             FROM SubClassTargets sct3
            WHERE sct3.class_target_id = NEW.class_target_id) - 100.0
        ) >
        (SELECT COALESCE(ct3.tolerance_percent, 0.0)
           FROM ClassTargets ct3
          WHERE ct3.id = NEW.class_target_id);

  -- Sub-class row validation (basic)
  UPDATE SubClassTargets
  SET validation_status =
      CASE
        WHEN NEW.target_percent    < 0.0 OR NEW.target_amount_chf < 0.0 THEN 'error'
        ELSE 'compliant'
      END,
      updated_at = CURRENT_TIMESTAMP
  WHERE id = NEW.id;

  -- Bubble warning to parent if child % sum beyond tolerance (do not override 'error')
  UPDATE ClassTargets
  SET validation_status =
      CASE
        WHEN validation_status = 'error' THEN 'error'
        ELSE 'warning'
      END,
      updated_at = CURRENT_TIMESTAMP
  WHERE id = NEW.class_target_id
    AND ABS(
          (SELECT COALESCE(SUM(sct4.target_percent), 0.0)
             FROM SubClassTargets sct4
            WHERE sct4.class_target_id = NEW.class_target_id) - 100.0
        ) >
        (SELECT COALESCE(ct4.tolerance_percent, 0.0)
           FROM ClassTargets ct4
          WHERE ct4.id = NEW.class_target_id);
END;

-- AFTER UPDATE on SubClassTargets
CREATE TRIGGER trg_sct_after_update
AFTER UPDATE ON SubClassTargets
BEGIN
  -- Log child % sum vs tolerance (non-blocking)
  INSERT INTO TargetChangeLog(target_type, target_id, field_name, old_value, new_value, changed_by)
  SELECT 'class', NEW.class_target_id, 'child_percent_sum_vs_tol',
         NULL,
         printf('sum=%.4f tol=%.4f',
                (SELECT COALESCE(SUM(sct2.target_percent), 0.0)
                   FROM SubClassTargets sct2
                  WHERE sct2.class_target_id = NEW.class_target_id),
                (SELECT COALESCE(ct2.tolerance_percent, 0.0)
                   FROM ClassTargets ct2
                  WHERE ct2.id = NEW.class_target_id)),
         'trigger'
  WHERE ABS(
          (SELECT COALESCE(SUM(sct3.target_percent), 0.0)
             FROM SubClassTargets sct3
            WHERE sct3.class_target_id = NEW.class_target_id) - 100.0
        ) >
        (SELECT COALESCE(ct3.tolerance_percent, 0.0)
           FROM ClassTargets ct3
          WHERE ct3.id = NEW.class_target_id);

  -- Sub-class row validation (basic)
  UPDATE SubClassTargets
  SET validation_status =
      CASE
        WHEN NEW.target_percent    < 0.0 OR NEW.target_amount_chf < 0.0 THEN 'error'
        ELSE 'compliant'
      END,
      updated_at = CURRENT_TIMESTAMP
  WHERE id = NEW.id;

  -- Bubble warning to parent if child % sum beyond tolerance (do not override 'error')
  UPDATE ClassTargets
  SET validation_status =
      CASE
        WHEN validation_status = 'error' THEN 'error'
        ELSE 'warning'
      END,
      updated_at = CURRENT_TIMESTAMP
  WHERE id = NEW.class_target_id
    AND ABS(
          (SELECT COALESCE(SUM(sct4.target_percent), 0.0)
             FROM SubClassTargets sct4
            WHERE sct4.class_target_id = NEW.class_target_id) - 100.0
        ) >
        (SELECT COALESCE(ct4.tolerance_percent, 0.0)
           FROM ClassTargets ct4
          WHERE ct4.id = NEW.class_target_id);
END;

----------------------------------------------------------------------
-- 3) Backfill validation_status for existing rows (idempotent)
----------------------------------------------------------------------

-- Classes backfill
UPDATE ClassTargets
SET validation_status =
    CASE
      WHEN target_percent < 0.0 OR target_amount_chf < 0.0 THEN 'error'
      WHEN ABS((SELECT COALESCE(SUM(ct5.target_percent), 0.0) FROM ClassTargets ct5) - 100.0) > 0.1 THEN 'warning'
      ELSE 'compliant'
    END,
    updated_at = CURRENT_TIMESTAMP;

-- Sub-classes backfill
UPDATE SubClassTargets
SET validation_status =
    CASE
      WHEN target_percent < 0.0 OR target_amount_chf < 0.0 THEN 'error'
      ELSE 'compliant'
    END,
    updated_at = CURRENT_TIMESTAMP;

-- Bubble warnings to parents where child sum exceeds tolerance
UPDATE ClassTargets
SET validation_status =
    CASE
      WHEN validation_status = 'error' THEN 'error'
      ELSE 'warning'
    END,
    updated_at = CURRENT_TIMESTAMP
WHERE EXISTS (
  SELECT 1
  FROM (
    SELECT sct6.class_target_id AS cid,
           ABS(SUM(sct6.target_percent) - 100.0) AS drift
    FROM SubClassTargets sct6
    GROUP BY sct6.class_target_id
  ) x
  JOIN ClassTargets ct6 ON ct6.id = x.cid
  WHERE ClassTargets.id = x.cid
    AND x.drift > COALESCE(ct6.tolerance_percent, 0.0)
);

-- Optional: bump a config flag if you track schema versions
UPDATE Configuration SET value = '4.23' WHERE key = 'db_version';

-- migrate:down
-- Remove only the triggers created by this migration
DROP TRIGGER IF EXISTS trg_ct_after_insert;
DROP TRIGGER IF EXISTS trg_ct_after_update;
DROP TRIGGER IF EXISTS trg_sct_after_insert;
DROP TRIGGER IF EXISTS trg_sct_after_update;
