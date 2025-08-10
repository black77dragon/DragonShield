-- migrate:up
-- Sync validation_status with ValidationFindings and purge zero-target findings
BEGIN;

-- 1) Purge stale findings for zero-target classes
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

-- 2) Recompute SubClassTargets statuses
UPDATE SubClassTargets AS sct
SET validation_status = (
  CASE
    WHEN EXISTS (
      SELECT 1 FROM ValidationFindings vf
      WHERE vf.entity_type='subclass' AND vf.entity_id=sct.id AND vf.severity='error'
    ) THEN 'error'
    WHEN EXISTS (
      SELECT 1 FROM ValidationFindings vf
      WHERE vf.entity_type='subclass' AND vf.entity_id=sct.id AND vf.severity='warning'
    ) THEN 'warning'
    ELSE 'compliant'
  END
);

-- 3) Recompute ClassTargets statuses considering subclasses
UPDATE ClassTargets AS ct
SET validation_status = (
  CASE
    WHEN EXISTS (
      SELECT 1 FROM ValidationFindings vf
      WHERE vf.entity_type='class' AND vf.entity_id=ct.id AND vf.severity='error'
    ) OR EXISTS (
      SELECT 1 FROM ValidationFindings vf
      JOIN SubClassTargets s ON vf.entity_type='subclass' AND vf.entity_id=s.id
      WHERE s.class_target_id=ct.id AND vf.severity='error'
    ) THEN 'error'
    WHEN EXISTS (
      SELECT 1 FROM ValidationFindings vf
      WHERE vf.entity_type='class' AND vf.entity_id=ct.id AND vf.severity='warning'
    ) OR EXISTS (
      SELECT 1 FROM ValidationFindings vf
      JOIN SubClassTargets s ON vf.entity_type='subclass' AND vf.entity_id=s.id
      WHERE s.class_target_id=ct.id AND vf.severity='warning'
    ) THEN 'warning'
    ELSE 'compliant'
  END
);

-- 4) Trigger: after INSERT on ValidationFindings
CREATE TRIGGER trg_validation_findings_ai_class
AFTER INSERT ON ValidationFindings
WHEN NEW.entity_type='class'
BEGIN
  UPDATE ClassTargets
  SET validation_status = (
    CASE
      WHEN EXISTS (SELECT 1 FROM ValidationFindings WHERE entity_type='class' AND entity_id=NEW.entity_id AND severity='error')
        OR EXISTS (SELECT 1 FROM ValidationFindings vf JOIN SubClassTargets s ON vf.entity_type='subclass' AND vf.entity_id=s.id WHERE s.class_target_id=NEW.entity_id AND vf.severity='error') THEN 'error'
      WHEN EXISTS (SELECT 1 FROM ValidationFindings WHERE entity_type='class' AND entity_id=NEW.entity_id AND severity='warning')
        OR EXISTS (SELECT 1 FROM ValidationFindings vf JOIN SubClassTargets s ON vf.entity_type='subclass' AND vf.entity_id=s.id WHERE s.class_target_id=NEW.entity_id AND vf.severity='warning') THEN 'warning'
      ELSE 'compliant'
    END
  )
  WHERE id=NEW.entity_id;
END;

CREATE TRIGGER trg_validation_findings_ai_subclass
AFTER INSERT ON ValidationFindings
WHEN NEW.entity_type='subclass'
BEGIN
  UPDATE SubClassTargets
  SET validation_status = (
    CASE
      WHEN EXISTS (SELECT 1 FROM ValidationFindings WHERE entity_type='subclass' AND entity_id=NEW.entity_id AND severity='error') THEN 'error'
      WHEN EXISTS (SELECT 1 FROM ValidationFindings WHERE entity_type='subclass' AND entity_id=NEW.entity_id AND severity='warning') THEN 'warning'
      ELSE 'compliant'
    END
  )
  WHERE id=NEW.entity_id;

  UPDATE ClassTargets
  SET validation_status = (
    CASE
      WHEN EXISTS (SELECT 1 FROM ValidationFindings WHERE entity_type='class' AND entity_id=ct.id AND severity='error')
         OR EXISTS (SELECT 1 FROM ValidationFindings vf JOIN SubClassTargets s ON vf.entity_type='subclass' AND vf.entity_id=s.id WHERE s.class_target_id=ct.id AND vf.severity='error') THEN 'error'
      WHEN EXISTS (SELECT 1 FROM ValidationFindings WHERE entity_type='class' AND entity_id=ct.id AND severity='warning')
         OR EXISTS (SELECT 1 FROM ValidationFindings vf JOIN SubClassTargets s ON vf.entity_type='subclass' AND vf.entity_id=s.id WHERE s.class_target_id=ct.id AND vf.severity='warning') THEN 'warning'
      ELSE 'compliant'
    END
  )
  WHERE ct.id = (SELECT class_target_id FROM SubClassTargets WHERE id = NEW.entity_id);
END;

