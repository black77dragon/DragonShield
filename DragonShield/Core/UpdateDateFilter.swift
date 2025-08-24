import Foundation

/// Date range filters for updates.
enum UpdateDateFilter: String, CaseIterable, Identifiable {
    case today
    case last7d
    case last30d
    case last90d
    case last365d
    case all

    var id: String { rawValue }

    var label: String {
        switch self {
        case .today: return "Today"
        case .last7d: return "Last 7d"
        case .last30d: return "Last 30d"
        case .last90d: return "Last 90d"
        case .last365d: return "Last 365d"
        case .all: return "All"
        }
    }

    func contains(_ date: Date, timeZone: TimeZone) -> Bool {
        switch self {
        case .all:
            return true
        case .today, .last7d, .last30d, .last90d, .last365d:
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone
            let now = Date()
            let startOfToday = calendar.startOfDay(for: now)
            let days: Int
            switch self {
            case .today: days = 1
            case .last7d: days = 7
            case .last30d: days = 30
            case .last90d: days = 90
            case .last365d: days = 365
            case .all: days = 0
            }
            let start = calendar.date(byAdding: .day, value: -(days - 1), to: startOfToday)!
            let end = calendar.date(byAdding: .day, value: 1, to: startOfToday)!
            return date >= start && date < end
        }
    }
}
