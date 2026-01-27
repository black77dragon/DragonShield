// DragonShield/Thesis/ThesisStore.swift
// Local-first store and import/export helpers for Thesis Management (v1.2)

import Foundation
import Combine
import SQLite3

enum ThesisStoreError: Error, Equatable {
    case thesisNotFound
    case kpiCapExceeded
    case kpiNotFound
    case reviewFinalized
    case primaryKPIIncomplete([String])
    case duplicatePatch
    case invalidPatch(String)
}

enum PromptTemplateError: Error, Equatable {
    case databaseUnavailable
    case readOnly
    case emptyBody
    case invalidKey
    case failed(String)
}

enum ThesisKpiPromptError: Error, Equatable {
    case databaseUnavailable
    case readOnly
    case emptyBody
    case invalidKey
    case failed(String)
}

struct PatchValidationResult {
    let errors: [String]
    let warnings: [String]
    let diff: [String]
    let patch: WeeklyReviewPatch?

    var isValid: Bool { errors.isEmpty && patch != nil }
}

struct PatchApplyResult {
    let validation: PatchValidationResult
    let review: WeeklyReview?
    let isDuplicate: Bool
}

struct WeeklyReviewPatch: Codable {
    struct Summary: Codable {
        let headline: String
        let overallStatus: String?
        let confidenceScore: Int
        let assumptionsStatus: [AssumptionStatus]

        enum CodingKeys: String, CodingKey {
            case headline
            case overallStatus = "overall_status"
            case confidenceScore = "confidence_score"
            case assumptionsStatus = "assumptions_status"
        }
    }

    struct AssumptionStatus: Codable {
        let assumptionId: String
        let status: AssumptionHealth
        let note: String?

        enum CodingKeys: String, CodingKey {
            case assumptionId = "assumption_id"
            case status
            case note
        }
    }

    struct PatchKPI: Codable {
        let kpiId: String
        let currentValue: Double?
        let trend: KPITrend?
        let delta1w: Double?
        let delta4w: Double?
        let ragStatus: RAGStatus?
        let comment: String?

        enum CodingKeys: String, CodingKey {
            case kpiId = "kpi_id"
            case currentValue = "current_value"
            case trend
            case delta1w = "delta_1w"
            case delta4w = "delta_4w"
            case ragStatus = "rag_status"
            case comment
        }
    }

    struct PatchEvents: Codable {
        let macroEvents: [String]?
        let microEvents: [String]?

        enum CodingKeys: String, CodingKey {
            case macroEvents = "macro_events"
            case microEvents = "micro_events"
        }
    }

    struct PatchDecision: Codable {
        let action: ReviewDecision
        let rationale: [String]?
        let watchItems: [String]?

        enum CodingKeys: String, CodingKey {
            case action
            case rationale
            case watchItems = "watch_items"
        }
    }

    struct PatchIntegrity: Codable {
        let incompleteKpis: [String]?
        let rangeBreaches: [String]?
        let notes: String?

        enum CodingKeys: String, CodingKey {
            case incompleteKpis = "incomplete_kpis"
            case rangeBreaches = "range_breaches"
            case notes
        }
    }

    let schema: String
    let patchId: String
    let generatedAt: String
    let model: String
    let thesisId: String
    let week: String
    let summary: Summary
    let kpis: [PatchKPI]
    let events: PatchEvents
    let decision: PatchDecision
    let integrity: PatchIntegrity

    enum CodingKeys: String, CodingKey {
        case schema
        case patchId = "patch_id"
        case generatedAt = "generated_at"
        case model
        case thesisId = "thesis_id"
        case week
        case summary
        case kpis
        case events
        case decision
        case integrity
    }
}

final class ThesisStore: ObservableObject {
    @Published private(set) var theses: [Thesis] = []
    @Published private(set) var reviews: [WeeklyReview] = []
    @Published private(set) var appliedPatchIds: Set<String> = []
    @Published private(set) var promptTemplates: [PromptTemplate] = []
    @Published private(set) var thesisKpiPrompts: [ThesisKpiPrompt] = []

    private let dbManager: DatabaseManager?
    private static let thesisImportPromptKey = "thesis_import_prompt_v1"
    private static let weeklyReviewPromptKey = "weekly_review_prompt_v1"
    private static let defaultThesisImportPrompt = """
    You are given thesis notes. First, assess whether the input includes everything needed for the thesis_import_v1 schema. If anything is missing or unclear (for example, no kill criteria), ask concise clarification questions in plain text and do not output JSON yet. Only after all required details are provided should you proceed to generate the JSON file.

    Output rules (must follow exactly when you output JSON):
    - Return ONLY valid JSON. No markdown, no commentary, no code fences.
    - Use ASCII double quotes (") only. Do NOT use smart quotes.
    - No trailing commas. No NaN/Infinity.
    - Use the exact schema below. No extra keys.
    - Use numbers for numeric fields and true/false for booleans (not strings).

    Content rules:
    - Primary KPIs: 3-5. Secondary KPIs: 0-4. Total <= 9.
    - Assumptions: 3-5. Kill criteria: at least 1.
    - tier must be "tier1" or "tier2".
    - investment_role must be one of: Hedge, Convexity, Growth, Income, Optionality.
    - Ranges must satisfy lower < upper.

    Schema (thesis_import_v1):
    {
      "schema": "thesis_import_v1",
      "name": "Thesis name",
      "tier": "tier1",
      "investment_role": "Hedge | Convexity | Growth | Income | Optionality",
      "north_star": "5-8 sentences",
      "non_goals": "Boundaries and exclusions",
      "assumptions": [
        { "id": "optional or null", "title": "Assumption 1", "detail": "Falsifiable detail" }
      ],
      "kill_criteria": [
        { "id": "optional or null", "description": "Binary invalidation condition" }
      ],
      "kpis": [
        {
          "id": "optional or null",
          "name": "KPI name",
          "unit": "unit",
          "description": "What it measures",
          "source": "optional; where data comes from",
          "is_primary": true,
          "direction": "higherIsBetter",
          "ranges": {
            "green": { "lower": 0, "upper": 0 },
            "amber": { "lower": 0, "upper": 0 },
            "red": { "lower": 0, "upper": 0 }
          }
        }
      ]
    }
    """
    private static let weeklyReviewPatchSchemaTemplate = """
    {
      "schema": "weekly_review_patch_v1",
      "patch_id": "uuid",
      "generated_at": "YYYY-MM-DD",
      "model": "model-id",
      "thesis_id": "{{THESIS_ID}}",
      "week": "YYYY-Www",
      "summary": {
        "headline": "string",
        "overall_status": "green | amber | red | unknown",
        "confidence_score": 1,
        "assumptions_status": [
          { "assumption_id": "assumption_id", "status": "intact | stressed | violated", "note": "string or null" }
        ]
      },
      "kpis": [
        {
          "kpi_id": "kpi_id",
          "current_value": 0.0,
          "trend": "up | flat | down | na",
          "delta_1w": 0.0,
          "delta_4w": 0.0,
          "rag_status": "green | amber | red | unknown",
          "comment": "string or null"
        }
      ],
      "events": {
        "macro_events": ["string"],
        "micro_events": ["string"]
      },
      "decision": {
        "action": "Add | Trim | Hold | Pause | Exit | Monitor",
        "rationale": ["string"],
        "watch_items": ["string"]
      },
      "integrity": {
        "incomplete_kpis": ["kpi_id"],
        "range_breaches": ["kpi_id"],
        "notes": "string or null"
      }
    }
    """
    private static let defaultWeeklyReviewPrompt = """
    ROLE & STANDARD

    You are acting as a Tier-1 buy-side investment analyst producing a weekly thesis review patch for a portfolio management system.

    Your output will directly inform capital allocation decisions.

    Quality bar
    - Facts only. No speculation presented as fact.
    - Every material claim must be backed by verifiable sources.
    - If data is unavailable, inconsistent, or unverifiable, you must explicitly say so.
    - Hallucination or inference beyond sources is a hard failure.

    ---

    INPUTS PROVIDED

    You are given:
    - Full thesis definition (North Star, role, non-goals, assumptions, kill criteria)
    - KPI definitions with authoritative ranges and data sources (system truth)
    - A thesis-specific KPI pack prompt for KPI updates (if provided)
    - A target WeeklyReviewPatch v1 JSON schema
    - A unique Thesis ID

    You must not alter the thesis, KPI definitions, or ranges.

    THESIS INPUTS (SYSTEM-PROVIDED)

    Thesis ID: {{THESIS_ID}}
    Name: {{THESIS_NAME}}
    Tier: {{THESIS_TIER}}
    North Star: {{THESIS_NORTH_STAR}}
    Investment Role: {{THESIS_INVESTMENT_ROLE}}
    Non-goals: {{THESIS_NON_GOALS}}

    Assumptions:
    {{THESIS_ASSUMPTIONS}}

    Kill criteria:
    {{THESIS_KILL_CRITERIA}}

    {{KPI_DEFINITIONS_BLOCK}}

    KPI Pack Prompt (thesis-specific):
    {{KPI_PACK_PROMPT_BLOCK}}

    WeeklyReviewPatch v1 JSON schema:
    {{WEEKLY_REVIEW_PATCH_SCHEMA}}

    {{REVIEW_HISTORY_BLOCK}}
    {{LAST_REVIEW_BLOCK}}

    ---

    PART A - EVIDENCE-FIRST RESEARCH (FACT COLLECTION)

    Objective

    Collect current, factual, cross-validated evidence relevant to the thesis for the review period.

    Mandatory source coverage

    You must search and extract information from multiple independent source classes, including where applicable:
    1. Primary data / statistics
    - Official statistics offices (e.g., EIA, Eurostat, IEA, ISO, grid operators)
    - Market operators (ISOs, power exchanges, transmission operators)
    - Company filings if directly relevant
    2. Institutional / regulatory sources
    - Regulators, ministries, central agencies
    - Official policy releases and consultation papers
    3. Market & pricing data
    - Spot vs forward spreads
    - Congestion / scarcity indicators
    - Capacity, utilization, outage data
    4. Reputable news & analysis
    - Tier-1 newspapers and trade journals
    - Energy-specialist publications
    - No blogs, no opinion-only sources
    5. Expert signal (optional, non-binding)
    - Credible expert commentary or consensus summaries
    - Must be clearly labeled and never treated as fact

    Data requirements
    - Prefer numbers over narratives
    - Include latest available values, trends, and deltas
    - Explicitly note time period, geography, and measurement methodology
    - Maintain a source list with URLs or publication identifiers

    Hard rules
    - Do NOT fabricate data
    - Do NOT interpolate missing values
    - Do NOT convert qualitative commentary into quantitative conclusions
    - If conflicting data exists, present both and explain the discrepancy

    ---

    PART B - STRUCTURED THESIS ASSESSMENT

    You must evaluate only against the provided thesis structure, using the collected facts.

    Required assessment blocks

    1. KPI Assessment
    For each KPI:
    - Current observed value (or "data unavailable")
    - Trend vs prior period (up / flat / down)
    - RAG status based strictly on predefined ranges
    - One-line factual interpretation

    2. Material Events
    Identify events that are new, material, and relevant to the thesis:
    - Regulatory changes
    - Supply disruptions
    - Demand shocks
    - Geopolitical escalations
    - Structural policy decisions

    Each event must include:
    - What happened
    - Why it matters to this thesis
    - Source reference(s)

    3. Assumption Check
    For each assumption:
    - Status: holding / weakening / violated
    - Evidence supporting the status
    - Explicit citation

    4. Kill Criteria Check
    For each kill criterion:
    - Triggered: true / false
    - Evidence assessment
    - Clear explanation (binary logic, no hedging)

    5. Rationale Update
    Synthesize:
    - What changed since last review
    - Why it matters
    - Whether the thesis strength improved, deteriorated, or stayed stable

    No storytelling. Causal logic only.

    6. Watch Items
    List forward-looking items to monitor:
    - Upcoming decisions
    - Data releases
    - Policy milestones
    - Known stress points

    ---

    PART C - JSON GENERATION (STRICT OUTPUT)

    Output requirements
    - Produce ONLY a valid WeeklyReviewPatch v1 JSON object
    - No markdown
    - No commentary
    - No prose outside JSON
    - ASCII characters only
    - UTF-8, LF line endings
    - Fully machine-parsable

    Validation rules
    - All required fields present
    - KPI statuses must align with numeric ranges
    - No invented fields
    - All referenced facts must appear in the evidence base
    - If any required element cannot be populated due to missing data -> STOP and report failure instead of generating JSON

    ---

    FAILURE CONDITIONS (MANDATORY STOP)

    You must stop and ask for clarification if:
    - A KPI cannot be measured with available data
    - A source cannot be verified
    - The thesis definition is internally inconsistent
    - The schema version is unclear

    Do not "best-guess" your way through gaps.

    ---

    MENTAL MODEL (DO NOT OUTPUT)

    You are not writing commentary.
    You are producing a forensic delta record between:

    Last known thesis state -> current world state

    Precision > fluency
    Evidence > intuition
    Discipline > completeness
    """

