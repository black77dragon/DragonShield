import SwiftUI

/// DragonShield Design System - Layout
/// Provides consistent spacing, sizing, and corner radii.
struct DSLayout {
    
    // MARK: - Spacing
    
    /// 4pt - Tight spacing for related items
    static let spaceXS: CGFloat = 4
    
    /// 8pt - Standard spacing for grouped items
    static let spaceS: CGFloat = 8
    
    /// 16pt - Standard padding for cards and sections
    static let spaceM: CGFloat = 16
    
    /// 24pt - Section separation or outer padding
    static let spaceL: CGFloat = 24
    
    /// 32pt - Major section breaks
    static let spaceXL: CGFloat = 32
    
    /// 48pt - Large whitespace for "Sophisticated Simplicity"
    static let spaceXXL: CGFloat = 48
    
    /// Standard spacing between rows in data tables
    static let tableRowSpacing: CGFloat = 1
    
    /// Standard vertical padding inside table rows
    static let tableRowPadding: CGFloat = 12
    
    // MARK: - Corner Radii
    
    /// 4pt - Small elements (tags, badges)
    static let radiusS: CGFloat = 4
    
    /// 8pt - Standard elements (buttons, inputs)
    static let radiusM: CGFloat = 8
    
    /// 12pt - Cards and containers
    static let radiusL: CGFloat = 12
    
    /// 16pt - Large panels or modals
    static let radiusXL: CGFloat = 16
    
    // MARK: - Dimensions
    
    /// 32pt - Standard button height
    static let buttonHeight: CGFloat = 32
    
    /// 44pt - Large button height (touch targets)
    static let buttonHeightLarge: CGFloat = 44
    
    /// 220pt - Standard sidebar width
    static let sidebarWidth: CGFloat = 220
}

extension CGFloat {
    static let dsSpaceXS = DSLayout.spaceXS
    static let dsSpaceS = DSLayout.spaceS
    static let dsSpaceM = DSLayout.spaceM
    static let dsSpaceL = DSLayout.spaceL
    static let dsSpaceXL = DSLayout.spaceXL
    static let dsSpaceXXL = DSLayout.spaceXXL
    
    static let dsRadiusS = DSLayout.radiusS
    static let dsRadiusM = DSLayout.radiusM
    static let dsRadiusL = DSLayout.radiusL
    static let dsRadiusXL = DSLayout.radiusXL
}
