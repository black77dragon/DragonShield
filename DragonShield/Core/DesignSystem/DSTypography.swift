import SwiftUI

/// DragonShield Design System - Typography
/// Provides consistent text styles, font weights, and view modifiers.
struct DSTypography {
    
    // MARK: - Headers
    
    /// Large page titles (e.g., Dashboard, Portfolio Name)
    /// Size: 28pt, Weight: Bold, Design: Rounded
    static var headerLarge: Font {
        .system(size: 28, weight: .bold, design: .rounded)
    }
    
    /// Section headers (e.g., "Top Positions", "Alerts")
    /// Size: 22pt, Weight: Semibold, Design: Rounded
    static var headerMedium: Font {
        .system(size: 22, weight: .semibold, design: .rounded)
    }
    
    /// Card titles or subsection headers
    /// Size: 17pt, Weight: Semibold, Design: Default
    static var headerSmall: Font {
        .system(size: 17, weight: .semibold, design: .default)
    }
    
    // MARK: - Body
    
    /// Standard body text
    /// Size: 14pt (Standard), Weight: Regular
    static var body: Font {
        .body
    }
    
    /// Secondary or dense information
    /// Size: 13pt, Weight: Regular
    static var bodySmall: Font {
        .subheadline
    }
    
    /// Metadata, timestamps, footnotes
    /// Size: 11pt, Weight: Medium
    static var caption: Font {
        .caption.weight(.medium)
    }
    
    // MARK: - Special
    
    /// Monospaced numbers (financial data, codes)
    static var mono: Font {
        .system(.body, design: .monospaced)
    }
    
    /// Small Monospaced (for compact tables)
    static var monoSmall: Font {
        .system(.caption, design: .monospaced)
    }
    
    /// Large stats (e.g., KPI tiles)
    static var statLarge: Font {
        .system(size: 42, weight: .bold, design: .rounded)
    }
}

// Extension to allow easy access from Font
extension Font {
    static let ds = DSTypography.self
}

// MARK: - View Modifiers

struct DSHeaderLargeModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.ds.headerLarge)
            .foregroundColor(.ds.textPrimary)
    }
}

struct DSHeaderMediumModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.ds.headerMedium)
            .foregroundColor(.ds.textPrimary)
    }
}

struct DSHeaderSmallModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.ds.headerSmall)
            .foregroundColor(.ds.textPrimary)
    }
}

struct DSBodyModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.ds.body)
            .foregroundColor(.ds.textPrimary)
    }
}

struct DSBodySmallModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.ds.bodySmall)
            .foregroundColor(.ds.textSecondary)
    }
}

struct DSCaptionModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.ds.caption)
            .foregroundColor(.ds.textSecondary)
    }
}

struct DSMonoModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.ds.mono)
            .foregroundColor(.ds.textPrimary)
    }
}

struct DSMonoSmallModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.ds.monoSmall)
            .foregroundColor(.ds.textSecondary)
    }
}

struct DSStatLargeModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.ds.statLarge)
            .foregroundColor(.ds.textPrimary)
    }
}

extension View {
    func dsHeaderLarge() -> some View {
        modifier(DSHeaderLargeModifier())
    }
    
    func dsHeaderMedium() -> some View {
        modifier(DSHeaderMediumModifier())
    }
    
    func dsHeaderSmall() -> some View {
        modifier(DSHeaderSmallModifier())
    }
    
    func dsBody() -> some View {
        modifier(DSBodyModifier())
    }
    
    func dsBodySmall() -> some View {
        modifier(DSBodySmallModifier())
    }
    
    func dsCaption() -> some View {
        modifier(DSCaptionModifier())
    }
    
    func dsMono() -> some View {
        modifier(DSMonoModifier())
    }
    
    func dsMonoSmall() -> some View {
        modifier(DSMonoSmallModifier())
    }
    
    func dsStatLarge() -> some View {
        modifier(DSStatLargeModifier())
    }
}
