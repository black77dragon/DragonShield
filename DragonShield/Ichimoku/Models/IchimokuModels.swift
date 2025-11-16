import Foundation

enum IchimokuIndexSource: String, CaseIterable, Identifiable {
    case sp500 = "SP500"
    case nasdaq100 = "NASDAQ100"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sp500: return "S&P 500"
        case .nasdaq100: return "Nasdaq 100"
        }
    }
}

struct IchimokuTicker: Identifiable, Hashable {
    let id: Int
    let symbol: String
    let name: String
    let indexSource: IchimokuIndexSource
    let isActive: Bool
    let notes: String?
}

struct IchimokuPriceBar: Hashable {
    let tickerId: Int
    let date: Date
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Double?
    let source: String?
}

struct IchimokuIndicatorRow: Hashable {
    let tickerId: Int
    let date: Date
    let tenkan: Double?
    let kijun: Double?
    let senkouA: Double?
    let senkouB: Double?
    let chikou: Double?
    let tenkanSlope: Double?
    let kijunSlope: Double?
    let priceToKijunRatio: Double?
    let tenkanKijunDistance: Double?
    let momentumScore: Double?
}

struct IchimokuCandidateStoreRow {
    let scanDate: Date
    let tickerId: Int
    let rank: Int
    let momentumScore: Double
    let closePrice: Double
    let tenkan: Double?
    let kijun: Double?
    let tenkanSlope: Double?
    let kijunSlope: Double?
    let priceToKijunRatio: Double?
    let tenkanKijunDistance: Double?
    let notes: String?
}

struct IchimokuCandidateRow: Identifiable, Hashable {
    let id: UUID = .init()
    let scanDate: Date
    let ticker: IchimokuTicker
    let rank: Int
    let momentumScore: Double
    let closePrice: Double
    let tenkan: Double?
    let kijun: Double?
    let tenkanSlope: Double?
    let kijunSlope: Double?
    let priceToKijunRatio: Double?
    let tenkanKijunDistance: Double?
    let notes: String?
}

enum IchimokuPositionStatus: String, CaseIterable, Identifiable {
    case active = "ACTIVE"
    case closed = "CLOSED"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .active: return "Active"
        case .closed: return "Closed"
        }
    }
}

struct IchimokuPositionRow: Identifiable, Hashable {
    let id: Int
    let ticker: IchimokuTicker
    let dateOpened: Date
    let status: IchimokuPositionStatus
    let confirmedByUser: Bool
    let lastEvaluated: Date?
    let lastClose: Double?
    let lastKijun: Double?
}

struct IchimokuSellAlertRow: Identifiable, Hashable {
    let id: Int
    let ticker: IchimokuTicker
    let alertDate: Date
    let closePrice: Double
    let kijunValue: Double?
    let reason: String
    let resolvedAt: Date?
}

enum IchimokuRunStatus: String {
    case success = "SUCCESS"
    case failed = "FAILED"
    case partial = "PARTIAL"
    case inProgress = "IN_PROGRESS"
}

struct IchimokuRunLogRow: Identifiable, Hashable {
    let id: Int
    let startedAt: Date
    let completedAt: Date?
    let status: IchimokuRunStatus
    let message: String?
    let ticksProcessed: Int
    let candidatesFound: Int
    let alertsTriggered: Int
}

struct IchimokuSettingsState {
    var scheduleEnabled: Bool
    var scheduleTime: DateComponents
    var scheduleTimeZone: TimeZone
    var maxCandidates: Int
    var historyLookbackDays: Int
    var regressionWindow: Int
    var priceProviderPriority: [String]
}

extension IchimokuSettingsState {
    static let defaults = IchimokuSettingsState(
        scheduleEnabled: true,
        scheduleTime: DateComponents(hour: 22, minute: 0),
        scheduleTimeZone: TimeZone(identifier: "Europe/London") ?? .current,
        maxCandidates: 5,
        historyLookbackDays: 300,
        regressionWindow: 5,
        priceProviderPriority: ["yahoo", "finnhub", "coingecko"]
    )
}