    init(dbManager: DatabaseManager? = nil, seedDemoData: Bool = true) {
        self.dbManager = dbManager
        dbManager?.ensureThesisTables()
        loadFromDatabase()
        reloadThesisKpiPrompts()
        reloadPromptTemplates()
        bootstrapPromptTemplatesIfNeeded()
        reloadPromptTemplates()
        if theses.isEmpty && seedDemoData {
            seedIntoDatabase()
            loadFromDatabase()
            reloadThesisKpiPrompts()
        }
    }

    func thesisImportPrompt() -> String {
        activePromptTemplateBody(for: .thesisImport) ?? Self.defaultThesisImportPrompt
    }

    func saveThesisImportPrompt(_ text: String) {
        _ = createPromptTemplateVersion(key: .thesisImport, body: text, settings: nil)
    }

    func weeklyReviewPromptTemplate() -> String {
        activePromptTemplateBody(for: .weeklyReview) ?? Self.defaultWeeklyReviewPrompt
    }

    func saveWeeklyReviewPromptTemplate(_ text: String) {
        _ = createPromptTemplateVersion(
            key: .weeklyReview,
            body: text,
            settings: PromptTemplateSettings.weeklyReviewDefault
        )
    }

    func promptTemplates(for key: PromptTemplateKey) -> [PromptTemplate] {
        promptTemplates
            .filter { $0.key == key }
            .sorted { $0.version > $1.version }
    }

    func activePromptTemplate(for key: PromptTemplateKey) -> PromptTemplate? {
        promptTemplates.first(where: { $0.key == key && $0.status == .active })
    }

