import SwiftUI
#if os(macOS)
    import AppKit
#endif

private enum TransactionTypeColumn: String, CaseIterable, Codable, MaintenanceTableColumn {
    case name
    case code
    case description
    case affectsPosition
    case affectsCash
    case isIncome
    case sortOrder

    var title: String {
        switch self {
        case .name: return "Name"
        case .code: return "Code"
        case .description: return "Description"
        case .affectsPosition: return "Position"
        case .affectsCash: return "Cash"
        case .isIncome: return "Income"
        case .sortOrder: return "Order"
        }
    }

    var menuTitle: String { title }
}

private struct TransactionTypeItem: Identifiable, Equatable {
    let id: Int
    let code: String
    let name: String
    let description: String
    let affectsPosition: Bool
    let affectsCash: Bool
    let isIncome: Bool
    let sortOrder: Int
}

// MARK: - Transaction Types View

struct TransactionTypesView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @State private var transactionTypes: [TransactionTypeItem] = []
    @State private var showAddTypeSheet = false
    @State private var showEditTypeSheet = false
    @State private var selectedType: TransactionTypeItem? = nil
    @State private var showingDeleteAlert = false
    @State private var typeToDelete: TransactionTypeItem? = nil
    @State private var deleteInfo: (canDelete: Bool, transactionCount: Int)? = nil
    @State private var searchText = ""

    @State private var sortColumn: SortColumn = .sortOrder
    @State private var sortAscending: Bool = true
    @State private var positionFilters: Set<String> = []
    @State private var cashFilters: Set<String> = []
    @State private var incomeFilters: Set<String> = []
    @StateObject private var tableModel = ResizableTableViewModel<TransactionTypeColumn>(configuration: TransactionTypesView.tableConfiguration)

    // Animation states
    @State private var headerOpacity: Double = 0
    @State private var contentOffset: CGFloat = 30
    @State private var buttonsOpacity: Double = 0

    private static let visibleColumnsKey = "TransactionTypesView.visibleColumns.v1"

    private enum SortColumn: String, CaseIterable {
        case name
        case code
        case description
        case affectsPosition
        case affectsCash
        case isIncome
        case sortOrder
    }

    private static let tableConfiguration: MaintenanceTableConfiguration<TransactionTypeColumn> = {
        #if os(macOS)
            MaintenanceTableConfiguration(
                preferenceKind: .transactionTypes,
                columnOrder: TransactionTypeColumn.allCases,
                defaultVisibleColumns: Set(TransactionTypeColumn.allCases),
                requiredColumns: [.name, .code],
                defaultColumnWidths: [
                    .name: 220,
                    .code: 120,
                    .description: 320,
                    .affectsPosition: 120,
                    .affectsCash: 110,
                    .isIncome: 110,
                    .sortOrder: 90,
                ],
                minimumColumnWidths: [
                    .name: 180,
                    .code: 100,
                    .description: 240,
                    .affectsPosition: 100,
                    .affectsCash: 90,
                    .isIncome: 90,
                    .sortOrder: 70,
                ],
                visibleColumnsDefaultsKey: visibleColumnsKey,
                columnHandleWidth: 10,
                columnHandleHitSlop: 8,
                columnTextInset: DSLayout.spaceS,
                headerBackground: DSColor.surfaceSecondary,
                fontConfigBuilder: { size in
                    MaintenanceTableFontConfig(
                        primary: size.baseSize,
                        secondary: max(11, size.secondarySize),
                        header: size.headerSize,
                        badge: max(10, size.badgeSize)
                    )
                },
                columnResizeCursor: nil
            )
        #else
            MaintenanceTableConfiguration(
                preferenceKind: .transactionTypes,
                columnOrder: TransactionTypeColumn.allCases,
                defaultVisibleColumns: Set(TransactionTypeColumn.allCases),
                requiredColumns: [.name, .code],
                defaultColumnWidths: [
                    .name: 220,
                    .code: 120,
                    .description: 320,
                    .affectsPosition: 120,
                    .affectsCash: 110,
                    .isIncome: 110,
                    .sortOrder: 90,
                ],
                minimumColumnWidths: [
                    .name: 180,
                    .code: 100,
                    .description: 240,
                    .affectsPosition: 100,
                    .affectsCash: 90,
                    .isIncome: 90,
                    .sortOrder: 70,
                ],
                visibleColumnsDefaultsKey: visibleColumnsKey,
                columnHandleWidth: 10,
                columnHandleHitSlop: 8,
                columnTextInset: DSLayout.spaceS,
                headerBackground: DSColor.surfaceSecondary,
                fontConfigBuilder: { size in
                    MaintenanceTableFontConfig(
                        primary: size.baseSize,
                        secondary: max(11, size.secondarySize),
                        header: size.headerSize,
                        badge: max(10, size.badgeSize)
                    )
                }
            )
        #endif
    }()

    private var selectedFontSize: MaintenanceTableFontSize { tableModel.selectedFontSize }
    private var visibleColumns: Set<TransactionTypeColumn> { tableModel.visibleColumns }
    private var fontSizeBinding: Binding<MaintenanceTableFontSize> {
        Binding(
            get: { tableModel.selectedFontSize },
            set: { tableModel.selectedFontSize = $0 }
        )
    }

    private var trimmedSearchText: String { searchText.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var filteredTypes: [TransactionTypeItem] {
        var result = transactionTypes

        if !trimmedSearchText.isEmpty {
            let query = trimmedSearchText.lowercased()
            result = result.filter { type in
                type.name.lowercased().contains(query) ||
                    type.code.lowercased().contains(query) ||
                    type.description.lowercased().contains(query)
            }
        }

        if !positionFilters.isEmpty {
            result = result.filter { positionFilters.contains(booleanLabel(for: $0.affectsPosition)) }
        }
        if !cashFilters.isEmpty {
            result = result.filter { cashFilters.contains(booleanLabel(for: $0.affectsCash)) }
        }
        if !incomeFilters.isEmpty {
            result = result.filter { incomeFilters.contains(booleanLabel(for: $0.isIncome)) }
        }

        return result
    }

    private var sortedTypes: [TransactionTypeItem] {
        let base = filteredTypes
        guard base.count > 1 else { return base }

        let sorted = base.sorted { lhs, rhs in
            switch sortColumn {
            case .name:
                return compare(lhs.name, rhs.name)
            case .code:
                return compare(lhs.code, rhs.code)
            case .description:
                return compare(lhs.description, rhs.description)
            case .affectsPosition:
                return compareBool(lhs.affectsPosition, rhs.affectsPosition)
            case .affectsCash:
                return compareBool(lhs.affectsCash, rhs.affectsCash)
            case .isIncome:
                return compareBool(lhs.isIncome, rhs.isIncome)
            case .sortOrder:
                return lhs.sortOrder < rhs.sortOrder
            }
        }

        return sortAscending ? sorted : Array(sorted.reversed())
    }

    private var hasActiveFilters: Bool {
        !positionFilters.isEmpty || !cashFilters.isEmpty || !incomeFilters.isEmpty
    }

    var body: some View {
        ZStack {
            DSColor.background
                .ignoresSafeArea()

            VStack(spacing: DSLayout.spaceM) {
                headerSection
                    .opacity(headerOpacity)

                controlsSection
                    .offset(y: contentOffset)

                tableSection
                    .offset(y: contentOffset)

                actionBar
                    .opacity(buttonsOpacity)
            }
            .padding(.horizontal, DSLayout.spaceL)
            .padding(.vertical, DSLayout.spaceL)
        }
        .onAppear {
            tableModel.connect(to: dbManager)
            tableModel.recalcColumnWidths(shouldPersist: false)
            ensureFiltersWithinVisibleColumns()
            loadTransactionTypes()
            animateEntrance()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshTransactionTypes"))) { _ in
            loadTransactionTypes()
        }
        .sheet(isPresented: $showAddTypeSheet) {
            AddTransactionTypeView().environmentObject(dbManager)
        }
        .sheet(isPresented: $showEditTypeSheet) {
            if let type = selectedType {
                EditTransactionTypeView(typeId: type.id).environmentObject(dbManager)
            }
        }
        .alert(deleteAlertTitle, isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            if (deleteInfo?.transactionCount ?? 0) > 0 {
                Button("Delete Anyway", role: .destructive) { proceedDelete() }
            } else {
                Button("Delete", role: .destructive) { proceedDelete() }
            }
        } message: {
            Text(deleteAlertMessage)
        }
        .onChange(of: tableModel.visibleColumns) { _, _ in
            ensureFiltersWithinVisibleColumns()
        }
    }

    // MARK: - Layout

    private var headerSection: some View {
        HStack(alignment: .center, spacing: DSLayout.spaceM) {
            VStack(alignment: .leading, spacing: DSLayout.spaceXS) {
                HStack(spacing: DSLayout.spaceS) {
                    Image(systemName: "tag.circle.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(DSColor.accentMain)
                    Text("Transaction Types")
                        .dsHeaderLarge()
                }

                Text("Manage transaction categories used across your portfolios.")
                    .dsBody()
                    .foregroundColor(DSColor.textSecondary)
            }

            Spacer()

            HStack(spacing: DSLayout.spaceS) {
                statPill(title: "Total", value: "\(transactionTypes.count)", color: DSColor.textSecondary)
                statPill(title: "Position", value: "\(transactionTypes.filter { $0.affectsPosition }.count)", color: DSColor.accentMain)
                statPill(title: "Income", value: "\(transactionTypes.filter { $0.isIncome }.count)", color: DSColor.accentSuccess)
            }
        }
    }

    private var controlsSection: some View {
        DSCard {
            VStack(spacing: DSLayout.spaceS) {
                HStack(spacing: DSLayout.spaceS) {
                    searchField
                    Spacer(minLength: DSLayout.spaceS)
                    columnsMenu
                    fontSizePicker
                    if hasActiveFilters {
                        Button("Reset Filters", action: clearFilters)
                            .buttonStyle(DSButtonStyle(type: .ghost, size: .small))
                    }
                    if visibleColumns != TransactionTypesView.tableConfiguration.defaultVisibleColumns || selectedFontSize != .medium {
                        Button("Reset View", action: resetTablePreferences)
                            .buttonStyle(DSButtonStyle(type: .ghost, size: .small))
                    }
                }

                if hasActiveFilters {
                    HStack(spacing: DSLayout.spaceS) {
                        ForEach(positionFilters.sorted(), id: \.self) { value in
                            filterChip(text: "Position: \(value)") { positionFilters.remove(value) }
                        }
                        ForEach(cashFilters.sorted(), id: \.self) { value in
                            filterChip(text: "Cash: \(value)") { cashFilters.remove(value) }
                        }
                        ForEach(incomeFilters.sorted(), id: \.self) { value in
                            filterChip(text: "Income: \(value)") { incomeFilters.remove(value) }
                        }
                    }
                }

                if !trimmedSearchText.isEmpty {
                    Text("Showing \(filteredTypes.count) of \(transactionTypes.count) types")
                        .dsCaption()
                        .foregroundColor(DSColor.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: DSLayout.spaceS) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(DSColor.textSecondary)

            TextField("Search transaction types", text: $searchText)
                .textFieldStyle(.plain)
                .foregroundColor(DSColor.textPrimary)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(DSColor.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DSLayout.spaceM)
        .padding(.vertical, DSLayout.spaceS)
        .background(DSColor.surfaceSecondary)
        .cornerRadius(DSLayout.radiusM)
        .overlay(
            RoundedRectangle(cornerRadius: DSLayout.radiusM)
                .stroke(DSColor.border, lineWidth: 1)
        )
    }

    private var tableSection: some View {
        DSCard(padding: DSLayout.spaceS) {
            VStack(spacing: DSLayout.spaceS) {
                if filteredTypes.isEmpty {
                    emptyStateView
                } else {
                    typesTable
                }
            }
        }
    }

    private var typesTable: some View {
        MaintenanceTableView(
            model: tableModel,
            rows: sortedTypes,
            rowSpacing: CGFloat(dbManager.tableRowSpacing),
            showHorizontalIndicators: true,
            rowContent: { type, context in
                TransactionTypeRowView(
                    type: type,
                    columns: context.columns,
                    fontConfig: context.fontConfig,
                    rowPadding: CGFloat(dbManager.tableRowPadding),
                    isSelected: selectedType?.id == type.id,
                    onTap: { selectedType = type },
                    onEdit: {
                        selectedType = type
                        showEditTypeSheet = true
                    },
                    widthFor: { context.widthForColumn($0) }
                )
            },
            headerContent: { column, fontConfig in
                transactionHeaderContent(for: column, fontConfig: fontConfig)
            }
        )
    }

    private var actionBar: some View {
        DSCard {
            HStack(spacing: DSLayout.spaceS) {
                Button { showAddTypeSheet = true } label: {
                    Label("Add Transaction Type", systemImage: "plus")
                }
                .buttonStyle(DSButtonStyle(type: .primary))

                Button {
                    if selectedType != nil {
                        showEditTypeSheet = true
                    }
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .buttonStyle(DSButtonStyle(type: .secondary))
                .disabled(selectedType == nil)

                Button {
                    if let type = selectedType {
                        prepareDelete(type)
                    }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .buttonStyle(DSButtonStyle(type: .destructive))
                .disabled(selectedType == nil)

                Spacer()

                if let type = selectedType {
                    HStack(spacing: DSLayout.spaceS) {
                        Text("Selected:")
                            .dsCaption()
                            .foregroundColor(DSColor.textSecondary)
                        DSBadge(text: type.name, color: DSColor.textSecondary)
                    }
                }
            }
        }
        .opacity(buttonsOpacity)
    }

    private var emptyStateView: some View {
        VStack(spacing: DSLayout.spaceM) {
            Image(systemName: trimmedSearchText.isEmpty ? "tray" : "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(DSColor.textSecondary)

            VStack(spacing: DSLayout.spaceXS) {
                Text(trimmedSearchText.isEmpty ? "No transaction types yet" : "No matches found")
                    .dsHeaderSmall()
                    .foregroundColor(DSColor.textPrimary)

                Text(trimmedSearchText.isEmpty ?
                    "Create your first transaction type to categorize activity." :
                    "Adjust your search terms or clear filters.")
                    .dsBody()
                    .foregroundColor(DSColor.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if trimmedSearchText.isEmpty {
                Button { showAddTypeSheet = true } label: {
                    Label("Add Transaction Type", systemImage: "plus")
                }
                .buttonStyle(DSButtonStyle(type: .primary))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 220)
    }

    // MARK: - Table Helpers

    private func transactionHeaderContent(for column: TransactionTypeColumn, fontConfig: MaintenanceTableFontConfig) -> some View {
        let targetSort = sortColumn(from: column)
        let isActiveSort = sortColumn == targetSort
        let binding = filterBinding(for: column)
        let options = filterOptions(for: column)

        return HStack(spacing: DSLayout.spaceXS) {
            Button(action: { toggleSort(for: column) }) {
                HStack(spacing: DSLayout.spaceXS) {
                    Text(column.title)
                        .font(.system(size: fontConfig.header, weight: .semibold))
                        .foregroundColor(DSColor.textPrimary)
                    if isActiveSort {
                        Image(systemName: sortAscending ? "arrow.up" : "arrow.down")
                            .font(.system(size: fontConfig.header - 3, weight: .bold))
                            .foregroundColor(DSColor.accentMain)
                    }
                }
            }
            .buttonStyle(.plain)

            if let binding, !options.isEmpty {
                Menu {
                    ForEach(options, id: \.self) { value in
                        Button {
                            toggleFilter(value, binding: binding)
                        } label: {
                            Label(value, systemImage: binding.wrappedValue.contains(value) ? "checkmark" : "")
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .foregroundColor(binding.wrappedValue.isEmpty ? DSColor.textSecondary : DSColor.accentMain)
                }
                .menuStyle(BorderlessButtonMenuStyle())
            }
        }
    }

    private var columnsMenu: some View {
        Menu {
            ForEach(TransactionTypeColumn.allCases, id: \.self) { column in
                let isVisible = visibleColumns.contains(column)
                Button {
                    toggleColumn(column)
                } label: {
                    Label(column.menuTitle, systemImage: isVisible ? "checkmark" : "")
                }
                .disabled(isVisible && (visibleColumns.count == 1 || TransactionTypesView.tableConfiguration.requiredColumns.contains(column)))
            }
            Divider()
            Button("Reset Columns", action: resetVisibleColumns)
        } label: {
            Label("Columns", systemImage: "slider.horizontal.3")
                .dsBody()
        }
    }

    private var fontSizePicker: some View {
        Picker("Font Size", selection: fontSizeBinding) {
            ForEach(MaintenanceTableFontSize.allCases, id: \.self) { size in
                Text(size.label).tag(size)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 220)
        .labelsHidden()
    }

    private func toggleColumn(_ column: TransactionTypeColumn) {
        tableModel.toggleColumn(column)
        ensureFiltersWithinVisibleColumns()
    }

    private func resetVisibleColumns() {
        tableModel.resetVisibleColumns()
        clearFilters()
    }

    private func resetTablePreferences() {
        tableModel.resetTablePreferences()
        clearFilters()
    }

    private func filterBinding(for column: TransactionTypeColumn) -> Binding<Set<String>>? {
        switch column {
        case .affectsPosition: return $positionFilters
        case .affectsCash: return $cashFilters
        case .isIncome: return $incomeFilters
        default: return nil
        }
    }

    private func filterOptions(for column: TransactionTypeColumn) -> [String] {
        switch column {
        case .affectsPosition, .affectsCash, .isIncome: return ["Yes", "No"]
        default: return []
        }
    }

    private func toggleFilter(_ value: String, binding: Binding<Set<String>>) {
        if binding.wrappedValue.contains(value) {
            binding.wrappedValue.remove(value)
        } else {
            binding.wrappedValue.insert(value)
        }
    }

    private func booleanLabel(for value: Bool) -> String {
        value ? "Yes" : "No"
    }

    private func clearFilters() {
        positionFilters.removeAll()
        cashFilters.removeAll()
        incomeFilters.removeAll()
    }

    private func ensureFiltersWithinVisibleColumns() {
        if !visibleColumns.contains(.affectsPosition) { positionFilters.removeAll() }
        if !visibleColumns.contains(.affectsCash) { cashFilters.removeAll() }
        if !visibleColumns.contains(.isIncome) { incomeFilters.removeAll() }
    }

    private func sortColumn(from column: TransactionTypeColumn) -> SortColumn {
        switch column {
        case .name: return .name
        case .code: return .code
        case .description: return .description
        case .affectsPosition: return .affectsPosition
        case .affectsCash: return .affectsCash
        case .isIncome: return .isIncome
        case .sortOrder: return .sortOrder
        }
    }

    private func toggleSort(for column: TransactionTypeColumn) {
        let target = sortColumn(from: column)
        if sortColumn == target {
            sortAscending.toggle()
        } else {
            sortColumn = target
            sortAscending = true
        }
    }

    private func compare(_ lhs: String, _ rhs: String) -> Bool {
        let result = lhs.localizedCaseInsensitiveCompare(rhs)
        if result == .orderedSame {
            return lhs < rhs
        }
        return result == .orderedAscending
    }

    private func compareBool(_ lhs: Bool, _ rhs: Bool) -> Bool {
        if lhs == rhs {
            return compare(lhs ? "Yes" : "No", rhs ? "Yes" : "No")
        }
        return lhs && !rhs
    }

    private func filterChip(text: String, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: DSLayout.spaceXS) {
            Text(text)
                .dsCaption()
                .foregroundColor(DSColor.textPrimary)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(DSColor.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DSLayout.spaceS)
        .padding(.vertical, DSLayout.spaceXS)
        .background(DSColor.surfaceSecondary)
        .cornerRadius(DSLayout.radiusM)
    }

    // MARK: - Data

    func loadTransactionTypes() {
        let currentId = selectedType?.id
        transactionTypes = dbManager.fetchTransactionTypes().map { type in
            TransactionTypeItem(
                id: type.id,
                code: type.code,
                name: type.name,
                description: type.description,
                affectsPosition: type.affectsPosition,
                affectsCash: type.affectsCash,
                isIncome: type.isIncome,
                sortOrder: type.sortOrder
            )
        }
        if let currentId, let match = transactionTypes.first(where: { $0.id == currentId }) {
            selectedType = match
        }
    }

    private func prepareDelete(_ type: TransactionTypeItem) {
        typeToDelete = type
        deleteInfo = dbManager.canDeleteTransactionType(id: type.id)
        showingDeleteAlert = true
    }

    private func proceedDelete() {
        if let type = typeToDelete {
            performDelete(type)
        }
    }

    private func performDelete(_ type: TransactionTypeItem) {
        let success = dbManager.deleteTransactionType(id: type.id)

        if success {
            loadTransactionTypes()
            selectedType = nil
            typeToDelete = nil
        }
    }

    private var deleteAlertTitle: String {
        let count = deleteInfo?.transactionCount ?? 0
        return count > 0 ? "Delete Transaction Type with Data" : "Delete Transaction Type"
    }

    private var deleteAlertMessage: String {
        guard let type = typeToDelete else { return "Are you sure you want to delete this transaction type?" }
        let count = deleteInfo?.transactionCount ?? 0
        if count > 0 {
            return "'\(type.name)' is used by \(count) transaction(s). Deleting it may remove references."
        }
        return "Delete '\(type.name)'?"
    }

    // MARK: - Animations

    private func animateEntrance() {
        withAnimation(.easeOut(duration: 0.6).delay(0.1)) {
            headerOpacity = 1.0
        }

        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3)) {
            contentOffset = 0
        }

        withAnimation(.easeOut(duration: 0.4).delay(0.5)) {
            buttonsOpacity = 1.0
        }
    }

    // MARK: - Helpers

    private func statPill(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: DSLayout.spaceXS) {
            Text(title.uppercased())
                .dsCaption()
                .foregroundColor(DSColor.textSecondary)
            Text(value)
                .font(.ds.headerSmall)
                .foregroundColor(color)
        }
        .padding(.horizontal, DSLayout.spaceM)
        .padding(.vertical, DSLayout.spaceS)
        .background(DSColor.surface)
        .cornerRadius(DSLayout.radiusM)
        .overlay(
            RoundedRectangle(cornerRadius: DSLayout.radiusM)
                .stroke(DSColor.border, lineWidth: 1)
        )
    }
}

// MARK: - Table Row

private struct TransactionTypeRowView: View {
    let type: TransactionTypeItem
    let columns: [TransactionTypeColumn]
    let fontConfig: MaintenanceTableFontConfig
    let rowPadding: CGFloat
    let isSelected: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    let widthFor: (TransactionTypeColumn) -> CGFloat

    var body: some View {
        HStack(spacing: 0) {
            ForEach(columns, id: \.self) { column in
                columnView(for: column)
            }
        }
        .padding(.trailing, DSLayout.spaceM)
        .padding(.vertical, max(rowPadding, DSLayout.spaceS))
        .background(
            RoundedRectangle(cornerRadius: DSLayout.radiusM)
                .fill(isSelected ? DSColor.surfaceHighlight : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: DSLayout.radiusM)
                        .stroke(isSelected ? DSColor.accentMain.opacity(0.35) : Color.clear, lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .onTapGesture(count: 2) { onEdit() }
        #if os(macOS)
            .contextMenu {
                Button("Edit Type", action: onEdit)
                Button("Select Type", action: onTap)
                Divider()
                Button("Copy Name") {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(type.name, forType: .string)
                }
                Button("Copy Code") {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(type.code, forType: .string)
                }
            }
        #endif
            .animation(.easeInOut(duration: 0.2), value: isSelected)
    }

    @ViewBuilder
    private func columnView(for column: TransactionTypeColumn) -> some View {
        switch column {
        case .name:
            Text(type.name)
                .font(.system(size: fontConfig.primary, weight: .medium))
                .foregroundColor(DSColor.textPrimary)
                .padding(.leading, DSLayout.spaceM)
                .padding(.trailing, DSLayout.spaceS)
                .frame(width: widthFor(.name), alignment: .leading)
        case .code:
            Text(type.code)
                .font(.system(size: fontConfig.secondary, design: .monospaced))
                .foregroundColor(DSColor.textSecondary)
                .padding(.horizontal, DSLayout.spaceS)
                .padding(.vertical, DSLayout.spaceXS)
                .background(DSColor.surfaceSecondary)
                .cornerRadius(DSLayout.radiusS)
                .frame(width: widthFor(.code), alignment: .leading)
        case .description:
            Text(type.description)
                .font(.system(size: fontConfig.secondary))
                .foregroundColor(DSColor.textSecondary)
                .lineLimit(2)
                .padding(.horizontal, DSLayout.spaceS)
                .frame(width: widthFor(.description), alignment: .leading)
        case .affectsPosition:
            indicatorView(isOn: type.affectsPosition, onColor: DSColor.accentMain)
                .frame(width: widthFor(.affectsPosition), alignment: .center)
        case .affectsCash:
            indicatorView(isOn: type.affectsCash, onColor: DSColor.accentSuccess)
                .frame(width: widthFor(.affectsCash), alignment: .center)
        case .isIncome:
            indicatorView(isOn: type.isIncome, onColor: DSColor.accentWarning)
                .frame(width: widthFor(.isIncome), alignment: .center)
        case .sortOrder:
            Text("\(type.sortOrder)")
                .font(.system(size: fontConfig.secondary, weight: .medium))
                .foregroundColor(DSColor.textPrimary)
                .frame(width: widthFor(.sortOrder), alignment: .center)
        }
    }

    private func indicatorView(isOn: Bool, onColor: Color) -> some View {
        let size = max(fontConfig.badge, 8)
        return HStack(spacing: DSLayout.spaceXS) {
            Circle()
                .fill(isOn ? onColor : DSColor.textTertiary.opacity(0.4))
                .frame(width: size, height: size)
            Text(isOn ? "Yes" : "No")
                .font(.system(size: fontConfig.secondary, weight: .medium))
                .foregroundColor(isOn ? onColor : DSColor.textSecondary)
        }
    }
}

// MARK: - Add Transaction Type

struct AddTransactionTypeView: View {
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject var dbManager: DatabaseManager

    @State private var typeName = ""
    @State private var typeCode = ""
    @State private var typeDescription = ""
    @State private var sortOrder = "0"
    @State private var affectsPosition = true
    @State private var affectsCash = true
    @State private var isIncome = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false

    var isValid: Bool {
        !typeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !typeCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            Int(sortOrder) != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            transactionFormHeader(
                title: "New Transaction Type",
                subtitle: "Create a reusable category for transactions.",
                primaryLabel: isLoading ? "Saving..." : "Save",
                isPrimaryEnabled: isValid && !isLoading,
                isLoading: isLoading,
                onSave: saveTransactionType,
                onCancel: { presentationMode.wrappedValue.dismiss() }
            )

            Divider().overlay(DSColor.border)

            ScrollView {
                DSCard {
                    VStack(alignment: .leading, spacing: DSLayout.spaceL) {
                        typeInfoSection(accent: DSColor.accentMain)
                        behaviorSection(accent: DSColor.accentSuccess)
                    }
                }
                .padding(DSLayout.spaceM)
            }
        }
        .frame(width: 640, height: 560)
        .background(DSColor.background)
        .alert("Unable to Save", isPresented: $showingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    private func typeInfoSection(accent: Color) -> some View {
        VStack(alignment: .leading, spacing: DSLayout.spaceM) {
            transactionFormSectionHeader(title: "Type Information", icon: "tag", color: accent)

            transactionTypeFormField(
                title: "Type Name",
                placeholder: "e.g., Stock Purchase",
                icon: "textformat",
                text: $typeName,
                isRequired: true
            )

            transactionTypeFormField(
                title: "Type Code",
                placeholder: "e.g., BUY_STOCK",
                icon: "number",
                text: $typeCode,
                isRequired: true,
                autoUppercase: true
            )

            transactionTypeFormField(
                title: "Description",
                placeholder: "Brief description of this transaction type",
                icon: "text.alignleft",
                text: $typeDescription,
                isRequired: false
            )

            transactionTypeFormField(
                title: "Sort Order",
                placeholder: "0",
                icon: "arrow.up.arrow.down",
                text: $sortOrder,
                isRequired: true
            )
        }
    }

    private func behaviorSection(accent: Color) -> some View {
        VStack(alignment: .leading, spacing: DSLayout.spaceM) {
            transactionFormSectionHeader(title: "Transaction Behavior", icon: "gearshape.fill", color: accent)

            VStack(spacing: DSLayout.spaceM) {
                behaviorToggle(
                    title: "Affects Position",
                    description: "Changes security holdings",
                    isOn: $affectsPosition,
                    accent: DSColor.accentMain
                )

                behaviorToggle(
                    title: "Affects Cash",
                    description: "Changes cash balance",
                    isOn: $affectsCash,
                    accent: DSColor.accentSuccess
                )

                behaviorToggle(
                    title: "Income Transaction",
                    description: "Dividends, interest, or other income",
                    isOn: $isIncome,
                    accent: DSColor.accentWarning
                )
            }
        }
    }

    private func saveTransactionType() {
        guard isValid else {
            alertMessage = "Please fill in all required fields"
            showingAlert = true
            return
        }

        isLoading = true

        let success = dbManager.addTransactionType(
            code: typeCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
            name: typeName.trimmingCharacters(in: .whitespacesAndNewlines),
            description: typeDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            affectsPosition: affectsPosition,
            affectsCash: affectsCash,
            isIncome: isIncome,
            sortOrder: Int(sortOrder) ?? 0
        )

        DispatchQueue.main.async {
            self.isLoading = false

            if success {
                NotificationCenter.default.post(name: NSNotification.Name("RefreshTransactionTypes"), object: nil)
                presentationMode.wrappedValue.dismiss()
            } else {
                self.alertMessage = "Failed to add transaction type. Please try again."
                self.showingAlert = true
            }
        }
    }
}

// MARK: - Edit Transaction Type

struct EditTransactionTypeView: View {
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject var dbManager: DatabaseManager
    let typeId: Int

    @State private var typeName = ""
    @State private var typeCode = ""
    @State private var typeDescription = ""
    @State private var sortOrder = "0"
    @State private var affectsPosition = true
    @State private var affectsCash = true
    @State private var isIncome = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false

    @State private var hasChanges = false

    @State private var originalName = ""
    @State private var originalCode = ""
    @State private var originalDescription = ""
    @State private var originalSortOrder = "0"
    @State private var originalAffectsPosition = true
    @State private var originalAffectsCash = true
    @State private var originalIsIncome = false

    var isValid: Bool {
        !typeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !typeCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            Int(sortOrder) != nil
    }

    private func detectChanges() {
        hasChanges = typeName != originalName ||
            typeCode != originalCode ||
            typeDescription != originalDescription ||
            sortOrder != originalSortOrder ||
            affectsPosition != originalAffectsPosition ||
            affectsCash != originalAffectsCash ||
            isIncome != originalIsIncome
    }

    var body: some View {
        VStack(spacing: 0) {
            transactionFormHeader(
                title: "Edit Transaction Type",
                subtitle: "Update how this transaction type behaves.",
                primaryLabel: isLoading ? "Saving..." : "Save Changes",
                isPrimaryEnabled: isValid && hasChanges && !isLoading,
                isLoading: isLoading,
                onSave: saveEditTransactionType,
                onCancel: {
                    if hasChanges {
                        showUnsavedChangesAlert()
                    } else {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            )

            if hasChanges {
                HStack(spacing: DSLayout.spaceS) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 8))
                        .foregroundColor(DSColor.accentWarning)
                    Text("Unsaved changes")
                        .dsCaption()
                        .foregroundColor(DSColor.accentWarning)
                    Spacer()
                }
                .padding(.horizontal, DSLayout.spaceM)
                .padding(.vertical, DSLayout.spaceXS)
            }

            Divider().overlay(DSColor.border)

            ScrollView {
                DSCard {
                    VStack(alignment: .leading, spacing: DSLayout.spaceL) {
                        typeInfoSection(accent: DSColor.accentMain)
                        behaviorSection(accent: DSColor.accentSuccess)
                    }
                }
                .padding(DSLayout.spaceM)
            }
        }
        .frame(width: 640, height: 580)
        .background(DSColor.background)
        .onAppear {
            loadTypeData()
        }
        .alert("Unable to Save", isPresented: $showingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    private func typeInfoSection(accent: Color) -> some View {
        VStack(alignment: .leading, spacing: DSLayout.spaceM) {
            transactionFormSectionHeader(title: "Type Information", icon: "tag", color: accent)

            transactionTypeFormField(
                title: "Type Name",
                placeholder: "e.g., Stock Purchase",
                icon: "textformat",
                text: $typeName,
                isRequired: true
            )
            .onChange(of: typeName) { _, _ in detectChanges() }

            transactionTypeFormField(
                title: "Type Code",
                placeholder: "e.g., BUY_STOCK",
                icon: "number",
                text: $typeCode,
                isRequired: true,
                autoUppercase: true
            )
            .onChange(of: typeCode) { _, _ in detectChanges() }

            transactionTypeFormField(
                title: "Description",
                placeholder: "Brief description of this transaction type",
                icon: "text.alignleft",
                text: $typeDescription,
                isRequired: false
            )
            .onChange(of: typeDescription) { _, _ in detectChanges() }

            transactionTypeFormField(
                title: "Sort Order",
                placeholder: "0",
                icon: "arrow.up.arrow.down",
                text: $sortOrder,
                isRequired: true
            )
            .onChange(of: sortOrder) { _, _ in detectChanges() }
        }
    }

    private func behaviorSection(accent: Color) -> some View {
        VStack(alignment: .leading, spacing: DSLayout.spaceM) {
            transactionFormSectionHeader(title: "Transaction Behavior", icon: "gearshape.fill", color: accent)

            VStack(spacing: DSLayout.spaceM) {
                behaviorToggle(
                    title: "Affects Position",
                    description: "Changes security holdings",
                    isOn: $affectsPosition,
                    accent: DSColor.accentMain
                )
                .onChange(of: affectsPosition) { _, _ in detectChanges() }

                behaviorToggle(
                    title: "Affects Cash",
                    description: "Changes cash balance",
                    isOn: $affectsCash,
                    accent: DSColor.accentSuccess
                )
                .onChange(of: affectsCash) { _, _ in detectChanges() }

                behaviorToggle(
                    title: "Income Transaction",
                    description: "Dividends, interest, or other income",
                    isOn: $isIncome,
                    accent: DSColor.accentWarning
                )
                .onChange(of: isIncome) { _, _ in detectChanges() }
            }
        }
    }

    private func loadTypeData() {
        if let details = dbManager.fetchTransactionTypeDetails(id: typeId) {
            typeName = details.name
            typeCode = details.code
            typeDescription = details.description
            sortOrder = "\(details.sortOrder)"
            affectsPosition = details.affectsPosition
            affectsCash = details.affectsCash
            isIncome = details.isIncome

            originalName = typeName
            originalCode = typeCode
            originalDescription = typeDescription
            originalSortOrder = sortOrder
            originalAffectsPosition = affectsPosition
            originalAffectsCash = affectsCash
            originalIsIncome = isIncome

            detectChanges()
        }
    }

    private func showUnsavedChangesAlert() {
        let alert = NSAlert()
        alert.messageText = "Unsaved Changes"
        alert.informativeText = "You have unsaved changes. Are you sure you want to close without saving?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Save & Close")
        alert.addButton(withTitle: "Discard Changes")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()

        switch response {
        case .alertFirstButtonReturn: // Save & Close
            saveEditTransactionType()
        case .alertSecondButtonReturn: // Discard Changes
            presentationMode.wrappedValue.dismiss()
        default:
            break
        }
    }

    private func saveEditTransactionType() {
        guard isValid && hasChanges else { return }

        isLoading = true

        let success = dbManager.updateTransactionType(
            id: typeId,
            code: typeCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
            name: typeName.trimmingCharacters(in: .whitespacesAndNewlines),
            description: typeDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            affectsPosition: affectsPosition,
            affectsCash: affectsCash,
            isIncome: isIncome,
            sortOrder: Int(sortOrder) ?? 0
        )

        DispatchQueue.main.async {
            self.isLoading = false

            if success {
                self.originalName = self.typeName
                self.originalCode = self.typeCode
                self.originalDescription = self.typeDescription
                self.originalSortOrder = self.sortOrder
                self.originalAffectsPosition = self.affectsPosition
                self.originalAffectsCash = self.affectsCash
                self.originalIsIncome = self.isIncome
                self.detectChanges()

                NotificationCenter.default.post(name: NSNotification.Name("RefreshTransactionTypes"), object: nil)

                presentationMode.wrappedValue.dismiss()
            } else {
                self.alertMessage = "Failed to update transaction type. Please try again."
                self.showingAlert = true
            }
        }
    }
}

// MARK: - Form Helpers

private func transactionFormHeader(
    title: String,
    subtitle: String,
    primaryLabel: String,
    isPrimaryEnabled: Bool,
    isLoading: Bool,
    onSave: @escaping () -> Void,
    onCancel: @escaping () -> Void
) -> some View {
    HStack {
        VStack(alignment: .leading, spacing: DSLayout.spaceXS) {
            Text(title)
                .dsHeaderMedium()
            Text(subtitle)
                .dsBodySmall()
                .foregroundColor(DSColor.textSecondary)
        }

        Spacer()

        Button("Cancel", action: onCancel)
            .buttonStyle(DSButtonStyle(type: .ghost))

        Button {
            onSave()
        } label: {
            HStack(spacing: DSLayout.spaceXS) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
                Text(primaryLabel)
            }
        }
        .buttonStyle(DSButtonStyle(type: .primary))
        .disabled(!isPrimaryEnabled)
    }
    .padding(DSLayout.spaceM)
}

private func transactionFormSectionHeader(title: String, icon: String, color: Color) -> some View {
    HStack(spacing: DSLayout.spaceS) {
        Image(systemName: icon)
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(color)
        Text(title)
            .dsHeaderSmall()
    }
}

private func transactionTypeFormField(
    title: String,
    placeholder: String,
    icon: String,
    text: Binding<String>,
    isRequired: Bool,
    autoUppercase: Bool = false
) -> some View {
    VStack(alignment: .leading, spacing: DSLayout.spaceXS) {
        HStack(spacing: DSLayout.spaceXS) {
            Image(systemName: icon)
                .foregroundColor(DSColor.textSecondary)
            Text(title + (isRequired ? "*" : ""))
                .dsBodySmall()
                .foregroundColor(DSColor.textSecondary)
        }

        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .font(.ds.body)
            .foregroundColor(DSColor.textPrimary)
            .padding(.horizontal, DSLayout.spaceM)
            .padding(.vertical, DSLayout.spaceS)
            .background(DSColor.surfaceSecondary)
            .cornerRadius(DSLayout.radiusM)
            .overlay(
                RoundedRectangle(cornerRadius: DSLayout.radiusM)
                    .stroke(DSColor.border, lineWidth: 1)
            )
            .onChange(of: text.wrappedValue) { _, newValue in
                if autoUppercase {
                    text.wrappedValue = newValue.uppercased()
                }
            }
    }
}

private func behaviorToggle(title: String, description: String, isOn: Binding<Bool>, accent: Color) -> some View {
    VStack(alignment: .leading, spacing: DSLayout.spaceXS) {
        Text(title)
            .dsBody()
            .foregroundColor(DSColor.textPrimary)
        Text(description)
            .dsCaption()
            .foregroundColor(DSColor.textSecondary)

        Toggle(description, isOn: isOn)
            .labelsHidden()
            .toggleStyle(SwitchToggleStyle(tint: accent))
            .padding(.horizontal, DSLayout.spaceM)
            .padding(.vertical, DSLayout.spaceS)
            .background(DSColor.surfaceSecondary)
            .cornerRadius(DSLayout.radiusM)
            .overlay(
                RoundedRectangle(cornerRadius: DSLayout.radiusM)
                    .stroke(DSColor.border, lineWidth: 1)
            )
    }
}
