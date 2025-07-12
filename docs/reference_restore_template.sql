PRAGMA foreign_keys = OFF;
BEGIN TRANSACTION;
-- Run `schema.sql` first to create all tables, then apply this data dump.
-- DROP & re-CREATE only the reference tables here
-- INSERT statements for Configuration, Currencies, AssetClasses, AssetSubClasses, AccountTypes, Institutions, etc.
COMMIT;
PRAGMA foreign_keys = ON;
