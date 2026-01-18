import Foundation

enum ThesisRAG: String, CaseIterable, Codable {
    case green
    case amber
    case red

    static func driverRAG(for score: Int?) -> ThesisRAG? {
        guard let score else { return nil }
        switch score {
        case 7...10: return .green
        case 4...6: return .amber
        case 1...3: return .red
        default: return nil
        }
    }

    static func riskRAG(for score: Int?) -> ThesisRAG? {
        guard let score else { return nil }
        switch score {
        case 1...3: return .green
        case 4...6: return .amber
        case 7...10: return .red
        default: return nil
        }
    }
}

enum ThesisVerdict: String, CaseIterable, Codable {
    case valid
    case watch
    case impaired
    case broken
}

enum ThesisLinkStatus: String, CaseIterable, Codable {
    case active
    case inactive
}

enum ThesisBulletType: String, CaseIterable, Codable {
    case claim
    case datapoint
    case implication
    case rule
}

enum ThesisDriverImplication: String, CaseIterable, Codable {
    case none
    case monitor
    case adjust
}

enum ThesisRiskImpact: String, CaseIterable, Codable {
    case none
    case minor
    case material
}

enum ThesisRiskAction: String, CaseIterable, Codable {
    case none
    case hedge
    case rebalance
    case reduce
    case exit
}

enum ThesisExposureRuleType: String, CaseIterable, Codable {
    case byTicker = "by_ticker"
    case byInstrumentId = "by_instrument_id"
    case byAssetClass = "by_asset_class"
    case byTag = "by_tag"
    case byCustomQuery = "by_custom_query"
}

struct ThesisDefinition: Identifiable, Hashable {
    let id: Int
    var name: String
    var summaryCoreThesis: String?
    var defaultScoringRules: String?
    var createdAt: String
    var updatedAt: String

    static func isValidName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= 120
    }
}

struct ThesisSection: Identifiable, Hashable {
    let id: Int
    var thesisDefId: Int
    var sortOrder: Int
    var headline: String
    var description: String?
    var ragDefault: ThesisRAG?
    var scoreDefault: Int?
}

struct ThesisBullet: Identifiable, Hashable {
    let id: Int
    var sectionId: Int
    var sortOrder: Int
    var text: String
    var type: ThesisBulletType
    var linkedMetrics: [String]
    var linkedEvidence: [String]
}

struct ThesisDriverDefinition: Identifiable, Hashable {
    let id: Int
    var thesisDefId: Int
    var code: String
    var name: String
    var definition: String?
    var reviewQuestion: String?
    var weight: Double?
    var sortOrder: Int
}

struct ThesisRiskDefinition: Identifiable, Hashable {
    let id: Int
    var thesisDefId: Int
    var name: String
    var category: String
    var whatWorsens: String?
    var whatImproves: String?
    var mitigations: String?
    var weight: Double?
    var sortOrder: Int
}

struct PortfolioThesisLink: Identifiable, Hashable {
    let id: Int
    var themeId: Int
    var thesisDefId: Int
    var status: ThesisLinkStatus
    var isPrimary: Bool
    var reviewFrequency: String
    var notes: String?
    var createdAt: String
    var updatedAt: String
}

struct PortfolioThesisSleeve: Identifiable, Hashable {
    let id: Int
    var portfolioThesisId: Int
    var name: String
    var targetMinPct: Double?
    var targetMaxPct: Double?
    var maxPct: Double?
    var ruleText: String?
    var sortOrder: Int
}

struct PortfolioThesisExposureRule: Identifiable, Hashable {
    let id: Int
    var portfolioThesisId: Int
    var sleeveId: Int?
    var ruleType: ThesisExposureRuleType
    var ruleValue: String
    var weighting: Double?
    var effectiveFrom: String?
    var effectiveTo: String?
    var isActive: Bool
}

struct PortfolioThesisWeeklyAssessment: Identifiable, Hashable {
    let id: Int
    var weeklyChecklistId: Int
    var portfolioThesisId: Int
    var verdict: ThesisVerdict?
    var rag: ThesisRAG?
    var driverStrengthScore: Double?
    var riskPressureScore: Double?
    var topChangesText: String?
    var actionsSummary: String?
    var createdAt: String
    var updatedAt: String
}

