import SwiftUI

struct ColorChip: View {
    let hex: String
    let label: String

    var body: some View {
        Text(label)
            .font(.caption)
            .padding(4)
            .background(Color(hex: hex) ?? .clear)
            .foregroundColor((Color(hex: hex)?.isDarkColor ?? false) ? .white : .black)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.3)))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

extension Color {
    init?(hex: String) {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard hexString.hasPrefix("#") else { return nil }
        hexString.removeFirst()
        guard hexString.count == 6, let intVal = Int(hexString, radix: 16) else { return nil }
        let r = Double((intVal >> 16) & 0xFF) / 255.0
        let g = Double((intVal >> 8) & 0xFF) / 255.0
        let b = Double(intVal & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }

    var isDarkColor: Bool {
        #if canImport(AppKit)
        let ns = NSColor(self)
        guard let rgb = ns.usingColorSpace(.sRGB) else { return false }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        rgb.getRed(&r, green: &g, blue: &b, alpha: &a)
        #else
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        #endif
        let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
        return luminance < 0.5
    }
}

