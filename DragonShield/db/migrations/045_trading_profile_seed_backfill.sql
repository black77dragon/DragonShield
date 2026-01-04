-- migrate:up
-- Purpose: Backfill Trading Profile seed data when initial seeding only inserted partial rows.

INSERT OR IGNORE INTO TradingProfileCoordinates (profile_id, title, weight_percent, value, sort_order, is_locked)
VALUES (1, 'Time Horizon', 15, 7.5, 1, 1),
       (1, 'Belief Updating', 15, 8.0, 2, 1),
       (1, 'Loss Sensitivity', 15, 8.0, 3, 1),
       (1, 'Position Concentration', 10, 6.0, 4, 1),
       (1, 'Decision Trigger', 10, 6.5, 5, 1),
       (1, 'Market Alignment', 10, 7.0, 6, 1),
       (1, 'Activity Level', 10, 8.0, 7, 1),
       (1, 'Research Style', 5, 8.0, 8, 1),
       (1, 'Error Acceptance', 10, 8.5, 9, 1);

INSERT INTO TradingProfileDominance (profile_id, category, text, sort_order)
SELECT 1, 'primary', 'Bayesian belief updating', 1
WHERE EXISTS (SELECT 1 FROM TradingProfiles WHERE profile_id = 1)
  AND NOT EXISTS (
    SELECT 1 FROM TradingProfileDominance
     WHERE profile_id = 1 AND category = 'primary' AND text = 'Bayesian belief updating'
  );
INSERT INTO TradingProfileDominance (profile_id, category, text, sort_order)
SELECT 1, 'primary', 'Drawdown avoidance', 2
WHERE EXISTS (SELECT 1 FROM TradingProfiles WHERE profile_id = 1)
  AND NOT EXISTS (
    SELECT 1 FROM TradingProfileDominance
     WHERE profile_id = 1 AND category = 'primary' AND text = 'Drawdown avoidance'
  );
INSERT INTO TradingProfileDominance (profile_id, category, text, sort_order)
SELECT 1, 'primary', 'Low activity / patience', 3
WHERE EXISTS (SELECT 1 FROM TradingProfiles WHERE profile_id = 1)
  AND NOT EXISTS (
    SELECT 1 FROM TradingProfileDominance
     WHERE profile_id = 1 AND category = 'primary' AND text = 'Low activity / patience'
  );
INSERT INTO TradingProfileDominance (profile_id, category, text, sort_order)
SELECT 1, 'primary', 'Macro breadth', 4
WHERE EXISTS (SELECT 1 FROM TradingProfiles WHERE profile_id = 1)
  AND NOT EXISTS (
    SELECT 1 FROM TradingProfileDominance
     WHERE profile_id = 1 AND category = 'primary' AND text = 'Macro breadth'
  );
INSERT INTO TradingProfileDominance (profile_id, category, text, sort_order)
SELECT 1, 'secondary', 'Selective concentration', 1
WHERE EXISTS (SELECT 1 FROM TradingProfiles WHERE profile_id = 1)
  AND NOT EXISTS (
    SELECT 1 FROM TradingProfileDominance
     WHERE profile_id = 1 AND category = 'secondary' AND text = 'Selective concentration'
  );
INSERT INTO TradingProfileDominance (profile_id, category, text, sort_order)
SELECT 1, 'secondary', 'Narrative awareness', 2
WHERE EXISTS (SELECT 1 FROM TradingProfiles WHERE profile_id = 1)
  AND NOT EXISTS (
    SELECT 1 FROM TradingProfileDominance
     WHERE profile_id = 1 AND category = 'secondary' AND text = 'Narrative awareness'
  );
INSERT INTO TradingProfileDominance (profile_id, category, text, sort_order)
SELECT 1, 'avoid', 'Deep conviction', 1
WHERE EXISTS (SELECT 1 FROM TradingProfiles WHERE profile_id = 1)
  AND NOT EXISTS (
    SELECT 1 FROM TradingProfileDominance
     WHERE profile_id = 1 AND category = 'avoid' AND text = 'Deep conviction'
  );
