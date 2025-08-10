-- migrate:up
-- PRAGMA foreign_keys=ON;
-- Reconcile validation_status with ValidationFindings and add triggers for future sync.
BEGIN;

-- Purge findings for zero-target classes and their subclasses
DELETE FROM ValidationFindings
WHERE entity_type IN ('class','subclass') AND (
    (entity_type='class' AND entity_id IN (
        SELECT id FROM ClassTargets WHERE target_percent = 0 AND COALESCE(target_amount_chf,0) = 0
    ))
    OR
    (entity_type='subclass' AND entity_id IN (
        SELECT sct.id
        FROM SubClassTargets sct
        JOIN ClassTargets ct ON ct.id = sct.class_target_id
        WHERE ct.target_percent = 0 AND COALESCE(ct.target_amount_chf,0) = 0
    ))
);

-- Recompute subclass statuses based on current findings
UPDATE SubClassTargets
SET validation_status = (
  SELECT CASE
    WHEN EXISTS(SELECT 1 FROM ValidationFindings vf WHERE vf.entity_type='subclass' AND vf.entity_id=SubClassTargets.id AND vf.severity='error') THEN 'error'
    WHEN EXISTS(SELECT 1 FROM ValidationFindings vf WHERE vf.entity_type='subclass' AND vf.entity_id=SubClassTargets.id AND vf.severity='warning') THEN 'warning'
    ELSE 'compliant'
  END
);

-- Recompute class statuses considering subclass findings
UPDATE ClassTargets
SET validation_status = (
  SELECT CASE
    WHEN EXISTS(
      SELECT 1 FROM ValidationFindings vf
      WHERE vf.severity='error' AND (
        (vf.entity_type='class' AND vf.entity_id=ClassTargets.id)
        OR (vf.entity_type='subclass' AND vf.entity_id IN (SELECT id FROM SubClassTargets WHERE class_target_id=ClassTargets.id))
      )
    ) THEN 'error'
    WHEN EXISTS(
      SELECT 1 FROM ValidationFindings vf
      WHERE vf.severity='warning' AND (
        (vf.entity_type='class' AND vf.entity_id=ClassTargets.id)
        OR (vf.entity_type='subclass' AND vf.entity_id IN (SELECT id FROM SubClassTargets WHERE class_target_id=ClassTargets.id))
      )
    ) THEN 'warning'
    ELSE 'compliant'
  END
);

-- Trigger: recompute class status after inserting a class-level finding
CREATE TRIGGER trg_vf_ai_class AFTER INSERT ON ValidationFindings
WHEN NEW.entity_type='class'
BEGIN
  UPDATE ClassTargets
  SET validation_status = (
    SELECT CASE
      WHEN EXISTS(
        SELECT 1 FROM ValidationFindings vf
        WHERE vf.severity='error' AND (
          (vf.entity_type='class' AND vf.entity_id=NEW.entity_id)
          OR (vf.entity_type='subclass' AND vf.entity_id IN (SELECT id FROM SubClassTargets WHERE class_target_id=NEW.entity_id))
        )
      ) THEN 'error'
      WHEN EXISTS(
        SELECT 1 FROM ValidationFindings vf
        WHERE vf.severity='warning' AND (
          (vf.entity_type='class' AND vf.entity_id=NEW.entity_id)
          OR (vf.entity_type='subclass' AND vf.entity_id IN (SELECT id FROM SubClassTargets WHERE class_target_id=NEW.entity_id))
        )
      ) THEN 'warning'
      ELSE 'compliant'
    END
  )
  WHERE id=NEW.entity_id;
END;

