#if os(iOS)
import Foundation

enum ValueFormatting {
    private static let wholeFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.usesGroupingSeparator = true
        f.groupingSeparator = "'"
        f.maximumFractionDigits = 0
        f.minimumFractionDigits = 0
        return f
    }()

    /// Formats large amounts (>= 1'000) with Swiss grouping and no decimals.
    /// Example: 8098098 -> "8'098'098"
    static func large(_ value: Double) -> String {
        wholeFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.0f", value)
    }
}
#endif