INSERT INTO TradingProfileDominance (profile_id, category, text, sort_order)
SELECT 1, 'avoid', 'Tactical trading', 2
WHERE EXISTS (SELECT 1 FROM TradingProfiles WHERE profile_id = 1)
  AND NOT EXISTS (
    SELECT 1 FROM TradingProfileDominance
     WHERE profile_id = 1 AND category = 'avoid' AND text = 'Tactical trading'
  );
INSERT INTO TradingProfileDominance (profile_id, category, text, sort_order)
SELECT 1, 'avoid', 'Contrarian positioning', 3
WHERE EXISTS (SELECT 1 FROM TradingProfiles WHERE profile_id = 1)
  AND NOT EXISTS (
    SELECT 1 FROM TradingProfileDominance
     WHERE profile_id = 1 AND category = 'avoid' AND text = 'Contrarian positioning'
  );

INSERT INTO TradingProfileRegimeSignals (profile_id, signal_type, text, sort_order)
SELECT 1, 'confirming', 'Liquidity impulse stabilizing', 1
WHERE EXISTS (SELECT 1 FROM TradingProfiles WHERE profile_id = 1)
  AND NOT EXISTS (
    SELECT 1 FROM TradingProfileRegimeSignals
     WHERE profile_id = 1 AND signal_type = 'confirming' AND text = 'Liquidity impulse stabilizing'
  );
INSERT INTO TradingProfileRegimeSignals (profile_id, signal_type, text, sort_order)
SELECT 1, 'confirming', 'Volatility compression', 2
WHERE EXISTS (SELECT 1 FROM TradingProfiles WHERE profile_id = 1)
  AND NOT EXISTS (
    SELECT 1 FROM TradingProfileRegimeSignals
     WHERE profile_id = 1 AND signal_type = 'confirming' AND text = 'Volatility compression'
  );
INSERT INTO TradingProfileRegimeSignals (profile_id, signal_type, text, sort_order)
SELECT 1, 'invalidating', 'Growth re-acceleration', 1
WHERE EXISTS (SELECT 1 FROM TradingProfiles WHERE profile_id = 1)
  AND NOT EXISTS (
    SELECT 1 FROM TradingProfileRegimeSignals
     WHERE profile_id = 1 AND signal_type = 'invalidating' AND text = 'Growth re-acceleration'
  );
INSERT INTO TradingProfileRegimeSignals (profile_id, signal_type, text, sort_order)
SELECT 1, 'invalidating', 'Yield curve normalization', 2
WHERE EXISTS (SELECT 1 FROM TradingProfiles WHERE profile_id = 1)
  AND NOT EXISTS (
    SELECT 1 FROM TradingProfileRegimeSignals
     WHERE profile_id = 1 AND signal_type = 'invalidating' AND text = 'Yield curve normalization'
  );
INSERT INTO TradingProfileRegimeSignals (profile_id, signal_type, text, sort_order)
SELECT 1, 'implication', 'Maintain exposure', 1
WHERE EXISTS (SELECT 1 FROM TradingProfiles WHERE profile_id = 1)
  AND NOT EXISTS (
    SELECT 1 FROM TradingProfileRegimeSignals
     WHERE profile_id = 1 AND signal_type = 'implication' AND text = 'Maintain exposure'
  );
INSERT INTO TradingProfileRegimeSignals (profile_id, signal_type, text, sort_order)
SELECT 1, 'implication', 'No size increases', 2
WHERE EXISTS (SELECT 1 FROM TradingProfiles WHERE profile_id = 1)
  AND NOT EXISTS (
    SELECT 1 FROM TradingProfileRegimeSignals
     WHERE profile_id = 1 AND signal_type = 'implication' AND text = 'No size increases'
  );
