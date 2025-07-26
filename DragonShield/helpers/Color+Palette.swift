import SwiftUI

extension Color {
    static let success = Color(red: 48/255, green: 209/255, blue: 88/255)
    static let warning = Color(red: 255/255, green: 159/255, blue: 10/255)
    static let error = Color(red: 255/255, green: 59/255, blue: 48/255)
    /// Light red used to highlight validation warnings.
    static let paleRed = Color(red: 1.0, green: 236/255, blue: 236/255)
    /// Light orange used to highlight subclass-only activity.
    static let paleOrange = Color(red: 1.0, green: 244/255, blue: 229/255)
    /// Soft beige used to group asset classes.
    static let beige = Color(red: 250/255, green: 243/255, blue: 224/255)
    /// Soft blue highlight used for segmented controls and headers.
    static let softBlue = Color(red: 229/255, green: 241/255, blue: 255/255)

    /// Asset allocation numeric colours
    static let allocationGreen = Color(red: 22/255, green: 163/255, blue: 74/255)
    static let allocationAmber = Color(red: 245/255, green: 158/255, blue: 11/255)
    static let allocationRed = Color(red: 220/255, green: 38/255, blue: 38/255)

    /// Neutral gray used for text field backgrounds across platforms.
    static var fieldGray: Color {
#if os(macOS)
        Color(NSColor.controlBackgroundColor)
#else
        Color(UIColor.systemGray6)
#endif
    }
}
