-- 007_validation_status_views.sql
-- migrate:up
-- Purpose: Aggregate ValidationFindings into class and subclass validation statuses
CREATE VIEW IF NOT EXISTS V_SubClassValidationStatus AS
WITH sub_err AS (
  SELECT entity_id AS sub_class_id FROM ValidationFindings
  WHERE entity_type='subclass' AND severity='error'
),
sub_warn AS (
  SELECT entity_id AS sub_class_id FROM ValidationFindings
  WHERE entity_type='subclass' AND severity='warning'
)
SELECT s.sub_class_id,
       CASE
         WHEN EXISTS(SELECT 1 FROM sub_err e WHERE e.sub_class_id=s.sub_class_id) THEN 'error'
         WHEN EXISTS(SELECT 1 FROM sub_warn w WHERE w.sub_class_id=s.sub_class_id) THEN 'warning'
         ELSE 'compliant'
       END AS validation_status,
       (SELECT COUNT(*) FROM ValidationFindings vf
         WHERE vf.entity_type='subclass' AND vf.entity_id=s.sub_class_id) AS findings_count
FROM AssetSubClasses s;

CREATE VIEW IF NOT EXISTS V_ClassValidationStatus AS
WITH class_err AS (
  SELECT ac.class_id FROM AssetClasses ac
  WHERE EXISTS (SELECT 1 FROM ValidationFindings vf
                  WHERE vf.entity_type='class'
                    AND vf.entity_id=ac.class_id
                    AND vf.severity='error')
     OR EXISTS (SELECT 1 FROM ValidationFindings vf
                  JOIN AssetSubClasses s ON s.sub_class_id=vf.entity_id
                 WHERE vf.entity_type='subclass'
                   AND s.class_id=ac.class_id
                   AND vf.severity='error')
),
class_warn AS (
  SELECT ac.class_id FROM AssetClasses ac
  WHERE EXISTS (SELECT 1 FROM ValidationFindings vf
                  WHERE vf.entity_type='class'
                    AND vf.entity_id=ac.class_id
                    AND vf.severity='warning')
     OR EXISTS (SELECT 1 FROM ValidationFindings vf
                  JOIN AssetSubClasses s ON s.sub_class_id=vf.entity_id
                 WHERE vf.entity_type='subclass'
                   AND s.class_id=ac.class_id
                   AND vf.severity='warning')
)
SELECT ac.class_id,
       CASE
         WHEN EXISTS (SELECT 1 FROM class_err e WHERE e.class_id=ac.class_id) THEN 'error'
         WHEN EXISTS (SELECT 1 FROM class_warn w WHERE w.class_id=ac.class_id) THEN 'warning'
         ELSE 'compliant'
       END AS validation_status,
       (
         SELECT COUNT(*) FROM ValidationFindings vf
         WHERE (vf.entity_type='class' AND vf.entity_id=ac.class_id)
            OR (vf.entity_type='subclass' AND vf.entity_id IN (
                 SELECT sub_class_id FROM AssetSubClasses s WHERE s.class_id=ac.class_id
               ))
       ) AS findings_count
FROM AssetClasses ac;

-- migrate:down
DROP VIEW IF EXISTS V_ClassValidationStatus;
DROP VIEW IF EXISTS V_SubClassValidationStatus;
