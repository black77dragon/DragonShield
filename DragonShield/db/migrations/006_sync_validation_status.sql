-- migrate:up
-- Sync validation_status from ValidationFindings and enforce zero-target skip rule

-- Purge findings for zero-target classes and their subclasses
DELETE FROM ValidationFindings
WHERE entity_type = 'class'
  AND entity_id IN (
    SELECT ct.id
    FROM ClassTargets ct
    WHERE ct.target_percent = 0 AND COALESCE(ct.target_amount_chf, 0) = 0
);

DELETE FROM ValidationFindings
WHERE entity_type = 'subclass'
  AND entity_id IN (
    SELECT sct.id
    FROM SubClassTargets sct
    JOIN ClassTargets ct ON ct.id = sct.class_target_id
    WHERE ct.target_percent = 0 AND COALESCE(ct.target_amount_chf, 0) = 0
);

-- Recompute SubClassTargets.validation_status
UPDATE SubClassTargets AS sct
SET validation_status = (
  SELECT CASE
    WHEN EXISTS (
      SELECT 1 FROM ValidationFindings vf
      WHERE vf.entity_type = 'subclass'
        AND vf.entity_id = sct.id
        AND vf.severity = 'error'
    ) THEN 'error'
    WHEN EXISTS (
      SELECT 1 FROM ValidationFindings vf
      WHERE vf.entity_type = 'subclass'
        AND vf.entity_id = sct.id
        AND vf.severity = 'warning'
    ) THEN 'warning'
    ELSE 'compliant'
  END
);

-- Recompute ClassTargets.validation_status
UPDATE ClassTargets AS ct
SET validation_status = (
  SELECT CASE
    WHEN EXISTS (
      SELECT 1 FROM ValidationFindings vf
      WHERE (
        (vf.entity_type = 'class' AND vf.entity_id = ct.id)
        OR
        (vf.entity_type = 'subclass' AND vf.entity_id IN (
          SELECT sct.id
          FROM SubClassTargets sct
          WHERE sct.class_target_id = ct.id
        ))
      ) AND vf.severity = 'error'
    ) THEN 'error'
    WHEN EXISTS (
      SELECT 1 FROM ValidationFindings vf
      WHERE (
        (vf.entity_type = 'class' AND vf.entity_id = ct.id)
        OR
        (vf.entity_type = 'subclass' AND vf.entity_id IN (
          SELECT sct.id
          FROM SubClassTargets sct
          WHERE sct.class_target_id = ct.id
        ))
      ) AND vf.severity = 'warning'
    ) THEN 'warning'
    ELSE 'compliant'
  END
);