-- Trigger: recompute subclass and parent class statuses after inserting a subclass finding
CREATE TRIGGER trg_vf_ai_subclass AFTER INSERT ON ValidationFindings
WHEN NEW.entity_type='subclass'
BEGIN
  UPDATE SubClassTargets
  SET validation_status = (
    SELECT CASE
      WHEN EXISTS(SELECT 1 FROM ValidationFindings vf WHERE vf.entity_type='subclass' AND vf.entity_id=NEW.entity_id AND vf.severity='error') THEN 'error'
      WHEN EXISTS(SELECT 1 FROM ValidationFindings vf WHERE vf.entity_type='subclass' AND vf.entity_id=NEW.entity_id AND vf.severity='warning') THEN 'warning'
      ELSE 'compliant'
    END
  )
  WHERE id=NEW.entity_id;

  UPDATE ClassTargets
  SET validation_status = (
    SELECT CASE
      WHEN EXISTS(
        SELECT 1 FROM ValidationFindings vf
        WHERE vf.severity='error' AND (
          (vf.entity_type='class' AND vf.entity_id=ClassTargets.id)
          OR (vf.entity_type='subclass' AND vf.entity_id IN (SELECT id FROM SubClassTargets WHERE class_target_id = ClassTargets.id))
        )
      ) THEN 'error'
      WHEN EXISTS(
        SELECT 1 FROM ValidationFindings vf
        WHERE vf.severity='warning' AND (
          (vf.entity_type='class' AND vf.entity_id=ClassTargets.id)
          OR (vf.entity_type='subclass' AND vf.entity_id IN (SELECT id FROM SubClassTargets WHERE class_target_id = ClassTargets.id))
        )
      ) THEN 'warning'
      ELSE 'compliant'
    END
  )
  WHERE id = (SELECT class_target_id FROM SubClassTargets WHERE id=NEW.entity_id);
END;

-- Trigger: recompute class status after deleting a class-level finding
CREATE TRIGGER trg_vf_ad_class AFTER DELETE ON ValidationFindings
WHEN OLD.entity_type='class'
BEGIN
  UPDATE ClassTargets
  SET validation_status = (
    SELECT CASE
      WHEN EXISTS(
        SELECT 1 FROM ValidationFindings vf
        WHERE vf.severity='error' AND (
          (vf.entity_type='class' AND vf.entity_id=OLD.entity_id)
          OR (vf.entity_type='subclass' AND vf.entity_id IN (SELECT id FROM SubClassTargets WHERE class_target_id=OLD.entity_id))
        )
      ) THEN 'error'
      WHEN EXISTS(
        SELECT 1 FROM ValidationFindings vf
        WHERE vf.severity='warning' AND (
          (vf.entity_type='class' AND vf.entity_id=OLD.entity_id)
          OR (vf.entity_type='subclass' AND vf.entity_id IN (SELECT id FROM SubClassTargets WHERE class_target_id=OLD.entity_id))
        )
      ) THEN 'warning'
      ELSE 'compliant'
    END
  )
  WHERE id=OLD.entity_id;
END;

-- Trigger: recompute subclass and parent class statuses after deleting a subclass finding
CREATE TRIGGER trg_vf_ad_subclass AFTER DELETE ON ValidationFindings
WHEN OLD.entity_type='subclass'
BEGIN
  UPDATE SubClassTargets
  SET validation_status = (
    SELECT CASE
      WHEN EXISTS(SELECT 1 FROM ValidationFindings vf WHERE vf.entity_type='subclass' AND vf.entity_id=OLD.entity_id AND vf.severity='error') THEN 'error'
      WHEN EXISTS(SELECT 1 FROM ValidationFindings vf WHERE vf.entity_type='subclass' AND vf.entity_id=OLD.entity_id AND vf.severity='warning') THEN 'warning'
      ELSE 'compliant'
    END
  )
  WHERE id=OLD.entity_id;

  UPDATE ClassTargets
  SET validation_status = (
    SELECT CASE
      WHEN EXISTS(
        SELECT 1 FROM ValidationFindings vf
        WHERE vf.severity='error' AND (
          (vf.entity_type='class' AND vf.entity_id=ClassTargets.id)
          OR (vf.entity_type='subclass' AND vf.entity_id IN (SELECT id FROM SubClassTargets WHERE class_target_id = ClassTargets.id))
        )
      ) THEN 'error'
      WHEN EXISTS(
        SELECT 1 FROM ValidationFindings vf
        WHERE vf.severity='warning' AND (
          (vf.entity_type='class' AND vf.entity_id=ClassTargets.id)
          OR (vf.entity_type='subclass' AND vf.entity_id IN (SELECT id FROM SubClassTargets WHERE class_target_id = ClassTargets.id))
        )
      ) THEN 'warning'
      ELSE 'compliant'
    END
  )
  WHERE id = (SELECT class_target_id FROM SubClassTargets WHERE id=OLD.entity_id);
