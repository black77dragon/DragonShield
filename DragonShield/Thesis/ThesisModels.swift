// DragonShield/Thesis/ThesisModels.swift
// Core data structures for the Thesis Management module (v1.2)

import Foundation

enum RAGStatus: String, Codable, CaseIterable {
    case green
    case amber
    case red
    case unknown

    var colorName: String {
        switch self {
        case .green: return "green"
        case .amber: return "amber"
        case .red: return "red"
        case .unknown: return "gray"
        }
    }
}

enum KPIDirection: String, Codable, CaseIterable {
    case higherIsBetter
    case lowerIsBetter
}

enum KPITrend: String, Codable, CaseIterable {
    case up
    case flat
    case down
    case na

    var symbol: String {
        switch self {
        case .up: return "arrow.up"
        case .flat: return "arrow.right"
        case .down: return "arrow.down"
        case .na: return "questionmark"
        }
    }
}

enum ThesisTier: String, Codable, CaseIterable {
    case tier1
    case tier2

    var label: String {
        switch self {
        case .tier1: return "Tier-1"
        case .tier2: return "Tier-2"
        }
    }
}

enum AssumptionHealth: String, Codable, CaseIterable {
    case intact
    case stressed
    case violated
}

enum KillCriterionStatus: String, Codable, CaseIterable {
    case clear
    case watch
    case triggered
}

struct KPIRange: Codable, Hashable {
    var lower: Double
    var upper: Double

    func contains(_ value: Double) -> Bool {
        value >= lower && value <= upper
    }
}

struct KPIRangeSet: Codable, Hashable {
    var green: KPIRange
    var amber: KPIRange
    var red: KPIRange

    func status(for value: Double?) -> RAGStatus {
        guard let value else { return .unknown }
        if green.contains(value) { return .green }
        if amber.contains(value) { return .amber }
        if red.contains(value) { return .red }
        return .unknown
    }
}

struct KPIDefinition: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var unit: String
    var description: String
    var source: String = ""
    var isPrimary: Bool
    var direction: KPIDirection
    var ranges: KPIRangeSet
}

enum PromptTemplateKey: String, Codable, CaseIterable, Identifiable {
    case thesisImport = "thesis_import"
    case weeklyReview = "weekly_review"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .thesisImport: return "Thesis Import"
        case .weeklyReview: return "Weekly Review"
        }
    }
}

enum PromptTemplateStatus: String, Codable, CaseIterable {
    case active
    case inactive
    case archived
}

struct PromptTemplateSettings: Codable, Hashable {
    var includeRanges: Bool
    var includeLastReview: Bool
    var historyWindow: Int

    static let weeklyReviewDefault = PromptTemplateSettings(
        includeRanges: true,
        includeLastReview: true,
        historyWindow: 12
    )
}

struct PromptTemplate: Identifiable, Hashable {
    let id: Int
    let key: PromptTemplateKey
    let version: Int
    let status: PromptTemplateStatus
    let body: String
    let settings: PromptTemplateSettings?
    let createdAt: Date?
    let updatedAt: Date?
}

enum ThesisKpiPromptStatus: String, Codable, CaseIterable {
    case active
    case inactive
    case archived
}

struct ThesisKpiPrompt: Identifiable, Hashable {
    let id: Int
    let thesisId: String
    let version: Int
    let status: ThesisKpiPromptStatus
    let body: String
    let createdAt: Date?
    let updatedAt: Date?
}

struct AssumptionDefinition: Identifiable, Codable, Hashable {
    let id: String
    var title: String
    var detail: String
}

struct KillCriterion: Identifiable, Codable, Hashable {
    let id: String
    var description: String
}

struct Thesis: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var northStar: String
    var investmentRole: String
    var nonGoals: String
    var tier: ThesisTier
    var assumptions: [AssumptionDefinition]
    var killCriteria: [KillCriterion]
    var primaryKPIs: [KPIDefinition]
    var secondaryKPIs: [KPIDefinition]

    var pinned: Bool { tier == .tier1 }
}

struct AssumptionStatusEntry: Identifiable, Codable, Hashable {
    var id: String { assumptionId }
    let assumptionId: String
    var status: AssumptionHealth
    var note: String?
}

struct KillCriterionStatusEntry: Identifiable, Codable, Hashable {
    var id: String { criterionId }
    let criterionId: String
    var status: KillCriterionStatus
    var note: String?
}

enum ReviewDecision: String, Codable, CaseIterable {
    case add = "Add"
    case trim = "Trim"
    case hold = "Hold"
    case pause = "Pause"
    case exit = "Exit"
    case monitor = "Monitor"

