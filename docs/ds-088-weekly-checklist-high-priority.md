# DS-088 Weekly Macro Check: High Priority Portfolios

## Decision
Store the high-priority flag on `PortfolioTheme` as `weekly_checklist_high_priority` (INTEGER 0/1).

## Rationale
- High priority is a per-portfolio attribute, and weekly checklist metadata already lives on `PortfolioTheme`.
- Keeping the flag on the main table avoids extra joins and keeps checklist queries/UI fast and simple.

## Implementation Notes
- Migration `048_weekly_checklist_high_priority.sql` adds the column and seeds the requested portfolios.
- Weekly checklist overview/tile surfaces a High Priority badge and sorts priority portfolios first.
- Portfolio settings include a High Priority toggle under Weekly Checklist.
