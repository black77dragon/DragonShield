PRAGMA foreign_keys = OFF;
BEGIN TRANSACTION;
-- DROP & re-CREATE only the reference tables here
-- INSERT statements for Configuration, Currencies, AssetClasses, AssetSubClasses, AccountTypes, Institutions, etc.
COMMIT;
PRAGMA foreign_keys = ON;
