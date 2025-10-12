import SwiftUI

enum KanbanFontSize: String, CaseIterable {
    case xSmall
    case small
    case medium
    case large
    case xLarge

    var label: String {
        switch self {
        case .xSmall: return "XS"
        case .small: return "S"
        case .medium: return "M"
        case .large: return "L"
        case .xLarge: return "XL"
        }
    }

    private var basePointSize: CGFloat {
        switch self {
        case .xSmall: return 10
        case .small: return 12
        case .medium: return 14
        case .large: return 16
        case .xLarge: return 18
        }
    }

    var primaryPointSize: CGFloat { basePointSize }

    var secondaryPointSize: CGFloat { max(10, basePointSize - 1) }

    var badgePointSize: CGFloat { max(9, secondaryPointSize - 1) }

    var primaryFont: Font {
        .system(size: primaryPointSize, weight: .semibold)
    }

    var secondaryFont: Font {
        .system(size: secondaryPointSize)
    }

    var badgeFont: Font {
        .system(size: badgePointSize, weight: .medium)
    }

    func dueDateFont(weight: Font.Weight) -> Font {
        .system(size: secondaryPointSize, weight: weight)
    }
}
