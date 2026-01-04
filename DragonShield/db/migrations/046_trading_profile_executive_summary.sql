-- migrate:up
-- Purpose: Add Trading Strategy Executive Summary to TradingProfiles.

ALTER TABLE TradingProfiles
    ADD COLUMN trading_strategy_executive_summary TEXT;

UPDATE TradingProfiles
SET trading_strategy_executive_summary = 'Executive Summary (Short)

René Keller''s investment profile is best described as a medium-to-long horizon, probabilistic macro allocator.
The profile is characterized by strong Bayesian belief updating, high drawdown sensitivity, low trading frequency, and a preference for broad macro signals over deep single-idea conviction.

The dominant edge is discipline, structure, and risk governance, not prediction or speed.
Accordingly, strategies that rely on regime identification, trend-supported macro themes, and controlled exposure sizing are a strong fit, while day trading, deep single-name stock picking, and conviction-driven concentration are structurally misaligned.

The primary behavioral risk is confidence-driven oversizing when a macro thesis feels intellectually compelling. Guardrails and explicit regime discipline are therefore essential components of execution.'
WHERE trading_strategy_executive_summary IS NULL;

-- migrate:down
-- No rollback for added column.