INSERT INTO TradingProfileRegimeSignals (profile_id, signal_type, text, sort_order)
SELECT 1, 'implication', 'Wait for confirmation', 3
WHERE EXISTS (SELECT 1 FROM TradingProfiles WHERE profile_id = 1)
  AND NOT EXISTS (
    SELECT 1 FROM TradingProfileRegimeSignals
     WHERE profile_id = 1 AND signal_type = 'implication' AND text = 'Wait for confirmation'
  );

INSERT INTO TradingProfileStrategyFit (profile_id, strategy_name, status_label, status_tone, reason, sort_order)
SELECT 1, 'Macro Regime Allocation', 'Excellent', 'success', NULL, 1
WHERE EXISTS (SELECT 1 FROM TradingProfiles WHERE profile_id = 1)
  AND NOT EXISTS (
    SELECT 1 FROM TradingProfileStrategyFit
     WHERE profile_id = 1 AND strategy_name = 'Macro Regime Allocation'
  );
INSERT INTO TradingProfileStrategyFit (profile_id, strategy_name, status_label, status_tone, reason, sort_order)
SELECT 1, 'BTC / Monetary Regime', 'Strong', 'success', NULL, 2
WHERE EXISTS (SELECT 1 FROM TradingProfiles WHERE profile_id = 1)
  AND NOT EXISTS (
    SELECT 1 FROM TradingProfileStrategyFit
     WHERE profile_id = 1 AND strategy_name = 'BTC / Monetary Regime'
  );
INSERT INTO TradingProfileStrategyFit (profile_id, strategy_name, status_label, status_tone, reason, sort_order)
SELECT 1, 'Trend Following', 'Good', 'accent', NULL, 3
WHERE EXISTS (SELECT 1 FROM TradingProfiles WHERE profile_id = 1)
  AND NOT EXISTS (
    SELECT 1 FROM TradingProfileStrategyFit
     WHERE profile_id = 1 AND strategy_name = 'Trend Following'
  );
INSERT INTO TradingProfileStrategyFit (profile_id, strategy_name, status_label, status_tone, reason, sort_order)
SELECT 1, 'Tactical Trading', 'Blocked', 'danger', 'Horizon + activity mismatch.', 4
WHERE EXISTS (SELECT 1 FROM TradingProfiles WHERE profile_id = 1)
  AND NOT EXISTS (
    SELECT 1 FROM TradingProfileStrategyFit
     WHERE profile_id = 1 AND strategy_name = 'Tactical Trading'
  );
INSERT INTO TradingProfileStrategyFit (profile_id, strategy_name, status_label, status_tone, reason, sort_order)
SELECT 1, 'High-Conviction Bets', 'Blocked', 'danger', 'Drawdown sensitivity.', 5
WHERE EXISTS (SELECT 1 FROM TradingProfiles WHERE profile_id = 1)
  AND NOT EXISTS (
    SELECT 1 FROM TradingProfileStrategyFit
     WHERE profile_id = 1 AND strategy_name = 'High-Conviction Bets'
  );

INSERT INTO TradingProfileRiskSignals (profile_id, signal_type, text, sort_order)
SELECT 1, 'warning', 'Activity up without regime change', 1
WHERE EXISTS (SELECT 1 FROM TradingProfiles WHERE profile_id = 1)
  AND NOT EXISTS (
    SELECT 1 FROM TradingProfileRiskSignals
     WHERE profile_id = 1 AND signal_type = 'warning' AND text = 'Activity up without regime change'
  );
INSERT INTO TradingProfileRiskSignals (profile_id, signal_type, text, sort_order)
SELECT 1, 'warning', 'Narrative persistence detected', 2
WHERE EXISTS (SELECT 1 FROM TradingProfiles WHERE profile_id = 1)
  AND NOT EXISTS (
    SELECT 1 FROM TradingProfileRiskSignals
     WHERE profile_id = 1 AND signal_type = 'warning' AND text = 'Narrative persistence detected'
  );
