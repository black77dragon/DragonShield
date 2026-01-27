-- migrate:up
-- Purpose: Remove thesis management tables.

DROP TABLE IF EXISTS RiskWeeklyAssessmentItem;
DROP TABLE IF EXISTS DriverWeeklyAssessmentItem;
DROP TABLE IF EXISTS PortfolioThesisWeeklyAssessment;
DROP TABLE IF EXISTS PortfolioThesisExposureRule;
DROP TABLE IF EXISTS PortfolioThesisSleeve;
DROP TABLE IF EXISTS PortfolioThesisLink;
DROP TABLE IF EXISTS ThesisRiskDefinition;
DROP TABLE IF EXISTS ThesisDriverDefinition;
DROP TABLE IF EXISTS ThesisBullet;
DROP TABLE IF EXISTS ThesisSection;
DROP TABLE IF EXISTS ThesisDefinition;

-- migrate:down
-- Recreate thesis management tables (rollback).

CREATE TABLE IF NOT EXISTS ThesisDefinition (
    thesis_def_id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL CHECK (LENGTH(name) BETWEEN 1 AND 120),
    summary_core_thesis TEXT NULL CHECK (LENGTH(summary_core_thesis) <= 8000),
    default_scoring_rules TEXT NULL,
    created_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
    updated_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE TABLE IF NOT EXISTS ThesisSection (
    section_id INTEGER PRIMARY KEY AUTOINCREMENT,
    thesis_def_id INTEGER NOT NULL REFERENCES ThesisDefinition(thesis_def_id) ON DELETE CASCADE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    headline TEXT NOT NULL CHECK (LENGTH(headline) BETWEEN 1 AND 200),
    description TEXT NULL CHECK (LENGTH(description) <= 4000),
    rag_default TEXT NULL CHECK (rag_default IN ('green','amber','red')),
    score_default INTEGER NULL CHECK (score_default BETWEEN 1 AND 10),
    created_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
    updated_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now'))
);
CREATE INDEX IF NOT EXISTS idx_thesis_section_def_order ON ThesisSection(thesis_def_id, sort_order);

CREATE TABLE IF NOT EXISTS ThesisBullet (
    bullet_id INTEGER PRIMARY KEY AUTOINCREMENT,
    section_id INTEGER NOT NULL REFERENCES ThesisSection(section_id) ON DELETE CASCADE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    text TEXT NOT NULL CHECK (LENGTH(text) BETWEEN 1 AND 2000),
    type TEXT NOT NULL CHECK (type IN ('claim','datapoint','implication','rule')),
    linked_metrics_json TEXT NULL,
    linked_evidence_json TEXT NULL,
    created_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
    updated_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now'))
);
CREATE INDEX IF NOT EXISTS idx_thesis_bullet_section_order ON ThesisBullet(section_id, sort_order);

CREATE TABLE IF NOT EXISTS ThesisDriverDefinition (
    driver_def_id INTEGER PRIMARY KEY AUTOINCREMENT,
    thesis_def_id INTEGER NOT NULL REFERENCES ThesisDefinition(thesis_def_id) ON DELETE CASCADE,
    code TEXT NOT NULL,
    name TEXT NOT NULL CHECK (LENGTH(name) BETWEEN 1 AND 120),
    definition TEXT NULL,
    review_question TEXT NULL,
    weight REAL NULL CHECK (weight >= 0),
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
    updated_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now'))
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_thesis_driver_code ON ThesisDriverDefinition(thesis_def_id, code);
CREATE INDEX IF NOT EXISTS idx_thesis_driver_order ON ThesisDriverDefinition(thesis_def_id, sort_order);

CREATE TABLE IF NOT EXISTS ThesisRiskDefinition (
    risk_def_id INTEGER PRIMARY KEY AUTOINCREMENT,
    thesis_def_id INTEGER NOT NULL REFERENCES ThesisDefinition(thesis_def_id) ON DELETE CASCADE,
    name TEXT NOT NULL CHECK (LENGTH(name) BETWEEN 1 AND 160),
    category TEXT NOT NULL DEFAULT 'market' CHECK (category IN ('thesis-breaking','operational','market','structure','liquidity','regulatory','valuation','other')),
    what_worsens TEXT NULL,
    what_improves TEXT NULL,
    mitigations TEXT NULL,
    weight REAL NULL CHECK (weight >= 0),
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
    updated_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now'))
);
CREATE INDEX IF NOT EXISTS idx_thesis_risk_order ON ThesisRiskDefinition(thesis_def_id, sort_order);

CREATE TABLE IF NOT EXISTS PortfolioThesisLink (
    portfolio_thesis_id INTEGER PRIMARY KEY AUTOINCREMENT,
    theme_id INTEGER NOT NULL REFERENCES PortfolioTheme(id) ON DELETE CASCADE,
    thesis_def_id INTEGER NOT NULL REFERENCES ThesisDefinition(thesis_def_id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','inactive')),
    is_primary INTEGER NOT NULL DEFAULT 0 CHECK (is_primary IN (0,1)),
    review_frequency TEXT NOT NULL DEFAULT 'weekly',
    notes TEXT NULL,
    created_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
    updated_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
    UNIQUE(theme_id, thesis_def_id)
);
CREATE INDEX IF NOT EXISTS idx_portfolio_thesis_theme ON PortfolioThesisLink(theme_id, status);

CREATE TABLE IF NOT EXISTS PortfolioThesisSleeve (
    sleeve_id INTEGER PRIMARY KEY AUTOINCREMENT,
    portfolio_thesis_id INTEGER NOT NULL REFERENCES PortfolioThesisLink(portfolio_thesis_id) ON DELETE CASCADE,
    name TEXT NOT NULL CHECK (LENGTH(name) BETWEEN 1 AND 120),
    target_min_pct REAL NULL CHECK (target_min_pct >= 0),
    target_max_pct REAL NULL CHECK (target_max_pct >= 0),
    max_pct REAL NULL CHECK (max_pct >= 0),
    rule_text TEXT NULL,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
    updated_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now'))
);
CREATE INDEX IF NOT EXISTS idx_thesis_sleeve_portfolio ON PortfolioThesisSleeve(portfolio_thesis_id, sort_order);

CREATE TABLE IF NOT EXISTS PortfolioThesisExposureRule (
    exposure_rule_id INTEGER PRIMARY KEY AUTOINCREMENT,
    portfolio_thesis_id INTEGER NOT NULL REFERENCES PortfolioThesisLink(portfolio_thesis_id) ON DELETE CASCADE,
    sleeve_id INTEGER NULL REFERENCES PortfolioThesisSleeve(sleeve_id) ON DELETE SET NULL,
    rule_type TEXT NOT NULL CHECK (rule_type IN ('by_ticker','by_instrument_id','by_asset_class','by_tag','by_custom_query')),
    rule_value TEXT NOT NULL,
    weighting REAL NULL CHECK (weighting >= 0),
    effective_from TEXT NULL,
    effective_to TEXT NULL,
    is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0,1)),
    created_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
    updated_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now'))
);
CREATE INDEX IF NOT EXISTS idx_thesis_exposure_portfolio ON PortfolioThesisExposureRule(portfolio_thesis_id, rule_type);
CREATE INDEX IF NOT EXISTS idx_thesis_exposure_sleeve ON PortfolioThesisExposureRule(sleeve_id);

CREATE TABLE IF NOT EXISTS PortfolioThesisWeeklyAssessment (
    assessment_id INTEGER PRIMARY KEY AUTOINCREMENT,
    weekly_checklist_id INTEGER NOT NULL REFERENCES WeeklyChecklist(id) ON DELETE CASCADE,
    portfolio_thesis_id INTEGER NOT NULL REFERENCES PortfolioThesisLink(portfolio_thesis_id) ON DELETE CASCADE,
    verdict TEXT NULL CHECK (verdict IN ('valid','watch','impaired','broken')),
    rag TEXT NULL CHECK (rag IN ('green','amber','red')),
    driver_strength_score REAL NULL CHECK (driver_strength_score >= 0 AND driver_strength_score <= 10),
    risk_pressure_score REAL NULL CHECK (risk_pressure_score >= 0 AND risk_pressure_score <= 10),
    top_changes_text TEXT NULL,
    actions_summary TEXT NULL,
    created_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
    updated_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
    UNIQUE(weekly_checklist_id, portfolio_thesis_id)
);
CREATE INDEX IF NOT EXISTS idx_thesis_assessment_weekly ON PortfolioThesisWeeklyAssessment(weekly_checklist_id);
CREATE INDEX IF NOT EXISTS idx_thesis_assessment_portfolio ON PortfolioThesisWeeklyAssessment(portfolio_thesis_id);

CREATE TABLE IF NOT EXISTS DriverWeeklyAssessmentItem (
    assessment_item_id INTEGER PRIMARY KEY AUTOINCREMENT,
    assessment_id INTEGER NOT NULL REFERENCES PortfolioThesisWeeklyAssessment(assessment_id) ON DELETE CASCADE,
    driver_def_id INTEGER NOT NULL REFERENCES ThesisDriverDefinition(driver_def_id) ON DELETE CASCADE,
    rag TEXT NULL CHECK (rag IN ('green','amber','red')),
    score INTEGER NULL CHECK (score BETWEEN 1 AND 10),
    delta_vs_prior INTEGER NULL,
    change_sentence TEXT NULL,
    evidence_refs_json TEXT NULL,
    implication TEXT NULL CHECK (implication IN ('none','monitor','adjust')),
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
    updated_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
    UNIQUE(assessment_id, driver_def_id)
);
CREATE INDEX IF NOT EXISTS idx_driver_assessment_order ON DriverWeeklyAssessmentItem(assessment_id, sort_order);

CREATE TABLE IF NOT EXISTS RiskWeeklyAssessmentItem (
    assessment_item_id INTEGER PRIMARY KEY AUTOINCREMENT,
    assessment_id INTEGER NOT NULL REFERENCES PortfolioThesisWeeklyAssessment(assessment_id) ON DELETE CASCADE,
    risk_def_id INTEGER NOT NULL REFERENCES ThesisRiskDefinition(risk_def_id) ON DELETE CASCADE,
    rag TEXT NULL CHECK (rag IN ('green','amber','red')),
    score INTEGER NULL CHECK (score BETWEEN 1 AND 10),
    delta_vs_prior INTEGER NULL,
    change_sentence TEXT NULL,
    evidence_refs_json TEXT NULL,
    thesis_impact TEXT NULL CHECK (thesis_impact IN ('none','minor','material')),
    recommended_action TEXT NULL CHECK (recommended_action IN ('none','hedge','rebalance','reduce','exit')),
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
    updated_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
    UNIQUE(assessment_id, risk_def_id)
);
CREATE INDEX IF NOT EXISTS idx_risk_assessment_order ON RiskWeeklyAssessmentItem(assessment_id, sort_order);