END;

-- Trigger: handle updates by recalculating statuses for old and new entities
CREATE TRIGGER trg_vf_au AFTER UPDATE ON ValidationFindings
BEGIN
  -- Recompute for OLD entity
  UPDATE ClassTargets
  SET validation_status = (
    SELECT CASE
      WHEN EXISTS(
        SELECT 1 FROM ValidationFindings vf
        WHERE vf.severity='error' AND (
          (vf.entity_type='class' AND vf.entity_id=OLD.entity_id)
          OR (vf.entity_type='subclass' AND vf.entity_id IN (SELECT id FROM SubClassTargets WHERE class_target_id=OLD.entity_id))
        )
      ) THEN 'error'
      WHEN EXISTS(
        SELECT 1 FROM ValidationFindings vf
        WHERE vf.severity='warning' AND (
          (vf.entity_type='class' AND vf.entity_id=OLD.entity_id)
          OR (vf.entity_type='subclass' AND vf.entity_id IN (SELECT id FROM SubClassTargets WHERE class_target_id=OLD.entity_id))
        )
      ) THEN 'warning'
      ELSE 'compliant'
    END
  )
  WHERE OLD.entity_type='class' AND id=OLD.entity_id;

  UPDATE SubClassTargets
  SET validation_status = (
    SELECT CASE
      WHEN EXISTS(SELECT 1 FROM ValidationFindings vf WHERE vf.entity_type='subclass' AND vf.entity_id=OLD.entity_id AND vf.severity='error') THEN 'error'
      WHEN EXISTS(SELECT 1 FROM ValidationFindings vf WHERE vf.entity_type='subclass' AND vf.entity_id=OLD.entity_id AND vf.severity='warning') THEN 'warning'
      ELSE 'compliant'
    END
  )
  WHERE OLD.entity_type='subclass' AND id=OLD.entity_id;

  UPDATE ClassTargets
  SET validation_status = (
    SELECT CASE
      WHEN EXISTS(
        SELECT 1 FROM ValidationFindings vf
        WHERE vf.severity='error' AND (
          (vf.entity_type='class' AND vf.entity_id=ClassTargets.id)
          OR (vf.entity_type='subclass' AND vf.entity_id IN (SELECT id FROM SubClassTargets WHERE class_target_id = ClassTargets.id))
        )
      ) THEN 'error'
      WHEN EXISTS(
        SELECT 1 FROM ValidationFindings vf
        WHERE vf.severity='warning' AND (
          (vf.entity_type='class' AND vf.entity_id=ClassTargets.id)
          OR (vf.entity_type='subclass' AND vf.entity_id IN (SELECT id FROM SubClassTargets WHERE class_target_id = ClassTargets.id))
        )
      ) THEN 'warning'
      ELSE 'compliant'
    END
  )
  WHERE OLD.entity_type='subclass' AND id = (SELECT class_target_id FROM SubClassTargets WHERE id=OLD.entity_id);

  -- Recompute for NEW entity
  UPDATE ClassTargets
  SET validation_status = (
    SELECT CASE
      WHEN EXISTS(
        SELECT 1 FROM ValidationFindings vf
        WHERE vf.severity='error' AND (
          (vf.entity_type='class' AND vf.entity_id=NEW.entity_id)
          OR (vf.entity_type='subclass' AND vf.entity_id IN (SELECT id FROM SubClassTargets WHERE class_target_id=NEW.entity_id))
        )
      ) THEN 'error'
      WHEN EXISTS(
        SELECT 1 FROM ValidationFindings vf
        WHERE vf.severity='warning' AND (
          (vf.entity_type='class' AND vf.entity_id=NEW.entity_id)
          OR (vf.entity_type='subclass' AND vf.entity_id IN (SELECT id FROM SubClassTargets WHERE class_target_id=NEW.entity_id))
        )
      ) THEN 'warning'
      ELSE 'compliant'
    END
  )
  WHERE NEW.entity_type='class' AND id=NEW.entity_id;

  UPDATE SubClassTargets
  SET validation_status = (
    SELECT CASE
      WHEN EXISTS(SELECT 1 FROM ValidationFindings vf WHERE vf.entity_type='subclass' AND vf.entity_id=NEW.entity_id AND vf.severity='error') THEN 'error'
      WHEN EXISTS(SELECT 1 FROM ValidationFindings vf WHERE vf.entity_type='subclass' AND vf.entity_id=NEW.entity_id AND vf.severity='warning') THEN 'warning'
      ELSE 'compliant'
    END
  )
  WHERE NEW.entity_type='subclass' AND id=NEW.entity_id;

  UPDATE ClassTargets
  SET validation_status = (
    SELECT CASE
      WHEN EXISTS(
        SELECT 1 FROM ValidationFindings vf
        WHERE vf.severity='error' AND (
          (vf.entity_type='class' AND vf.entity_id=ClassTargets.id)
          OR (vf.entity_type='subclass' AND vf.entity_id IN (SELECT id FROM SubClassTargets WHERE class_target_id = ClassTargets.id))
        )
      ) THEN 'error'
      WHEN EXISTS(
        SELECT 1 FROM ValidationFindings vf
        WHERE vf.severity='warning' AND (
          (vf.entity_type='class' AND vf.entity_id=ClassTargets.id)
          OR (vf.entity_type='subclass' AND vf.entity_id IN (SELECT id FROM SubClassTargets WHERE class_target_id = ClassTargets.id))
        )
      ) THEN 'warning'
      ELSE 'compliant'
    END
  )
  WHERE NEW.entity_type='subclass' AND id = (SELECT class_target_id FROM SubClassTargets WHERE id=NEW.entity_id);
