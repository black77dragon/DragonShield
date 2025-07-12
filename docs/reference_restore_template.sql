PRAGMA foreign_keys = OFF;
BEGIN TRANSACTION;
-- Run `schema.sql` first to create all tables, then apply this data dump.
--
-- This dump contains CREATE and INSERT statements for all reference tables
-- including Instruments and Accounts.
--
-- DROP & re-CREATE only these reference tables here if necessary.
COMMIT;
PRAGMA foreign_keys = ON;
