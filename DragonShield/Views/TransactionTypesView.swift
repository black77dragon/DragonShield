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

// MARK: - Version 1.0
// MARK: - History: Initial creation - transaction types management with CRUD operations

struct TransactionTypesView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @State private var transactionTypes: [TransactionTypeItem] = []
    @State private var showAddTypeSheet = false
    @State private var showEditTypeSheet = false
    @State private var selectedType: TransactionTypeItem? = nil
    @State private var showingDeleteAlert = false
    @State private var typeToDelete: TransactionTypeItem? = nil
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
                .affectsPosition: 110,
                .affectsCash: 100,
                .isIncome: 110,
                .sortOrder: 90
            ],
            minimumColumnWidths: [
                .name: 180,
                .code: 100,
                .description: 240,
                .affectsPosition: 90,
                .affectsCash: 80,
                .isIncome: 80,
                .sortOrder: 70
            ],
            visibleColumnsDefaultsKey: visibleColumnsKey,
            columnHandleWidth: 10,
            columnHandleHitSlop: 8,
            columnTextInset: 12,
            headerBackground: Color.orange.opacity(0.1),
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
                .affectsPosition: 110,
                .affectsCash: 100,
                .isIncome: 110,
                .sortOrder: 90
            ],
            minimumColumnWidths: [
                .name: 180,
                .code: 100,
                .description: 240,
                .affectsPosition: 90,
                .affectsCash: 80,
                .isIncome: 80,
                .sortOrder: 70
            ],
            visibleColumnsDefaultsKey: visibleColumnsKey,
            columnHandleWidth: 10,
            columnHandleHitSlop: 8,
            columnTextInset: 12,
            headerBackground: Color.orange.opacity(0.1),
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

    // Filtered types based on search
    private var filteredTypes: [TransactionTypeItem] {
        var result = transactionTypes

        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedQuery.isEmpty {
            let query = trimmedQuery.lowercased()
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
    
    var body: some View {
        ZStack {
            // Premium gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.99, blue: 1.0),
                    Color(red: 0.95, green: 0.97, blue: 0.99),
                    Color(red: 0.93, green: 0.95, blue: 0.98)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Subtle animated background elements
            TransactionTypesParticleBackground()
            
            VStack(spacing: 0) {
                modernHeader
                searchAndStats
                typesContent
                modernActionBar
            }
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
        .alert("Delete Transaction Type", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let type = typeToDelete {
                    confirmDelete(type)
                }
            }
        } message: {
            if let type = typeToDelete {
                Text("Are you sure you want to delete '\(type.name)'?")
            }
        }
        .onChange(of: tableModel.visibleColumns) { _, _ in
            ensureFiltersWithinVisibleColumns()
        }
    }
    
    // MARK: - Modern Header
    private var modernHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    Image(systemName: "tag.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.orange)
                    
                    Text("Transaction Types")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.black, .gray],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                
                Text("Manage your transaction categories and classifications")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Quick stats
            HStack(spacing: 16) {
                modernStatCard(
                    title: "Total",
                    value: "\(transactionTypes.count)",
                    icon: "number.circle.fill",
                    color: .orange
                )
                
                modernStatCard(
                    title: "Position",
                    value: "\(transactionTypes.filter { $0.affectsPosition }.count)",
                    icon: "chart.line.uptrend.xyaxis.circle.fill",
                    color: .blue
                )
                
                modernStatCard(
                    title: "Income",
                    value: "\(transactionTypes.filter { $0.isIncome }.count)",
                    icon: "plus.circle.fill",
                    color: .green
                )
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .opacity(headerOpacity)
    }
    
    // MARK: - Search and Stats
    private var searchAndStats: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search transaction types...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
            
            // Results indicator
            if !searchText.isEmpty || hasActiveFilters {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Found \(filteredTypes.count) of \(transactionTypes.count) types")
                        .font(.caption)
                        .foregroundColor(.gray)

                    if hasActiveFilters {
                        HStack(spacing: 8) {
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
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 24)
        .offset(y: contentOffset)
    }
    
    // MARK: - Types Content
    private var typesContent: some View {
        VStack(spacing: 16) {
            tableControls
            if filteredTypes.isEmpty {
                emptyStateView
            } else {
                typesTable
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .offset(y: contentOffset)
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: searchText.isEmpty ? "tag" : "magnifyingglass")
                    .font(.system(size: 64))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.gray.opacity(0.5), .gray.opacity(0.3)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                VStack(spacing: 8) {
                    Text(searchText.isEmpty ? "No transaction types yet" : "No matching types")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray)
                    
                    Text(searchText.isEmpty ?
                         "Create your first transaction type to categorize your financial activities" :
                         "Try adjusting your search terms")
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                
                if searchText.isEmpty {
                    Button { showAddTypeSheet = true } label: {
                        Label("Add Transaction Type", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.67, green: 0.89, blue: 0.67))
                    .foregroundColor(.black)
                    .padding(.top, 8)
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Types Table
    private var typesTable: some View {
        MaintenanceTableView(
            model: tableModel,
            rows: sortedTypes,
            rowSpacing: 1,
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

    private var tableControls: some View {
        HStack(spacing: 12) {
            columnsMenu
            fontSizePicker
            if hasActiveFilters {
                Button("Reset Filters", action: clearFilters)
                    .buttonStyle(.link)
            }
            Spacer()
            if visibleColumns != TransactionTypesView.tableConfiguration.defaultVisibleColumns || selectedFontSize != .medium {
                Button("Reset View", action: resetTablePreferences)
                    .buttonStyle(.link)
            }
        }
        .padding(.horizontal, 4)
        .font(.system(size: 12))
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
        }
    }

    private var fontSizePicker: some View {
        Picker("Font Size", selection: fontSizeBinding) {
            ForEach(MaintenanceTableFontSize.allCases, id: \.self) { size in
                Text(size.label).tag(size)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 240)
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

    private var hasActiveFilters: Bool {
        !positionFilters.isEmpty || !cashFilters.isEmpty || !incomeFilters.isEmpty
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

    private func booleanLabel(for value: Bool) -> String {
        value ? "Yes" : "No"
    }

    private func clearFilters() {
        positionFilters.removeAll()
        cashFilters.removeAll()
        incomeFilters.removeAll()
    }

    private func filterChip(text: String, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.caption)
                .foregroundColor(.primary)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.orange.opacity(0.15))
        .clipShape(Capsule())
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

    private func transactionHeaderContent(for column: TransactionTypeColumn, fontConfig: MaintenanceTableFontConfig) -> some View {
        let targetSort = sortColumn(from: column)
        let isActiveSort = sortColumn == targetSort
        let filterBinding = filterBinding(for: column)
        let options = filterOptions(for: column)

        return HStack(spacing: 6) {
            Button(action: { toggleSort(for: column) }) {
                HStack(spacing: 4) {
                    Text(column.title)
                        .font(.system(size: fontConfig.header, weight: .semibold))
                        .foregroundColor(.black)
                    Image(systemName: "triangle.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(isActiveSort ? .accentColor : .gray.opacity(0.3))
                        .rotationEffect(.degrees(isActiveSort && !sortAscending ? 180 : 0))
                        .opacity(isActiveSort ? 1 : 0)
                }
            }
            .buttonStyle(.plain)

            if let binding = filterBinding, !options.isEmpty {
                Menu {
                    ForEach(options, id: \.self) { value in
                        Button {
                            if binding.wrappedValue.contains(value) {
                                binding.wrappedValue.remove(value)
                            } else {
                                binding.wrappedValue.insert(value)
                            }
                        } label: {
                            Label(value, systemImage: binding.wrappedValue.contains(value) ? "checkmark" : "")
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .foregroundColor(binding.wrappedValue.isEmpty ? .gray : .accentColor)
                }
                .menuStyle(BorderlessButtonMenuStyle())
            }
        }
    }
    
    // MARK: - Modern Action Bar
    private var modernActionBar: some View {
        VStack(spacing: 0) {
            // Divider line
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1)
            
            HStack(spacing: 16) {
                // Primary action
                Button { showAddTypeSheet = true } label: {
                    Label("Add Transaction Type", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.67, green: 0.89, blue: 0.67))
                .foregroundColor(.black)
                
                // Secondary actions
                if selectedType != nil {
                    Button {
                        showEditTypeSheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "pencil")
                            Text("Edit")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())
                    
                    Button {
                        if let type = selectedType {
                            typeToDelete = type
                            showingDeleteAlert = true
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                            Text("Delete")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.red)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.red.opacity(0.1))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.red.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                
                Spacer()
                
                // Selection indicator
                if let type = selectedType {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.orange)
                        Text("Selected: \(type.name)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.05))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(.regularMaterial)
        }
        .opacity(buttonsOpacity)
    }
    
    // MARK: - Helper Views
    private func modernStatCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.gray)
            }
            
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: color.opacity(0.1), radius: 3, x: 0, y: 1)
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
    
    // MARK: - Functions
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

    private func confirmDelete(_ type: TransactionTypeItem) {
#if os(macOS)
        let deleteInfo = dbManager.canDeleteTransactionType(id: type.id)

        if deleteInfo.transactionCount > 0 {
            let alert = NSAlert()
            alert.messageText = "Delete Transaction Type with Data"
            alert.informativeText = "This transaction type '\(type.name)' is used by \(deleteInfo.transactionCount) transaction(s). Deleting it may cause data inconsistencies.\n\nAre you sure you want to proceed?"
            alert.alertStyle = .critical
            alert.addButton(withTitle: "Delete Anyway")
            alert.addButton(withTitle: "Cancel")

            if alert.runModal() == .alertFirstButtonReturn {
                performDelete(type)
            }
        } else {
            let alert = NSAlert()
            alert.messageText = "Delete Transaction Type"
            alert.informativeText = "Are you sure you want to delete '\(type.name)'?"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Delete")
            alert.addButton(withTitle: "Cancel")

            if alert.runModal() == .alertFirstButtonReturn {
                performDelete(type)
            }
        }
#else
        performDelete(type)
#endif
    }

    private func performDelete(_ type: TransactionTypeItem) {
        let success = dbManager.deleteTransactionType(id: type.id)

        if success {
            loadTransactionTypes()
            selectedType = nil
            typeToDelete = nil
        }
    }
}

// MARK: - Transaction Type Row
fileprivate struct TransactionTypeRowView: View {
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
        .padding(.trailing, 12)
        .padding(.vertical, max(rowPadding, 8))
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.orange.opacity(0.1) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.orange.opacity(0.3) : Color.clear, lineWidth: 1)
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
                .foregroundColor(.primary)
                .padding(.leading, 16)
                .padding(.trailing, 8)
                .frame(width: widthFor(.name), alignment: .leading)
        case .code:
            Text(type.code)
                .font(.system(size: fontConfig.secondary, design: .monospaced))
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .frame(width: widthFor(.code), alignment: .leading)
        case .description:
            Text(type.description)
                .font(.system(size: fontConfig.secondary))
                .foregroundColor(.secondary)
                .lineLimit(2)
                .padding(.horizontal, 8)
                .frame(width: widthFor(.description), alignment: .leading)
        case .affectsPosition:
            indicatorView(isOn: type.affectsPosition, onColor: .blue)
                .frame(width: widthFor(.affectsPosition), alignment: .center)
        case .affectsCash:
            indicatorView(isOn: type.affectsCash, onColor: .green)
                .frame(width: widthFor(.affectsCash), alignment: .center)
        case .isIncome:
            indicatorView(isOn: type.isIncome, onColor: .purple)
                .frame(width: widthFor(.isIncome), alignment: .center)
        case .sortOrder:
            Text("\(type.sortOrder)")
                .font(.system(size: fontConfig.secondary, weight: .medium))
                .foregroundColor(.primary)
                .frame(width: widthFor(.sortOrder), alignment: .center)
        }
    }

    private func indicatorView(isOn: Bool, onColor: Color) -> some View {
        let size = max(fontConfig.badge, 8)
        return Circle()
            .fill(isOn ? onColor : Color.gray.opacity(0.3))
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(isOn ? onColor.opacity(0.4) : Color.gray.opacity(0.2), lineWidth: 1)
            )
    }
}

// MARK: - Add Transaction Type View
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
    
    // Animation states
    @State private var formScale: CGFloat = 0.9
    @State private var headerOpacity: Double = 0
    @State private var sectionsOffset: CGFloat = 50
    
    var isValid: Bool {
        !typeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !typeCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        Int(sortOrder) != nil
    }
    
    // MARK: - Computed Properties
    private var completionPercentage: Double {
        var completed = 0.0
        let total = 4.0
        
        if !typeName.isEmpty { completed += 1 }
        if !typeCode.isEmpty { completed += 1 }
        if !typeDescription.isEmpty { completed += 1 }
        completed += 1 // Always count settings
        
        return completed / total
    }
    
    var body: some View {
        ZStack {
            // Premium gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.99, blue: 1.0),
                    Color(red: 0.95, green: 0.97, blue: 0.99),
                    Color(red: 0.93, green: 0.95, blue: 0.98)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Subtle animated background elements
            AddTransactionTypeParticleBackground()
            
            // Main content
            VStack(spacing: 0) {
                addModernHeader
                addProgressBar
                addModernContent
            }
        }
        .frame(width: 700, height: 650)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
        .scaleEffect(formScale)
        .onAppear {
            animateAddEntrance()
        }
        .alert("Result", isPresented: $showingAlert) {
            Button("OK") {
                if alertMessage.contains("✅") {
                    animateAddExit()
                }
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Add Modern Header
    private var addModernHeader: some View {
        HStack {
            Button {
                animateAddExit()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.gray)
                    .frame(width: 32, height: 32)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 1))
            }
            .buttonStyle(ScaleButtonStyle())
            
            Spacer()
            
            HStack(spacing: 12) {
                Image(systemName: "tag.circle.badge.plus")
                    .font(.system(size: 24))
                    .foregroundColor(.orange)
                
                Text("Add Transaction Type")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.black, .gray],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            
            Spacer()
            
            Button {
                saveTransactionType()
            } label: {
                HStack(spacing: 8) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                    }
                    
                    Text(isLoading ? "Saving..." : "Save")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(height: 32)
                .padding(.horizontal, 16)
                .background(
                    Group {
                        if isValid && !isLoading {
                            Color.orange
                        } else {
                            Color.gray.opacity(0.4)
                        }
                    }
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(.white.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: isValid ? .orange.opacity(0.3) : .clear, radius: 8, x: 0, y: 2)
            }
            .disabled(isLoading || !isValid)
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .opacity(headerOpacity)
    }
    
    // MARK: - Add Progress Bar
    private var addProgressBar: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Completion")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text("\(Int(completionPercentage * 100))%")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.orange)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [.orange, .green],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * completionPercentage, height: 6)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: completionPercentage)
                        .shadow(color: .orange.opacity(0.3), radius: 3, x: 0, y: 1)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }
    
    // MARK: - Add Modern Content
    private var addModernContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                addTypeInfoSection
                addBehaviorSection
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 100)
        }
        .offset(y: sectionsOffset)
    }
    
    // MARK: - Type Info Section
    private var addTypeInfoSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            addSectionHeader(title: "Type Information", icon: "tag.circle.fill", color: .orange)
            
            VStack(spacing: 16) {
                addModernTextField(
                    title: "Type Name",
                    text: $typeName,
                    placeholder: "e.g., Stock Purchase",
                    icon: "textformat",
                    isRequired: true
                )
                
                addModernTextField(
                    title: "Type Code",
                    text: $typeCode,
                    placeholder: "e.g., BUY_STOCK",
                    icon: "number",
                    isRequired: true,
                    autoUppercase: true
                )
                
                addModernTextField(
                    title: "Description",
                    text: $typeDescription,
                    placeholder: "Brief description of this transaction type",
                    icon: "text.alignleft",
                    isRequired: false
                )
                
                addModernTextField(
                    title: "Sort Order",
                    text: $sortOrder,
                    placeholder: "0",
                    icon: "arrow.up.arrow.down",
                    isRequired: true
                )
            }
        }
        .padding(24)
        .background(addTransactionTypeGlassMorphismBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .orange.opacity(0.1), radius: 10, x: 0, y: 5)
    }
    
    // MARK: - Behavior Section
    private var addBehaviorSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            addSectionHeader(title: "Transaction Behavior", icon: "gearshape.circle.fill", color: .blue)
            
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    // Affects Position Toggle
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "chart.line.uptrend.xyaxis.circle")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                            
                            Text("Affects Position")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.black.opacity(0.7))
                            
                            Spacer()
                        }
                        
                        Toggle("Changes security holdings", isOn: $affectsPosition)
                            .toggleStyle(SwitchToggleStyle(tint: .blue))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.8))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Affects Cash Toggle
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "dollarsign.circle")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                            
                            Text("Affects Cash")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.black.opacity(0.7))
                            
                            Spacer()
                        }
                        
                        Toggle("Changes cash balance", isOn: $affectsCash)
                            .toggleStyle(SwitchToggleStyle(tint: .green))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.8))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                    }
                    .frame(maxWidth: .infinity)
                }
                
                // Is Income Toggle
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                        
                        Text("Income Transaction")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.black.opacity(0.7))
                        
                        Spacer()
                    }
                    
                    Toggle("This is an income transaction (dividends, interest, etc.)", isOn: $isIncome)
                        .toggleStyle(SwitchToggleStyle(tint: .purple))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                }
            }
        }
        .padding(24)
        .background(addTransactionTypeGlassMorphismBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .blue.opacity(0.1), radius: 10, x: 0, y: 5)
    }
    
    // MARK: - Add Glassmorphism Background
    private var addTransactionTypeGlassMorphismBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .background(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.8),
                            .white.opacity(0.6)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            .orange.opacity(0.05),
                            .blue.opacity(0.03),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }
    
    // MARK: - Helper Views
    private func addSectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(
                    LinearGradient(
                        colors: [color, color.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text(title)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.black.opacity(0.8))
            
            Spacer()
        }
    }
    
    private func addModernTextField(
        title: String,
        text: Binding<String>,
        placeholder: String,
        icon: String,
        isRequired: Bool,
        autoUppercase: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                
                Text(title + (isRequired ? "*" : ""))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.black.opacity(0.7))
                
                Spacer()
            }
            
            TextField(placeholder, text: text)
                .font(.system(size: 16))
                .foregroundColor(.black)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                .onChange(of: text.wrappedValue) { oldValue, newValue in
                    if autoUppercase {
                        text.wrappedValue = newValue.uppercased()
                    }
                }
        }
    }
    
    // MARK: - Animations
    private func animateAddEntrance() {
        withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
            formScale = 1.0
        }
        
        withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
            headerOpacity = 1.0
        }
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4)) {
            sectionsOffset = 0
        }
    }
    
    private func animateAddExit() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            formScale = 0.9
            headerOpacity = 0
            sectionsOffset = 50
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            presentationMode.wrappedValue.dismiss()
        }
    }
    
    // MARK: - Functions
    func saveTransactionType() {
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
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.animateAddExit()
                }
            } else {
                self.alertMessage = "❌ Failed to add transaction type. Please try again."
                self.showingAlert = true
            }
        }
    }
}

