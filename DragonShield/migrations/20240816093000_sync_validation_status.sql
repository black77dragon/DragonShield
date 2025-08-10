-- migrate:up
-- PRAGMA foreign_keys=ON;
-- Sync validation_status with ValidationFindings and purge stale zero-target entries.
BEGIN;

-- Purge findings for classes with zero targets
DELETE FROM ValidationFindings
WHERE entity_type IN ('class','subclass')
  AND (
    (entity_type='class' AND entity_id IN (
       SELECT id FROM ClassTargets
       WHERE target_percent = 0 AND COALESCE(target_amount_chf,0) = 0
    ))
    OR
    (entity_type='subclass' AND entity_id IN (
       SELECT sct.id
       FROM SubClassTargets sct
       JOIN ClassTargets ct ON ct.id = sct.class_target_id
       WHERE ct.target_percent = 0 AND COALESCE(ct.target_amount_chf,0) = 0
    ))
  );

-- Recompute SubClassTargets statuses
UPDATE SubClassTargets
SET validation_status = CASE
    WHEN EXISTS(SELECT 1 FROM ValidationFindings WHERE entity_type='subclass' AND entity_id=SubClassTargets.id AND severity='error') THEN 'error'
    WHEN EXISTS(SELECT 1 FROM ValidationFindings WHERE entity_type='subclass' AND entity_id=SubClassTargets.id AND severity='warning') THEN 'warning'
    ELSE 'compliant'
END;

-- Recompute ClassTargets statuses considering subclasses
UPDATE ClassTargets
SET validation_status = CASE
    WHEN EXISTS(
        SELECT 1 FROM ValidationFindings vf
        WHERE vf.severity='error'
          AND (
            (vf.entity_type='class' AND vf.entity_id=ClassTargets.id) OR
            (vf.entity_type='subclass' AND vf.entity_id IN (
                SELECT id FROM SubClassTargets WHERE class_target_id=ClassTargets.id
            ))
          )
    ) THEN 'error'
    WHEN EXISTS(
        SELECT 1 FROM ValidationFindings vf
        WHERE vf.severity='warning'
          AND (
            (vf.entity_type='class' AND vf.entity_id=ClassTargets.id) OR
            (vf.entity_type='subclass' AND vf.entity_id IN (
                SELECT id FROM SubClassTargets WHERE class_target_id=ClassTargets.id
            ))
          )
    ) THEN 'warning'
    ELSE 'compliant'
END;

-- Update database version
UPDATE Configuration SET value='4.26' WHERE key='db_version';

-- Trigger: sync status after insert on ValidationFindings
CREATE TRIGGER trg_vf_after_insert
AFTER INSERT ON ValidationFindings
BEGIN
  UPDATE SubClassTargets
  SET validation_status = CASE
      WHEN EXISTS(SELECT 1 FROM ValidationFindings WHERE entity_type='subclass' AND entity_id=NEW.entity_id AND severity='error') THEN 'error'
      WHEN EXISTS(SELECT 1 FROM ValidationFindings WHERE entity_type='subclass' AND entity_id=NEW.entity_id AND severity='warning') THEN 'warning'
      ELSE 'compliant'
  END
  WHERE NEW.entity_type='subclass' AND id=NEW.entity_id;

  UPDATE ClassTargets
  SET validation_status = CASE
      WHEN EXISTS(
        SELECT 1 FROM ValidationFindings vf
        WHERE vf.severity='error'
          AND (
            (vf.entity_type='class' AND vf.entity_id=ClassTargets.id) OR
            (vf.entity_type='subclass' AND vf.entity_id IN (SELECT id FROM SubClassTargets WHERE class_target_id=ClassTargets.id))
          )
      ) THEN 'error'
      WHEN EXISTS(
        SELECT 1 FROM ValidationFindings vf
        WHERE vf.severity='warning'
          AND (
            (vf.entity_type='class' AND vf.entity_id=ClassTargets.id) OR
            (vf.entity_type='subclass' AND vf.entity_id IN (SELECT id FROM SubClassTargets WHERE class_target_id=ClassTargets.id))
          )
      ) THEN 'warning'
      ELSE 'compliant'
  END
  WHERE id = CASE
      WHEN NEW.entity_type='class' THEN NEW.entity_id
      ELSE (SELECT class_target_id FROM SubClassTargets WHERE id=NEW.entity_id)
  END;
END;

-- Trigger: sync status after delete on ValidationFindings
CREATE TRIGGER trg_vf_after_delete
AFTER DELETE ON ValidationFindings
BEGIN
  UPDATE SubClassTargets
  SET validation_status = CASE
      WHEN EXISTS(SELECT 1 FROM ValidationFindings WHERE entity_type='subclass' AND entity_id=OLD.entity_id AND severity='error') THEN 'error'
      WHEN EXISTS(SELECT 1 FROM ValidationFindings WHERE entity_type='subclass' AND entity_id=OLD.entity_id AND severity='warning') THEN 'warning'
      ELSE 'compliant'
  END
  WHERE OLD.entity_type='subclass' AND id=OLD.entity_id;

  UPDATE ClassTargets
  SET validation_status = CASE
      WHEN EXISTS(
        SELECT 1 FROM ValidationFindings vf
        WHERE vf.severity='error'
          AND (
            (vf.entity_type='class' AND vf.entity_id=ClassTargets.id) OR
            (vf.entity_type='subclass' AND vf.entity_id IN (SELECT id FROM SubClassTargets WHERE class_target_id=ClassTargets.id))
          )
      ) THEN 'error'
      WHEN EXISTS(
        SELECT 1 FROM ValidationFindings vf
        WHERE vf.severity='warning'
          AND (
            (vf.entity_type='class' AND vf.entity_id=ClassTargets.id) OR
            (vf.entity_type='subclass' AND vf.entity_id IN (SELECT id FROM SubClassTargets WHERE class_target_id=ClassTargets.id))
          )
      ) THEN 'warning'
      ELSE 'compliant'
  END
  WHERE id = CASE
      WHEN OLD.entity_type='class' THEN OLD.entity_id
      ELSE (SELECT class_target_id FROM SubClassTargets WHERE id=OLD.entity_id)
  END;
