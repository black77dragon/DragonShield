import SwiftUI

struct MaintenanceTableRowContext<Column: MaintenanceTableColumn> {
    let columns: [Column]
    let fontConfig: MaintenanceTableFontConfig
    let widthForColumn: (Column) -> CGFloat
}

struct MaintenanceTableView<Data: RandomAccessCollection, Column: MaintenanceTableColumn, HeaderContent: View, RowView: View>: View where Data.Element: Identifiable {
    @ObservedObject var model: ResizableTableViewModel<Column>
    let rows: Data
    let rowSpacing: CGFloat
    let showHorizontalIndicators: Bool
    let rowContent: (Data.Element, MaintenanceTableRowContext<Column>) -> RowView
    let headerContent: (Column, MaintenanceTableFontConfig) -> HeaderContent

    init(
        model: ResizableTableViewModel<Column>,
        rows: Data,
        rowSpacing: CGFloat = 0,
        showHorizontalIndicators: Bool = true,
        @ViewBuilder rowContent: @escaping (Data.Element, MaintenanceTableRowContext<Column>) -> RowView,
        @ViewBuilder headerContent: @escaping (Column, MaintenanceTableFontConfig) -> HeaderContent
    ) {
        self.model = model
        self.rows = rows
        self.rowSpacing = rowSpacing
        self.showHorizontalIndicators = showHorizontalIndicators
        self.rowContent = rowContent
        self.headerContent = headerContent
    }

    var body: some View {
        GeometryReader { proxy in
            let availableWidth = max(proxy.size.width, 0)
            let targetWidth = max(availableWidth, model.totalMinimumWidth)

            ScrollView(.horizontal, showsIndicators: showHorizontalIndicators) {
                VStack(spacing: 0) {
                    header
                    rowsView
                }
                .frame(width: targetWidth, alignment: .leading)
            }
            .frame(width: availableWidth, alignment: .leading)
            .onAppear {
                model.updateAvailableWidth(targetWidth)
            }
            .onChange(of: proxy.size.width) { _, newWidth in
                model.updateAvailableWidth(max(newWidth, model.totalMinimumWidth))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 0)
    }

    private var header: some View {
        HStack(spacing: 0) {
            ForEach(model.activeColumns, id: \.self) { column in
                headerCell(for: column)
                    .frame(width: model.width(for: column), alignment: .leading)
            }
        }
        .padding(.trailing, 12)
        .padding(.vertical, 2)
        .background(
            Rectangle()
                .fill(model.configuration.headerBackground)
                .overlay(Rectangle().stroke(Color.blue.opacity(0.15), lineWidth: 1))
        )
        .frame(width: max(model.availableTableWidth, model.totalMinimumWidth), alignment: .leading)
    }

    private var rowsView: some View {
        let context = MaintenanceTableRowContext(
            columns: model.activeColumns,
            fontConfig: model.fontConfig,
            widthForColumn: { model.width(for: $0) }
        )

        return ScrollView {
            LazyVStack(spacing: rowSpacing) {
                ForEach(rows) { row in
                    rowContent(row, context)
                }
            }
        }
        .background(
            Rectangle()
                .fill(.regularMaterial)
                .overlay(Rectangle().stroke(Color.gray.opacity(0.12), lineWidth: 1))
        )
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        .frame(width: max(model.availableTableWidth, model.totalMinimumWidth), alignment: .leading)
    }

    private func headerCell(for column: Column) -> some View {
        let leadingTarget = model.leadingHandleTarget(for: column)
        let isLast = model.isLastActiveColumn(column)
        let inset = model.configuration.columnTextInset
        let handleWidth = model.configuration.columnHandleWidth

        return ZStack(alignment: .leading) {
            if let target = leadingTarget {
                resizeHandle(for: target)
            }
            if isLast {
                resizeHandle(for: column)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            HStack(spacing: 6) {
                headerContent(column, model.fontConfig)
            }
            .padding(.leading, inset + (leadingTarget == nil ? 0 : handleWidth))
            .padding(.trailing, isLast ? handleWidth + 8 : 8)
        }
    }

    private func resizeHandle(for column: Column) -> some View {
        let handleWidth = model.configuration.columnHandleWidth
        let hitSlop = model.configuration.columnHandleHitSlop

        return Rectangle()
            .fill(Color.clear)
            .frame(width: handleWidth + hitSlop * 2, height: 28)
            .offset(x: -hitSlop)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        #if os(macOS)
                            if let cursor = model.configuration.columnResizeCursor {
                                cursor.set()
                            } else {
                                NSCursor.resizeLeftRight.set()
                            }
                        #endif
                        model.beginDrag(for: column)
                        model.updateDrag(for: column, translation: value.translation.width)
                    }
                    .onEnded { _ in
                        model.finalizeDrag()
                        #if os(macOS)
                            NSCursor.arrow.set()
                        #endif
                    }
            )
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 0.5)
                    .fill(Color.gray.opacity(0.8))
                    .frame(width: 2, height: 22)
            }
            .padding(.vertical, 2)
            .background(Color.clear)
        #if os(macOS)
            .onHover { inside in
                if inside {
                    if let cursor = model.configuration.columnResizeCursor {
                        cursor.set()
                    } else {
                        NSCursor.resizeLeftRight.set()
                    }
                } else {
                    NSCursor.arrow.set()
                }
            }
        #endif
    }
}
