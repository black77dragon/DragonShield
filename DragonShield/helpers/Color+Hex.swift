import SwiftUI

extension Color {
    init?(hex: String) {
        var hex = hex.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        if hex.hasPrefix("#") {
            hex.removeFirst()
        }
        guard hex.count == 6, let int = Int(hex, radix: 16) else { return nil }
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

enum ColorContrast {
    static func isDark(hex: String) -> Bool {
        var hex = hex.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        if hex.hasPrefix("#") {
            hex.removeFirst()
        }
        guard hex.count == 6, let int = Int(hex, radix: 16) else { return false }
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0

        func channel(_ c: Double) -> Double {
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }

        let luminance = 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
        return luminance < 0.5
    }
}
