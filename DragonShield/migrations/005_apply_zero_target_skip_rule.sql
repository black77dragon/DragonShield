-- Apply zero-target skip rule: purge findings for classes without allocation and ensure compliant status
DELETE FROM ValidationFindings
WHERE entity_type IN ('class','subclass')
  AND (
    (entity_type='class' AND entity_id IN (
        SELECT id FROM ClassTargets WHERE target_percent = 0 AND COALESCE(target_amount_chf,0) = 0
    ))
    OR
    (entity_type='subclass' AND entity_id IN (
        SELECT sct.id FROM SubClassTargets sct
        JOIN ClassTargets ct ON ct.id = sct.class_target_id
        WHERE ct.target_percent = 0 AND COALESCE(ct.target_amount_chf,0) = 0
    ))
  );

UPDATE ClassTargets
SET validation_status = 'compliant'
WHERE target_percent = 0 AND COALESCE(target_amount_chf,0) = 0;

UPDATE SubClassTargets
SET validation_status = 'compliant'
WHERE class_target_id IN (
    SELECT id FROM ClassTargets
    WHERE target_percent = 0 AND COALESCE(target_amount_chf,0) = 0
);

CREATE INDEX IF NOT EXISTS idx_subclass_targets_class_id ON SubClassTargets(class_target_id);
CREATE INDEX IF NOT EXISTS idx_class_targets_status ON ClassTargets(validation_status);