-- 5) Trigger: after DELETE on ValidationFindings
CREATE TRIGGER trg_validation_findings_ad_class
AFTER DELETE ON ValidationFindings
WHEN OLD.entity_type='class'
BEGIN
  UPDATE ClassTargets
  SET validation_status = (
    CASE
      WHEN EXISTS (SELECT 1 FROM ValidationFindings WHERE entity_type='class' AND entity_id=OLD.entity_id AND severity='error')
        OR EXISTS (SELECT 1 FROM ValidationFindings vf JOIN SubClassTargets s ON vf.entity_type='subclass' AND vf.entity_id=s.id WHERE s.class_target_id=OLD.entity_id AND vf.severity='error') THEN 'error'
      WHEN EXISTS (SELECT 1 FROM ValidationFindings WHERE entity_type='class' AND entity_id=OLD.entity_id AND severity='warning')
        OR EXISTS (SELECT 1 FROM ValidationFindings vf JOIN SubClassTargets s ON vf.entity_type='subclass' AND vf.entity_id=s.id WHERE s.class_target_id=OLD.entity_id AND vf.severity='warning') THEN 'warning'
      ELSE 'compliant'
    END
  )
  WHERE id=OLD.entity_id;
END;

CREATE TRIGGER trg_validation_findings_ad_subclass
AFTER DELETE ON ValidationFindings
WHEN OLD.entity_type='subclass'
BEGIN
  UPDATE SubClassTargets
  SET validation_status = (
    CASE
      WHEN EXISTS (SELECT 1 FROM ValidationFindings WHERE entity_type='subclass' AND entity_id=OLD.entity_id AND severity='error') THEN 'error'
      WHEN EXISTS (SELECT 1 FROM ValidationFindings WHERE entity_type='subclass' AND entity_id=OLD.entity_id AND severity='warning') THEN 'warning'
      ELSE 'compliant'
    END
  )
  WHERE id=OLD.entity_id;

  UPDATE ClassTargets
  SET validation_status = (
    CASE
      WHEN EXISTS (SELECT 1 FROM ValidationFindings WHERE entity_type='class' AND entity_id=ct.id AND severity='error')
         OR EXISTS (SELECT 1 FROM ValidationFindings vf JOIN SubClassTargets s ON vf.entity_type='subclass' AND vf.entity_id=s.id WHERE s.class_target_id=ct.id AND vf.severity='error') THEN 'error'
      WHEN EXISTS (SELECT 1 FROM ValidationFindings WHERE entity_type='class' AND entity_id=ct.id AND severity='warning')
         OR EXISTS (SELECT 1 FROM ValidationFindings vf JOIN SubClassTargets s ON vf.entity_type='subclass' AND vf.entity_id=s.id WHERE s.class_target_id=ct.id AND vf.severity='warning') THEN 'warning'
      ELSE 'compliant'
    END
  )
  WHERE ct.id = (SELECT class_target_id FROM SubClassTargets WHERE id = OLD.entity_id);
END;

-- 6) Trigger: after UPDATE on ValidationFindings (recompute for old and new)
CREATE TRIGGER trg_validation_findings_au_class
AFTER UPDATE ON ValidationFindings
WHEN OLD.entity_type='class' OR NEW.entity_type='class'
BEGIN
  UPDATE ClassTargets
  SET validation_status = (
    CASE
      WHEN EXISTS (SELECT 1 FROM ValidationFindings WHERE entity_type='class' AND entity_id=OLD.entity_id AND severity='error')
        OR EXISTS (SELECT 1 FROM ValidationFindings vf JOIN SubClassTargets s ON vf.entity_type='subclass' AND vf.entity_id=s.id WHERE s.class_target_id=OLD.entity_id AND vf.severity='error') THEN 'error'
      WHEN EXISTS (SELECT 1 FROM ValidationFindings WHERE entity_type='class' AND entity_id=OLD.entity_id AND severity='warning')
        OR EXISTS (SELECT 1 FROM ValidationFindings vf JOIN SubClassTargets s ON vf.entity_type='subclass' AND vf.entity_id=s.id WHERE s.class_target_id=OLD.entity_id AND vf.severity='warning') THEN 'warning'
      ELSE 'compliant'
    END
  )
  WHERE id=OLD.entity_id;

  UPDATE ClassTargets
  SET validation_status = (
    CASE
      WHEN EXISTS (SELECT 1 FROM ValidationFindings WHERE entity_type='class' AND entity_id=NEW.entity_id AND severity='error')
        OR EXISTS (SELECT 1 FROM ValidationFindings vf JOIN SubClassTargets s ON vf.entity_type='subclass' AND vf.entity_id=s.id WHERE s.class_target_id=NEW.entity_id AND vf.severity='error') THEN 'error'
      WHEN EXISTS (SELECT 1 FROM ValidationFindings WHERE entity_type='class' AND entity_id=NEW.entity_id AND severity='warning')
        OR EXISTS (SELECT 1 FROM ValidationFindings vf JOIN SubClassTargets s ON vf.entity_type='subclass' AND vf.entity_id=s.id WHERE s.class_target_id=NEW.entity_id AND vf.severity='warning') THEN 'warning'
      ELSE 'compliant'
    END
  )
  WHERE id=NEW.entity_id;
