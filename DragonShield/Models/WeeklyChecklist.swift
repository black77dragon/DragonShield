import Foundation

enum WeeklyChecklistStatus: String, CaseIterable, Codable {
    case draft
    case completed
    case skipped
}

enum RegimeAssessment: String, CaseIterable, Codable {
    case changed
    case noise
    case unsure
}

enum ThesisImpact: String, CaseIterable, Codable {
    case strengthened
    case weakened
    case unchanged
}

enum ActionDecision: String, CaseIterable, Codable {
    case doNothing
    case trim
    case add
    case exit
}

struct ThesisCheck: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var position: String = ""
    var originalThesis: String = ""
    var newData: String = ""
    var impact: ThesisImpact? = nil
    var wouldEnterToday: Bool = false
}

struct NarrativeDrift: Codable, Hashable {
    var storyOverEvidence: Bool = false
    var invalidationCriteriaRelaxed: Bool = false
    var addedNewReasons: Bool = false
    var redFlagNotes: String = ""
}

struct ExposureCheck: Codable, Hashable {
    var topMacroRisks: [String] = ["", "", ""]
    var sharedRiskPositions: String = ""
    var hiddenCorrelations: String = ""
    var sleepRiskAcknowledged: Bool = false
    var upsizingRuleConfirmed: Bool = false
}

struct ActionDiscipline: Codable, Hashable {
    var decision: ActionDecision? = nil
    var decisionLine: String = ""
}

struct WeeklyChecklistAnswers: Codable, Hashable {
    var regimeStatement: String = ""
    var regimeAssessment: RegimeAssessment? = nil
    var liquidity: String = ""
    var rates: String = ""
    var policyStance: String = ""
    var riskAppetite: String = ""
    var thesisChecks: [ThesisCheck] = []
    var narrativeDrift: NarrativeDrift = .init()
    var exposureCheck: ExposureCheck = .init()
    var actionDiscipline: ActionDiscipline = .init()

    static func decode(from json: String) -> WeeklyChecklistAnswers? {
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(WeeklyChecklistAnswers.self, from: data)
    }

    func encodeJSON() -> String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

struct WeeklyChecklistEntry: Identifiable, Hashable {
    let id: Int
    let themeId: Int
    let weekStartDate: Date
    var status: WeeklyChecklistStatus
    var answers: WeeklyChecklistAnswers?
    var completedAt: Date?
    var skippedAt: Date?
    var skipComment: String?
    var lastEditedAt: Date
    var revision: Int
    var createdAt: Date
}

