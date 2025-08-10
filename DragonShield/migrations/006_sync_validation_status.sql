-- migrate:up
-- PRAGMA foreign_keys=ON;
-- Purpose: Synchronize validation_status across ClassTargets and SubClassTargets based on ValidationFindings,
--          enforce the zero-target skip rule, and add supporting indexes and triggers.
-- Notes:
--  - We treat ValidationFindings.entity_id as the domain identifier (class_id for 'class', subclass_id for 'subclass').
--  - Purges remove stale findings for entities whose targets are zero (percent=0 and amount_chf=0).
--  - Initial sync sets statuses to 'violated' if findings exist, otherwise 'compliant'.
--  - Triggers keep statuses synchronized on INSERT/DELETE/UPDATE to ValidationFindings and when class targets become zero.

BEGIN;

-- 1) Performance: ensure fast lookup of findings by entity
CREATE INDEX IF NOT EXISTS idx_vf_entity
  ON ValidationFindings(entity_type, entity_id);

-- Optional helper for trigger ops
CREATE INDEX IF NOT EXISTS idx_sct_class_target_id
  ON SubClassTargets(class_target_id);

-- 2) Purge stale findings for entities that should be skipped (zero targets)
--    For classes: entity_id is class_id of ClassTargets rows with zero targets
DELETE FROM ValidationFindings
WHERE entity_type = 'class'
  AND entity_id IN (
    SELECT DISTINCT ct.class_id
    FROM ClassTargets ct
    WHERE COALESCE(ct.target_percent,0) = 0
      AND COALESCE(ct.target_amount_chf,0) = 0
  );

--    For subclasses: entity_id is subclass_id of SubClassTargets rows with zero targets
DELETE FROM ValidationFindings
WHERE entity_type = 'subclass'
  AND entity_id IN (
    SELECT DISTINCT sct.subclass_id
    FROM SubClassTargets sct
    WHERE COALESCE(sct.target_percent,0) = 0
      AND COALESCE(sct.target_amount_chf,0) = 0
  );

-- 3) Initial status sync from ValidationFindings
--    Classes: violated if any finding exists, else compliant
UPDATE ClassTargets ct
SET validation_status = CASE
  WHEN EXISTS (
    SELECT 1 FROM ValidationFindings vf
    WHERE vf.entity_type='class' AND vf.entity_id = ct.class_id
  )
  THEN 'violated' ELSE 'compliant' END;

--    Subclasses: violated if any finding exists, else compliant
UPDATE SubClassTargets sct
SET validation_status = CASE
  WHEN EXISTS (
    SELECT 1 FROM ValidationFindings vf
    WHERE vf.entity_type='subclass' AND vf.entity_id = sct.subclass_id
  )
  THEN 'violated' ELSE 'compliant' END;

-- 4) Triggers to keep statuses synchronized

-- 4a) On INSERT into ValidationFindings → set impacted entity to 'violated'
CREATE TRIGGER IF NOT EXISTS trg_vf_after_insert
AFTER INSERT ON ValidationFindings
BEGIN
  -- class
  UPDATE ClassTargets
    SET validation_status='violated'
    WHERE NEW.entity_type='class'
      AND class_id = NEW.entity_id;

  -- subclass
  UPDATE SubClassTargets
    SET validation_status='violated'
    WHERE NEW.entity_type='subclass'
      AND subclass_id = NEW.entity_id;
END;

-- 4b) On DELETE from ValidationFindings → if no remaining findings for that entity, set to 'compliant'
CREATE TRIGGER IF NOT EXISTS trg_vf_after_delete
AFTER DELETE ON ValidationFindings
BEGIN
  -- class
  UPDATE ClassTargets
    SET validation_status='compliant'
    WHERE OLD.entity_type='class'
      AND class_id = OLD.entity_id
      AND NOT EXISTS (
        SELECT 1 FROM ValidationFindings vf
        WHERE vf.entity_type='class' AND vf.entity_id = OLD.entity_id
      );

  -- subclass
  UPDATE SubClassTargets
    SET validation_status='compliant'
    WHERE OLD.entity_type='subclass'
      AND subclass_id = OLD.entity_id
      AND NOT EXISTS (
        SELECT 1 FROM ValidationFindings vf
        WHERE vf.entity_type='subclass' AND vf.entity_id = OLD.entity_id
      );