    static var ordered: [ReviewDecision] { [.add, .trim, .hold, .pause, .exit, .monitor] }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        if let exact = ReviewDecision(rawValue: raw) {
            self = exact
            return
        }
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let match = ReviewDecision.allCases.first(where: { $0.rawValue.lowercased() == normalized }) {
            self = match
            return
        }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown decision \(raw)")
    }
}

struct KPIReading: Identifiable, Codable, Hashable {
    let id: UUID
    let kpiId: String
    var currentValue: Double?
    var trend: KPITrend
    var delta1w: Double?
    var delta4w: Double?
    var comment: String?
    var status: RAGStatus

    init(kpiId: String,
         currentValue: Double? = nil,
         trend: KPITrend = .na,
         delta1w: Double? = nil,
         delta4w: Double? = nil,
         comment: String? = nil,
         status: RAGStatus = .unknown)
    {
        self.id = UUID()
        self.kpiId = kpiId
        self.currentValue = currentValue
        self.trend = trend
        self.delta1w = delta1w
        self.delta4w = delta4w
        self.comment = comment
        self.status = status
    }
}

struct WeekNumber: Hashable, Codable, Comparable {
    let year: Int
    let week: Int

    init(year: Int, week: Int) {
        self.year = year
        self.week = week
    }

    init?(string: String) {
        let cleaned = string.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let pattern = #"(\d{4})-?W(\d{1,2})"#
        guard let range = cleaned.range(of: pattern, options: .regularExpression) else { return nil }
        let match = String(cleaned[range])
        let components = match.replacingOccurrences(of: "W", with: "-").split(separator: "-")
        guard components.count == 2,
              let yearPart = Int(components[0]),
              let weekPart = Int(components[1])
        else { return nil }
        year = yearPart
        week = weekPart
    }

    var stringValue: String {
        String(format: "%04d-W%02d", year, week)
    }

    var startDate: Date {
        var components = DateComponents()
        components.weekOfYear = week
        components.yearForWeekOfYear = year
        components.weekday = 2 // Monday
        return Calendar(identifier: .iso8601).date(from: components) ?? Date()
    }

    static func current() -> WeekNumber {
        let calendar = Calendar(identifier: .iso8601)
        let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        return WeekNumber(year: comps.yearForWeekOfYear ?? 2024, week: comps.weekOfYear ?? 1)
    }

    static func < (lhs: WeekNumber, rhs: WeekNumber) -> Bool {
        if lhs.year == rhs.year { return lhs.week < rhs.week }
        return lhs.year < rhs.year
    }
}

struct WeeklyReview: Identifiable, Codable, Hashable {
    let id: UUID
    let thesisId: String
    var week: WeekNumber
    var headline: String
    var confidence: Int
    var assumptionStatuses: [AssumptionStatusEntry]
    var killCriteriaStatuses: [KillCriterionStatusEntry]
    var kpiReadings: [KPIReading]
    var macroEvents: [String]
    var microEvents: [String]
    var decision: ReviewDecision
    var rationale: [String]
    var watchItems: [String]
    var status: RAGStatus
    var createdAt: Date
    var finalizedAt: Date?
    var patchId: String?
    var killSwitchTriggered: Bool
    var notes: String?
    var missingPrimaryKpis: [String]

    init(id: UUID = UUID(),
         thesisId: String,
         week: WeekNumber,
         headline: String = "",
         confidence: Int = 3,
         assumptionStatuses: [AssumptionStatusEntry],
         killCriteriaStatuses: [KillCriterionStatusEntry],
         kpiReadings: [KPIReading],
         macroEvents: [String] = [],
         microEvents: [String] = [],
         decision: ReviewDecision = .hold,
         rationale: [String] = [],
         watchItems: [String] = [],
         status: RAGStatus = .unknown,
         createdAt: Date = Date(),
         finalizedAt: Date? = nil,
         patchId: String? = nil,
         killSwitchTriggered: Bool = false,
         notes: String? = nil,
         missingPrimaryKpis: [String] = [])
    {
        self.id = id
        self.thesisId = thesisId
        self.week = week
        self.headline = headline
        self.confidence = confidence
        self.assumptionStatuses = assumptionStatuses
        self.killCriteriaStatuses = killCriteriaStatuses
        self.kpiReadings = kpiReadings
        self.macroEvents = macroEvents
        self.microEvents = microEvents
        self.decision = decision
        self.rationale = rationale
        self.watchItems = watchItems
        self.status = status
        self.createdAt = createdAt
        self.finalizedAt = finalizedAt
        self.patchId = patchId
        self.killSwitchTriggered = killSwitchTriggered
        self.notes = notes
        self.missingPrimaryKpis = missingPrimaryKpis
    }

    var isDraft: Bool { finalizedAt == nil }
}

struct KPIHistoryPoint: Identifiable {
    let id = UUID()
    let week: WeekNumber
    let value: Double?
    let status: RAGStatus
}