-- Helpful indexes for ValidationFindings lookups
CREATE INDEX IF NOT EXISTS idx_vf_entity ON ValidationFindings(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_vf_severity_time ON ValidationFindings(severity, computed_at);

-- Triggers to keep validation_status synced

DROP TRIGGER IF EXISTS trg_vf_ai_class;
CREATE TRIGGER trg_vf_ai_class AFTER INSERT ON ValidationFindings
WHEN NEW.entity_type = 'class'
BEGIN
  -- Enforce zero-target skip rule
  DELETE FROM ValidationFindings
  WHERE id = NEW.id
    AND EXISTS (
      SELECT 1 FROM ClassTargets ct
      WHERE ct.id = NEW.entity_id
        AND ct.target_percent = 0 AND COALESCE(ct.target_amount_chf, 0) = 0
    );

  UPDATE ClassTargets
  SET validation_status = (
    SELECT CASE
      WHEN EXISTS (
        SELECT 1 FROM ValidationFindings vf
        WHERE (
          (vf.entity_type = 'class' AND vf.entity_id = NEW.entity_id)
          OR
          (vf.entity_type = 'subclass' AND vf.entity_id IN (
            SELECT sct.id FROM SubClassTargets sct
            WHERE sct.class_target_id = NEW.entity_id
          ))
        ) AND vf.severity = 'error'
      ) THEN 'error'
      WHEN EXISTS (
        SELECT 1 FROM ValidationFindings vf
        WHERE (
          (vf.entity_type = 'class' AND vf.entity_id = NEW.entity_id)
          OR
          (vf.entity_type = 'subclass' AND vf.entity_id IN (
            SELECT sct.id FROM SubClassTargets sct
            WHERE sct.class_target_id = NEW.entity_id
          ))
        ) AND vf.severity = 'warning'
      ) THEN 'warning'
      ELSE 'compliant'
    END
  )
  WHERE id = NEW.entity_id;
END;

DROP TRIGGER IF EXISTS trg_vf_ai_subclass;
CREATE TRIGGER trg_vf_ai_subclass AFTER INSERT ON ValidationFindings
WHEN NEW.entity_type = 'subclass'
BEGIN
  -- Enforce zero-target skip rule
  DELETE FROM ValidationFindings
  WHERE id = NEW.id
    AND EXISTS (
      SELECT 1
      FROM ClassTargets ct
      JOIN SubClassTargets sct ON sct.class_target_id = ct.id
      WHERE sct.id = NEW.entity_id
        AND ct.target_percent = 0 AND COALESCE(ct.target_amount_chf, 0) = 0
    );

  UPDATE SubClassTargets
  SET validation_status = (
    SELECT CASE
      WHEN EXISTS (
        SELECT 1 FROM ValidationFindings vf
        WHERE vf.entity_type = 'subclass'
          AND vf.entity_id = NEW.entity_id
          AND vf.severity = 'error'
      ) THEN 'error'
      WHEN EXISTS (
        SELECT 1 FROM ValidationFindings vf
        WHERE vf.entity_type = 'subclass'
          AND vf.entity_id = NEW.entity_id
          AND vf.severity = 'warning'
      ) THEN 'warning'
      ELSE 'compliant'
    END
  )
  WHERE id = NEW.entity_id;

  UPDATE ClassTargets
  SET validation_status = (
    SELECT CASE
      WHEN EXISTS (
        SELECT 1 FROM ValidationFindings vf
        WHERE (
          (vf.entity_type = 'class' AND vf.entity_id = (
            SELECT sct.class_target_id FROM SubClassTargets sct WHERE sct.id = NEW.entity_id
          ))
          OR
          (vf.entity_type = 'subclass' AND vf.entity_id IN (
            SELECT sct2.id FROM SubClassTargets sct2
            WHERE sct2.class_target_id = (
              SELECT sct.class_target_id FROM SubClassTargets sct WHERE sct.id = NEW.entity_id
            )
          ))
        ) AND vf.severity = 'error'
      ) THEN 'error'
      WHEN EXISTS (
        SELECT 1 FROM ValidationFindings vf
        WHERE (
          (vf.entity_type = 'class' AND vf.entity_id = (
            SELECT sct.class_target_id FROM SubClassTargets sct WHERE sct.id = NEW.entity_id
          ))
          OR
          (vf.entity_type = 'subclass' AND vf.entity_id IN (
            SELECT sct2.id FROM SubClassTargets sct2
            WHERE sct2.class_target_id = (
              SELECT sct.class_target_id FROM SubClassTargets sct WHERE sct.id = NEW.entity_id
            )
          ))
        ) AND vf.severity = 'warning'
      ) THEN 'warning'
      ELSE 'compliant'
    END
  )
  WHERE id = (
    SELECT sct.class_target_id FROM SubClassTargets sct WHERE sct.id = NEW.entity_id
  );
END;

DROP TRIGGER IF EXISTS trg_vf_ad_class;
CREATE TRIGGER trg_vf_ad_class AFTER DELETE ON ValidationFindings
WHEN OLD.entity_type = 'class'
BEGIN
  UPDATE ClassTargets
  SET validation_status = (
    SELECT CASE
      WHEN EXISTS (
        SELECT 1 FROM ValidationFindings vf
        WHERE (
          (vf.entity_type = 'class' AND vf.entity_id = OLD.entity_id)
          OR
          (vf.entity_type = 'subclass' AND vf.entity_id IN (
            SELECT sct.id FROM SubClassTargets sct
            WHERE sct.class_target_id = OLD.entity_id
          ))
        ) AND vf.severity = 'error'
      ) THEN 'error'
      WHEN EXISTS (
        SELECT 1 FROM ValidationFindings vf
        WHERE (
          (vf.entity_type = 'class' AND vf.entity_id = OLD.entity_id)
          OR
          (vf.entity_type = 'subclass' AND vf.entity_id IN (
            SELECT sct.id FROM SubClassTargets sct
            WHERE sct.class_target_id = OLD.entity_id
          ))
        ) AND vf.severity = 'warning'
      ) THEN 'warning'
      ELSE 'compliant'
    END
  )
  WHERE id = OLD.entity_id;
END;

DROP TRIGGER IF EXISTS trg_vf_ad_subclass;
CREATE TRIGGER trg_vf_ad_subclass AFTER DELETE ON ValidationFindings
WHEN OLD.entity_type = 'subclass'
BEGIN
  UPDATE SubClassTargets
  SET validation_status = (
    SELECT CASE
      WHEN EXISTS (
        SELECT 1 FROM ValidationFindings vf
        WHERE vf.entity_type = 'subclass'
          AND vf.entity_id = OLD.entity_id
          AND vf.severity = 'error'
      ) THEN 'error'
      WHEN EXISTS (
        SELECT 1 FROM ValidationFindings vf
        WHERE vf.entity_type = 'subclass'
          AND vf.entity_id = OLD.entity_id
          AND vf.severity = 'warning'
      ) THEN 'warning'
      ELSE 'compliant'
    END
  )
  WHERE id = OLD.entity_id;

  UPDATE ClassTargets
  SET validation_status = (
    SELECT CASE
      WHEN EXISTS (
        SELECT 1 FROM ValidationFindings vf
        WHERE (
          (vf.entity_type = 'class' AND vf.entity_id = (
            SELECT sct.class_target_id FROM SubClassTargets sct WHERE sct.id = OLD.entity_id
          ))
          OR
          (vf.entity_type = 'subclass' AND vf.entity_id IN (
            SELECT sct2.id FROM SubClassTargets sct2
            WHERE sct2.class_target_id = (
              SELECT sct.class_target_id FROM SubClassTargets sct WHERE sct.id = OLD.entity_id
            )
          ))
        ) AND vf.severity = 'error'
      ) THEN 'error'
      WHEN EXISTS (
        SELECT 1 FROM ValidationFindings vf
        WHERE (
          (vf.entity_type = 'class' AND vf.entity_id = (
            SELECT sct.class_target_id FROM SubClassTargets sct WHERE sct.id = OLD.entity_id
          ))
          OR
          (vf.entity_type = 'subclass' AND vf.entity_id IN (
            SELECT sct2.id FROM SubClassTargets sct2
            WHERE sct2.class_target_id = (
              SELECT sct.class_target_id FROM SubClassTargets sct WHERE sct.id = OLD.entity_id
            )
          ))
        ) AND vf.severity = 'warning'
      ) THEN 'warning'
      ELSE 'compliant'
    END
  )
  WHERE id = (
    SELECT sct.class_target_id FROM SubClassTargets sct WHERE sct.id = OLD.entity_id
  );
END;

DROP TRIGGER IF EXISTS trg_vf_au_sync;
CREATE TRIGGER trg_vf_au_sync AFTER UPDATE ON ValidationFindings
BEGIN
  -- Recompute for old entity
  UPDATE ClassTargets
  SET validation_status = (
    SELECT CASE
      WHEN EXISTS (
        SELECT 1 FROM ValidationFindings vf
        WHERE (
          (vf.entity_type = 'class' AND vf.entity_id = OLD.entity_id)
          OR
          (vf.entity_type = 'subclass' AND vf.entity_id IN (
            SELECT sct.id FROM SubClassTargets sct
            WHERE sct.class_target_id = OLD.entity_id
          ))
        ) AND vf.severity = 'error'
      ) THEN 'error'
      WHEN EXISTS (
        SELECT 1 FROM ValidationFindings vf
        WHERE (
          (vf.entity_type = 'class' AND vf.entity_id = OLD.entity_id)
          OR
          (vf.entity_type = 'subclass' AND vf.entity_id IN (
            SELECT sct.id FROM SubClassTargets sct
            WHERE sct.class_target_id = OLD.entity_id
          ))
        ) AND vf.severity = 'warning'
      ) THEN 'warning'
      ELSE 'compliant'
    END
  )
  WHERE id = OLD.entity_id AND OLD.entity_type = 'class';

  UPDATE SubClassTargets
  SET validation_status = (
    SELECT CASE
      WHEN EXISTS (
        SELECT 1 FROM ValidationFindings vf
        WHERE vf.entity_type = 'subclass'
          AND vf.entity_id = OLD.entity_id
          AND vf.severity = 'error'
      ) THEN 'error'
      WHEN EXISTS (
        SELECT 1 FROM ValidationFindings vf
        WHERE vf.entity_type = 'subclass'
          AND vf.entity_id = OLD.entity_id
          AND vf.severity = 'warning'
      ) THEN 'warning'
      ELSE 'compliant'
    END
  )
  WHERE id = OLD.entity_id AND OLD.entity_type = 'subclass';

  UPDATE ClassTargets
  SET validation_status = (
    SELECT CASE
      WHEN EXISTS (
        SELECT 1 FROM ValidationFindings vf
        WHERE (
          (vf.entity_type = 'class' AND vf.entity_id = (
            SELECT sct.class_target_id FROM SubClassTargets sct WHERE sct.id = OLD.entity_id
          ))
          OR
          (vf.entity_type = 'subclass' AND vf.entity_id IN (
            SELECT sct2.id FROM SubClassTargets sct2
            WHERE sct2.class_target_id = (
              SELECT sct.class_target_id FROM SubClassTargets sct WHERE sct.id = OLD.entity_id
            )
          ))
        ) AND vf.severity = 'error'
      ) THEN 'error'
      WHEN EXISTS (
        SELECT 1 FROM ValidationFindings vf
        WHERE (
          (vf.entity_type = 'class' AND vf.entity_id = (
            SELECT sct.class_target_id FROM SubClassTargets sct WHERE sct.id = OLD.entity_id
          ))
          OR
          (vf.entity_type = 'subclass' AND vf.entity_id IN (
            SELECT sct2.id FROM SubClassTargets sct2
            WHERE sct2.class_target_id = (
              SELECT sct.class_target_id FROM SubClassTargets sct WHERE sct.id = OLD.entity_id
            )
          ))
        ) AND vf.severity = 'warning'
      ) THEN 'warning'
      ELSE 'compliant'
    END
  )
  WHERE id = (
    SELECT sct.class_target_id FROM SubClassTargets sct WHERE sct.id = OLD.entity_id
  ) AND OLD.entity_type = 'subclass';

  -- Recompute for new entity
  UPDATE ClassTargets
  SET validation_status = (
    SELECT CASE
      WHEN EXISTS (
        SELECT 1 FROM ValidationFindings vf
        WHERE (
          (vf.entity_type = 'class' AND vf.entity_id = NEW.entity_id)
          OR
          (vf.entity_type = 'subclass' AND vf.entity_id IN (
            SELECT sct.id FROM SubClassTargets sct
            WHERE sct.class_target_id = NEW.entity_id
          ))
        ) AND vf.severity = 'error'
      ) THEN 'error'
      WHEN EXISTS (
        SELECT 1 FROM ValidationFindings vf
        WHERE (
          (vf.entity_type = 'class' AND vf.entity_id = NEW.entity_id)
          OR
          (vf.entity_type = 'subclass' AND vf.entity_id IN (
            SELECT sct.id FROM SubClassTargets sct
            WHERE sct.class_target_id = NEW.entity_id
          ))
        ) AND vf.severity = 'warning'
      ) THEN 'warning'
      ELSE 'compliant'
    END
  )
  WHERE id = NEW.entity_id AND NEW.entity_type = 'class';

  UPDATE SubClassTargets
  SET validation_status = (
    SELECT CASE
      WHEN EXISTS (
        SELECT 1 FROM ValidationFindings vf
        WHERE vf.entity_type = 'subclass'
          AND vf.entity_id = NEW.entity_id
          AND vf.severity = 'error'
      ) THEN 'error'
      WHEN EXISTS (
        SELECT 1 FROM ValidationFindings vf
        WHERE vf.entity_type = 'subclass'
          AND vf.entity_id = NEW.entity_id
          AND vf.severity = 'warning'
      ) THEN 'warning'
      ELSE 'compliant'
    END
  )
  WHERE id = NEW.entity_id AND NEW.entity_type = 'subclass';

  UPDATE ClassTargets
  SET validation_status = (
    SELECT CASE
      WHEN EXISTS (
        SELECT 1 FROM ValidationFindings vf
        WHERE (
          (vf.entity_type = 'class' AND vf.entity_id = (
            SELECT sct.class_target_id FROM SubClassTargets sct WHERE sct.id = NEW.entity_id
          ))
          OR
          (vf.entity_type = 'subclass' AND vf.entity_id IN (
            SELECT sct2.id FROM SubClassTargets sct2
            WHERE sct2.class_target_id = (
              SELECT sct.class_target_id FROM SubClassTargets sct WHERE sct.id = NEW.entity_id
            )
          ))
        ) AND vf.severity = 'error'
      ) THEN 'error'
      WHEN EXISTS (
        SELECT 1 FROM ValidationFindings vf
        WHERE (
          (vf.entity_type = 'class' AND vf.entity_id = (
            SELECT sct.class_target_id FROM SubClassTargets sct WHERE sct.id = NEW.entity_id
          ))
          OR
          (vf.entity_type = 'subclass' AND vf.entity_id IN (
            SELECT sct2.id FROM SubClassTargets sct2
            WHERE sct2.class_target_id = (
              SELECT sct.class_target_id FROM SubClassTargets sct WHERE sct.id = NEW.entity_id
            )
          ))
        ) AND vf.severity = 'warning'
      ) THEN 'warning'
      ELSE 'compliant'
    END
  )
  WHERE id = (
    SELECT sct.class_target_id FROM SubClassTargets sct WHERE sct.id = NEW.entity_id
  ) AND NEW.entity_type = 'subclass';
END;

DROP TRIGGER IF EXISTS trg_ct_zero_target;
CREATE TRIGGER trg_ct_zero_target AFTER UPDATE ON ClassTargets
WHEN NEW.target_percent = 0 AND COALESCE(NEW.target_amount_chf, 0) = 0
BEGIN
  DELETE FROM ValidationFindings
  WHERE (entity_type = 'class' AND entity_id = NEW.id)
     OR (entity_type = 'subclass' AND entity_id IN (
          SELECT sct.id FROM SubClassTargets sct WHERE sct.class_target_id = NEW.id
        ));

  UPDATE ClassTargets SET validation_status = 'compliant' WHERE id = NEW.id;
  UPDATE SubClassTargets SET validation_status = 'compliant' WHERE class_target_id = NEW.id;
END;

-- migrate:down
-- Drop validation sync triggers and indexes; statuses remain as-is
DROP TRIGGER IF EXISTS trg_vf_ai_class;
DROP TRIGGER IF EXISTS trg_vf_ai_subclass;
DROP TRIGGER IF EXISTS trg_vf_ad_class;
DROP TRIGGER IF EXISTS trg_vf_ad_subclass;
DROP TRIGGER IF EXISTS trg_vf_au_sync;
DROP TRIGGER IF EXISTS trg_ct_zero_target;
DROP INDEX IF EXISTS idx_vf_entity;
DROP INDEX IF EXISTS idx_vf_severity_time;
