-- migrate:up
-- PRAGMA foreign_keys=ON;
-- Sync validation_status columns with ValidationFindings and add triggers to keep them in sync.
BEGIN;

-- Drop legacy triggers that set validation_status directly
DROP TRIGGER IF EXISTS trg_ct_after_insert;
DROP TRIGGER IF EXISTS trg_ct_after_update;
DROP TRIGGER IF EXISTS trg_sct_after_insert;
DROP TRIGGER IF EXISTS trg_sct_after_update;
DROP TRIGGER IF EXISTS trg_ct_after_aiu;
DROP TRIGGER IF EXISTS trg_sct_after_aiu;

-- Purge stale findings for zero-target classes and subclasses
DELETE FROM ValidationFindings
WHERE entity_type IN ('class','subclass')
  AND (
    (entity_type='class' AND entity_id IN (
        SELECT id FROM ClassTargets
        WHERE target_percent = 0 AND COALESCE(target_amount_chf,0)=0
    ))
    OR
    (entity_type='subclass' AND entity_id IN (
        SELECT sct.id
        FROM SubClassTargets sct
        JOIN ClassTargets ct ON ct.id = sct.class_target_id
        WHERE ct.target_percent = 0 AND COALESCE(ct.target_amount_chf,0)=0
    ))
  );

-- Recompute subclass statuses from current findings
UPDATE SubClassTargets
SET validation_status = (
    WITH sev AS (
        SELECT MAX(CASE severity WHEN 'error' THEN 2 WHEN 'warning' THEN 1 ELSE 0 END) AS rank
        FROM ValidationFindings
        WHERE entity_type='subclass' AND entity_id=SubClassTargets.id
    )
    SELECT CASE COALESCE(rank,0)
           WHEN 2 THEN 'error'
           WHEN 1 THEN 'warning'
           ELSE 'compliant' END
    FROM sev
),
updated_at = CURRENT_TIMESTAMP;

-- Recompute class statuses from current findings (including subclasses)
UPDATE ClassTargets
SET validation_status = (
    WITH sev AS (
        SELECT MAX(CASE severity WHEN 'error' THEN 2 WHEN 'warning' THEN 1 ELSE 0 END) AS rank
        FROM ValidationFindings vf
        WHERE (vf.entity_type='class' AND vf.entity_id=ClassTargets.id)
           OR (vf.entity_type='subclass' AND vf.entity_id IN (
                SELECT id FROM SubClassTargets WHERE class_target_id=ClassTargets.id
           ))
    )
    SELECT CASE COALESCE(rank,0)
           WHEN 2 THEN 'error'
           WHEN 1 THEN 'warning'
           ELSE 'compliant' END
    FROM sev
),
updated_at = CURRENT_TIMESTAMP;

-- Trigger: recompute statuses after inserting a finding
CREATE TRIGGER IF NOT EXISTS trg_vf_after_insert
AFTER INSERT ON ValidationFindings
BEGIN
  -- Update subclass if applicable
  UPDATE SubClassTargets
  SET validation_status = (
      WITH sev AS (
          SELECT MAX(CASE severity WHEN 'error' THEN 2 WHEN 'warning' THEN 1 ELSE 0 END) AS rank
          FROM ValidationFindings
          WHERE entity_type='subclass' AND entity_id=NEW.entity_id
      )
      SELECT CASE COALESCE(rank,0)
             WHEN 2 THEN 'error'
             WHEN 1 THEN 'warning'
             ELSE 'compliant' END
      FROM sev
  ),
  updated_at = CURRENT_TIMESTAMP
  WHERE NEW.entity_type='subclass' AND id=NEW.entity_id;

  -- Determine affected class id
  UPDATE ClassTargets
  SET validation_status = (
      WITH sev AS (
          SELECT MAX(CASE severity WHEN 'error' THEN 2 WHEN 'warning' THEN 1 ELSE 0 END) AS rank
          FROM ValidationFindings vf
          WHERE (vf.entity_type='class' AND vf.entity_id = CASE WHEN NEW.entity_type='class' THEN NEW.entity_id ELSE (SELECT class_target_id FROM SubClassTargets WHERE id=NEW.entity_id) END)
             OR (vf.entity_type='subclass' AND vf.entity_id IN (
                  SELECT id FROM SubClassTargets WHERE class_target_id = CASE WHEN NEW.entity_type='class' THEN NEW.entity_id ELSE (SELECT class_target_id FROM SubClassTargets WHERE id=NEW.entity_id) END
             ))
      )
      SELECT CASE COALESCE(rank,0)
             WHEN 2 THEN 'error'
             WHEN 1 THEN 'warning'
             ELSE 'compliant' END
      FROM sev
  ),
  updated_at = CURRENT_TIMESTAMP
  WHERE id = CASE WHEN NEW.entity_type='class' THEN NEW.entity_id ELSE (SELECT class_target_id FROM SubClassTargets WHERE id=NEW.entity_id) END;
