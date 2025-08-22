import Foundation

enum DateFormatting {
    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        f.timeZone = .current
        return f
    }()

    static func userFriendly(_ isoString: String?) -> String {
        guard let isoString = isoString, let date = isoFormatter.date(from: isoString) else { return "—" }
        return displayFormatter.string(from: date)
    }
}
