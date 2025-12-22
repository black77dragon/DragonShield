import Foundation

enum DateFormatting {
    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        f.timeZone = .current
        return f
    }()

    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d.M.yy"
        f.timeZone = .current
        return f
    }()

    private static let asOfFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        f.timeZone = .current
        return f
    }()

    static func userFriendly(_ isoString: String?) -> String {
        guard let isoString, let date = ISO8601DateParser.parse(isoString) else { return "—" }
        return displayFormatter.string(from: date)
    }

    static func dateOnly(_ isoString: String?) -> String {
        guard let isoString, let date = ISO8601DateParser.parse(isoString) else { return "—" }
        return shortDateFormatter.string(from: date)
    }

    static func asOfDisplay(_ date: Date?) -> String {
        guard let date else { return "—" }
        return asOfFormatter.string(from: date)
    }
}