END;

-- 4c) On UPDATE to ValidationFindings.entity_type/entity_id → treat as delete(old) + insert(new)
CREATE TRIGGER IF NOT EXISTS trg_vf_after_update
AFTER UPDATE OF entity_type, entity_id ON ValidationFindings
BEGIN
  -- old class → maybe compliant if nothing else remains
  UPDATE ClassTargets
    SET validation_status='compliant'
    WHERE OLD.entity_type='class'
      AND class_id = OLD.entity_id
      AND NOT EXISTS (
        SELECT 1 FROM ValidationFindings vf
        WHERE vf.entity_type='class' AND vf.entity_id = OLD.entity_id
      );

  -- old subclass → maybe compliant if nothing else remains
  UPDATE SubClassTargets
    SET validation_status='compliant'
    WHERE OLD.entity_type='subclass'
      AND subclass_id = OLD.entity_id
      AND NOT EXISTS (
        SELECT 1 FROM ValidationFindings vf
        WHERE vf.entity_type='subclass' AND vf.entity_id = OLD.entity_id
      );

  -- new class → set violated
  UPDATE ClassTargets
    SET validation_status='violated'
    WHERE NEW.entity_type='class'
      AND class_id = NEW.entity_id;

  -- new subclass → set violated
  UPDATE SubClassTargets
    SET validation_status='violated'
    WHERE NEW.entity_type='subclass'
      AND subclass_id = NEW.entity_id;
END;

-- 4d) Zero-target skip rule on ClassTargets changes:
--     Whenever a ClassTargets row is inserted/updated with zero targets,
--     mark the class target + its SubClassTargets compliant and purge any findings.
CREATE TRIGGER IF NOT EXISTS trg_ct_zero_target
AFTER INSERT ON ClassTargets
WHEN COALESCE(NEW.target_percent,0)=0 AND COALESCE(NEW.target_amount_chf,0)=0
BEGIN
  -- class-level compliant
  UPDATE ClassTargets
    SET validation_status='compliant'
    WHERE id = NEW.id;

  -- subclass-level compliant (by association via class_target_id)
  UPDATE SubClassTargets
    SET validation_status='compliant'
    WHERE class_target_id = NEW.id;

  -- purge related findings (class and subclasses under this class_target)
  DELETE FROM ValidationFindings
    WHERE entity_type='class'
      AND entity_id = NEW.class_id;

  DELETE FROM ValidationFindings
    WHERE entity_type='subclass'
      AND entity_id IN (
        SELECT sct.subclass_id
        FROM SubClassTargets sct
        WHERE sct.class_target_id = NEW.id
      );
END;

CREATE TRIGGER IF NOT EXISTS trg_ct_zero_target_update
AFTER UPDATE OF target_percent, target_amount_chf ON ClassTargets
WHEN COALESCE(NEW.target_percent,0)=0 AND COALESCE(NEW.target_amount_chf,0)=0
BEGIN
  -- class-level compliant
  UPDATE ClassTargets
    SET validation_status='compliant'
    WHERE id = NEW.id;

  -- subclass-level compliant
  UPDATE SubClassTargets
    SET validation_status='compliant'
    WHERE class_target_id = NEW.id;

  -- purge related findings
  DELETE FROM ValidationFindings
    WHERE entity_type='class'
      AND entity_id = NEW.class_id;

  DELETE FROM ValidationFindings
    WHERE entity_type='subclass'
      AND entity_id IN (
        SELECT sct.subclass_id
        FROM SubClassTargets sct
        WHERE sct.class_target_id = NEW.id
      );
END;

COMMIT;

-- migrate:down
-- PRAGMA foreign_keys=ON;
-- Reverse objects created here. Note: data purges are NOT restored.
BEGIN;
DROP TRIGGER IF EXISTS trg_vf_after_insert;
DROP TRIGGER IF EXISTS trg_vf_after_delete;
DROP TRIGGER IF EXISTS trg_vf_after_update;
DROP TRIGGER IF EXISTS trg_ct_zero_target;
DROP TRIGGER IF EXISTS trg_ct_zero_target_update;

DROP INDEX IF EXISTS idx_sct_class_target_id;
DROP INDEX IF EXISTS idx_vf_entity;
COMMIT;