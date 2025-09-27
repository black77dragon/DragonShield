import SwiftUI

enum KanbanFontSize: String, CaseIterable {
    case xSmall, small, medium, large, xLarge

    var label: String {
        switch self {
        case .xSmall: return "XS"
        case .small: return "S"
        case .medium: return "M"
        case .large: return "L"
        case .xLarge: return "XL"
        }
    }

    private var metricIndex: Int {
        switch self {
        case .xSmall: return 0
        case .small: return 1
        case .medium: return 2
        case .large: return 3
        case .xLarge: return 4
        }
    }

    var primaryPointSize: CGFloat {
        TableFontMetrics.baseSize(for: metricIndex)
    }

    var secondaryPointSize: CGFloat {
        max(10, primaryPointSize - 1)
    }

    var badgePointSize: CGFloat {
        max(9, secondaryPointSize - 1)
    }

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
