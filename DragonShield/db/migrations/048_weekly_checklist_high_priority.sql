-- migrate:up
-- Purpose: Add high priority flag for weekly checklist portfolios.

ALTER TABLE PortfolioTheme
    ADD COLUMN weekly_checklist_high_priority INTEGER NOT NULL DEFAULT 0 CHECK (weekly_checklist_high_priority IN (0,1));

UPDATE PortfolioTheme
   SET weekly_checklist_high_priority = 1
 WHERE LOWER(TRIM(name)) IN (
    'rv crypto thesis',
    'china ai tech portfolio',
    'avalaor special investments',
    'i/o fund ai technology',
    'energy'
 );

-- migrate:down
-- PortfolioTheme column rollback requires DB restore.
