import Foundation

enum WeeklyChecklistDateHelper {
    static let calendar: Calendar = {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = TimeZone.current
        return cal
    }()

    static let weekFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM yyyy"
        f.timeZone = .current
        return f
    }()

    static let timestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        f.timeZone = .current
        return f
    }()

    static func weekStart(for date: Date) -> Date {
        let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: comps) ?? calendar.startOfDay(for: date)
    }

    static func weekKey(_ date: Date) -> String {
        DateFormatter.iso8601DateOnly.string(from: date)
    }

    static func weekLabel(_ date: Date) -> String {
        "Week of \(weekFormatter.string(from: date))"
    }
}

