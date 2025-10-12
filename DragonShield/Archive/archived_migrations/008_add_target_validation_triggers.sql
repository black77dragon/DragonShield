-- Migration 008: Add validation triggers for ClassTargets and SubClassTargets sums
-- Bump db_version to 4.21

CREATE TRIGGER IF NOT EXISTS trg_validate_class_targets_insert
AFTER INSERT ON ClassTargets
BEGIN
    INSERT INTO TargetChangeLog(target_type, target_id, field_name, new_value, changed_by)
    SELECT 'class', NEW.id, 'parent_sum_percent',
           printf('%.2f', total_pct), 'trigger'
    FROM (SELECT SUM(target_percent) AS total_pct FROM ClassTargets)
    WHERE ABS(total_pct - 100.0) > 0.1;
END;

CREATE TRIGGER IF NOT EXISTS trg_validate_class_targets_update
AFTER UPDATE ON ClassTargets
BEGIN
    INSERT INTO TargetChangeLog(target_type, target_id, field_name, new_value, changed_by)
    SELECT 'class', NEW.id, 'parent_sum_percent',
           printf('%.2f', total_pct), 'trigger'
    FROM (SELECT SUM(target_percent) AS total_pct FROM ClassTargets)
    WHERE ABS(total_pct - 100.0) > 0.1;
END;

CREATE TRIGGER IF NOT EXISTS trg_validate_subclass_targets_insert
AFTER INSERT ON SubClassTargets
BEGIN
    INSERT INTO TargetChangeLog(target_type, target_id, field_name, new_value, changed_by)
    SELECT 'class', NEW.class_target_id, 'child_sum_percent',
           printf('%.2f', total_pct), 'trigger'
    FROM (
        SELECT SUM(target_percent) AS total_pct
        FROM SubClassTargets
        WHERE class_target_id = NEW.class_target_id
    ), (
        SELECT tolerance_percent AS tol FROM ClassTargets WHERE id = NEW.class_target_id
    )
    WHERE ABS(total_pct - 100.0) > tol;
END;

CREATE TRIGGER IF NOT EXISTS trg_validate_subclass_targets_update
AFTER UPDATE ON SubClassTargets
BEGIN
    INSERT INTO TargetChangeLog(target_type, target_id, field_name, new_value, changed_by)
    SELECT 'class', NEW.class_target_id, 'child_sum_percent',
           printf('%.2f', total_pct), 'trigger'
    FROM (
        SELECT SUM(target_percent) AS total_pct
        FROM SubClassTargets
        WHERE class_target_id = NEW.class_target_id
    ), (
        SELECT tolerance_percent AS tol FROM ClassTargets WHERE id = NEW.class_target_id
    )
    WHERE ABS(total_pct - 100.0) > tol;
END;

UPDATE Configuration SET value='4.21' WHERE key='db_version';