END;

-- Trigger: sync status after update on ValidationFindings
CREATE TRIGGER trg_vf_after_update
AFTER UPDATE ON ValidationFindings
BEGIN
  -- Recompute using OLD values
  UPDATE SubClassTargets
  SET validation_status = CASE
      WHEN EXISTS(SELECT 1 FROM ValidationFindings WHERE entity_type='subclass' AND entity_id=OLD.entity_id AND severity='error') THEN 'error'
      WHEN EXISTS(SELECT 1 FROM ValidationFindings WHERE entity_type='subclass' AND entity_id=OLD.entity_id AND severity='warning') THEN 'warning'
      ELSE 'compliant'
  END
  WHERE OLD.entity_type='subclass' AND id=OLD.entity_id;

  UPDATE ClassTargets
  SET validation_status = CASE
      WHEN EXISTS(
        SELECT 1 FROM ValidationFindings vf
        WHERE vf.severity='error'
          AND (
            (vf.entity_type='class' AND vf.entity_id=ClassTargets.id) OR
            (vf.entity_type='subclass' AND vf.entity_id IN (SELECT id FROM SubClassTargets WHERE class_target_id=ClassTargets.id))
          )
      ) THEN 'error'
      WHEN EXISTS(
        SELECT 1 FROM ValidationFindings vf
        WHERE vf.severity='warning'
          AND (
            (vf.entity_type='class' AND vf.entity_id=ClassTargets.id) OR
            (vf.entity_type='subclass' AND vf.entity_id IN (SELECT id FROM SubClassTargets WHERE class_target_id=ClassTargets.id))
          )
      ) THEN 'warning'
      ELSE 'compliant'
  END
  WHERE id = CASE
      WHEN OLD.entity_type='class' THEN OLD.entity_id
      ELSE (SELECT class_target_id FROM SubClassTargets WHERE id=OLD.entity_id)
  END;

  -- Recompute using NEW values
  UPDATE SubClassTargets
  SET validation_status = CASE
      WHEN EXISTS(SELECT 1 FROM ValidationFindings WHERE entity_type='subclass' AND entity_id=NEW.entity_id AND severity='error') THEN 'error'
      WHEN EXISTS(SELECT 1 FROM ValidationFindings WHERE entity_type='subclass' AND entity_id=NEW.entity_id AND severity='warning') THEN 'warning'
      ELSE 'compliant'
  END
  WHERE NEW.entity_type='subclass' AND id=NEW.entity_id;

  UPDATE ClassTargets
  SET validation_status = CASE
      WHEN EXISTS(
        SELECT 1 FROM ValidationFindings vf
        WHERE vf.severity='error'
          AND (
            (vf.entity_type='class' AND vf.entity_id=ClassTargets.id) OR
            (vf.entity_type='subclass' AND vf.entity_id IN (SELECT id FROM SubClassTargets WHERE class_target_id=ClassTargets.id))
          )
      ) THEN 'error'
      WHEN EXISTS(
        SELECT 1 FROM ValidationFindings vf
        WHERE vf.severity='warning'
          AND (
            (vf.entity_type='class' AND vf.entity_id=ClassTargets.id) OR
            (vf.entity_type='subclass' AND vf.entity_id IN (SELECT id FROM SubClassTargets WHERE class_target_id=ClassTargets.id))
          )
      ) THEN 'warning'
      ELSE 'compliant'
  END
  WHERE id = CASE
      WHEN NEW.entity_type='class' THEN NEW.entity_id
      ELSE (SELECT class_target_id FROM SubClassTargets WHERE id=NEW.entity_id)
  END;
END;

-- Trigger: zero-target skip rule on ClassTargets
CREATE TRIGGER trg_ct_zero_target
AFTER INSERT OR UPDATE ON ClassTargets
WHEN NEW.target_percent = 0 AND COALESCE(NEW.target_amount_chf,0) = 0
BEGIN
  DELETE FROM ValidationFindings
  WHERE (entity_type='class' AND entity_id=NEW.id)
     OR (entity_type='subclass' AND entity_id IN (SELECT id FROM SubClassTargets WHERE class_target_id=NEW.id));
  UPDATE ClassTargets SET validation_status='compliant' WHERE id=NEW.id;
  UPDATE SubClassTargets SET validation_status='compliant' WHERE class_target_id=NEW.id;
END;

COMMIT;

-- migrate:down
-- PRAGMA foreign_keys=ON;
-- Drop validation sync triggers (data clean-up not reverted).
BEGIN;
DROP TRIGGER IF EXISTS trg_vf_after_insert;
DROP TRIGGER IF EXISTS trg_vf_after_delete;
DROP TRIGGER IF EXISTS trg_vf_after_update;
DROP TRIGGER IF EXISTS trg_ct_zero_target;
COMMIT;