END;

CREATE TRIGGER trg_validation_findings_au_subclass
AFTER UPDATE ON ValidationFindings
WHEN OLD.entity_type='subclass' OR NEW.entity_type='subclass'
BEGIN
  UPDATE SubClassTargets
  SET validation_status = (
    CASE
      WHEN EXISTS (SELECT 1 FROM ValidationFindings WHERE entity_type='subclass' AND entity_id=OLD.entity_id AND severity='error') THEN 'error'
      WHEN EXISTS (SELECT 1 FROM ValidationFindings WHERE entity_type='subclass' AND entity_id=OLD.entity_id AND severity='warning') THEN 'warning'
      ELSE 'compliant'
    END
  )
  WHERE id=OLD.entity_id;

  UPDATE SubClassTargets
  SET validation_status = (
    CASE
      WHEN EXISTS (SELECT 1 FROM ValidationFindings WHERE entity_type='subclass' AND entity_id=NEW.entity_id AND severity='error') THEN 'error'
      WHEN EXISTS (SELECT 1 FROM ValidationFindings WHERE entity_type='subclass' AND entity_id=NEW.entity_id AND severity='warning') THEN 'warning'
      ELSE 'compliant'
    END
  )
  WHERE id=NEW.entity_id;

  UPDATE ClassTargets
  SET validation_status = (
    CASE
      WHEN EXISTS (SELECT 1 FROM ValidationFindings WHERE entity_type='class' AND entity_id=ct.id AND severity='error')
         OR EXISTS (SELECT 1 FROM ValidationFindings vf JOIN SubClassTargets s ON vf.entity_type='subclass' AND vf.entity_id=s.id WHERE s.class_target_id=ct.id AND vf.severity='error') THEN 'error'
      WHEN EXISTS (SELECT 1 FROM ValidationFindings WHERE entity_type='class' AND entity_id=ct.id AND severity='warning')
         OR EXISTS (SELECT 1 FROM ValidationFindings vf JOIN SubClassTargets s ON vf.entity_type='subclass' AND vf.entity_id=s.id WHERE s.class_target_id=ct.id AND vf.severity='warning') THEN 'warning'
      ELSE 'compliant'
    END
  )
  WHERE ct.id = (SELECT class_target_id FROM SubClassTargets WHERE id = NEW.entity_id)
     OR ct.id = (SELECT class_target_id FROM SubClassTargets WHERE id = OLD.entity_id);
END;

-- 7) Triggers to purge findings when class target becomes zero
CREATE TRIGGER trg_ct_zero_target_cleanup_insert
AFTER INSERT ON ClassTargets
WHEN NEW.target_percent = 0 AND COALESCE(NEW.target_amount_chf,0) = 0
BEGIN
  DELETE FROM ValidationFindings WHERE entity_type='class' AND entity_id=NEW.id;
  DELETE FROM ValidationFindings WHERE entity_type='subclass' AND entity_id IN (
    SELECT id FROM SubClassTargets WHERE class_target_id = NEW.id
  );
  UPDATE SubClassTargets SET validation_status='compliant' WHERE class_target_id = NEW.id;
  UPDATE ClassTargets SET validation_status='compliant' WHERE id = NEW.id;
END;

CREATE TRIGGER trg_ct_zero_target_cleanup_update
AFTER UPDATE ON ClassTargets
WHEN NEW.target_percent = 0 AND COALESCE(NEW.target_amount_chf,0) = 0
BEGIN
  DELETE FROM ValidationFindings WHERE entity_type='class' AND entity_id=NEW.id;
  DELETE FROM ValidationFindings WHERE entity_type='subclass' AND entity_id IN (
    SELECT id FROM SubClassTargets WHERE class_target_id = NEW.id
  );
  UPDATE SubClassTargets SET validation_status='compliant' WHERE class_target_id = NEW.id;
  UPDATE ClassTargets SET validation_status='compliant' WHERE id = NEW.id;
END;

-- 8) Bump db_version
UPDATE Configuration SET value='4.26' WHERE key='db_version';

COMMIT;

-- migrate:down
-- Drop validation status sync triggers (data restoration not attempted)
BEGIN;
DROP TRIGGER IF EXISTS trg_validation_findings_ai_class;
DROP TRIGGER IF EXISTS trg_validation_findings_ai_subclass;
DROP TRIGGER IF EXISTS trg_validation_findings_ad_class;
DROP TRIGGER IF EXISTS trg_validation_findings_ad_subclass;
DROP TRIGGER IF EXISTS trg_validation_findings_au_class;
DROP TRIGGER IF EXISTS trg_validation_findings_au_subclass;
DROP TRIGGER IF EXISTS trg_ct_zero_target_cleanup_insert;
DROP TRIGGER IF EXISTS trg_ct_zero_target_cleanup_update;
UPDATE Configuration SET value='4.24' WHERE key='db_version';
COMMIT;