END;

-- Trigger: recompute statuses after deleting a finding
CREATE TRIGGER IF NOT EXISTS trg_vf_after_delete
AFTER DELETE ON ValidationFindings
BEGIN
  -- Update subclass if applicable
  UPDATE SubClassTargets
  SET validation_status = (
      WITH sev AS (
          SELECT MAX(CASE severity WHEN 'error' THEN 2 WHEN 'warning' THEN 1 ELSE 0 END) AS rank
          FROM ValidationFindings
          WHERE entity_type='subclass' AND entity_id=OLD.entity_id
      )
      SELECT CASE COALESCE(rank,0)
             WHEN 2 THEN 'error'
             WHEN 1 THEN 'warning'
             ELSE 'compliant' END
      FROM sev
  ),
  updated_at = CURRENT_TIMESTAMP
  WHERE OLD.entity_type='subclass' AND id=OLD.entity_id;

  -- Determine affected class id
  UPDATE ClassTargets
  SET validation_status = (
      WITH sev AS (
          SELECT MAX(CASE severity WHEN 'error' THEN 2 WHEN 'warning' THEN 1 ELSE 0 END) AS rank
          FROM ValidationFindings vf
          WHERE (vf.entity_type='class' AND vf.entity_id = CASE WHEN OLD.entity_type='class' THEN OLD.entity_id ELSE (SELECT class_target_id FROM SubClassTargets WHERE id=OLD.entity_id) END)
             OR (vf.entity_type='subclass' AND vf.entity_id IN (
                  SELECT id FROM SubClassTargets WHERE class_target_id = CASE WHEN OLD.entity_type='class' THEN OLD.entity_id ELSE (SELECT class_target_id FROM SubClassTargets WHERE id=OLD.entity_id) END
             ))
      )
      SELECT CASE COALESCE(rank,0)
             WHEN 2 THEN 'error'
             WHEN 1 THEN 'warning'
             ELSE 'compliant' END
      FROM sev
  ),
  updated_at = CURRENT_TIMESTAMP
  WHERE id = CASE WHEN OLD.entity_type='class' THEN OLD.entity_id ELSE (SELECT class_target_id FROM SubClassTargets WHERE id=OLD.entity_id) END;
END;