struct DriverWeeklyAssessmentItem: Identifiable, Hashable {
    let id: Int
    var assessmentId: Int
    var driverDefId: Int
    var rag: ThesisRAG?
    var score: Int?
    var deltaVsPrior: Int?
    var changeSentence: String?
    var evidenceRefs: [String]
    var implication: ThesisDriverImplication?
    var sortOrder: Int
}

struct RiskWeeklyAssessmentItem: Identifiable, Hashable {
    let id: Int
    var assessmentId: Int
    var riskDefId: Int
    var rag: ThesisRAG?
    var score: Int?
    var deltaVsPrior: Int?
    var changeSentence: String?
    var evidenceRefs: [String]
    var thesisImpact: ThesisRiskImpact?
    var recommendedAction: ThesisRiskAction?
    var sortOrder: Int
}

struct ThesisScoreSummary {
    let driverStrength: Double?
    let riskPressure: Double?
    let verdictSuggestion: ThesisVerdict?
}

struct ThesisAssessmentDraft: Identifiable, Hashable {
    let portfolioThesisId: Int
    var thesisName: String
    var thesisSummary: String?
    var drivers: [ThesisDriverDefinition]
    var risks: [ThesisRiskDefinition]
    var verdict: ThesisVerdict?
    var topChangesText: String
    var actionsSummary: String
    var driverItems: [DriverWeeklyAssessmentItem]
    var riskItems: [RiskWeeklyAssessmentItem]
    var priorDriverScores: [Int: Int]
    var priorRiskScores: [Int: Int]
    var isExpanded: Bool

    var id: Int { portfolioThesisId }

    mutating func carryForward() {
        for index in driverItems.indices {
            let defId = driverItems[index].driverDefId
            if let prior = priorDriverScores[defId] {
                driverItems[index].score = prior
                driverItems[index].rag = ThesisRAG.driverRAG(for: prior)
            }
            driverItems[index].changeSentence = ""
        }
        for index in riskItems.indices {
            let defId = riskItems[index].riskDefId
            if let prior = priorRiskScores[defId] {
                riskItems[index].score = prior
                riskItems[index].rag = ThesisRAG.riskRAG(for: prior)
            }
            riskItems[index].changeSentence = ""
        }
    }
}

enum ThesisScoring {
    static func weightedAverage(items: [(score: Int?, weight: Double?)]) -> Double? {
        let weighted = items.compactMap { item -> (score: Double, weight: Double)? in
            guard let score = item.score else { return nil }
            let weight = max(0, item.weight ?? 1)
            return (Double(score), weight)
        }
        guard !weighted.isEmpty else { return nil }
        let totalWeight = weighted.reduce(0.0) { $0 + $1.weight }
        guard totalWeight > 0 else { return nil }
        let total = weighted.reduce(0.0) { $0 + ($1.score * $1.weight) }
        return total / totalWeight
    }

    static func verdictSuggestion(driverStrength: Double?, riskPressure: Double?, driverItems: [DriverWeeklyAssessmentItem], riskItems: [RiskWeeklyAssessmentItem], riskDefinitions: [ThesisRiskDefinition]) -> ThesisVerdict? {
        guard let driverStrength, let riskPressure else { return nil }
        let riskById = Dictionary(uniqueKeysWithValues: riskDefinitions.map { ($0.id, $0.category.lowercased()) })
        let thesisBreakingTriggered = riskItems.contains { item in
            guard let score = item.score else { return false }
            let category = riskById[item.riskDefId] ?? ""
            return category == "thesis-breaking" && score >= 8
        }
        let coreDriverInvalidated = driverItems.contains { item in
            guard let score = item.score else { return false }
            return score <= 2
        }
        if thesisBreakingTriggered || coreDriverInvalidated { return .broken }
        if driverStrength < 4 || riskPressure >= 7 { return .impaired }
        if driverStrength < 6 || riskPressure >= 5 { return .watch }
        return .valid
    }
}