// MARK: - Edit Transaction Type View
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
    
    // Animation states
    @State private var formScale: CGFloat = 0.9
    @State private var headerOpacity: Double = 0
    @State private var sectionsOffset: CGFloat = 50
    @State private var hasChanges = false
    
    // Store original values
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
    
    // MARK: - Computed Properties
    private var completionPercentage: Double {
        var completed = 0.0
        let total = 4.0
        
        if !typeName.isEmpty { completed += 1 }
        if !typeCode.isEmpty { completed += 1 }
        if !typeDescription.isEmpty { completed += 1 }
        completed += 1 // Always count settings
        
        return completed / total
    }
    
    var body: some View {
        ZStack {
            // Premium gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.97, green: 0.98, blue: 1.0),
                    Color(red: 0.94, green: 0.96, blue: 0.99),
                    Color(red: 0.91, green: 0.94, blue: 0.98)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Background particles
            EditTransactionTypeParticleBackground()
            
            // Main content
            VStack(spacing: 0) {
                editModernHeader
                editChangeIndicator
                editProgressBar
                editModernContent
            }
        }
        .frame(width: 700, height: 700)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
        .scaleEffect(formScale)
        .onAppear {
            loadTypeData()
            animateEditEntrance()
        }
        .alert("Result", isPresented: $showingAlert) {
            Button("OK") {
                showingAlert = false
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Edit Modern Header
    private var editModernHeader: some View {
        HStack {
            Button {
                if hasChanges {
                    showUnsavedChangesAlert()
                } else {
                    animateEditExit()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.gray)
                    .frame(width: 32, height: 32)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 1))
            }
            .buttonStyle(ScaleButtonStyle())
            
            Spacer()
            
            HStack(spacing: 12) {
                Image(systemName: "tag.circle.badge.gearshape")
                    .font(.system(size: 24))
                    .foregroundColor(.orange)
                
                Text("Edit Transaction Type")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.black, .gray],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            
            Spacer()
            
            Button {
                saveEditTransactionType()
            } label: {
                HStack(spacing: 8) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: hasChanges ? "checkmark.circle.fill" : "checkmark")
                            .font(.system(size: 14, weight: .bold))
                    }
                    
                    Text(isLoading ? "Saving..." : "Save Changes")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(height: 32)
                .padding(.horizontal, 16)
                .background(
                    Group {
                        if isValid && hasChanges && !isLoading {
                            Color.orange
                        } else {
                            Color.gray.opacity(0.4)
                        }
                    }
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(.white.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: isValid && hasChanges ? .orange.opacity(0.3) : .clear, radius: 8, x: 0, y: 2)
            }
            .disabled(isLoading || !isValid || !hasChanges)
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .opacity(headerOpacity)
    }
    
    // MARK: - Edit Change Indicator
    private var editChangeIndicator: some View {
        HStack {
            if hasChanges {
                HStack(spacing: 8) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.orange)
                    
                    Text("Unsaved changes")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.1))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
                .transition(.opacity.combined(with: .scale))
            }
            
            Spacer()
        }
        .padding(.horizontal, 24)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: hasChanges)
    }
    
    // MARK: - Edit Progress Bar
    private var editProgressBar: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Completion")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text("\(Int(completionPercentage * 100))%")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.orange)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [.orange, .green],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * completionPercentage, height: 6)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: completionPercentage)
                        .shadow(color: .orange.opacity(0.3), radius: 3, x: 0, y: 1)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }
    
    // MARK: - Edit Modern Content
    private var editModernContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                editTypeInfoSection
                editBehaviorSection
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 100)
        }
        .offset(y: sectionsOffset)
    }
    
    // MARK: - Edit Type Info Section
    private var editTypeInfoSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            editSectionHeader(title: "Type Information", icon: "tag.circle.fill", color: .orange)
            
            VStack(spacing: 16) {
                editModernTextField(
                    title: "Type Name",
                    text: $typeName,
                    placeholder: "e.g., Stock Purchase",
                    icon: "textformat",
                    isRequired: true
                )
                .onChange(of: typeName) { oldValue, newValue in detectChanges() }
                
                editModernTextField(
                    title: "Type Code",
                    text: $typeCode,
                    placeholder: "e.g., BUY_STOCK",
                    icon: "number",
                    isRequired: true,
                    autoUppercase: true
                )
                .onChange(of: typeCode) { oldValue, newValue in detectChanges() }
                
                editModernTextField(
                    title: "Description",
                    text: $typeDescription,
                    placeholder: "Brief description of this transaction type",
                    icon: "text.alignleft",
                    isRequired: false
                )
                .onChange(of: typeDescription) { oldValue, newValue in detectChanges() }
                
                editModernTextField(
                    title: "Sort Order",
                    text: $sortOrder,
                    placeholder: "0",
                    icon: "arrow.up.arrow.down",
                    isRequired: true
                )
                .onChange(of: sortOrder) { oldValue, newValue in detectChanges() }
            }
        }
        .padding(24)
        .background(editTransactionTypeGlassMorphismBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .orange.opacity(0.1), radius: 10, x: 0, y: 5)
    }
    
    // MARK: - Edit Behavior Section
    private var editBehaviorSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            editSectionHeader(title: "Transaction Behavior", icon: "gearshape.circle.fill", color: .blue)
            
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    // Affects Position Toggle
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "chart.line.uptrend.xyaxis.circle")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                            
                            Text("Affects Position")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.black.opacity(0.7))
                            
                            Spacer()
                        }
                        
                        Toggle("Changes security holdings", isOn: $affectsPosition)
                            .toggleStyle(SwitchToggleStyle(tint: .blue))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.8))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                            .onChange(of: affectsPosition) { oldValue, newValue in detectChanges() }
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Affects Cash Toggle
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "dollarsign.circle")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                            
                            Text("Affects Cash")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.black.opacity(0.7))
                            
                            Spacer()
                        }
                        
                        Toggle("Changes cash balance", isOn: $affectsCash)
                            .toggleStyle(SwitchToggleStyle(tint: .green))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.8))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                            .onChange(of: affectsCash) { oldValue, newValue in detectChanges() }
                    }
                    .frame(maxWidth: .infinity)
                }
                
                // Is Income Toggle
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                        
                        Text("Income Transaction")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.black.opacity(0.7))
                        
                        Spacer()
                    }
                    
                    Toggle("This is an income transaction (dividends, interest, etc.)", isOn: $isIncome)
                        .toggleStyle(SwitchToggleStyle(tint: .purple))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                        .onChange(of: isIncome) { oldValue, newValue in detectChanges() }
                }
            }
        }
        .padding(24)
        .background(editTransactionTypeGlassMorphismBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .blue.opacity(0.1), radius: 10, x: 0, y: 5)
    }
    
    // MARK: - Edit Glassmorphism Background
    private var editTransactionTypeGlassMorphismBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .background(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.85),
                            .white.opacity(0.65)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            .orange.opacity(0.05),
                            .blue.opacity(0.03),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }
    
    // MARK: - Helper Views
    private func editSectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(
                    LinearGradient(
                        colors: [color, color.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text(title)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.black.opacity(0.8))
            
            Spacer()
        }
    }
    
    private func editModernTextField(
        title: String,
        text: Binding<String>,
        placeholder: String,
        icon: String,
        isRequired: Bool,
        autoUppercase: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                
                Text(title + (isRequired ? "*" : ""))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.black.opacity(0.7))
                
                Spacer()
            }
            
            TextField(placeholder, text: text)
                .font(.system(size: 16))
                .foregroundColor(.black)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                .onChange(of: text.wrappedValue) { oldValue, newValue in
                    if autoUppercase {
                        text.wrappedValue = newValue.uppercased()
                    }
                }
        }
    }
    
    // MARK: - Animations
    private func animateEditEntrance() {
        withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
            formScale = 1.0
        }
        
        withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
            headerOpacity = 1.0
        }
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4)) {
            sectionsOffset = 0
        }
    }
    
    private func animateEditExit() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            formScale = 0.9
            headerOpacity = 0
            sectionsOffset = 50
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            presentationMode.wrappedValue.dismiss()
        }
    }
    
    // MARK: - Functions
    func loadTypeData() {
        if let details = dbManager.fetchTransactionTypeDetails(id: typeId) {
            typeName = details.name
            typeCode = details.code
            typeDescription = details.description
            sortOrder = "\(details.sortOrder)"
            affectsPosition = details.affectsPosition
            affectsCash = details.affectsCash
            isIncome = details.isIncome
            
            // Store original values
            originalName = typeName
            originalCode = typeCode
            originalDescription = typeDescription
            originalSortOrder = sortOrder
            originalAffectsPosition = affectsPosition
            originalAffectsCash = affectsCash
            originalIsIncome = isIncome
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
            animateEditExit()
        default: // Cancel
            break
        }
    }
    
    func saveEditTransactionType() {
        guard isValid else {
            alertMessage = "Please fill in all required fields correctly"
            showingAlert = true
            return
        }
        
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
                // Update original values to reflect saved state
                self.originalName = self.typeName
                self.originalCode = self.typeCode
                self.originalDescription = self.typeDescription
                self.originalSortOrder = self.sortOrder
                self.originalAffectsPosition = self.affectsPosition
                self.originalAffectsCash = self.affectsCash
                self.originalIsIncome = self.isIncome
                self.detectChanges()
                
                NotificationCenter.default.post(name: NSNotification.Name("RefreshTransactionTypes"), object: nil)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.animateEditExit()
                }
            } else {
                self.alertMessage = "❌ Failed to update transaction type. Please try again."
                self.showingAlert = true
            }
        }
    }
}

