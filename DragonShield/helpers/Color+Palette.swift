import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

#if os(macOS)
private func adaptiveColor(light: NSColor, dark: NSColor) -> Color {
    let name = NSColor.Name(UUID().uuidString)
    let dynamic = NSColor(name: name, dynamicProvider: { appearance in
        let match = appearance.bestMatch(from: [.darkAqua, .vibrantDark, .aqua, .vibrantLight])
        switch match {
        case .darkAqua?, .vibrantDark?:
            return dark
        default:
            return light
        }
    })
    return Color(nsColor: dynamic)
}
#else
private func adaptiveColor(light: UIColor, dark: UIColor) -> Color {
    Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? dark : light
    })
}
#endif

extension Color {
    static let success = Color(red: 48/255, green: 209/255, blue: 88/255)
    static let warning = Color(red: 255/255, green: 159/255, blue: 10/255)
    static let error = Color(red: 255/255, green: 59/255, blue: 48/255)
    /// Light red used to highlight validation warnings.
    static var paleRed: Color {
#if os(macOS)
        adaptiveColor(
            light: NSColor(red: 1.0, green: 236/255, blue: 236/255, alpha: 1.0),
            dark: NSColor.systemRed.withAlphaComponent(0.35)
        )
#else
        adaptiveColor(
            light: UIColor(red: 1.0, green: 236/255, blue: 236/255, alpha: 1.0),
            dark: UIColor.systemRed.withAlphaComponent(0.35)
        )
#endif
    }
    /// Light orange used to highlight subclass-only activity.
    static let paleOrange = Color(red: 1.0, green: 244/255, blue: 229/255)
    /// Soft beige used to group asset classes.
    static let beige = Color(red: 250/255, green: 243/255, blue: 224/255)
    /// Soft blue highlight used for segmented controls and headers.
    static let softBlue = Color(red: 229/255, green: 241/255, blue: 255/255)
    /// Blue tint used for target editor headers.
    static let sectionBlue = Color(red: 230/255, green: 244/255, blue: 255/255)
    /// Row highlight used when editing in tables.
    static let rowHighlight = Color(red: 245/255, green: 249/255, blue: 255/255)

    /// Neutral gray used for text field backgrounds across platforms.
    static var fieldGray: Color {
#if os(macOS)
        Color(NSColor.controlBackgroundColor)
#else
        Color(UIColor.systemGray6)
#endif
    }
    /// Numeric value colors
    static let numberGreen = Color(red: 0x16/255, green: 0xA3/255, blue: 0x4A/255)
    static let numberAmber = Color(red: 0xF5/255, green: 0x9E/255, blue: 0x0B/255)
    static let numberRed = Color(red: 0xDC/255, green: 0x26/255, blue: 0x26/255)

    /// Stroke colours used for card borders
    static var tertiary: Color {
        #if os(macOS)
        Color(nsColor: .tertiaryLabelColor)
        #else
        Color(uiColor: .tertiaryLabel)
        #endif
    }

    static var quaternary: Color {
        #if os(macOS)
        Color(nsColor: .quaternaryLabelColor)
        #else
        Color(uiColor: .quaternaryLabel)
        #endif
    }

    /// System gray colours cross-platform
    static var systemGray4: Color {
        #if os(macOS)
        Color(red: 174/255, green: 174/255, blue: 178/255)
        #else
        Color(uiColor: .systemGray4)
        #endif
    }

    static var systemGray5: Color {
        #if os(macOS)
        Color(red: 199/255, green: 199/255, blue: 204/255)
        #else
        Color(uiColor: .systemGray5)
        #endif
    }

    static var systemGray6: Color {
        #if os(macOS)
        Color(red: 239/255, green: 239/255, blue: 244/255)
        #else
        Color(uiColor: .systemGray6)
        #endif
    }
}
