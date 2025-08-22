import Foundation

enum DateFormatting {
    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoFormatterFallback = ISO8601DateFormatter()

    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        f.timeZone = .current
        return f
    }()

    static func friendly(_ iso: String?) -> String {
        guard let iso = iso else { return "—" }
        if let date = isoFormatter.date(from: iso) ?? isoFormatterFallback.date(from: iso) {
            return displayFormatter.string(from: date)
        }
        return iso
    }
}