// MARK: - Background Particles for Add/Edit Views
struct AddTransactionTypeParticleBackground: View {
    @State private var particles: [AddTransactionTypeParticle] = []
    
    var body: some View {
        ZStack {
            ForEach(particles.indices, id: \.self) { index in
                Circle()
                    .fill(Color.orange.opacity(0.04))
                    .frame(width: particles[index].size, height: particles[index].size)
                    .position(particles[index].position)
                    .opacity(particles[index].opacity)
            }
        }
        .onAppear {
            createParticles()
            animateParticles()
        }
    }
    
    private func createParticles() {
        particles = (0..<12).map { _ in
            AddTransactionTypeParticle(
                position: CGPoint(
                    x: CGFloat.random(in: 0...700),
                    y: CGFloat.random(in: 0...650)
                ),
                size: CGFloat.random(in: 3...9),
                opacity: Double.random(in: 0.1...0.2)
            )
        }
    }
    
    private func animateParticles() {
        withAnimation(.linear(duration: 25).repeatForever(autoreverses: false)) {
            for index in particles.indices {
                particles[index].position.y -= 800
                particles[index].opacity = Double.random(in: 0.05...0.15)
            }
        }
    }
}

struct EditTransactionTypeParticleBackground: View {
    @State private var particles: [EditTransactionTypeParticle] = []
    