INSERT INTO TradingProfileRiskSignals (profile_id, signal_type, text, sort_order)
SELECT 1, 'action', 'Size increases frozen', 1
WHERE EXISTS (SELECT 1 FROM TradingProfiles WHERE profile_id = 1)
  AND NOT EXISTS (
    SELECT 1 FROM TradingProfileRiskSignals
     WHERE profile_id = 1 AND signal_type = 'action' AND text = 'Size increases frozen'
  );
INSERT INTO TradingProfileRiskSignals (profile_id, signal_type, text, sort_order)
SELECT 1, 'action', 'Review recommended', 2
WHERE EXISTS (SELECT 1 FROM TradingProfiles WHERE profile_id = 1)
  AND NOT EXISTS (
    SELECT 1 FROM TradingProfileRiskSignals
     WHERE profile_id = 1 AND signal_type = 'action' AND text = 'Review recommended'
  );

INSERT INTO TradingProfileRules (profile_id, rule_text, sort_order)
SELECT 1, 'No position outside active regime', 1
WHERE EXISTS (SELECT 1 FROM TradingProfiles WHERE profile_id = 1)
  AND NOT EXISTS (
    SELECT 1 FROM TradingProfileRules
     WHERE profile_id = 1 AND rule_text = 'No position outside active regime'
  );
INSERT INTO TradingProfileRules (profile_id, rule_text, sort_order)
SELECT 1, 'No size increase without confirmation', 2
WHERE EXISTS (SELECT 1 FROM TradingProfiles WHERE profile_id = 1)
  AND NOT EXISTS (
    SELECT 1 FROM TradingProfileRules
     WHERE profile_id = 1 AND rule_text = 'No size increase without confirmation'
  );
INSERT INTO TradingProfileRules (profile_id, rule_text, sort_order)
SELECT 1, 'No tactical actions on strategic capital', 3
WHERE EXISTS (SELECT 1 FROM TradingProfiles WHERE profile_id = 1)
  AND NOT EXISTS (
    SELECT 1 FROM TradingProfileRules
     WHERE profile_id = 1 AND rule_text = 'No tactical actions on strategic capital'
  );

INSERT INTO TradingProfileRuleViolations (profile_id, violation_date, rule_text, resolution_text)
SELECT 1, '2026-01-03', 'Rule 2 violated -> BTC size increase blocked', 'Automatic cap applied.'
WHERE EXISTS (SELECT 1 FROM TradingProfiles WHERE profile_id = 1)
  AND NOT EXISTS (
    SELECT 1 FROM TradingProfileRuleViolations
     WHERE profile_id = 1 AND violation_date = '2026-01-03' AND rule_text = 'Rule 2 violated -> BTC size increase blocked'
  );

INSERT INTO TradingProfileReviewLog (profile_id, review_date, event, decision, confidence, notes)
SELECT 1, '2026-01-03', 'Regime reassessment', 'No change', 'Medium', 'Volatility compression proved misleading.'
WHERE EXISTS (SELECT 1 FROM TradingProfiles WHERE profile_id = 1)
  AND NOT EXISTS (
    SELECT 1 FROM TradingProfileReviewLog
     WHERE profile_id = 1 AND review_date = '2026-01-03' AND event = 'Regime reassessment'
  );
INSERT INTO TradingProfileReviewLog (profile_id, review_date, event, decision, confidence, notes)
SELECT 1, '2025-12-01', 'Annual profile review', 'Increase belief updating weight', 'High', 'Macro signals improved, but sizing discipline remains priority.'
WHERE EXISTS (SELECT 1 FROM TradingProfiles WHERE profile_id = 1)
  AND NOT EXISTS (
    SELECT 1 FROM TradingProfileReviewLog
     WHERE profile_id = 1 AND review_date = '2025-12-01' AND event = 'Annual profile review'
  );

-- migrate:down
-- Data backfill only.