-- Trigger: recompute statuses after updating a finding
CREATE TRIGGER IF NOT EXISTS trg_vf_after_update
AFTER UPDATE ON ValidationFindings
BEGIN
  -- Recompute for old reference
  UPDATE SubClassTargets
  SET validation_status = (
      WITH sev AS (
          SELECT MAX(CASE severity WHEN 'error' THEN 2 WHEN 'warning' THEN 1 ELSE 0 END) AS rank
          FROM ValidationFindings
          WHERE entity_type='subclass' AND entity_id=OLD.entity_id
      )
      SELECT CASE COALESCE(rank,0)
             WHEN 2 THEN 'error'
             WHEN 1 THEN 'warning'
             ELSE 'compliant' END
      FROM sev
  ),
  updated_at = CURRENT_TIMESTAMP
  WHERE OLD.entity_type='subclass' AND id=OLD.entity_id;

  UPDATE ClassTargets
  SET validation_status = (
      WITH sev AS (
          SELECT MAX(CASE severity WHEN 'error' THEN 2 WHEN 'warning' THEN 1 ELSE 0 END) AS rank
          FROM ValidationFindings vf
          WHERE (vf.entity_type='class' AND vf.entity_id = CASE WHEN OLD.entity_type='class' THEN OLD.entity_id ELSE (SELECT class_target_id FROM SubClassTargets WHERE id=OLD.entity_id) END)
             OR (vf.entity_type='subclass' AND vf.entity_id IN (
                  SELECT id FROM SubClassTargets WHERE class_target_id = CASE WHEN OLD.entity_type='class' THEN OLD.entity_id ELSE (SELECT class_target_id FROM SubClassTargets WHERE id=OLD.entity_id) END
             ))
      )
      SELECT CASE COALESCE(rank,0)
             WHEN 2 THEN 'error'
             WHEN 1 THEN 'warning'
             ELSE 'compliant' END
      FROM sev
  ),
  updated_at = CURRENT_TIMESTAMP
  WHERE id = CASE WHEN OLD.entity_type='class' THEN OLD.entity_id ELSE (SELECT class_target_id FROM SubClassTargets WHERE id=OLD.entity_id) END;

  -- Recompute for new reference
  UPDATE SubClassTargets
  SET validation_status = (
      WITH sev AS (
          SELECT MAX(CASE severity WHEN 'error' THEN 2 WHEN 'warning' THEN 1 ELSE 0 END) AS rank
          FROM ValidationFindings
          WHERE entity_type='subclass' AND entity_id=NEW.entity_id
      )
      SELECT CASE COALESCE(rank,0)
             WHEN 2 THEN 'error'
             WHEN 1 THEN 'warning'
             ELSE 'compliant' END
      FROM sev
  ),
  updated_at = CURRENT_TIMESTAMP
  WHERE NEW.entity_type='subclass' AND id=NEW.entity_id;

  UPDATE ClassTargets
  SET validation_status = (
      WITH sev AS (
          SELECT MAX(CASE severity WHEN 'error' THEN 2 WHEN 'warning' THEN 1 ELSE 0 END) AS rank
          FROM ValidationFindings vf
          WHERE (vf.entity_type='class' AND vf.entity_id = CASE WHEN NEW.entity_type='class' THEN NEW.entity_id ELSE (SELECT class_target_id FROM SubClassTargets WHERE id=NEW.entity_id) END)
             OR (vf.entity_type='subclass' AND vf.entity_id IN (
                  SELECT id FROM SubClassTargets WHERE class_target_id = CASE WHEN NEW.entity_type='class' THEN NEW.entity_id ELSE (SELECT class_target_id FROM SubClassTargets WHERE id=NEW.entity_id) END
             ))
      )
      SELECT CASE COALESCE(rank,0)
             WHEN 2 THEN 'error'
             WHEN 1 THEN 'warning'
             ELSE 'compliant' END
      FROM sev
  ),
  updated_at = CURRENT_TIMESTAMP
  WHERE id = CASE WHEN NEW.entity_type='class' THEN NEW.entity_id ELSE (SELECT class_target_id FROM SubClassTargets WHERE id=NEW.entity_id) END;
END;

-- Triggers to purge findings when a class target becomes zero
CREATE TRIGGER IF NOT EXISTS trg_ct_zero_insert
AFTER INSERT ON ClassTargets
WHEN NEW.target_percent = 0 AND COALESCE(NEW.target_amount_chf,0)=0
BEGIN
  DELETE FROM ValidationFindings
  WHERE (entity_type='class' AND entity_id=NEW.id)
     OR (entity_type='subclass' AND entity_id IN (
            SELECT id FROM SubClassTargets WHERE class_target_id=NEW.id
         ));

  UPDATE ClassTargets
  SET validation_status='compliant', updated_at=CURRENT_TIMESTAMP
  WHERE id=NEW.id;

  UPDATE SubClassTargets
  SET validation_status='compliant', updated_at=CURRENT_TIMESTAMP
  WHERE class_target_id=NEW.id;
END;

CREATE TRIGGER IF NOT EXISTS trg_ct_zero_update
AFTER UPDATE ON ClassTargets
WHEN NEW.target_percent = 0 AND COALESCE(NEW.target_amount_chf,0)=0
BEGIN
  DELETE FROM ValidationFindings
  WHERE (entity_type='class' AND entity_id=NEW.id)
     OR (entity_type='subclass' AND entity_id IN (
            SELECT id FROM SubClassTargets WHERE class_target_id=NEW.id
         ));

  UPDATE ClassTargets
  SET validation_status='compliant', updated_at=CURRENT_TIMESTAMP
  WHERE id=NEW.id;

  UPDATE SubClassTargets
  SET validation_status='compliant', updated_at=CURRENT_TIMESTAMP
  WHERE class_target_id=NEW.id;
END;

-- Bump database version
UPDATE Configuration SET value='4.26' WHERE key='db_version';

COMMIT;

-- migrate:down
-- PRAGMA foreign_keys=ON;
-- Drop validation sync triggers and revert db_version. Legacy triggers are not restored.
BEGIN;
DROP TRIGGER IF EXISTS trg_vf_after_insert;
DROP TRIGGER IF EXISTS trg_vf_after_delete;
DROP TRIGGER IF EXISTS trg_vf_after_update;
DROP TRIGGER IF EXISTS trg_ct_zero_insert;
DROP TRIGGER IF EXISTS trg_ct_zero_update;
UPDATE Configuration SET value='4.25' WHERE key='db_version';
COMMIT;