    func createPromptTemplateVersion(
        key: PromptTemplateKey,
        body: String,
        settings: PromptTemplateSettings?
    ) -> Result<PromptTemplate, PromptTemplateError> {
        guard let dbManager, let db = dbManager.db else { return .failure(.databaseUnavailable) }
        if sqlite3_db_readonly(db, "main") == 1 { return .failure(.readOnly) }
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.emptyBody) }

        let nextVersion = (promptTemplates(for: key).map(\.version).max() ?? 0) + 1
        let settingsJson = settings.flatMap { encodeSettings($0) }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

        let begin = "BEGIN TRANSACTION;"
        let deactivate = "UPDATE PromptTemplate SET status = 'inactive', updated_at = STRFTIME('%Y-%m-%dT%H:%M:%fZ','now') WHERE template_key = ? AND status = 'active';"
        let insert = """
        INSERT INTO PromptTemplate (template_key, version, status, body, settings_json)
        VALUES (?, ?, 'active', ?, ?);
        """
        let commit = "COMMIT;"

        guard sqlite3_exec(db, begin, nil, nil, nil) == SQLITE_OK else {
            return .failure(.failed(dbManager.lastSQLErrorMessage()))
        }

        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, deactivate, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, key.rawValue, -1, SQLITE_TRANSIENT)
            if sqlite3_step(stmt) != SQLITE_DONE {
                sqlite3_finalize(stmt)
                sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
                return .failure(.failed(dbManager.lastSQLErrorMessage()))
            }
        } else {
            sqlite3_finalize(stmt)
            sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
            return .failure(.failed(dbManager.lastSQLErrorMessage()))
        }
        sqlite3_finalize(stmt)

        if sqlite3_prepare_v2(db, insert, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, key.rawValue, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(stmt, 2, Int32(nextVersion))
            sqlite3_bind_text(stmt, 3, trimmed, -1, SQLITE_TRANSIENT)
            if let settingsJson {
                sqlite3_bind_text(stmt, 4, settingsJson, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(stmt, 4)
            }
            if sqlite3_step(stmt) != SQLITE_DONE {
                sqlite3_finalize(stmt)
                sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
                return .failure(.failed(dbManager.lastSQLErrorMessage()))
            }
        } else {
            sqlite3_finalize(stmt)
            sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
            return .failure(.failed(dbManager.lastSQLErrorMessage()))
        }
        sqlite3_finalize(stmt)

        guard sqlite3_exec(db, commit, nil, nil, nil) == SQLITE_OK else {
            sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
            return .failure(.failed(dbManager.lastSQLErrorMessage()))
        }

        reloadPromptTemplates()
        if let created = activePromptTemplate(for: key) {
            return .success(created)
        }
        return .failure(.failed("Template created but not found"))
    }

    func activatePromptTemplate(id: Int) -> Result<PromptTemplate, PromptTemplateError> {
        guard let dbManager, let db = dbManager.db else { return .failure(.databaseUnavailable) }
        if sqlite3_db_readonly(db, "main") == 1 { return .failure(.readOnly) }
        guard let template = promptTemplates.first(where: { $0.id == id }) else { return .failure(.invalidKey) }
        if template.status == .active { return .success(template) }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        let begin = "BEGIN TRANSACTION;"
        let deactivate = "UPDATE PromptTemplate SET status = 'inactive', updated_at = STRFTIME('%Y-%m-%dT%H:%M:%fZ','now') WHERE template_key = ? AND status = 'active';"
        let activate = "UPDATE PromptTemplate SET status = 'active', updated_at = STRFTIME('%Y-%m-%dT%H:%M:%fZ','now') WHERE id = ?;"
        guard sqlite3_exec(db, begin, nil, nil, nil) == SQLITE_OK else {
            return .failure(.failed(dbManager.lastSQLErrorMessage()))
        }
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, deactivate, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, template.key.rawValue, -1, SQLITE_TRANSIENT)
            if sqlite3_step(stmt) != SQLITE_DONE {
                sqlite3_finalize(stmt)
                sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
                return .failure(.failed(dbManager.lastSQLErrorMessage()))
            }
        } else {
            sqlite3_finalize(stmt)
            sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
            return .failure(.failed(dbManager.lastSQLErrorMessage()))
        }
        sqlite3_finalize(stmt)

        if sqlite3_prepare_v2(db, activate, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(id))
            if sqlite3_step(stmt) != SQLITE_DONE {
                sqlite3_finalize(stmt)
                sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
                return .failure(.failed(dbManager.lastSQLErrorMessage()))
            }
        } else {
            sqlite3_finalize(stmt)
            sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
            return .failure(.failed(dbManager.lastSQLErrorMessage()))
        }
        sqlite3_finalize(stmt)
        if sqlite3_exec(db, "COMMIT;", nil, nil, nil) != SQLITE_OK {
            sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
            return .failure(.failed(dbManager.lastSQLErrorMessage()))
        }

        reloadPromptTemplates()
        guard let active = activePromptTemplate(for: template.key) else {
            return .failure(.failed("Active template not found"))
        }
        return .success(active)
    }

    func archivePromptTemplate(id: Int) -> Result<PromptTemplate, PromptTemplateError> {
        guard let dbManager, let db = dbManager.db else { return .failure(.databaseUnavailable) }
        if sqlite3_db_readonly(db, "main") == 1 { return .failure(.readOnly) }
        guard let template = promptTemplates.first(where: { $0.id == id }) else { return .failure(.invalidKey) }
        if template.status == .active { return .failure(.failed("Cannot archive active template")) }
        let sql = "UPDATE PromptTemplate SET status = 'archived', updated_at = STRFTIME('%Y-%m-%dT%H:%M:%fZ','now') WHERE id = ?;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(id))
            if sqlite3_step(stmt) != SQLITE_DONE {
                sqlite3_finalize(stmt)
                return .failure(.failed(dbManager.lastSQLErrorMessage()))
            }
        } else {
            sqlite3_finalize(stmt)
            return .failure(.failed(dbManager.lastSQLErrorMessage()))
        }
        sqlite3_finalize(stmt)
        reloadPromptTemplates()
        if let updated = promptTemplates.first(where: { $0.id == id }) {
            return .success(updated)
        }
        return .failure(.failed("Archived template not found"))
    }

    func promptTemplateSettings(for key: PromptTemplateKey) -> PromptTemplateSettings {
        activePromptTemplate(for: key)?.settings ?? .weeklyReviewDefault
    }

    func thesisKpiPrompts(for thesisId: String) -> [ThesisKpiPrompt] {
        thesisKpiPrompts
            .filter { $0.thesisId == thesisId }
            .sorted { $0.version > $1.version }
    }

    func activeThesisKpiPrompt(for thesisId: String) -> ThesisKpiPrompt? {
        thesisKpiPrompts.first(where: { $0.thesisId == thesisId && $0.status == .active })
    }

    func createThesisKpiPromptVersion(thesisId: String, body: String) -> Result<ThesisKpiPrompt, ThesisKpiPromptError> {
        guard let dbManager, let db = dbManager.db else { return .failure(.databaseUnavailable) }
        if sqlite3_db_readonly(db, "main") == 1 { return .failure(.readOnly) }
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.emptyBody) }

        let nextVersion = (thesisKpiPrompts(for: thesisId).map(\.version).max() ?? 0) + 1
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

        let begin = "BEGIN TRANSACTION;"
        let deactivate = "UPDATE ThesisKPIPrompt SET status = 'inactive', updated_at = STRFTIME('%Y-%m-%dT%H:%M:%fZ','now') WHERE thesis_id = ? AND status = 'active';"
        let insert = """
        INSERT INTO ThesisKPIPrompt (thesis_id, version, status, body)
        VALUES (?, ?, 'active', ?);
        """
        let commit = "COMMIT;"

        guard sqlite3_exec(db, begin, nil, nil, nil) == SQLITE_OK else {
            return .failure(.failed(dbManager.lastSQLErrorMessage()))
        }

        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, deactivate, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, thesisId, -1, SQLITE_TRANSIENT)
            if sqlite3_step(stmt) != SQLITE_DONE {
                sqlite3_finalize(stmt)
                sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
                return .failure(.failed(dbManager.lastSQLErrorMessage()))
            }
        } else {
            sqlite3_finalize(stmt)
            sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
            return .failure(.failed(dbManager.lastSQLErrorMessage()))
        }
        sqlite3_finalize(stmt)

        if sqlite3_prepare_v2(db, insert, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, thesisId, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(stmt, 2, Int32(nextVersion))
            sqlite3_bind_text(stmt, 3, trimmed, -1, SQLITE_TRANSIENT)
            if sqlite3_step(stmt) != SQLITE_DONE {
                sqlite3_finalize(stmt)
                sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
                return .failure(.failed(dbManager.lastSQLErrorMessage()))
            }
        } else {
            sqlite3_finalize(stmt)
            sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
            return .failure(.failed(dbManager.lastSQLErrorMessage()))
        }
        sqlite3_finalize(stmt)
        if sqlite3_exec(db, commit, nil, nil, nil) != SQLITE_OK {
            sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
            return .failure(.failed(dbManager.lastSQLErrorMessage()))
        }

        reloadThesisKpiPrompts()
        guard let active = activeThesisKpiPrompt(for: thesisId) else {
            return .failure(.failed("Active prompt not found"))
        }
        return .success(active)
    }

    func activateThesisKpiPrompt(id: Int) -> Result<ThesisKpiPrompt, ThesisKpiPromptError> {
        guard let dbManager, let db = dbManager.db else { return .failure(.databaseUnavailable) }
        if sqlite3_db_readonly(db, "main") == 1 { return .failure(.readOnly) }
        guard let prompt = thesisKpiPrompts.first(where: { $0.id == id }) else { return .failure(.invalidKey) }

        let begin = "BEGIN TRANSACTION;"
        let deactivate = "UPDATE ThesisKPIPrompt SET status = 'inactive', updated_at = STRFTIME('%Y-%m-%dT%H:%M:%fZ','now') WHERE thesis_id = ? AND status = 'active';"
        let activate = "UPDATE ThesisKPIPrompt SET status = 'active', updated_at = STRFTIME('%Y-%m-%dT%H:%M:%fZ','now') WHERE id = ?;"
        let commit = "COMMIT;"
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

        guard sqlite3_exec(db, begin, nil, nil, nil) == SQLITE_OK else {
            return .failure(.failed(dbManager.lastSQLErrorMessage()))
        }

        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, deactivate, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, prompt.thesisId, -1, SQLITE_TRANSIENT)
            if sqlite3_step(stmt) != SQLITE_DONE {
                sqlite3_finalize(stmt)
                sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
                return .failure(.failed(dbManager.lastSQLErrorMessage()))
            }
        } else {
            sqlite3_finalize(stmt)
            sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
            return .failure(.failed(dbManager.lastSQLErrorMessage()))
        }
        sqlite3_finalize(stmt)

        if sqlite3_prepare_v2(db, activate, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(id))
            if sqlite3_step(stmt) != SQLITE_DONE {
                sqlite3_finalize(stmt)
                sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
                return .failure(.failed(dbManager.lastSQLErrorMessage()))
            }
        } else {
            sqlite3_finalize(stmt)
            sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
            return .failure(.failed(dbManager.lastSQLErrorMessage()))
        }
        sqlite3_finalize(stmt)
        if sqlite3_exec(db, commit, nil, nil, nil) != SQLITE_OK {
            sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
            return .failure(.failed(dbManager.lastSQLErrorMessage()))
        }

        reloadThesisKpiPrompts()
        guard let active = activeThesisKpiPrompt(for: prompt.thesisId) else {
            return .failure(.failed("Active prompt not found"))
        }
        return .success(active)
    }

    func archiveThesisKpiPrompt(id: Int) -> Result<ThesisKpiPrompt, ThesisKpiPromptError> {
        guard let dbManager, let db = dbManager.db else { return .failure(.databaseUnavailable) }
        if sqlite3_db_readonly(db, "main") == 1 { return .failure(.readOnly) }
        guard let prompt = thesisKpiPrompts.first(where: { $0.id == id }) else { return .failure(.invalidKey) }
        if prompt.status == .active { return .failure(.failed("Cannot archive active prompt")) }
        let sql = "UPDATE ThesisKPIPrompt SET status = 'archived', updated_at = STRFTIME('%Y-%m-%dT%H:%M:%fZ','now') WHERE id = ?;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(id))
            if sqlite3_step(stmt) != SQLITE_DONE {
                sqlite3_finalize(stmt)
                return .failure(.failed(dbManager.lastSQLErrorMessage()))
            }
        } else {
            sqlite3_finalize(stmt)
            return .failure(.failed(dbManager.lastSQLErrorMessage()))
        }
        sqlite3_finalize(stmt)
        reloadThesisKpiPrompts()
        if let updated = thesisKpiPrompts.first(where: { $0.id == id }) {
            return .success(updated)
        }
        return .failure(.failed("Archived prompt not found"))
    }

    func thesis(id: String) -> Thesis? {
        theses.first(where: { $0.id == id })
    }

    func latestReview(for thesisId: String) -> WeeklyReview? {
        reviews
            .filter { $0.thesisId == thesisId }
            .sorted { $0.week > $1.week }
            .first
    }

    func reviews(for thesisId: String) -> [WeeklyReview] {
        reviews
            .filter { $0.thesisId == thesisId }
            .sorted { $0.week > $1.week }
    }

    func history(for thesisId: String, kpiId: String, limit: Int? = nil) -> [KPIHistoryPoint] {
        let filtered = reviews(for: thesisId)
        let points: [KPIHistoryPoint] = filtered.compactMap { review in
            guard let reading = review.kpiReadings.first(where: { $0.kpiId == kpiId }) else { return nil }
            return KPIHistoryPoint(week: review.week, value: reading.currentValue, status: reading.status)
        }
        if let limit {
            return Array(points.prefix(limit))
        }
        return points
    }

    func addKPI(to thesisId: String, definition: KPIDefinition) -> Result<KPIDefinition, ThesisStoreError> {
        guard let index = theses.firstIndex(where: { $0.id == thesisId }) else {
            return .failure(.thesisNotFound)
        }
        var thesis = theses[index]
        let primaryCount = thesis.primaryKPIs.count
        let secondaryCount = thesis.secondaryKPIs.count
        if definition.isPrimary {
            if primaryCount >= 5 { return .failure(.kpiCapExceeded) }
        } else {
            if secondaryCount >= 4 { return .failure(.kpiCapExceeded) }
        }
        if (primaryCount + secondaryCount) >= 9 {
            return .failure(.kpiCapExceeded)
        }
        if definition.isPrimary {
            thesis.primaryKPIs.append(definition)
        } else {
            thesis.secondaryKPIs.append(definition)
        }
        theses[index] = thesis
        persistKPIs([definition], thesisId: thesisId)
        return .success(definition)
    }

    func startDraft(thesisId: String, week: WeekNumber) -> WeeklyReview? {
        guard let thesis = thesis(id: thesisId) else { return nil }
        if let existing = reviews.first(where: { $0.thesisId == thesisId && $0.week == week }) {
            var updated = existing
            updated.kpiReadings = normalizedReadings(for: updated, thesis: thesis)
            updated.killCriteriaStatuses = normalizedKillCriteriaStatuses(
                existing: updated.killCriteriaStatuses,
                thesis: thesis,
                preserveTriggered: updated.killSwitchTriggered && updated.killCriteriaStatuses.isEmpty
            )
            if !updated.killCriteriaStatuses.isEmpty {
                updated.killSwitchTriggered = updated.killCriteriaStatuses.contains(where: { $0.status == .triggered })
            }
            updated.missingPrimaryKpis = thesis.primaryKPIs.compactMap { def in
                updated.kpiReadings.first(where: { $0.kpiId == def.id })?.currentValue == nil ? def.id : nil
            }
            return updated
        }
        let assumptionStatuses = thesis.assumptions.map { AssumptionStatusEntry(assumptionId: $0.id, status: .intact, note: nil) }
        let killCriteriaStatuses = thesis.killCriteria.map { KillCriterionStatusEntry(criterionId: $0.id, status: .clear, note: nil) }
        let kpiReadings = (thesis.primaryKPIs + thesis.secondaryKPIs).map { def in
            KPIReading(kpiId: def.id, status: .unknown)
        }
        let draft = WeeklyReview(
            thesisId: thesisId,
            week: week,
            headline: "",
            confidence: 3,
            assumptionStatuses: assumptionStatuses,
            killCriteriaStatuses: killCriteriaStatuses,
            kpiReadings: kpiReadings,
            macroEvents: [],
            microEvents: [],
            decision: .hold,
            rationale: [],
            watchItems: [],
            status: .unknown,
            createdAt: Date(),
            finalizedAt: nil,
            patchId: nil,
            killSwitchTriggered: false,
            notes: nil,
            missingPrimaryKpis: thesis.primaryKPIs.map(\.id)
        )
        return draft
    }

    func save(review: WeeklyReview, finalize: Bool) -> Result<WeeklyReview, ThesisStoreError> {
        guard let thesis = thesis(id: review.thesisId) else { return .failure(.thesisNotFound) }
        if let index = reviews.firstIndex(where: { $0.id == review.id }) {
            if reviews[index].finalizedAt != nil {
                return .failure(.reviewFinalized)
            }
        }
        var updated = review
        let definitionMap = Dictionary(uniqueKeysWithValues: (thesis.primaryKPIs + thesis.secondaryKPIs).map { ($0.id, $0) })
        updated.kpiReadings = updated.kpiReadings.map { reading in
            var newReading = reading
            if let definition = definitionMap[reading.kpiId] {
                newReading.status = definition.ranges.status(for: reading.currentValue)
            } else {
                newReading.status = .unknown
            }
            return newReading
        }
        updated.killCriteriaStatuses = normalizedKillCriteriaStatuses(
            existing: updated.killCriteriaStatuses,
            thesis: thesis,
            preserveTriggered: updated.killSwitchTriggered && updated.killCriteriaStatuses.isEmpty
        )
        if !updated.killCriteriaStatuses.isEmpty {
            updated.killSwitchTriggered = updated.killCriteriaStatuses.contains(where: { $0.status == .triggered })
        }
        updated.missingPrimaryKpis = thesis.primaryKPIs.compactMap { def in
            let value = updated.kpiReadings.first(where: { $0.kpiId == def.id })?.currentValue
            return value == nil ? def.id : nil
        }
        updated.status = computeOverallStatus(review: updated, thesis: thesis, definitionMap: definitionMap)
        if finalize {
            if !updated.missingPrimaryKpis.isEmpty {
                return .failure(.primaryKPIIncomplete(updated.missingPrimaryKpis))
            }
            updated.finalizedAt = Date()
        }
        if let index = reviews.firstIndex(where: { $0.id == updated.id }) {
            updated.createdAt = reviews[index].createdAt
            reviews[index] = updated
        } else {
            reviews.append(updated)
        }
        persistReview(updated)
        if let patch = updated.patchId {
            appliedPatchIds.insert(patch)
        }
        objectWillChange.send()
        return .success(updated)
    }

    func unlockReview(id: UUID) -> Bool {
        guard let index = reviews.firstIndex(where: { $0.id == id }) else { return false }
        var updated = reviews[index]
        updated.finalizedAt = nil
        reviews[index] = updated
        persistReview(updated)
        objectWillChange.send()
        return true
    }

    func daysSinceLastReview(thesisId: String) -> Int? {
        guard let lastReview = latestReview(for: thesisId) else { return nil }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: lastReview.week.startDate)
        let today = calendar.startOfDay(for: Date())
        let comps = calendar.dateComponents([.day], from: start, to: today)
        return comps.day
    }

    private func applyReplacements(_ text: String, replacements: [String: String]) -> String {
        var result = text
        for (token, value) in replacements {
            result = result.replacingOccurrences(of: token, with: value)
        }
        return result
    }

    func generatePrompt(thesisId: String) -> String? {
        guard let thesis = thesis(id: thesisId) else { return nil }
        let template = activePromptTemplateBody(for: .weeklyReview) ?? Self.defaultWeeklyReviewPrompt
        let settings = activePromptTemplate(for: .weeklyReview)?.settings ?? PromptTemplateSettings.weeklyReviewDefault
        let includeRanges = settings.includeRanges
        let includeLastReview = settings.includeLastReview
        let historyWindow = max(1, settings.historyWindow)

        let assumptionsText: String = thesis.assumptions.isEmpty
            ? "- None provided."
            : thesis.assumptions.map { "- [\($0.id)] \($0.title): \($0.detail)" }.joined(separator: "\n")
        let killCriteriaText: String = thesis.killCriteria.isEmpty
            ? "- None provided."
            : thesis.killCriteria.map { "- [\($0.id)] \($0.description)" }.joined(separator: "\n")

        let kpiDefinitionsBlock: String
        if includeRanges {
            var kpiLines: [String] = ["KPI Definitions (ranges and sources are system truth):"]
            let allKpis = thesis.primaryKPIs + thesis.secondaryKPIs
            if allKpis.isEmpty {
                kpiLines.append("- None available.")
            } else {
                for kpi in allKpis {
                    let sourceText = kpi.source.trimmingCharacters(in: .whitespacesAndNewlines)
                    kpiLines.append("- [\(kpi.id)] \(kpi.name) (\(kpi.unit)) \(kpi.isPrimary ? "[PRIMARY]" : "[SECONDARY]") dir: \(kpi.direction.rawValue)")
                    kpiLines.append("  Ranges -> Green: \(kpi.ranges.green.lower)-\(kpi.ranges.green.upper), Amber: \(kpi.ranges.amber.lower)-\(kpi.ranges.amber.upper), Red: \(kpi.ranges.red.lower)-\(kpi.ranges.red.upper)")
                    kpiLines.append("  Source -> \(sourceText.isEmpty ? "not specified" : sourceText)")
                }
            }
            kpiDefinitionsBlock = kpiLines.joined(separator: "\n")
        } else {
            kpiDefinitionsBlock = "KPI Definitions: omitted per prompt settings."
        }

        let historySlice = Array(reviews(for: thesisId).prefix(historyWindow))
        var historyLines: [String] = ["Recent history (latest first):"]
        if historySlice.isEmpty {
            historyLines.append("- None available.")
        } else {
            for review in historySlice {
                historyLines.append("- Week \(review.week.stringValue) | Status: \(review.status.rawValue.uppercased()) | Decision: \(review.decision.rawValue)")
                historyLines.append("  Headline: \(review.headline)")
                let primary = thesis.primaryKPIs.prefix(3)
                for kpi in primary {
                    if let reading = review.kpiReadings.first(where: { $0.kpiId == kpi.id }) {
                        let valueText = reading.currentValue.map { String(format: "%.2f", $0) } ?? "n/a"
                        historyLines.append("  KPI \(kpi.name): \(valueText) (\(reading.status.rawValue))")
                    }
                }
            }
        }
        let reviewHistoryBlock = historyLines.joined(separator: "\n")
        let lastReviewDecision = historySlice.first?.decision.rawValue ?? "not available"
        let lastReviewBlock = includeLastReview ? "Last review decision: \(lastReviewDecision)" : ""

        let schemaText = Self.weeklyReviewPatchSchemaTemplate.replacingOccurrences(of: "{{THESIS_ID}}", with: thesis.id)
        let kpiPromptToken = "{{KPI_PACK_PROMPT_BLOCK}}"
        let rawKpiPrompt = activeThesisKpiPrompt(for: thesisId)?.body ?? ""
        let trimmedKpiPrompt = rawKpiPrompt.trimmingCharacters(in: .whitespacesAndNewlines)

        let baseReplacements: [String: String] = [
            "{{THESIS_ID}}": thesis.id,
            "{{THESIS_NAME}}": thesis.name,
            "{{THESIS_TIER}}": thesis.tier.label,
            "{{THESIS_NORTH_STAR}}": thesis.northStar,
            "{{THESIS_INVESTMENT_ROLE}}": thesis.investmentRole,
            "{{THESIS_NON_GOALS}}": thesis.nonGoals,
            "{{THESIS_ASSUMPTIONS}}": assumptionsText,
            "{{THESIS_KILL_CRITERIA}}": killCriteriaText,
            "{{KPI_DEFINITIONS_BLOCK}}": kpiDefinitionsBlock,
            "{{WEEKLY_REVIEW_PATCH_SCHEMA}}": schemaText,
            "{{REVIEW_HISTORY_BLOCK}}": reviewHistoryBlock,
            "{{LAST_REVIEW_BLOCK}}": lastReviewBlock
        ]

        let templateHasKpiBlock = template.contains(kpiPromptToken)
        let expandedKpiPrompt = applyReplacements(trimmedKpiPrompt, replacements: baseReplacements)
        var output = applyReplacements(template, replacements: baseReplacements)
        if templateHasKpiBlock {
            output = output.replacingOccurrences(of: kpiPromptToken, with: expandedKpiPrompt)
        } else if !expandedKpiPrompt.isEmpty {
            output += "\n\nKPI Pack Prompt (thesis-specific):\n\(expandedKpiPrompt)"
        }
        return output
    }

    func validatePatch(json: String) -> PatchValidationResult {
        guard let data = json.data(using: .utf8) else {
            return PatchValidationResult(errors: ["JSON is not valid UTF-8"], warnings: [], diff: [], patch: nil)
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys
        let patch: WeeklyReviewPatch
        do {
            patch = try decoder.decode(WeeklyReviewPatch.self, from: data)
        } catch {
            return PatchValidationResult(errors: ["Failed to decode patch: \(error)"], warnings: [], diff: [], patch: nil)
        }
        var errors: [String] = []
        var warnings: [String] = []
        if patch.schema.lowercased() != "weeklyreviewpatchv1" && patch.schema.lowercased() != "weekly_review_patch_v1" {
            errors.append("schema must be WeeklyReviewPatch v1")
        }
        guard let thesis = thesis(id: patch.thesisId) else {
            errors.append("thesis_id \(patch.thesisId) unknown")
            return PatchValidationResult(errors: errors, warnings: warnings, diff: [], patch: patch)
        }
        guard let weekNumber = WeekNumber(string: patch.week) else {
            errors.append("week must be in format YYYY-Www")
            return PatchValidationResult(errors: errors, warnings: warnings, diff: [], patch: patch)
        }
        if !(1...5).contains(patch.summary.confidenceScore) {
            errors.append("confidence_score must be 1-5")
        }
        let definitionMap = Dictionary(uniqueKeysWithValues: (thesis.primaryKPIs + thesis.secondaryKPIs).map { ($0.id, $0) })
        var unknownKpis: [String] = []
        for kpi in patch.kpis {
            if definitionMap[kpi.kpiId] == nil {
                unknownKpis.append(kpi.kpiId)
            }
        }
        if !unknownKpis.isEmpty {
            let joined = unknownKpis.joined(separator: ", ")
            errors.append("Unknown KPI ids: \(joined)")
        }
        let missingPrimary = thesis.primaryKPIs.compactMap { def in
            patch.kpis.first(where: { $0.kpiId == def.id }) == nil ? def.id : nil
        }
        if missingPrimary.count == thesis.primaryKPIs.count {
            warnings.append("No primary KPI values supplied in patch")
        }
        var diff: [String] = []
        if let existing = reviews.first(where: { $0.thesisId == thesis.id && $0.week == weekNumber }) {
            diff.append("Update WeeklyReview: \(existing.week.stringValue)")
            if existing.headline != patch.summary.headline {
                diff.append("- Headline: \(existing.headline) -> \(patch.summary.headline)")
            }
        } else {
            diff.append("Create WeeklyReview: \(patch.week)")
        }
        return PatchValidationResult(errors: errors, warnings: warnings, diff: diff, patch: patch)
    }

    func applyPatch(json: String, finalize: Bool) -> PatchApplyResult {
        let validation = validatePatch(json: json)
        guard validation.errors.isEmpty, let patch = validation.patch else {
            return PatchApplyResult(validation: validation, review: nil, isDuplicate: false)
        }
        if appliedPatchIds.contains(patch.patchId) {
            let existing = reviews.first(where: { $0.patchId == patch.patchId })
            return PatchApplyResult(validation: validation, review: existing, isDuplicate: true)
        }
        guard let thesis = thesis(id: patch.thesisId) else {
            return PatchApplyResult(validation: validation, review: nil, isDuplicate: false)
        }
        guard let weekNumber = WeekNumber(string: patch.week) else {
            return PatchApplyResult(validation: validation, review: nil, isDuplicate: false)
        }
        let definitionMap = Dictionary(uniqueKeysWithValues: (thesis.primaryKPIs + thesis.secondaryKPIs).map { ($0.id, $0) })
        let assumptionEntries = thesis.assumptions.map { def -> AssumptionStatusEntry in
            if let override = patch.summary.assumptionsStatus.first(where: { $0.assumptionId == def.id }) {
                return AssumptionStatusEntry(assumptionId: def.id, status: override.status, note: override.note)
            }
            return AssumptionStatusEntry(assumptionId: def.id, status: .intact, note: nil)
        }
        let readings: [KPIReading] = (thesis.primaryKPIs + thesis.secondaryKPIs).map { def in
            let incoming = patch.kpis.first(where: { $0.kpiId == def.id })
            let value = incoming?.currentValue
            let readingStatus = def.ranges.status(for: value)
            return KPIReading(
                kpiId: def.id,
                currentValue: value,
                trend: incoming?.trend ?? .na,
                delta1w: incoming?.delta1w,
                delta4w: incoming?.delta4w,
                comment: incoming?.comment,
                status: readingStatus
            )
        }
        let existingForWeek = reviews.first(where: { $0.thesisId == thesis.id && $0.week == weekNumber })
        let killCriteriaStatuses = normalizedKillCriteriaStatuses(
            existing: existingForWeek?.killCriteriaStatuses ?? [],
            thesis: thesis,
            preserveTriggered: existingForWeek?.killSwitchTriggered == true && (existingForWeek?.killCriteriaStatuses.isEmpty ?? true)
        )
        var newReview = WeeklyReview(
            id: existingForWeek?.id ?? UUID(),
            thesisId: thesis.id,
            week: weekNumber,
            headline: patch.summary.headline,
            confidence: patch.summary.confidenceScore,
            assumptionStatuses: assumptionEntries,
            killCriteriaStatuses: killCriteriaStatuses,
            kpiReadings: readings,
            macroEvents: patch.events.macroEvents ?? [],
            microEvents: patch.events.microEvents ?? [],
            decision: patch.decision.action,
            rationale: patch.decision.rationale ?? [],
            watchItems: patch.decision.watchItems ?? [],
            status: .unknown,
            createdAt: existingForWeek?.createdAt ?? Date(),
            finalizedAt: nil,
            patchId: patch.patchId,
            killSwitchTriggered: false,
            notes: patch.integrity.notes,
            missingPrimaryKpis: []
        )
        if !newReview.killCriteriaStatuses.isEmpty {
            newReview.killSwitchTriggered = newReview.killCriteriaStatuses.contains(where: { $0.status == .triggered })
        }
        let primaryMissing = thesis.primaryKPIs.compactMap { def in
            newReview.kpiReadings.first(where: { $0.kpiId == def.id })?.currentValue == nil ? def.id : nil
        }
        newReview.missingPrimaryKpis = primaryMissing
        newReview.status = computeOverallStatus(review: newReview, thesis: thesis, definitionMap: definitionMap)
        if finalize {
            if !primaryMissing.isEmpty {
                return PatchApplyResult(
                    validation: PatchValidationResult(
                        errors: ["Primary KPIs missing: \(primaryMissing.joined(separator: ", "))"],
                        warnings: validation.warnings,
                        diff: validation.diff,
                        patch: patch
                    ),
                    review: nil,
                    isDuplicate: false
                )
            }
            newReview.finalizedAt = Date()
        }
        if let index = reviews.firstIndex(where: { $0.thesisId == thesis.id && $0.week == weekNumber }) {
            if reviews[index].finalizedAt != nil {
                return PatchApplyResult(
                    validation: PatchValidationResult(
                        errors: ["Weekly review already finalized for week \(weekNumber.stringValue)"],
                        warnings: validation.warnings,
                        diff: validation.diff,
                        patch: patch
                    ),
                    review: reviews[index],
                    isDuplicate: false
                )
            }
            newReview.createdAt = reviews[index].createdAt
            reviews[index] = newReview
        } else {
            reviews.append(newReview)
        }
        appliedPatchIds.insert(patch.patchId)
        persistReview(newReview)
        objectWillChange.send()
        return PatchApplyResult(validation: validation, review: newReview, isDuplicate: false)
    }

    func computeOverallStatus(review: WeeklyReview, thesis: Thesis, definitionMap: [String: KPIDefinition]? = nil) -> RAGStatus {
        if review.killSwitchTriggered || review.killCriteriaStatuses.contains(where: { $0.status == .triggered }) {
            return .red
        }
        if review.assumptionStatuses.contains(where: { $0.status == .violated }) { return .red }
        let defMap = definitionMap ?? Dictionary(uniqueKeysWithValues: (thesis.primaryKPIs + thesis.secondaryKPIs).map { ($0.id, $0) })
        let primaryStatuses = review.kpiReadings.compactMap { reading -> RAGStatus? in
            guard let def = defMap[reading.kpiId], def.isPrimary else { return nil }
            return reading.status
        }
        if primaryStatuses.contains(.red) { return .red }
        if review.assumptionStatuses.contains(where: { $0.status == .stressed }) { return .amber }
        if primaryStatuses.contains(.amber) { return .amber }
        return .green
    }

    func topPrimaryKPIs(for thesis: Thesis, limit: Int = 3) -> [(KPIDefinition, KPIReading?)] {
        let latest = latestReview(for: thesis.id)
        let readings = latest?.kpiReadings ?? []
        let map = Dictionary(uniqueKeysWithValues: readings.map { ($0.kpiId, $0) })
        return Array(thesis.primaryKPIs.prefix(limit)).map { def in
            (def, map[def.id])
        }
    }

    func overdueFlag(for thesisId: String, thresholdDays: Int = 7) -> Bool {
        guard let days = daysSinceLastReview(thesisId: thesisId) else { return true }
        return days >= thresholdDays
    }

    // MARK: - CRUD (persisted)

    func createThesis(name: String,
                      northStar: String,
                      investmentRole: String,
                      nonGoals: String,
                      tier: ThesisTier,
                      assumptions: [AssumptionDefinition],
                      killCriteria: [KillCriterion],
                      primaryKPIs: [KPIDefinition] = [],
                      secondaryKPIs: [KPIDefinition] = []) -> Thesis
    {
        let thesis = Thesis(
            id: UUID().uuidString,
            name: name,
            northStar: northStar,
            investmentRole: investmentRole,
            nonGoals: nonGoals,
            tier: tier,
            assumptions: assumptions,
            killCriteria: killCriteria,
            primaryKPIs: primaryKPIs,
            secondaryKPIs: secondaryKPIs
        )
        theses.append(thesis)
        persistThesis(thesis, replaceExisting: false)
        persistKPIs(primaryKPIs + secondaryKPIs, thesisId: thesis.id)
        objectWillChange.send()
        return thesis
    }

    func updateThesis(_ updated: Thesis) -> Bool {
        guard let idx = theses.firstIndex(where: { $0.id == updated.id }) else { return false }
        theses[idx] = updated
        persistThesis(updated, replaceExisting: true)
        persistKPIs(updated.primaryKPIs + updated.secondaryKPIs, thesisId: updated.id)
        objectWillChange.send()
        return true
    }

    func deleteThesis(id: String) {
        theses.removeAll { $0.id == id }
        reviews.removeAll { $0.thesisId == id }
        thesisKpiPrompts.removeAll { $0.thesisId == id }
        deleteThesisFromDb(id: id)
        objectWillChange.send()
    }

    func updateKPI(thesisId: String, updated: KPIDefinition) -> Result<KPIDefinition, ThesisStoreError> {
        guard let tIndex = theses.firstIndex(where: { $0.id == thesisId }) else {
            return .failure(.thesisNotFound)
        }
        var thesis = theses[tIndex]
        if let idx = thesis.primaryKPIs.firstIndex(where: { $0.id == updated.id }) {
            if updated.isPrimary {
                thesis.primaryKPIs[idx] = updated
            } else {
                guard thesis.secondaryKPIs.count < 4 else { return .failure(.kpiCapExceeded) }
                thesis.primaryKPIs.remove(at: idx)
                thesis.secondaryKPIs.append(updated)
            }
        } else if let idx = thesis.secondaryKPIs.firstIndex(where: { $0.id == updated.id }) {
            if !updated.isPrimary {
                thesis.secondaryKPIs[idx] = updated
            } else {
                guard thesis.primaryKPIs.count < 5 else { return .failure(.kpiCapExceeded) }
                thesis.secondaryKPIs.remove(at: idx)
                thesis.primaryKPIs.append(updated)
            }
        } else {
            return .failure(.kpiNotFound)
        }
        theses[tIndex] = thesis
        persistKPIs([updated], thesisId: thesisId)
        objectWillChange.send()
        return .success(updated)
    }

    func deleteKPI(thesisId: String, kpiId: String) -> Result<Void, ThesisStoreError> {
        guard let tIndex = theses.firstIndex(where: { $0.id == thesisId }) else {
            return .failure(.thesisNotFound)
        }
        var thesis = theses[tIndex]
        let primaryCount = thesis.primaryKPIs.count
        let secondaryCount = thesis.secondaryKPIs.count
        thesis.primaryKPIs.removeAll { $0.id == kpiId }
        thesis.secondaryKPIs.removeAll { $0.id == kpiId }
        if thesis.primaryKPIs.count == primaryCount && thesis.secondaryKPIs.count == secondaryCount {
            return .failure(.kpiNotFound)
        }
        theses[tIndex] = thesis
        reviews = reviews.map { review in
            var updated = review
            updated.kpiReadings.removeAll { $0.kpiId == kpiId }
            return updated
        }
        deleteKPIFromDb(kpiId: kpiId)
        objectWillChange.send()
        return .success(())
    }

    func syncKPIs(thesisId: String) {
        guard let thesis = thesis(id: thesisId) else { return }
        persistKPIs(thesis.primaryKPIs + thesis.secondaryKPIs, thesisId: thesisId)
    }

    private func seedIntoDatabase() {
        let aiNorthStar = "Build and own the picks-and-shovels layer for enterprise AI workloads across Europe."
        let aiAssumptions = [
            AssumptionDefinition(id: "assump_ai_1", title: "GPU supply normalises", detail: "Access to compute grows faster than demand after 2026."),
            AssumptionDefinition(id: "assump_ai_2", title: "Enterprise adoption", detail: "Large enterprises standardise on hybrid cloud AI stacks."),
            AssumptionDefinition(id: "assump_ai_3", title: "Energy remains abundant", detail: "Grid upgrades keep pace with data center load.")
        ]
        let aiKill = [
            KillCriterion(id: "kill_ai_1", description: "Regulatory cap on model sizes halts hyperscale training in EU."),
            KillCriterion(id: "kill_ai_2", description: "Energy rationing >10% for data centers across two consecutive quarters.")
        ]
        let aiKPIsPrimary = [
            KPIDefinition(id: "kpi_ai_latency", name: "Inference Latency", unit: "ms p95", description: "Customer-facing latency for core workloads", source: "Internal telemetry (API monitoring)", isPrimary: true, direction: .lowerIsBetter, ranges: KPIRangeSet(green: .init(lower: 0, upper: 120), amber: .init(lower: 120, upper: 180), red: .init(lower: 180, upper: 1000))),
            KPIDefinition(id: "kpi_ai_mau", name: "Active Deployments", unit: "logos", description: "Number of active enterprise deployments", source: "CRM + billing system", isPrimary: true, direction: .higherIsBetter, ranges: KPIRangeSet(green: .init(lower: 25, upper: 200), amber: .init(lower: 15, upper: 24), red: .init(lower: 0, upper: 14))),
            KPIDefinition(id: "kpi_ai_cogs", name: "GPU COGS", unit: "% rev", description: "Compute cost as % of revenue", source: "Finance ledger (COGS)", isPrimary: true, direction: .lowerIsBetter, ranges: KPIRangeSet(green: .init(lower: 0, upper: 45), amber: .init(lower: 45, upper: 60), red: .init(lower: 60, upper: 100)))
        ]
        let aiKPIsSecondary = [
            KPIDefinition(id: "kpi_ai_breaches", name: "P1 Incidents", unit: "per qtr", description: "Security and reliability breaches", source: "Incident tracker (PagerDuty)", isPrimary: false, direction: .lowerIsBetter, ranges: KPIRangeSet(green: .init(lower: 0, upper: 2), amber: .init(lower: 3, upper: 4), red: .init(lower: 4, upper: 20))),
            KPIDefinition(id: "kpi_ai_energy", name: "Energy Price", unit: "CHF/MWh", description: "Baseload price in core regions", source: "Market data (power exchanges)", isPrimary: false, direction: .lowerIsBetter, ranges: KPIRangeSet(green: .init(lower: 0, upper: 70), amber: .init(lower: 70, upper: 110), red: .init(lower: 110, upper: 500)))
        ]
        let aiThesis = Thesis(
            id: "thesis_ai",
            name: "AI Infrastructure Rail",
            northStar: aiNorthStar,
            investmentRole: "Growth with strategic optionality on infra picks-and-shovels",
            nonGoals: "Do not chase speculative model tokens or single-vendor lock-in bets.",
            tier: .tier1,
            assumptions: aiAssumptions,
            killCriteria: aiKill,
            primaryKPIs: aiKPIsPrimary,
            secondaryKPIs: aiKPIsSecondary
        )

        let energyThesis = Thesis(
            id: "thesis_energy",
            name: "Energy Transition Backbone",
            northStar: "Capture durable value from regulated grid upgrades and storage monetisation.",
            investmentRole: "Income with moderate growth",
            nonGoals: "Avoid merchant price exposure and short-duration hype projects.",
            tier: .tier2,
            assumptions: [
                AssumptionDefinition(id: "assump_en_1", title: "Grid capex unlocked", detail: "Regulators keep approving higher allowed returns."),
                AssumptionDefinition(id: "assump_en_2", title: "Storage spreads persist", detail: "Day-night spreads remain above 25 CHF/MWh.")
            ],
            killCriteria: [
                KillCriterion(id: "kill_en_1", description: "Spread compression <10 CHF/MWh for two consecutive quarters.")
            ],
            primaryKPIs: [
                KPIDefinition(id: "kpi_en_spread", name: "Spread", unit: "CHF/MWh", description: "Day/night spread", source: "Power exchange forward curve", isPrimary: true, direction: .higherIsBetter, ranges: KPIRangeSet(green: .init(lower: 25, upper: 80), amber: .init(lower: 15, upper: 24), red: .init(lower: 0, upper: 14))),
                KPIDefinition(id: "kpi_en_reg", name: "Regulatory Clarity", unit: "score", description: "Visibility on allowed returns", source: "Regulatory filings and rulings", isPrimary: true, direction: .higherIsBetter, ranges: KPIRangeSet(green: .init(lower: 7, upper: 10), amber: .init(lower: 5, upper: 6), red: .init(lower: 0, upper: 4))),
                KPIDefinition(id: "kpi_en_capex", name: "Capex Execution", unit: "% plan", description: "Percent of plan delivered", source: "Internal project reporting", isPrimary: true, direction: .higherIsBetter, ranges: KPIRangeSet(green: .init(lower: 90, upper: 120), amber: .init(lower: 75, upper: 89), red: .init(lower: 0, upper: 74)))
            ],
            secondaryKPIs: [
                KPIDefinition(id: "kpi_en_esg", name: "ESG Pressure", unit: "events", description: "Material ESG escalations", source: "News + regulator monitoring", isPrimary: false, direction: .lowerIsBetter, ranges: KPIRangeSet(green: .init(lower: 0, upper: 1), amber: .init(lower: 2, upper: 3), red: .init(lower: 3, upper: 10)))
            ]
        )

        theses = [aiThesis, energyThesis]
        persistThesis(aiThesis, replaceExisting: false)
        persistThesis(energyThesis, replaceExisting: false)
        persistKPIs(aiKPIsPrimary + aiKPIsSecondary, thesisId: aiThesis.id)
        persistKPIs(energyThesis.primaryKPIs + energyThesis.secondaryKPIs, thesisId: energyThesis.id)
        let seeded = seedHistory(for: aiThesis, startWeekOffset: 0) + seedHistory(for: energyThesis, startWeekOffset: 0)
        seeded.forEach { _ = save(review: $0, finalize: true) }
    }

    private func seedHistory(for thesis: Thesis, startWeekOffset: Int) -> [WeeklyReview] {
        let calendar = Calendar(identifier: .iso8601)
        let currentWeek = WeekNumber.current()
        var history: [WeeklyReview] = []
        for offset in 0..<6 {
            guard let date = calendar.date(byAdding: .weekOfYear, value: -(offset + startWeekOffset), to: Date()) else { continue }
            let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            let week = WeekNumber(year: comps.yearForWeekOfYear ?? currentWeek.year, week: comps.weekOfYear ?? currentWeek.week)
            var assumptionStatuses = thesis.assumptions.map { AssumptionStatusEntry(assumptionId: $0.id, status: .intact, note: nil) }
            if offset == 1, let first = assumptionStatuses.first {
                assumptionStatuses = assumptionStatuses.map { entry in
                    if entry.assumptionId == first.assumptionId {
                        var updated = entry
                        updated.status = .stressed
                        updated.note = "Utility delays reported"
                        return updated
                    }
                    return entry
                }
            }
            let killCriteriaStatuses = thesis.killCriteria.map {
                KillCriterionStatusEntry(criterionId: $0.id, status: .clear, note: nil)
            }
            let kpiReadings: [KPIReading] = (thesis.primaryKPIs + thesis.secondaryKPIs).map { def in
                let step = Double(offset) * 0.5
                let base = min(def.ranges.green.upper, def.ranges.green.lower + step)
                let status = def.ranges.status(for: base)
                return KPIReading(kpiId: def.id, currentValue: base, trend: .flat, delta1w: 0, delta4w: 0, comment: nil, status: status)
            }
            var review = WeeklyReview(
                thesisId: thesis.id,
                week: week,
                headline: "Autogenerated seed headline \(week.stringValue)",
                confidence: 4,
                assumptionStatuses: assumptionStatuses,
                killCriteriaStatuses: killCriteriaStatuses,
                kpiReadings: kpiReadings,
                macroEvents: [],
                microEvents: [],
                decision: offset % 2 == 0 ? .hold : .monitor,
                rationale: ["Seed rationale"],
                watchItems: [],
                status: .unknown,
                createdAt: Date(),
                finalizedAt: Date(),
                patchId: nil,
                killSwitchTriggered: false,
                notes: nil,
                missingPrimaryKpis: []
            )
            review.status = computeOverallStatus(review: review, thesis: thesis)
            history.append(review)
        }
        return history
    }

    // MARK: - Persistence helpers

    private static let isoFormatter: ISO8601DateFormatter = {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fmt
    }()

    private func reloadThesisKpiPrompts() {
        thesisKpiPrompts = loadThesisKpiPromptsFromDatabase()
    }

    private func reloadPromptTemplates() {
        promptTemplates = loadPromptTemplatesFromDatabase()
    }

    private func bootstrapPromptTemplatesIfNeeded() {
        guard let dbManager, let db = dbManager.db else { return }
        if sqlite3_db_readonly(db, "main") == 1 { return }
        if promptTemplates.isEmpty {
            reloadPromptTemplates()
        }
        for key in PromptTemplateKey.allCases {
            if promptTemplates(for: key).isEmpty {
                let legacyKey = key == .thesisImport ? Self.thesisImportPromptKey : Self.weeklyReviewPromptKey
                let legacy = dbManager.configurationStore.configurationValue(for: legacyKey)
                let body = legacy?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                    ? legacy!
                    : defaultPromptTemplateBody(for: key)
                let settings = key == .weeklyReview ? PromptTemplateSettings.weeklyReviewDefault : nil
                _ = createPromptTemplateVersion(key: key, body: body, settings: settings)
            } else if activePromptTemplate(for: key) == nil,
                      let latest = promptTemplates(for: key).first {
                _ = activatePromptTemplate(id: latest.id)
            }
        }
    }

    private func activePromptTemplateBody(for key: PromptTemplateKey) -> String? {
        activePromptTemplate(for: key)?.body
    }

    private func defaultPromptTemplateBody(for key: PromptTemplateKey) -> String {
        switch key {
        case .thesisImport:
            return Self.defaultThesisImportPrompt
        case .weeklyReview:
            return Self.defaultWeeklyReviewPrompt
        }
    }

    private func encodeSettings(_ settings: PromptTemplateSettings) -> String? {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(settings) {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }

    private func decodeSettings(_ json: String?) -> PromptTemplateSettings? {
        guard let json, !json.isEmpty, let data = json.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        return try? decoder.decode(PromptTemplateSettings.self, from: data)
    }

    private func loadThesisKpiPromptsFromDatabase() -> [ThesisKpiPrompt] {
        guard let db = dbManager?.db else { return [] }
        var result: [ThesisKpiPrompt] = []
        let sql = """
        SELECT id, thesis_id, version, status, body, created_at, updated_at
        FROM ThesisKPIPrompt
        ORDER BY thesis_id, version DESC
        """
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(stmt, 0))
                guard let thesisIdC = sqlite3_column_text(stmt, 1),
                      let statusC = sqlite3_column_text(stmt, 3),
                      let bodyC = sqlite3_column_text(stmt, 4)
                else { continue }
                let thesisId = String(cString: thesisIdC)
                let statusRaw = String(cString: statusC)
                guard let status = ThesisKpiPromptStatus(rawValue: statusRaw) else { continue }
                let version = Int(sqlite3_column_int(stmt, 2))
                let body = String(cString: bodyC)
                let createdAt = sqlite3_column_text(stmt, 5).flatMap { String(cString: $0) }.flatMap { Self.isoFormatter.date(from: $0) }
                let updatedAt = sqlite3_column_text(stmt, 6).flatMap { String(cString: $0) }.flatMap { Self.isoFormatter.date(from: $0) }
                result.append(ThesisKpiPrompt(
                    id: id,
                    thesisId: thesisId,
                    version: version,
                    status: status,
                    body: body,
                    createdAt: createdAt,
                    updatedAt: updatedAt
                ))
            }
        }
        sqlite3_finalize(stmt)
        return result
    }

    private func loadPromptTemplatesFromDatabase() -> [PromptTemplate] {
        guard let db = dbManager?.db else { return [] }
        var result: [PromptTemplate] = []
        let sql = """
        SELECT id, template_key, version, status, body, settings_json, created_at, updated_at
        FROM PromptTemplate
        ORDER BY template_key, version DESC
        """
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(stmt, 0))
                guard let keyC = sqlite3_column_text(stmt, 1),
                      let statusC = sqlite3_column_text(stmt, 3),
                      let bodyC = sqlite3_column_text(stmt, 4)
                else { continue }
                let keyRaw = String(cString: keyC)
                guard let key = PromptTemplateKey(rawValue: keyRaw) else { continue }
                let statusRaw = String(cString: statusC)
                guard let status = PromptTemplateStatus(rawValue: statusRaw) else { continue }
                let version = Int(sqlite3_column_int(stmt, 2))
                let body = String(cString: bodyC)
                let settingsJson = sqlite3_column_text(stmt, 5).flatMap { String(cString: $0) }
                let createdAt = sqlite3_column_text(stmt, 6).flatMap { String(cString: $0) }.flatMap { Self.isoFormatter.date(from: $0) }
                let updatedAt = sqlite3_column_text(stmt, 7).flatMap { String(cString: $0) }.flatMap { Self.isoFormatter.date(from: $0) }
                let settings = decodeSettings(settingsJson)
                result.append(PromptTemplate(
                    id: id,
                    key: key,
                    version: version,
                    status: status,
                    body: body,
                    settings: settings,
                    createdAt: createdAt,
                    updatedAt: updatedAt
                ))
            }
        }
        sqlite3_finalize(stmt)
        return result
    }

    private func loadFromDatabase() {
        guard let db = dbManager?.db else { return }
        var loadedTheses: [Thesis] = []
        var assumptionsMap: [String: [AssumptionDefinition]] = [:]
        var killsMap: [String: [KillCriterion]] = [:]
        var kpiMap: [String: [KPIDefinition]] = [:]

        // Load base theses
        var stmt: OpaquePointer?
        let thesisSQL = "SELECT id,name,north_star,investment_role,non_goals,tier FROM Thesis"
        if sqlite3_prepare_v2(db, thesisSQL, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                guard let idC = sqlite3_column_text(stmt, 0) else { continue }
                let id = String(cString: idC)
                let name = String(cString: sqlite3_column_text(stmt, 1))
                let north = String(cString: sqlite3_column_text(stmt, 2))
                let role = String(cString: sqlite3_column_text(stmt, 3))
                let nonGoals = String(cString: sqlite3_column_text(stmt, 4))
                let tierRaw = String(cString: sqlite3_column_text(stmt, 5))
                let tier = ThesisTier(rawValue: tierRaw) ?? .tier2
                loadedTheses.append(Thesis(id: id, name: name, northStar: north, investmentRole: role, nonGoals: nonGoals, tier: tier, assumptions: [], killCriteria: [], primaryKPIs: [], secondaryKPIs: []))
            }
        }
        sqlite3_finalize(stmt)

        // Assumptions
        let assumptionSQL = "SELECT id, thesis_id, title, detail FROM ThesisAssumption"
        if sqlite3_prepare_v2(db, assumptionSQL, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                guard let idC = sqlite3_column_text(stmt, 0),
                      let thesisIdC = sqlite3_column_text(stmt, 1),
                      let titleC = sqlite3_column_text(stmt, 2),
                      let detailC = sqlite3_column_text(stmt, 3)
                else { continue }
                let thesisId = String(cString: thesisIdC)
                let def = AssumptionDefinition(id: String(cString: idC), title: String(cString: titleC), detail: String(cString: detailC))
                assumptionsMap[thesisId, default: []].append(def)
            }
        }
        sqlite3_finalize(stmt)

        // Kill criteria
        let killSQL = "SELECT id, thesis_id, description FROM ThesisKillCriterion"
        if sqlite3_prepare_v2(db, killSQL, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                guard let idC = sqlite3_column_text(stmt, 0),
                      let thesisIdC = sqlite3_column_text(stmt, 1),
                      let descC = sqlite3_column_text(stmt, 2)
                else { continue }
                let thesisId = String(cString: thesisIdC)
                let kill = KillCriterion(id: String(cString: idC), description: String(cString: descC))
                killsMap[thesisId, default: []].append(kill)
            }
        }
        sqlite3_finalize(stmt)

        // KPIs
        let hasSource = dbManager?.tableHasColumn("ThesisKPIDefinition", column: "source") ?? false
        let kpiSQL = hasSource
            ? """
            SELECT id, thesis_id, name, unit, description, source, is_primary, direction, green_low, green_high, amber_low, amber_high, red_low, red_high
            FROM ThesisKPIDefinition
            """
            : """
            SELECT id, thesis_id, name, unit, description, is_primary, direction, green_low, green_high, amber_low, amber_high, red_low, red_high
            FROM ThesisKPIDefinition
            """
        if sqlite3_prepare_v2(db, kpiSQL, -1, &stmt, nil) == SQLITE_OK {
            let isPrimaryIndex: Int32 = hasSource ? 6 : 5
            let directionIndex: Int32 = hasSource ? 7 : 6
            let greenLowIndex: Int32 = hasSource ? 8 : 7
            let greenHighIndex: Int32 = hasSource ? 9 : 8
            let amberLowIndex: Int32 = hasSource ? 10 : 9
            let amberHighIndex: Int32 = hasSource ? 11 : 10
            let redLowIndex: Int32 = hasSource ? 12 : 11
            let redHighIndex: Int32 = hasSource ? 13 : 12
            while sqlite3_step(stmt) == SQLITE_ROW {
                guard let idC = sqlite3_column_text(stmt, 0),
                      let thesisIdC = sqlite3_column_text(stmt, 1),
                      let nameC = sqlite3_column_text(stmt, 2),
                      let unitC = sqlite3_column_text(stmt, 3),
                      let descC = sqlite3_column_text(stmt, 4),
                      let dirC = sqlite3_column_text(stmt, directionIndex)
                else { continue }
                let thesisId = String(cString: thesisIdC)
                let sourceIndex: Int32 = 5
                let sourceText = hasSource ? (sqlite3_column_text(stmt, sourceIndex).map { String(cString: $0) } ?? "") : ""
                let def = KPIDefinition(
                    id: String(cString: idC),
                    name: String(cString: nameC),
                    unit: String(cString: unitC),
                    description: String(cString: descC),
                    source: sourceText,
                    isPrimary: sqlite3_column_int(stmt, isPrimaryIndex) == 1,
                    direction: KPIDirection(rawValue: String(cString: dirC)) ?? .higherIsBetter,
                    ranges: KPIRangeSet(
                        green: .init(lower: sqlite3_column_double(stmt, greenLowIndex), upper: sqlite3_column_double(stmt, greenHighIndex)),
                        amber: .init(lower: sqlite3_column_double(stmt, amberLowIndex), upper: sqlite3_column_double(stmt, amberHighIndex)),
                        red: .init(lower: sqlite3_column_double(stmt, redLowIndex), upper: sqlite3_column_double(stmt, redHighIndex))
                    )
                )
                kpiMap[thesisId, default: []].append(def)
            }
        }
        sqlite3_finalize(stmt)

        // Assemble theses
        for idx in loadedTheses.indices {
            let id = loadedTheses[idx].id
            loadedTheses[idx].assumptions = assumptionsMap[id] ?? []
            loadedTheses[idx].killCriteria = killsMap[id] ?? []
            let kpis = kpiMap[id] ?? []
            loadedTheses[idx].primaryKPIs = kpis.filter { $0.isPrimary }
            loadedTheses[idx].secondaryKPIs = kpis.filter { !$0.isPrimary }
        }
        theses = loadedTheses

        // Reviews
        var loadedReviews: [WeeklyReview] = []
        var patchSet: Set<String> = []
        let reviewSQL = """
        SELECT id, thesis_id, week, headline, confidence, decision, status, macro_events_json, micro_events_json, rationale_json, watch_items_json, finalized_at, created_at, patch_id, kill_switch, notes
        FROM ThesisWeeklyReview
        """
        if sqlite3_prepare_v2(db, reviewSQL, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                guard let idC = sqlite3_column_text(stmt, 0),
                      let thesisIdC = sqlite3_column_text(stmt, 1),
                      let weekC = sqlite3_column_text(stmt, 2),
                      let headlineC = sqlite3_column_text(stmt, 3)
                else { continue }
                let thesisId = String(cString: thesisIdC)
                let weekStr = String(cString: weekC)
                guard let week = WeekNumber(string: weekStr) else { continue }
                guard let thesis = thesis(id: thesisId) else { continue }
                let decisionRaw = String(cString: sqlite3_column_text(stmt, 5))
                let decision = ReviewDecision(rawValue: decisionRaw) ?? .hold
                let statusRaw = String(cString: sqlite3_column_text(stmt, 6))
                let macroEvents = decodeStringArray(from: stmt, index: 7)
                let microEvents = decodeStringArray(from: stmt, index: 8)
                let rationale = decodeStringArray(from: stmt, index: 9)
                let watchItems = decodeStringArray(from: stmt, index: 10)
                let finalizedAtStr = sqlite3_column_text(stmt, 11).flatMap { String(cString: $0) }
                let createdAtStr = sqlite3_column_text(stmt, 12).flatMap { String(cString: $0) }
                let patchId = sqlite3_column_text(stmt, 13).flatMap { String(cString: $0) }
                let killSwitch = sqlite3_column_int(stmt, 14) == 1
                let notes = sqlite3_column_text(stmt, 15).flatMap { String(cString: $0) }

                let assumptionStatuses = loadAssumptionStatuses(reviewId: String(cString: idC))
                let rawKillStatuses = loadKillCriteriaStatuses(reviewId: String(cString: idC))
                let normalizedKillStatuses = normalizedKillCriteriaStatuses(
                    existing: rawKillStatuses,
                    thesis: thesis,
                    preserveTriggered: killSwitch && rawKillStatuses.isEmpty
                )
                let killSwitchDerived = normalizedKillStatuses.isEmpty
                    ? killSwitch
                    : normalizedKillStatuses.contains(where: { $0.status == .triggered })
                let readings = loadKPIReadings(reviewId: String(cString: idC), thesisId: thesisId)

                var review = WeeklyReview(
                    id: UUID(uuidString: String(cString: idC)) ?? UUID(),
                    thesisId: thesisId,
                    week: week,
                    headline: String(cString: headlineC),
                    confidence: Int(sqlite3_column_int(stmt, 4)),
                    assumptionStatuses: assumptionStatuses,
                    killCriteriaStatuses: normalizedKillStatuses,
                    kpiReadings: readings,
                    macroEvents: macroEvents,
                    microEvents: microEvents,
                    decision: decision,
                    rationale: rationale,
                    watchItems: watchItems,
                    status: RAGStatus(rawValue: statusRaw) ?? .unknown,
                    createdAt: createdAtStr.flatMap { ThesisStore.isoFormatter.date(from: $0) } ?? Date(),
                    finalizedAt: finalizedAtStr.flatMap { ThesisStore.isoFormatter.date(from: $0) },
                    patchId: patchId,
                    killSwitchTriggered: killSwitchDerived,
                    notes: notes,
                    missingPrimaryKpis: []
                )
                let defMap = Dictionary(uniqueKeysWithValues: (thesis.primaryKPIs + thesis.secondaryKPIs).map { ($0.id, $0) })
                review.kpiReadings = normalizedReadings(for: review, thesis: thesis)
                review.missingPrimaryKpis = thesis.primaryKPIs.compactMap { def in
                    review.kpiReadings.first(where: { $0.kpiId == def.id })?.currentValue == nil ? def.id : nil
                }
                review.status = computeOverallStatus(review: review, thesis: thesis, definitionMap: defMap)
                loadedReviews.append(review)
                if let patchId { patchSet.insert(patchId) }
            }
        }
        sqlite3_finalize(stmt)
        reviews = loadedReviews
        appliedPatchIds = patchSet
    }

    private func decodeStringArray(from stmt: OpaquePointer?, index: Int32) -> [String] {
        guard let txt = sqlite3_column_text(stmt, index) else { return [] }
        let str = String(cString: txt)
        guard let data = str.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data, options: []) as? [String]
        else { return [] }
        return arr
    }

    private func loadAssumptionStatuses(reviewId: String) -> [AssumptionStatusEntry] {
        guard let db = dbManager?.db else { return [] }
        var result: [AssumptionStatusEntry] = []
        var stmt: OpaquePointer?
        let sql = "SELECT assumption_id,status,note FROM ThesisAssumptionStatus WHERE review_id = ?"
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            sqlite3_bind_text(stmt, 1, reviewId, -1, SQLITE_TRANSIENT)
            while sqlite3_step(stmt) == SQLITE_ROW {
                guard let aidC = sqlite3_column_text(stmt, 0),
                      let statusC = sqlite3_column_text(stmt, 1)
                else { continue }
                let assumptionId = String(cString: aidC)
                let status = AssumptionHealth(rawValue: String(cString: statusC)) ?? .intact
                let note = sqlite3_column_text(stmt, 2).flatMap { String(cString: $0) }
                result.append(AssumptionStatusEntry(assumptionId: assumptionId, status: status, note: note))
            }
        }
        sqlite3_finalize(stmt)
        return result
    }

    private func loadKillCriteriaStatuses(reviewId: String) -> [KillCriterionStatusEntry] {
        guard let db = dbManager?.db else { return [] }
        var result: [KillCriterionStatusEntry] = []
        var stmt: OpaquePointer?
        let sql = "SELECT kill_id,status,note FROM ThesisKillStatus WHERE review_id = ?"
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            sqlite3_bind_text(stmt, 1, reviewId, -1, SQLITE_TRANSIENT)
            while sqlite3_step(stmt) == SQLITE_ROW {
                guard let killIdC = sqlite3_column_text(stmt, 0),
                      let statusC = sqlite3_column_text(stmt, 1)
                else { continue }
                let status = KillCriterionStatus(rawValue: String(cString: statusC)) ?? .clear
                let note = sqlite3_column_text(stmt, 2).flatMap { String(cString: $0) }
                result.append(KillCriterionStatusEntry(criterionId: String(cString: killIdC), status: status, note: note))
            }
        }
        sqlite3_finalize(stmt)
        return result
    }

    private func loadKPIReadings(reviewId: String, thesisId: String) -> [KPIReading] {
        guard let db = dbManager?.db else { return [] }
        var result: [KPIReading] = []
        var stmt: OpaquePointer?
        let sql = """
        SELECT kpi_id, value, trend, delta_1w, delta_4w, comment, status
        FROM ThesisKPIReading
        WHERE review_id = ?
        """
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            sqlite3_bind_text(stmt, 1, reviewId, -1, SQLITE_TRANSIENT)
            while sqlite3_step(stmt) == SQLITE_ROW {
                guard let kpiC = sqlite3_column_text(stmt, 0) else { continue }
                let kpiId = String(cString: kpiC)
                let value = sqlite3_column_type(stmt, 1) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, 1)
                let trend = sqlite3_column_text(stmt, 2).flatMap { KPITrend(rawValue: String(cString: $0)) } ?? .na
                let delta1 = sqlite3_column_type(stmt, 3) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, 3)
                let delta4 = sqlite3_column_type(stmt, 4) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, 4)
                let comment = sqlite3_column_text(stmt, 5).flatMap { String(cString: $0) }
                let status = sqlite3_column_text(stmt, 6).flatMap { RAGStatus(rawValue: String(cString: $0)) } ?? .unknown
                let reading = KPIReading(kpiId: kpiId, currentValue: value, trend: trend, delta1w: delta1, delta4w: delta4, comment: comment, status: status)
                result.append(reading)
            }
        }
        sqlite3_finalize(stmt)
        return result
    }

    private func persistThesis(_ thesis: Thesis, replaceExisting: Bool) {
        guard let db = dbManager?.db else { return }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        let sql = """
        INSERT OR REPLACE INTO Thesis (id, name, north_star, investment_role, non_goals, tier, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, COALESCE((SELECT created_at FROM Thesis WHERE id = ?), STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')), STRFTIME('%Y-%m-%dT%H:%M:%fZ','now'));
        """
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, thesis.id, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, thesis.name, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 3, thesis.northStar, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 4, thesis.investmentRole, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 5, thesis.nonGoals, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 6, thesis.tier.rawValue, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 7, thesis.id, -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)

        if replaceExisting {
            let delA = "DELETE FROM ThesisAssumption WHERE thesis_id = ?"
            var delStmt: OpaquePointer?
            if sqlite3_prepare_v2(db, delA, -1, &delStmt, nil) == SQLITE_OK {
                sqlite3_bind_text(delStmt, 1, thesis.id, -1, SQLITE_TRANSIENT)
                sqlite3_step(delStmt)
            }
            sqlite3_finalize(delStmt)
            let delK = "DELETE FROM ThesisKillCriterion WHERE thesis_id = ?"
            if sqlite3_prepare_v2(db, delK, -1, &delStmt, nil) == SQLITE_OK {
                sqlite3_bind_text(delStmt, 1, thesis.id, -1, SQLITE_TRANSIENT)
                sqlite3_step(delStmt)
            }
            sqlite3_finalize(delStmt)
        }

        for assumption in thesis.assumptions {
            let insert = "INSERT OR REPLACE INTO ThesisAssumption (id, thesis_id, title, detail) VALUES (?, ?, ?, ?)"
            if sqlite3_prepare_v2(db, insert, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, assumption.id, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(stmt, 2, thesis.id, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(stmt, 3, assumption.title, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(stmt, 4, assumption.detail, -1, SQLITE_TRANSIENT)
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
        for kill in thesis.killCriteria {
            let insert = "INSERT OR REPLACE INTO ThesisKillCriterion (id, thesis_id, description) VALUES (?, ?, ?)"
            if sqlite3_prepare_v2(db, insert, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, kill.id, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(stmt, 2, thesis.id, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(stmt, 3, kill.description, -1, SQLITE_TRANSIENT)
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
    }

    private func persistKPIs(_ kpis: [KPIDefinition], thesisId: String? = nil) {
        dbManager?.ensureThesisTables()
        guard let db = dbManager?.db else { return }
        if sqlite3_db_readonly(db, "main") == 1 {
            logSQLError("Database is read-only; KPI changes not persisted")
            return
        }
        let hasSource = dbManager?.tableHasColumn("ThesisKPIDefinition", column: "source") ?? false
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        let sql = hasSource
            ? """
            INSERT OR REPLACE INTO ThesisKPIDefinition (id, thesis_id, name, unit, description, source, is_primary, direction, green_low, green_high, amber_low, amber_high, red_low, red_high)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """
            : """
            INSERT OR REPLACE INTO ThesisKPIDefinition (id, thesis_id, name, unit, description, is_primary, direction, green_low, green_high, amber_low, amber_high, red_low, red_high)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """
        var stmt: OpaquePointer?
        for def in kpis {
            let prepareResult = sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            guard prepareResult == SQLITE_OK else {
                logSQLError("prepare KPI insert failed")
                sqlite3_finalize(stmt)
                continue
            }
            sqlite3_bind_text(stmt, 1, def.id, -1, SQLITE_TRANSIENT)
            let ownerId = thesisId ?? theses.first(where: { $0.primaryKPIs.contains(def) || $0.secondaryKPIs.contains(def) })?.id ?? ""
            sqlite3_bind_text(stmt, 2, ownerId, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 3, def.name, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 4, def.unit, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 5, def.description, -1, SQLITE_TRANSIENT)
            var idx: Int32 = 6
            if hasSource {
                sqlite3_bind_text(stmt, idx, def.source, -1, SQLITE_TRANSIENT)
                idx += 1
            }
            sqlite3_bind_int(stmt, idx, def.isPrimary ? 1 : 0)
            idx += 1
            sqlite3_bind_text(stmt, idx, def.direction.rawValue, -1, SQLITE_TRANSIENT)
            idx += 1
            sqlite3_bind_double(stmt, idx, def.ranges.green.lower)
            idx += 1
            sqlite3_bind_double(stmt, idx, def.ranges.green.upper)
            idx += 1
            sqlite3_bind_double(stmt, idx, def.ranges.amber.lower)
            idx += 1
            sqlite3_bind_double(stmt, idx, def.ranges.amber.upper)
            idx += 1
            sqlite3_bind_double(stmt, idx, def.ranges.red.lower)
            idx += 1
            sqlite3_bind_double(stmt, idx, def.ranges.red.upper)
            let stepResult = sqlite3_step(stmt)
            if stepResult != SQLITE_DONE {
                logSQLError("insert KPI failed")
            }
            sqlite3_finalize(stmt)
        }
    }

    private func logSQLError(_ message: String) {
        guard let db = dbManager?.db else {
            print("❌ ThesisStore: \(message)")
            return
        }
        let detail = String(cString: sqlite3_errmsg(db))
        print("❌ ThesisStore: \(message) (\(detail))")
    }

    private func persistReview(_ review: WeeklyReview) {
        dbManager?.ensureThesisTables()
        guard let db = dbManager?.db else { return }
        if sqlite3_db_readonly(db, "main") == 1 {
            logSQLError("Database is read-only; review changes not persisted")
            return
        }
        syncKPIs(thesisId: review.thesisId)
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        let sql = """
        INSERT OR REPLACE INTO ThesisWeeklyReview
        (id, thesis_id, week, headline, confidence, decision, status, macro_events_json, micro_events_json, rationale_json, watch_items_json, finalized_at, created_at, patch_id, kill_switch, notes)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, review.id.uuidString, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, review.thesisId, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 3, review.week.stringValue, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 4, review.headline, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(stmt, 5, Int32(review.confidence))
            sqlite3_bind_text(stmt, 6, review.decision.rawValue, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 7, review.status.rawValue, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 8, encodeStringArray(review.macroEvents) ?? "[]", -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 9, encodeStringArray(review.microEvents) ?? "[]", -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 10, encodeStringArray(review.rationale) ?? "[]", -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 11, encodeStringArray(review.watchItems) ?? "[]", -1, SQLITE_TRANSIENT)
            if let finalized = review.finalizedAt {
                sqlite3_bind_text(stmt, 12, ThesisStore.isoFormatter.string(from: finalized), -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(stmt, 12)
            }
            sqlite3_bind_text(stmt, 13, ThesisStore.isoFormatter.string(from: review.createdAt), -1, SQLITE_TRANSIENT)
            if let patch = review.patchId {
                sqlite3_bind_text(stmt, 14, patch, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(stmt, 14)
            }
            sqlite3_bind_int(stmt, 15, review.killSwitchTriggered ? 1 : 0)
            if let notes = review.notes {
                sqlite3_bind_text(stmt, 16, notes, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(stmt, 16)
            }
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)

        // Assumption statuses
        var delStmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "DELETE FROM ThesisAssumptionStatus WHERE review_id = ?", -1, &delStmt, nil) == SQLITE_OK {
            sqlite3_bind_text(delStmt, 1, review.id.uuidString, -1, SQLITE_TRANSIENT)
            sqlite3_step(delStmt)
        }
        sqlite3_finalize(delStmt)
        let insertAssumption = "INSERT OR REPLACE INTO ThesisAssumptionStatus (review_id, assumption_id, status, note) VALUES (?,?,?,?)"
        for entry in review.assumptionStatuses {
            if sqlite3_prepare_v2(db, insertAssumption, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, review.id.uuidString, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(stmt, 2, entry.assumptionId, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(stmt, 3, entry.status.rawValue, -1, SQLITE_TRANSIENT)
                if let note = entry.note {
                    sqlite3_bind_text(stmt, 4, note, -1, SQLITE_TRANSIENT)
                } else {
                    sqlite3_bind_null(stmt, 4)
                }
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }

        // Kill criteria statuses
        if sqlite3_prepare_v2(db, "DELETE FROM ThesisKillStatus WHERE review_id = ?", -1, &delStmt, nil) == SQLITE_OK {
            sqlite3_bind_text(delStmt, 1, review.id.uuidString, -1, SQLITE_TRANSIENT)
            sqlite3_step(delStmt)
        }
        sqlite3_finalize(delStmt)
        let insertKill = "INSERT OR REPLACE INTO ThesisKillStatus (review_id, kill_id, status, note) VALUES (?,?,?,?)"
        for entry in review.killCriteriaStatuses {
            if sqlite3_prepare_v2(db, insertKill, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, review.id.uuidString, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(stmt, 2, entry.criterionId, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(stmt, 3, entry.status.rawValue, -1, SQLITE_TRANSIENT)
                if let note = entry.note {
                    sqlite3_bind_text(stmt, 4, note, -1, SQLITE_TRANSIENT)
                } else {
                    sqlite3_bind_null(stmt, 4)
                }
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }

        // KPI readings
        if sqlite3_prepare_v2(db, "DELETE FROM ThesisKPIReading WHERE review_id = ?", -1, &delStmt, nil) == SQLITE_OK {
            sqlite3_bind_text(delStmt, 1, review.id.uuidString, -1, SQLITE_TRANSIENT)
            sqlite3_step(delStmt)
        }
        sqlite3_finalize(delStmt)
        let insertReading = """
        INSERT OR REPLACE INTO ThesisKPIReading (review_id, kpi_id, value, trend, delta_1w, delta_4w, comment, status)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """
        for reading in review.kpiReadings {
            if sqlite3_prepare_v2(db, insertReading, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, review.id.uuidString, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(stmt, 2, reading.kpiId, -1, SQLITE_TRANSIENT)
                if let value = reading.currentValue {
                    sqlite3_bind_double(stmt, 3, value)
                } else { sqlite3_bind_null(stmt, 3) }
                sqlite3_bind_text(stmt, 4, reading.trend.rawValue, -1, SQLITE_TRANSIENT)
                if let d1 = reading.delta1w { sqlite3_bind_double(stmt, 5, d1) } else { sqlite3_bind_null(stmt, 5) }
                if let d4 = reading.delta4w { sqlite3_bind_double(stmt, 6, d4) } else { sqlite3_bind_null(stmt, 6) }
                if let comment = reading.comment {
                    sqlite3_bind_text(stmt, 7, comment, -1, SQLITE_TRANSIENT)
                } else { sqlite3_bind_null(stmt, 7) }
                sqlite3_bind_text(stmt, 8, reading.status.rawValue, -1, SQLITE_TRANSIENT)
                let stepResult = sqlite3_step(stmt)
                if stepResult != SQLITE_DONE {
                    logSQLError("insert KPI reading failed")
                }
            }
            sqlite3_finalize(stmt)
        }
    }

    private func normalizedReadings(for review: WeeklyReview, thesis: Thesis) -> [KPIReading] {
        let allDefs = thesis.primaryKPIs + thesis.secondaryKPIs
        let existing = Dictionary(uniqueKeysWithValues: review.kpiReadings.map { ($0.kpiId, $0) })
        return allDefs.map { def in
            if var reading = existing[def.id] {
                reading.status = def.ranges.status(for: reading.currentValue)
                return reading
            }
            return KPIReading(kpiId: def.id, status: def.ranges.status(for: nil))
        }
    }

    private func normalizedKillCriteriaStatuses(
        existing: [KillCriterionStatusEntry],
        thesis: Thesis,
        preserveTriggered: Bool = false
    ) -> [KillCriterionStatusEntry] {
        let existingMap = Dictionary(uniqueKeysWithValues: existing.map { ($0.criterionId, $0) })
        var usedLegacyTrigger = false
        return thesis.killCriteria.map { criterion in
            if let entry = existingMap[criterion.id] {
                return entry
            }
            var entry = KillCriterionStatusEntry(criterionId: criterion.id, status: .clear, note: nil)
            if preserveTriggered && !usedLegacyTrigger {
                entry.status = .triggered
                entry.note = "Legacy kill switch flag"
                usedLegacyTrigger = true
            }
            return entry
        }
    }

    private func deleteThesisFromDb(id: String) {
        guard let db = dbManager?.db else { return }
        var stmt: OpaquePointer?
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        if sqlite3_prepare_v2(db, "DELETE FROM Thesis WHERE id = ?", -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, id, -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    private func deleteKPIFromDb(kpiId: String) {
        dbManager?.ensureThesisTables()
        guard let db = dbManager?.db else { return }
        if sqlite3_db_readonly(db, "main") == 1 {
            logSQLError("Database is read-only; KPI delete not persisted")
            return
        }
        var stmt: OpaquePointer?
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        if sqlite3_prepare_v2(db, "DELETE FROM ThesisKPIDefinition WHERE id = ?", -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, kpiId, -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    private func encodeStringArray(_ arr: [String]) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: arr, options: []) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
