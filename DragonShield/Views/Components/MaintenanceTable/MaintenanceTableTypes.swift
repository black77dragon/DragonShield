import SwiftUI

protocol MaintenanceTableColumn: CaseIterable, Hashable, RawRepresentable where RawValue == String {}

struct MaintenanceTableFontConfig {
    let primary: CGFloat
    let secondary: CGFloat
    let header: CGFloat
    let badge: CGFloat
}

enum MaintenanceTableFontSize: String, CaseIterable {
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

    var baseSize: CGFloat {
        let index: Int
        switch self {
        case .xSmall: index = 0
        case .small: index = 1
        case .medium: index = 2
        case .large: index = 3
        case .xLarge: index = 4
        }
        return TableFontMetrics.baseSize(for: index)
    }

    var secondarySize: CGFloat { baseSize - 1 }
    var headerSize: CGFloat { baseSize - 1 }
    var badgeSize: CGFloat { max(baseSize - 2, 10) }
}

struct MaintenanceTableConfiguration<Column: MaintenanceTableColumn> {
    let preferenceKind: TablePreferenceKind
    let columnOrder: [Column]
    let defaultVisibleColumns: Set<Column>
    let requiredColumns: Set<Column>
    let defaultColumnWidths: [Column: CGFloat]
    let minimumColumnWidths: [Column: CGFloat]
    let visibleColumnsDefaultsKey: String
    let minimumWidthsDefaultsKey: String?
    let columnHandleWidth: CGFloat
    let columnHandleHitSlop: CGFloat
    let columnTextInset: CGFloat
    let headerBackground: Color
    let headerTrailingPadding: CGFloat
    let headerVerticalPadding: CGFloat
    let fontConfigBuilder: (MaintenanceTableFontSize) -> MaintenanceTableFontConfig
    #if os(macOS)
        let columnResizeCursor: NSCursor?
    #endif

    #if os(macOS)
        init(
            preferenceKind: TablePreferenceKind,
            columnOrder: [Column],
            defaultVisibleColumns: Set<Column>,
            requiredColumns: Set<Column>,
            defaultColumnWidths: [Column: CGFloat],
            minimumColumnWidths: [Column: CGFloat],
            visibleColumnsDefaultsKey: String,
            minimumWidthsDefaultsKey: String? = nil,
            columnHandleWidth: CGFloat = 10,
            columnHandleHitSlop: CGFloat = 8,
            columnTextInset: CGFloat = 12,
            headerBackground: Color,
            headerTrailingPadding: CGFloat = 12,
            headerVerticalPadding: CGFloat = 2,
            fontConfigBuilder: @escaping (MaintenanceTableFontSize) -> MaintenanceTableFontConfig,
            columnResizeCursor: NSCursor? = nil
        ) {
            self.preferenceKind = preferenceKind
            self.columnOrder = columnOrder
            self.defaultVisibleColumns = defaultVisibleColumns
            self.requiredColumns = requiredColumns
            self.defaultColumnWidths = defaultColumnWidths
            self.minimumColumnWidths = minimumColumnWidths
            self.visibleColumnsDefaultsKey = visibleColumnsDefaultsKey
            self.minimumWidthsDefaultsKey = minimumWidthsDefaultsKey
            self.columnHandleWidth = columnHandleWidth
            self.columnHandleHitSlop = columnHandleHitSlop
            self.columnTextInset = columnTextInset
            self.headerBackground = headerBackground
            self.headerTrailingPadding = headerTrailingPadding
            self.headerVerticalPadding = headerVerticalPadding
            self.fontConfigBuilder = fontConfigBuilder
            self.columnResizeCursor = columnResizeCursor
        }
    #else
        init(
            preferenceKind: TablePreferenceKind,
            columnOrder: [Column],
            defaultVisibleColumns: Set<Column>,
            requiredColumns: Set<Column>,
            defaultColumnWidths: [Column: CGFloat],
            minimumColumnWidths: [Column: CGFloat],
            visibleColumnsDefaultsKey: String,
            minimumWidthsDefaultsKey: String? = nil,
            columnHandleWidth: CGFloat = 10,
            columnHandleHitSlop: CGFloat = 8,
            columnTextInset: CGFloat = 12,
            headerBackground: Color,
            headerTrailingPadding: CGFloat = 12,
            headerVerticalPadding: CGFloat = 2,
            fontConfigBuilder: @escaping (MaintenanceTableFontSize) -> MaintenanceTableFontConfig
        ) {
            self.preferenceKind = preferenceKind
            self.columnOrder = columnOrder
            self.defaultVisibleColumns = defaultVisibleColumns
            self.requiredColumns = requiredColumns
            self.defaultColumnWidths = defaultColumnWidths
            self.minimumColumnWidths = minimumColumnWidths
            self.visibleColumnsDefaultsKey = visibleColumnsDefaultsKey
            self.minimumWidthsDefaultsKey = minimumWidthsDefaultsKey
            self.columnHandleWidth = columnHandleWidth
            self.columnHandleHitSlop = columnHandleHitSlop
            self.columnTextInset = columnTextInset
            self.headerBackground = headerBackground
            self.headerTrailingPadding = headerTrailingPadding
            self.headerVerticalPadding = headerVerticalPadding
            self.fontConfigBuilder = fontConfigBuilder
        }
    #endif
}
