-- 031_theme_budget.sql
-- Add theoretical theme budget (CHF) to PortfolioTheme
ALTER TABLE PortfolioTheme
  ADD COLUMN theoretical_budget_chf REAL NULL CHECK (theoretical_budget_chf >= 0);
