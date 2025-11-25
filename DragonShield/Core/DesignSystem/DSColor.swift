import SwiftUI

/// DragonShield Design System - Colors
/// Provides semantic color tokens for consistent theming across the application.
/// Implements a "Sophisticated Simplicity" aesthetic.
struct DSColor {
    // MARK: - Backgrounds
    
    /// Main application background
    /// Light: Clean white for freshness
    /// Dark: Deep, rich gray (almost black) for elegance
    static var background: Color {
        Color("DSBackground")
    }
    
    /// Primary surface (cards, panels)
    /// Light: Very subtle off-white or pure white with shadow
    /// Dark: Slightly lighter than background
    static var surface: Color {
        Color(nsColor: .windowBackgroundColor)
    }
    
    /// Secondary surface (sidebars, headers)
    static var surfaceSecondary: Color {
        Color(nsColor: .controlBackgroundColor)
    }
    
    /// Subtle surface for grouping content within cards
    static var surfaceSubtle: Color {
        Color.primary.opacity(0.03)
    }
    
    /// Elevated surface for popovers or floating elements
    static var surfaceElevated: Color {
        Color(nsColor: .windowBackgroundColor) // In a real app, this might be lighter/different
    }
    
    /// Highlighted surface (hover states, active items)
    static var surfaceHighlight: Color {
        Color.accentColor.opacity(0.08)
    }
    
    // MARK: - Text
    
    /// Primary content text - High contrast but not harsh black
    static var textPrimary: Color {
        Color.primary.opacity(0.95)
    }
    
    /// Secondary text (metadata, subtitles) - Readable but distinct
    static var textSecondary: Color {
        Color.primary.opacity(0.65)
    }
    
    /// Tertiary text (disabled, placeholders)
    static var textTertiary: Color {
        Color.primary.opacity(0.4)
    }
    
    /// Text on colored backgrounds (e.g., primary buttons)
    static var textOnAccent: Color {
        Color.white
    }
    
    // MARK: - Accents & Branding
    
    /// Primary brand color - Sophisticated Blue
    static var accentMain: Color {
        Color.accentColor
    }
    
    /// Primary Gradient for branding moments
    static var primaryGradient: LinearGradient {
        LinearGradient(
            colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // MARK: - Semantic Status
    
    /// Success state (positive trends, completion) - Muted, natural green
    static var accentSuccess: Color {
        Color.green
    }
    
    /// Warning state (alerts, caution) - Warm amber
    static var accentWarning: Color {
        Color.orange
    }
    
    /// Error state (failures, negative trends) - Soft but clear red
    static var accentError: Color {
        Color.red
    }
    
    // MARK: - Borders & Dividers
    
    /// Subtle borders for cards and dividers
    static var border: Color {
        Color.primary.opacity(0.08)
    }
    
    /// Slightly stronger border for inputs or active states
    static var borderStrong: Color {
        Color.primary.opacity(0.15)
    }
}

// Extension to allow easy access from Color
extension Color {
    static let ds = DSColor.self
}
