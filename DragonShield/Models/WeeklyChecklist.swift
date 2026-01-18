import Foundation

enum WeeklyChecklistStatus: String, CaseIterable, Codable {
    case draft
    case completed
    case skipped
}

enum ThesisScoreDelta: String, CaseIterable, Codable {
    case up
    case flat
    case down
}

enum ThesisActionTag: String, CaseIterable, Codable {
    case none
    case watch
    case add
    case trim
    case exit
}

enum ThesisRiskLevel: String, CaseIterable, Codable {
    case breaker
    case warn
}

enum ThesisRiskTriggered: String, CaseIterable, Codable {
    case yes
    case no
}

struct ThesisRisk: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var level: ThesisRiskLevel = .warn
    var rule: String = ""
    var trigger: String = ""
    var triggered: ThesisRiskTriggered = .no
}

struct ThesisCheck: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var position: String = ""
    var originalThesis: String = ""
    var macroScore: Int? = nil
    var macroDelta: ThesisScoreDelta? = nil
    var macroNote: String = ""
    var edgeScore: Int? = nil
    var edgeDelta: ThesisScoreDelta? = nil
    var edgeNote: String = ""
    var growthScore: Int? = nil
    var growthDelta: ThesisScoreDelta? = nil
    var growthNote: String = ""
    var actionTag: ThesisActionTag? = nil
    var changeLog: String = ""
    var risks: [ThesisRisk] = []

    var netScore: Double? {
        guard let macroScore, let edgeScore, let growthScore else { return nil }
        return Double(macroScore + edgeScore + growthScore) / 3.0
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case position
        case originalThesis
        case macroScore
        case macroDelta
        case macroNote
        case edgeScore
        case edgeDelta
        case edgeNote
        case growthScore
        case growthDelta
        case growthNote
        case actionTag
        case changeLog
        case newData
        case risks
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        position = try container.decodeIfPresent(String.self, forKey: .position) ?? ""
        originalThesis = try container.decodeIfPresent(String.self, forKey: .originalThesis) ?? ""
        macroScore = try container.decodeIfPresent(Int.self, forKey: .macroScore)
        macroDelta = try container.decodeIfPresent(ThesisScoreDelta.self, forKey: .macroDelta)
        macroNote = try container.decodeIfPresent(String.self, forKey: .macroNote) ?? ""
        edgeScore = try container.decodeIfPresent(Int.self, forKey: .edgeScore)
        edgeDelta = try container.decodeIfPresent(ThesisScoreDelta.self, forKey: .edgeDelta)
        edgeNote = try container.decodeIfPresent(String.self, forKey: .edgeNote) ?? ""
        growthScore = try container.decodeIfPresent(Int.self, forKey: .growthScore)
        growthDelta = try container.decodeIfPresent(ThesisScoreDelta.self, forKey: .growthDelta)
        growthNote = try container.decodeIfPresent(String.self, forKey: .growthNote) ?? ""
        actionTag = try container.decodeIfPresent(ThesisActionTag.self, forKey: .actionTag)
        changeLog = try container.decodeIfPresent(String.self, forKey: .changeLog)
            ?? container.decodeIfPresent(String.self, forKey: .newData)
            ?? ""
        risks = try container.decodeIfPresent([ThesisRisk].self, forKey: .risks) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(position, forKey: .position)
        try container.encode(originalThesis, forKey: .originalThesis)
        try container.encodeIfPresent(macroScore, forKey: .macroScore)
        try container.encodeIfPresent(macroDelta, forKey: .macroDelta)
        try container.encode(macroNote, forKey: .macroNote)
        try container.encodeIfPresent(edgeScore, forKey: .edgeScore)
        try container.encodeIfPresent(edgeDelta, forKey: .edgeDelta)
        try container.encode(edgeNote, forKey: .edgeNote)
        try container.encodeIfPresent(growthScore, forKey: .growthScore)
        try container.encodeIfPresent(growthDelta, forKey: .growthDelta)
        try container.encode(growthNote, forKey: .growthNote)
        try container.encodeIfPresent(actionTag, forKey: .actionTag)
        try container.encode(changeLog, forKey: .changeLog)
        try container.encode(risks, forKey: .risks)
    }
}

struct WeeklyChecklistAnswers: Codable, Hashable {
    var thesisChecks: [ThesisCheck] = []

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