    var body: some View {
        ZStack {
            ForEach(particles.indices, id: \.self) { index in
                Circle()
                    .fill(Color.orange.opacity(0.04))
                    .frame(width: particles[index].size, height: particles[index].size)
                    .position(particles[index].position)
                    .opacity(particles[index].opacity)
            }
        }
        .onAppear {
            createParticles()
            animateParticles()
        }
    }
    
    private func createParticles() {
        particles = (0..<12).map { _ in
            EditTransactionTypeParticle(
                position: CGPoint(
                    x: CGFloat.random(in: 0...700),
                    y: CGFloat.random(in: 0...700)
                ),
                size: CGFloat.random(in: 3...9),
                opacity: Double.random(in: 0.1...0.2)
            )
        }
    }
    
    private func animateParticles() {
        withAnimation(.linear(duration: 30).repeatForever(autoreverses: false)) {
            for index in particles.indices {
                particles[index].position.y -= 900
                particles[index].opacity = Double.random(in: 0.05...0.15)
            }
        }
    }
}

struct AddTransactionTypeParticle {
    var position: CGPoint
    var size: CGFloat
    var opacity: Double
}

struct EditTransactionTypeParticle {
    var position: CGPoint
    var size: CGFloat
    var opacity: Double
}

// MARK: - Background Particles
struct TransactionTypesParticleBackground: View {
    @State private var particles: [TransactionTypesParticle] = []
    
    var body: some View {
        ZStack {
            ForEach(particles.indices, id: \.self) { index in
                Circle()
                    .fill(Color.orange.opacity(0.03))
                    .frame(width: particles[index].size, height: particles[index].size)
                    .position(particles[index].position)
                    .opacity(particles[index].opacity)
            }
        }
        .onAppear {
            createParticles()
            animateParticles()
        }
    }
    
    private func createParticles() {
        particles = (0..<15).map { _ in
            TransactionTypesParticle(
                position: CGPoint(
                    x: CGFloat.random(in: 0...1200),
                    y: CGFloat.random(in: 0...800)
                ),
                size: CGFloat.random(in: 2...8),
                opacity: Double.random(in: 0.1...0.2)
            )
        }
    }
    
    private func animateParticles() {
        withAnimation(.linear(duration: 30).repeatForever(autoreverses: false)) {
            for index in particles.indices {
                particles[index].position.y -= 1000
                particles[index].opacity = Double.random(in: 0.05...0.15)
            }
        }
    }
}

struct TransactionTypesParticle {
    var position: CGPoint
    var size: CGFloat
    var opacity: Double
}
