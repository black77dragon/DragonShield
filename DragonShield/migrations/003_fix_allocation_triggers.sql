-- migrate:up
-- 1) Drop any old/buggy triggers if present (names we’ve used before)
DROP TRIGGER IF EXISTS trg_validate_class_targets_insert;
DROP TRIGGER IF EXISTS trg_validate_class_targets_update;
DROP TRIGGER IF EXISTS trg_validate_subclass_targets_insert;
DROP TRIGGER IF EXISTS trg_validate_subclass_targets_update;

-- 2) ClassTargets: AFTER INSERT OR UPDATE
--    a) Log the global class % sum if off ±0.1% (non-blocking)
--    b) Update this class row’s validation_status based on basic non-negativity and portfolio sum drift
CREATE TRIGGER trg_ct_after_aiu
AFTER INSERT OR UPDATE ON ClassTargets
BEGIN
-- Portfolio sum (percent) drift check using a scalar subquery (aliased)
INSERT INTO TargetChangeLog(target_type, target_id, field_name, old_value, new_value, changed_by)
SELECT 'class', NEW.id, 'portfolio_class_percent_sum',
NULL,
printf('%.4f', (SELECT COALESCE(SUM(ct2.target_percent),0.0) FROM ClassTargets ct2)),
'trigger'
WHERE ABS((SELECT COALESCE(SUM(ct2.target_percent),0.0) FROM ClassTargets ct2) - 100.0) > 0.1;

-- Update this class row’s validation_status.
-- Rule:
--   error    if NEW.target_percent < 0 or NEW.target_amount_chf < 0 (shouldn’t happen due to CHECK, but be defensive)
--   warning  if portfolio class % sum drifts beyond ±0.1%
--   compliant otherwise
UPDATE ClassTargets
SET validation_status =
CASE
WHEN NEW.target_percent < 0.0 OR NEW.target_amount_chf < 0.0 THEN 'error'
WHEN ABS((SELECT COALESCE(SUM(ct3.target_percent),0.0) FROM ClassTargets ct3) - 100.0) > 0.1 THEN 'warning'
ELSE 'compliant'
END,
updated_at = CURRENT_TIMESTAMP
WHERE id = NEW.id;
END;

-- 3) SubClassTargets: AFTER INSERT OR UPDATE
--    a) Log sub-class sum % vs parent (non-blocking), using aliases + scalar subqueries
--    b) Update sub-class row validation_status for basic checks
--    c) Bubble up warning to parent class row if child % sum deviates from 100% beyond parent tolerance
CREATE TRIGGER trg_sct_after_aiu
AFTER INSERT OR UPDATE ON SubClassTargets
BEGIN
-- Aliased scalar subqueries for totals and tolerance
INSERT INTO TargetChangeLog(target_type, target_id, field_name, old_value, new_value, changed_by)
SELECT 'class', NEW.class_target_id, 'child_percent_sum_vs_tol',
NULL,
printf('sum=%.4f tol=%.4f',
(SELECT COALESCE(SUM(sct2.target_percent),0.0) FROM SubClassTargets sct2 WHERE sct2.class_target_id = NEW.class_target_id),
(SELECT COALESCE(ct2.tolerance_percent,0.0) FROM ClassTargets ct2 WHERE ct2.id = NEW.class_target_id)
),
'trigger'
WHERE ABS(
(SELECT COALESCE(SUM(sct3.target_percent),0.0) FROM SubClassTargets sct3 WHERE sct3.class_target_id = NEW.class_target_id)
- 100.0
) > (SELECT COALESCE(ct3.tolerance_percent,0.0) FROM ClassTargets ct3 WHERE ct3.id = NEW.class_target_id);

-- Sub-class row validation (basic)
UPDATE SubClassTargets
SET validation_status =
CASE
WHEN NEW.target_percent < 0.0 OR NEW.target_amount_chf < 0.0 THEN 'error'
ELSE 'compliant'
END,
updated_at = CURRENT_TIMESTAMP
WHERE id = NEW.id;

-- If child % sum deviates beyond tolerance, mark parent class as at least 'warning' (do not overwrite 'error')
UPDATE ClassTargets
SET validation_status =
CASE
WHEN validation_status = 'error' THEN 'error'
ELSE 'warning'
END,
updated_at = CURRENT_TIMESTAMP
WHERE id = NEW.class_target_id
AND ABS(
(SELECT COALESCE(SUM(sct4.target_percent),0.0) FROM SubClassTargets sct4 WHERE sct4.class_target_id = NEW.class_target_id)
- 100.0
) > (SELECT COALESCE(ct4.tolerance_percent,0.0) FROM ClassTargets ct4 WHERE ct4.id = NEW.class_target_id);
END;

-- 4) OPTIONAL: Backfill validation_status for existing data (non-blocking, idempotent)
-- Classes basic backfill
UPDATE ClassTargets
SET validation_status =
CASE
WHEN target_percent < 0.0 OR target_amount_chf < 0.0 THEN 'error'
WHEN ABS((SELECT COALESCE(SUM(ct5.target_percent),0.0) FROM ClassTargets ct5) - 100.0) > 0.1 THEN 'warning'
ELSE 'compliant'
END,
updated_at = CURRENT_TIMESTAMP;

-- Sub-classes basic backfill
UPDATE SubClassTargets
SET validation_status =
CASE
WHEN target_percent < 0.0 OR target_amount_chf < 0.0 THEN 'error'
ELSE 'compliant'
END,
updated_at = CURRENT_TIMESTAMP;

-- Bubble warnings to parent where child sums exceed tolerance
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
AND x.drift > COALESCE(ct6.tolerance_percent,0.0)
);

-- Bump db_version to 4.23
UPDATE Configuration SET value='4.23' WHERE key='db_version';

-- migrate:down
-- Drop the new safe triggers (do NOT recreate the buggy ones)
DROP TRIGGER IF EXISTS trg_ct_after_aiu;
DROP TRIGGER IF EXISTS trg_sct_after_aiu;
-- Note: db_version rollback not handled
