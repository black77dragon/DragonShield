-- migrate:up
-- Purpose: Add Trading Profile governance tables (identity, coordinates, signals, rules, logs).

CREATE TABLE IF NOT EXISTS TradingProfiles (
    profile_id INTEGER PRIMARY KEY AUTOINCREMENT,
    profile_name TEXT NOT NULL,
    profile_type TEXT NOT NULL,
    primary_objective TEXT,
    last_review_date TEXT,
    next_review_text TEXT,
    active_regime TEXT,
    regime_confidence TEXT,
    risk_state TEXT,
    is_default INTEGER NOT NULL DEFAULT 0 CHECK (is_default IN (0,1)),
    is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0,1)),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS TradingProfileCoordinates (
    coordinate_id INTEGER PRIMARY KEY AUTOINCREMENT,
    profile_id INTEGER NOT NULL REFERENCES TradingProfiles(profile_id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    weight_percent REAL NOT NULL DEFAULT 0,
    value REAL NOT NULL DEFAULT 0,
    sort_order INTEGER NOT NULL DEFAULT 0,
    is_locked INTEGER NOT NULL DEFAULT 1 CHECK (is_locked IN (0,1)),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(profile_id, title)
);

CREATE TABLE IF NOT EXISTS TradingProfileDominance (
    dominance_id INTEGER PRIMARY KEY AUTOINCREMENT,
    profile_id INTEGER NOT NULL REFERENCES TradingProfiles(profile_id) ON DELETE CASCADE,
    category TEXT NOT NULL CHECK (category IN ('primary','secondary','avoid')),
    text TEXT NOT NULL,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS TradingProfileRegimeSignals (
    signal_id INTEGER PRIMARY KEY AUTOINCREMENT,
    profile_id INTEGER NOT NULL REFERENCES TradingProfiles(profile_id) ON DELETE CASCADE,
    signal_type TEXT NOT NULL CHECK (signal_type IN ('confirming','invalidating','implication')),
    text TEXT NOT NULL,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS TradingProfileStrategyFit (
    strategy_id INTEGER PRIMARY KEY AUTOINCREMENT,
    profile_id INTEGER NOT NULL REFERENCES TradingProfiles(profile_id) ON DELETE CASCADE,
    strategy_name TEXT NOT NULL,
    status_label TEXT NOT NULL,
    status_tone TEXT NOT NULL CHECK (status_tone IN ('success','warning','danger','accent','neutral')),
    reason TEXT,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS TradingProfileRiskSignals (
    risk_signal_id INTEGER PRIMARY KEY AUTOINCREMENT,
    profile_id INTEGER NOT NULL REFERENCES TradingProfiles(profile_id) ON DELETE CASCADE,
    signal_type TEXT NOT NULL CHECK (signal_type IN ('warning','action')),
    text TEXT NOT NULL,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS TradingProfileRules (
    rule_id INTEGER PRIMARY KEY AUTOINCREMENT,
    profile_id INTEGER NOT NULL REFERENCES TradingProfiles(profile_id) ON DELETE CASCADE,
    rule_text TEXT NOT NULL,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS TradingProfileRuleViolations (
    violation_id INTEGER PRIMARY KEY AUTOINCREMENT,
    profile_id INTEGER NOT NULL REFERENCES TradingProfiles(profile_id) ON DELETE CASCADE,
    violation_date TEXT NOT NULL,
    rule_text TEXT NOT NULL,
    resolution_text TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS TradingProfileReviewLog (
    review_id INTEGER PRIMARY KEY AUTOINCREMENT,
    profile_id INTEGER NOT NULL REFERENCES TradingProfiles(profile_id) ON DELETE CASCADE,
    review_date TEXT NOT NULL,
    event TEXT NOT NULL,
    decision TEXT NOT NULL,
    confidence TEXT NOT NULL,
    notes TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_trading_profile_default ON TradingProfiles(is_default, is_active);
CREATE INDEX IF NOT EXISTS idx_trading_profile_coordinates_profile ON TradingProfileCoordinates(profile_id, sort_order);
CREATE INDEX IF NOT EXISTS idx_trading_profile_dominance_profile ON TradingProfileDominance(profile_id, sort_order);
CREATE INDEX IF NOT EXISTS idx_trading_profile_regime_signals_profile ON TradingProfileRegimeSignals(profile_id, sort_order);
CREATE INDEX IF NOT EXISTS idx_trading_profile_strategy_profile ON TradingProfileStrategyFit(profile_id, sort_order);
CREATE INDEX IF NOT EXISTS idx_trading_profile_risk_profile ON TradingProfileRiskSignals(profile_id, sort_order);
CREATE INDEX IF NOT EXISTS idx_trading_profile_rules_profile ON TradingProfileRules(profile_id, sort_order);
CREATE INDEX IF NOT EXISTS idx_trading_profile_violations_profile ON TradingProfileRuleViolations(profile_id, violation_date);
CREATE INDEX IF NOT EXISTS idx_trading_profile_review_profile ON TradingProfileReviewLog(profile_id, review_date);

INSERT INTO TradingProfiles (
    profile_id,
    profile_name,
    profile_type,
    primary_objective,
    last_review_date,
    next_review_text,
    active_regime,
    regime_confidence,
    risk_state,
    is_default,
    is_active
)
SELECT
    1,
    'Rene Keller',
    'Probabilistic Macro Allocator',
    'Preserve financial independence, control drawdowns, exploit macro asymmetry',
    '2025-12-01',
    'Annual or Regime Shift',
    'Transitional / Neutral',
    'Medium',
    'Elevated',
    1,
    1
WHERE NOT EXISTS (SELECT 1 FROM TradingProfiles);

INSERT INTO TradingProfileCoordinates (profile_id, title, weight_percent, value, sort_order, is_locked)
SELECT 1, 'Time Horizon', 15, 7.5, 1, 1 WHERE EXISTS (SELECT 1 FROM TradingProfiles WHERE profile_id = 1)
    AND NOT EXISTS (SELECT 1 FROM TradingProfileCoordinates);
INSERT INTO TradingProfileCoordinates (profile_id, title, weight_percent, value, sort_order, is_locked)
SELECT 1, 'Belief Updating', 15, 8.0, 2, 1 WHERE EXISTS (SELECT 1 FROM TradingProfiles WHERE profile_id = 1)
    AND NOT EXISTS (SELECT 1 FROM TradingProfileCoordinates);
INSERT INTO TradingProfileCoordinates (profile_id, title, weight_percent, value, sort_order, is_locked)
SELECT 1, 'Loss Sensitivity', 15, 8.0, 3, 1 WHERE EXISTS (SELECT 1 FROM TradingProfiles WHERE profile_id = 1)
    AND NOT EXISTS (SELECT 1 FROM TradingProfileCoordinates);
INSERT INTO TradingProfileCoordinates (profile_id, title, weight_percent, value, sort_order, is_locked)
SELECT 1, 'Position Concentration', 10, 6.0, 4, 1 WHERE EXISTS (SELECT 1 FROM TradingProfiles WHERE profile_id = 1)
    AND NOT EXISTS (SELECT 1 FROM TradingProfileCoordinates);
INSERT INTO TradingProfileCoordinates (profile_id, title, weight_percent, value, sort_order, is_locked)
SELECT 1, 'Decision Trigger', 10, 6.5, 5, 1 WHERE EXISTS (SELECT 1 FROM TradingProfiles WHERE profile_id = 1)
    AND NOT EXISTS (SELECT 1 FROM TradingProfileCoordinates);
INSERT INTO TradingProfileCoordinates (profile_id, title, weight_percent, value, sort_order, is_locked)
SELECT 1, 'Market Alignment', 10, 7.0, 6, 1 WHERE EXISTS (SELECT 1 FROM TradingProfiles WHERE profile_id = 1)
    AND NOT EXISTS (SELECT 1 FROM TradingProfileCoordinates);
INSERT INTO TradingProfileCoordinates (profile_id, title, weight_percent, value, sort_order, is_locked)
SELECT 1, 'Activity Level', 10, 8.0, 7, 1 WHERE EXISTS (SELECT 1 FROM TradingProfiles WHERE profile_id = 1)
    AND NOT EXISTS (SELECT 1 FROM TradingProfileCoordinates);
INSERT INTO TradingProfileCoordinates (profile_id, title, weight_percent, value, sort_order, is_locked)
SELECT 1, 'Research Style', 5, 8.0, 8, 1 WHERE EXISTS (SELECT 1 FROM TradingProfiles WHERE profile_id = 1)
    AND NOT EXISTS (SELECT 1 FROM TradingProfileCoordinates);
INSERT INTO TradingProfileCoordinates (profile_id, title, weight_percent, value, sort_order, is_locked)
SELECT 1, 'Error Acceptance', 10, 8.5, 9, 1 WHERE EXISTS (SELECT 1 FROM TradingProfiles WHERE profile_id = 1)
    AND NOT EXISTS (SELECT 1 FROM TradingProfileCoordinates);

INSERT INTO TradingProfileDominance (profile_id, category, text, sort_order)
SELECT 1, 'primary', 'Bayesian belief updating', 1 WHERE EXISTS (SELECT 1 FROM TradingProfiles WHERE profile_id = 1)
    AND NOT EXISTS (SELECT 1 FROM TradingProfileDominance);
INSERT INTO TradingProfileDominance (profile_id, category, text, sort_order)
SELECT 1, 'primary', 'Drawdown avoidance', 2 WHERE EXISTS (SELECT 1 FROM TradingProfiles WHERE profile_id = 1)
    AND NOT EXISTS (SELECT 1 FROM TradingProfileDominance);
INSERT INTO TradingProfileDominance (profile_id, category, text, sort_order)
SELECT 1, 'primary', 'Low activity / patience', 3 WHERE EXISTS (SELECT 1 FROM TradingProfiles WHERE profile_id = 1)
    AND NOT EXISTS (SELECT 1 FROM TradingProfileDominance);
INSERT INTO TradingProfileDominance (profile_id, category, text, sort_order)
SELECT 1, 'primary', 'Macro breadth', 4 WHERE EXISTS (SELECT 1 FROM TradingProfiles WHERE profile_id = 1)
    AND NOT EXISTS (SELECT 1 FROM TradingProfileDominance);
INSERT INTO TradingProfileDominance (profile_id, category, text, sort_order)
SELECT 1, 'secondary', 'Selective concentration', 1 WHERE EXISTS (SELECT 1 FROM TradingProfiles WHERE profile_id = 1)
    AND NOT EXISTS (SELECT 1 FROM TradingProfileDominance);
INSERT INTO TradingProfileDominance (profile_id, category, text, sort_order)
SELECT 1, 'secondary', 'Narrative awareness', 2 WHERE EXISTS (SELECT 1 FROM TradingProfiles WHERE profile_id = 1)
    AND NOT EXISTS (SELECT 1 FROM TradingProfileDominance);
INSERT INTO TradingProfileDominance (profile_id, category, text, sort_order)
SELECT 1, 'avoid', 'Deep conviction', 1 WHERE EXISTS (SELECT 1 FROM TradingProfiles WHERE profile_id = 1)
    AND NOT EXISTS (SELECT 1 FROM TradingProfileDominance);
INSERT INTO TradingProfileDominance (profile_id, category, text, sort_order)
SELECT 1, 'avoid', 'Tactical trading', 2 WHERE EXISTS (SELECT 1 FROM TradingProfiles WHERE profile_id = 1)
    AND NOT EXISTS (SELECT 1 FROM TradingProfileDominance);
INSERT INTO TradingProfileDominance (profile_id, category, text, sort_order)
SELECT 1, 'avoid', 'Contrarian positioning', 3 WHERE EXISTS (SELECT 1 FROM TradingProfiles WHERE profile_id = 1)
    AND NOT EXISTS (SELECT 1 FROM TradingProfileDominance);

INSERT INTO TradingProfileRegimeSignals (profile_id, signal_type, text, sort_order)
SELECT 1, 'confirming', 'Liquidity impulse stabilizing', 1 WHERE EXISTS (SELECT 1 FROM TradingProfiles WHERE profile_id = 1)
    AND NOT EXISTS (SELECT 1 FROM TradingProfileRegimeSignals);
INSERT INTO TradingProfileRegimeSignals (profile_id, signal_type, text, sort_order)
SELECT 1, 'confirming', 'Volatility compression', 2 WHERE EXISTS (SELECT 1 FROM TradingProfiles WHERE profile_id = 1)
    AND NOT EXISTS (SELECT 1 FROM TradingProfileRegimeSignals);
INSERT INTO TradingProfileRegimeSignals (profile_id, signal_type, text, sort_order)
SELECT 1, 'invalidating', 'Growth re-acceleration', 1 WHERE EXISTS (SELECT 1 FROM TradingProfiles WHERE profile_id = 1)
    AND NOT EXISTS (SELECT 1 FROM TradingProfileRegimeSignals);
INSERT INTO TradingProfileRegimeSignals (profile_id, signal_type, text, sort_order)
SELECT 1, 'invalidating', 'Yield curve normalization', 2 WHERE EXISTS (SELECT 1 FROM TradingProfiles WHERE profile_id = 1)
    AND NOT EXISTS (SELECT 1 FROM TradingProfileRegimeSignals);
INSERT INTO TradingProfileRegimeSignals (profile_id, signal_type, text, sort_order)
SELECT 1, 'implication', 'Maintain exposure', 1 WHERE EXISTS (SELECT 1 FROM TradingProfiles WHERE profile_id = 1)
    AND NOT EXISTS (SELECT 1 FROM TradingProfileRegimeSignals);
INSERT INTO TradingProfileRegimeSignals (profile_id, signal_type, text, sort_order)
SELECT 1, 'implication', 'No size increases', 2 WHERE EXISTS (SELECT 1 FROM TradingProfiles WHERE profile_id = 1)
    AND NOT EXISTS (SELECT 1 FROM TradingProfileRegimeSignals);
INSERT INTO TradingProfileRegimeSignals (profile_id, signal_type, text, sort_order)
SELECT 1, 'implication', 'Wait for confirmation', 3 WHERE EXISTS (SELECT 1 FROM TradingProfiles WHERE profile_id = 1)
    AND NOT EXISTS (SELECT 1 FROM TradingProfileRegimeSignals);

INSERT INTO TradingProfileStrategyFit (profile_id, strategy_name, status_label, status_tone, reason, sort_order)
SELECT 1, 'Macro Regime Allocation', 'Excellent', 'success', NULL, 1 WHERE EXISTS (SELECT 1 FROM TradingProfiles WHERE profile_id = 1)
    AND NOT EXISTS (SELECT 1 FROM TradingProfileStrategyFit);
INSERT INTO TradingProfileStrategyFit (profile_id, strategy_name, status_label, status_tone, reason, sort_order)
SELECT 1, 'BTC / Monetary Regime', 'Strong', 'success', NULL, 2 WHERE EXISTS (SELECT 1 FROM TradingProfiles WHERE profile_id = 1)
    AND NOT EXISTS (SELECT 1 FROM TradingProfileStrategyFit);
INSERT INTO TradingProfileStrategyFit (profile_id, strategy_name, status_label, status_tone, reason, sort_order)
SELECT 1, 'Trend Following', 'Good', 'accent', NULL, 3 WHERE EXISTS (SELECT 1 FROM TradingProfiles WHERE profile_id = 1)
    AND NOT EXISTS (SELECT 1 FROM TradingProfileStrategyFit);
INSERT INTO TradingProfileStrategyFit (profile_id, strategy_name, status_label, status_tone, reason, sort_order)
SELECT 1, 'Tactical Trading', 'Blocked', 'danger', 'Horizon + activity mismatch.', 4 WHERE EXISTS (SELECT 1 FROM TradingProfiles WHERE profile_id = 1)
    AND NOT EXISTS (SELECT 1 FROM TradingProfileStrategyFit);
INSERT INTO TradingProfileStrategyFit (profile_id, strategy_name, status_label, status_tone, reason, sort_order)
SELECT 1, 'High-Conviction Bets', 'Blocked', 'danger', 'Drawdown sensitivity.', 5 WHERE EXISTS (SELECT 1 FROM TradingProfiles WHERE profile_id = 1)
    AND NOT EXISTS (SELECT 1 FROM TradingProfileStrategyFit);

INSERT INTO TradingProfileRiskSignals (profile_id, signal_type, text, sort_order)
SELECT 1, 'warning', 'Activity up without regime change', 1 WHERE EXISTS (SELECT 1 FROM TradingProfiles WHERE profile_id = 1)
    AND NOT EXISTS (SELECT 1 FROM TradingProfileRiskSignals);
INSERT INTO TradingProfileRiskSignals (profile_id, signal_type, text, sort_order)
SELECT 1, 'warning', 'Narrative persistence detected', 2 WHERE EXISTS (SELECT 1 FROM TradingProfiles WHERE profile_id = 1)
    AND NOT EXISTS (SELECT 1 FROM TradingProfileRiskSignals);
INSERT INTO TradingProfileRiskSignals (profile_id, signal_type, text, sort_order)
SELECT 1, 'action', 'Size increases frozen', 1 WHERE EXISTS (SELECT 1 FROM TradingProfiles WHERE profile_id = 1)
    AND NOT EXISTS (SELECT 1 FROM TradingProfileRiskSignals);
INSERT INTO TradingProfileRiskSignals (profile_id, signal_type, text, sort_order)
SELECT 1, 'action', 'Review recommended', 2 WHERE EXISTS (SELECT 1 FROM TradingProfiles WHERE profile_id = 1)
    AND NOT EXISTS (SELECT 1 FROM TradingProfileRiskSignals);

INSERT INTO TradingProfileRules (profile_id, rule_text, sort_order)
SELECT 1, 'No position outside active regime', 1 WHERE EXISTS (SELECT 1 FROM TradingProfiles WHERE profile_id = 1)
    AND NOT EXISTS (SELECT 1 FROM TradingProfileRules);
INSERT INTO TradingProfileRules (profile_id, rule_text, sort_order)
SELECT 1, 'No size increase without confirmation', 2 WHERE EXISTS (SELECT 1 FROM TradingProfiles WHERE profile_id = 1)
    AND NOT EXISTS (SELECT 1 FROM TradingProfileRules);
INSERT INTO TradingProfileRules (profile_id, rule_text, sort_order)
SELECT 1, 'No tactical actions on strategic capital', 3 WHERE EXISTS (SELECT 1 FROM TradingProfiles WHERE profile_id = 1)
    AND NOT EXISTS (SELECT 1 FROM TradingProfileRules);

INSERT INTO TradingProfileRuleViolations (profile_id, violation_date, rule_text, resolution_text)
SELECT 1, '2026-01-03', 'Rule 2 violated -> BTC size increase blocked', 'Automatic cap applied.'
WHERE EXISTS (SELECT 1 FROM TradingProfiles WHERE profile_id = 1)
    AND NOT EXISTS (SELECT 1 FROM TradingProfileRuleViolations);

INSERT INTO TradingProfileReviewLog (profile_id, review_date, event, decision, confidence, notes)
SELECT 1, '2026-01-03', 'Regime reassessment', 'No change', 'Medium', 'Volatility compression proved misleading.'
WHERE EXISTS (SELECT 1 FROM TradingProfiles WHERE profile_id = 1)
    AND NOT EXISTS (SELECT 1 FROM TradingProfileReviewLog);
INSERT INTO TradingProfileReviewLog (profile_id, review_date, event, decision, confidence, notes)
SELECT 1, '2025-12-01', 'Annual profile review', 'Increase belief updating weight', 'High', 'Macro signals improved, but sizing discipline remains priority.'
WHERE EXISTS (SELECT 1 FROM TradingProfiles WHERE profile_id = 1)
    AND NOT EXISTS (SELECT 1 FROM TradingProfileReviewLog);

-- migrate:down
DROP TABLE IF EXISTS TradingProfileReviewLog;
DROP TABLE IF EXISTS TradingProfileRuleViolations;
DROP TABLE IF EXISTS TradingProfileRules;
DROP TABLE IF EXISTS TradingProfileRiskSignals;
DROP TABLE IF EXISTS TradingProfileStrategyFit;
DROP TABLE IF EXISTS TradingProfileRegimeSignals;
DROP TABLE IF EXISTS TradingProfileDominance;
DROP TABLE IF EXISTS TradingProfileCoordinates;
DROP TABLE IF EXISTS TradingProfiles;