END;

-- Trigger: when a class target is set to zero, purge findings and mark compliant
CREATE TRIGGER trg_ct_zero_ai AFTER INSERT ON ClassTargets
WHEN NEW.target_percent = 0 AND COALESCE(NEW.target_amount_chf,0) = 0
BEGIN
  DELETE FROM ValidationFindings WHERE entity_type='class' AND entity_id=NEW.id;
  DELETE FROM ValidationFindings WHERE entity_type='subclass' AND entity_id IN (SELECT id FROM SubClassTargets WHERE class_target_id=NEW.id);
  UPDATE SubClassTargets SET validation_status='compliant' WHERE class_target_id=NEW.id;
  UPDATE ClassTargets SET validation_status='compliant' WHERE id=NEW.id;
END;

CREATE TRIGGER trg_ct_zero_au AFTER UPDATE ON ClassTargets
WHEN NEW.target_percent = 0 AND COALESCE(NEW.target_amount_chf,0) = 0
BEGIN
  DELETE FROM ValidationFindings WHERE entity_type='class' AND entity_id=NEW.id;
  DELETE FROM ValidationFindings WHERE entity_type='subclass' AND entity_id IN (SELECT id FROM SubClassTargets WHERE class_target_id=NEW.id);
  UPDATE SubClassTargets SET validation_status='compliant' WHERE class_target_id=NEW.id;
  UPDATE ClassTargets SET validation_status='compliant' WHERE id=NEW.id;
END;

-- Bump db version
UPDATE Configuration SET value = '4.25' WHERE key = 'db_version';

COMMIT;

-- migrate:down
-- PRAGMA foreign_keys=ON;
-- Drop sync triggers; data cleanup is not reversible.
BEGIN;
DROP TRIGGER IF EXISTS trg_vf_ai_class;
DROP TRIGGER IF EXISTS trg_vf_ai_subclass;
DROP TRIGGER IF EXISTS trg_vf_ad_class;
DROP TRIGGER IF EXISTS trg_vf_ad_subclass;
DROP TRIGGER IF EXISTS trg_vf_au;
DROP TRIGGER IF EXISTS trg_ct_zero_ai;
DROP TRIGGER IF EXISTS trg_ct_zero_au;
UPDATE Configuration SET value = '4.24' WHERE key = 'db_version';
COMMIT;
