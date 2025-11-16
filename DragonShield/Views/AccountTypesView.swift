import SwiftUI
#if os(macOS)
    import AppKit
#endif

private enum AccountTypeColumn: String, CaseIterable, Codable, MaintenanceTableColumn {
    case name
    case code
    case description
    case isActive

    var title: String {
        switch self {
        case .name: return "Name"
        case .code: return "Code"
        case .description: return "Description"
        case .isActive: return "Active"
        }
    }

    var menuTitle: String { title }
}

private struct AccountTypeItem: Identifiable, Equatable {
    let id: Int
    let code: String
    let name: String
    let description: String
    let isActive: Bool

    var statusLabel: String { isActive ? "Active" : "Inactive" }
}

struct AccountTypesView: View {
    @EnvironmentObject var dbManager: DatabaseManager

    @State private var accountTypes: [AccountTypeItem] = []
    @State private var selectedType: AccountTypeItem? = nil
    @State private var searchText = ""
    @State private var showAddTypeSheet = false
    @State private var showEditTypeSheet = false
    @State private var showingDeleteAlert = false
    @State private var typeToDelete: AccountTypeItem? = nil

    @State private var sortColumn: SortColumn = .name
    @State private var sortAscending: Bool = true
    @State private var statusFilters: Set<String> = []
    @StateObject private var tableModel = ResizableTableViewModel<AccountTypeColumn>(configuration: AccountTypesView.tableConfiguration)

    @State private var headerOpacity: Double = 0
    @State private var contentOffset: CGFloat = 30
    @State private var buttonsOpacity: Double = 0

    private static let visibleColumnsKey = "AccountTypesView.visibleColumns.v1"

    private enum SortColumn: String, CaseIterable {
        case name
        case code
        case description
        case isActive
    }

    private static let tableConfiguration: MaintenanceTableConfiguration<AccountTypeColumn> = {
        #if os(macOS)
            MaintenanceTableConfiguration(
                preferenceKind: .accountTypes,
                columnOrder: AccountTypeColumn.allCases,
                defaultVisibleColumns: Set(AccountTypeColumn.allCases),
                requiredColumns: [.name, .code],
                defaultColumnWidths: [
                    .name: 240,
                    .code: 140,
                    .description: 360,
                    .isActive: 120,
                ],
                minimumColumnWidths: [
                    .name: 200,
                    .code: 110,
                    .description: 260,
                    .isActive: 90,
                ],
                visibleColumnsDefaultsKey: visibleColumnsKey,
                columnHandleWidth: 10,
                columnHandleHitSlop: 8,
                columnTextInset: 12,
                headerBackground: Color.indigo.opacity(0.08),
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
                preferenceKind: .accountTypes,
                columnOrder: AccountTypeColumn.allCases,
                defaultVisibleColumns: Set(AccountTypeColumn.allCases),
                requiredColumns: [.name, .code],
                defaultColumnWidths: [
                    .name: 240,
                    .code: 140,
                    .description: 360,
                    .isActive: 120,
                ],
                minimumColumnWidths: [
                    .name: 200,
                    .code: 110,
                    .description: 260,
                    .isActive: 90,
                ],
                visibleColumnsDefaultsKey: visibleColumnsKey,
                columnHandleWidth: 10,
                columnHandleHitSlop: 8,
                columnTextInset: 12,
                headerBackground: Color.indigo.opacity(0.08),
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
    private var visibleColumns: Set<AccountTypeColumn> { tableModel.visibleColumns }
    private var fontSizeBinding: Binding<MaintenanceTableFontSize> {
        Binding(
            get: { tableModel.selectedFontSize },
            set: { newValue in
                DispatchQueue.main.async {
                    tableModel.selectedFontSize = newValue
                }
            }
        )
    }

    private var filteredTypes: [AccountTypeItem] {
        var result = accountTypes

        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedQuery.isEmpty {
            let query = trimmedQuery.lowercased()
            result = result.filter { type in
                type.name.lowercased().contains(query) ||
                    type.code.lowercased().contains(query) ||
                    type.description.lowercased().contains(query)
            }
        }

        if !statusFilters.isEmpty {
            result = result.filter { statusFilters.contains($0.statusLabel) }
        }

        return result
    }

    private var sortedTypes: [AccountTypeItem] {
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
            case .isActive:
                return compareBool(lhs.isActive, rhs.isActive)
            }
        }

        return sortAscending ? sorted : Array(sorted.reversed())
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.99, blue: 1.0),
                    Color(red: 0.95, green: 0.97, blue: 0.99),
                    Color(red: 0.93, green: 0.95, blue: 0.98),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            AccountTypesParticleBackground()

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
            loadAccountTypes()
            animateEntrance()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshAccountTypes"))) { _ in
            loadAccountTypes()
        }
        .onChange(of: tableModel.visibleColumns) { _, _ in
            ensureFiltersWithinVisibleColumns()
        }
        .sheet(isPresented: $showAddTypeSheet) {
            AddAccountTypeView().environmentObject(dbManager)
        }
        .sheet(isPresented: $showEditTypeSheet) {
            if let type = selectedType {
                EditAccountTypeView(accountTypeId: type.id).environmentObject(dbManager)
            }
        }
        .alert("Delete Account Type", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { typeToDelete = nil }
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
    }

    private var modernHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    Image(systemName: "creditcard.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.indigo)

                    Text("Account Types")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.black, .gray],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }

                Text("Manage your account categories")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            Spacer()

            HStack(spacing: 16) {
                modernStatCard(
                    title: "Total",
                    value: "\(accountTypes.count)",
                    icon: "number.circle.fill",
                    color: .indigo
                )

                modernStatCard(
                    title: "Active",
                    value: "\(accountTypes.filter { $0.isActive }.count)",
                    icon: "checkmark.circle.fill",
                    color: .green
                )
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .opacity(headerOpacity)
    }

    private var searchAndStats: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)

                TextField("Search account types...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())

                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
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

            if !searchText.isEmpty || hasActiveFilters {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Found \(filteredTypes.count) of \(accountTypes.count) types")
                        .font(.caption)
                        .foregroundColor(.gray)

                    if hasActiveFilters {
                        HStack(spacing: 8) {
                            ForEach(statusFilters.sorted(), id: \.self) { value in
                                filterChip(text: value) { statusFilters.remove(value) }
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .offset(y: contentOffset)
    }

    private var typesContent: some View {
        VStack(spacing: 16) {
            tableControls
            if sortedTypes.isEmpty {
                emptyStateView
            } else {
                typesTable
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .offset(y: contentOffset)
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
            if visibleColumns != AccountTypesView.tableConfiguration.defaultVisibleColumns || selectedFontSize != .medium {
                Button("Reset View", action: resetTablePreferences)
                    .buttonStyle(.link)
            }
        }
        .padding(.horizontal, 4)
        .font(.system(size: 12))
    }

    private var columnsMenu: some View {
        Menu {
            ForEach(AccountTypeColumn.allCases, id: \.self) { column in
                let isVisible = visibleColumns.contains(column)
                Button {
                    toggleColumn(column)
                } label: {
                    Label(column.menuTitle, systemImage: isVisible ? "checkmark" : "")
                }
                .disabled(isVisible && (visibleColumns.count == 1 || AccountTypesView.tableConfiguration.requiredColumns.contains(column)))
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

    private var typesTable: some View {
        MaintenanceTableView(
            model: tableModel,
            rows: sortedTypes,
            rowSpacing: CGFloat(dbManager.tableRowSpacing),
            showHorizontalIndicators: true,
            rowContent: { type, context in
                AccountTypeRowView(
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
                accountTypeHeaderContent(for: column, fontConfig: fontConfig)
            }
        )
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            VStack(spacing: 16) {
                Image(systemName: searchText.isEmpty ? "doc.plaintext.fill" : "magnifyingglass")
                    .font(.system(size: 64))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.gray.opacity(0.5), .gray.opacity(0.3)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                VStack(spacing: 8) {
                    Text(searchText.isEmpty ? "No account types yet" : "No matching account types")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray)

                    Text(searchText.isEmpty ? "Add your first account type to classify accounts" : "Try adjusting your search or filters")
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }

                if searchText.isEmpty {
                    Button { showAddTypeSheet = true } label: {
                        Label("Add Account Type", systemImage: "plus")
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

    private var modernActionBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1)

            HStack(spacing: 16) {
                Button { showAddTypeSheet = true } label: {
                    Label("Add Account Type", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.67, green: 0.89, blue: 0.67))
                .foregroundColor(.black)

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

                if let type = selectedType {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.indigo)
                        Text("Selected: \(type.name)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.indigo.opacity(0.05))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(.regularMaterial)
        }
        .opacity(buttonsOpacity)
    }

    private func accountTypeHeaderContent(for column: AccountTypeColumn, fontConfig: MaintenanceTableFontConfig) -> some View {
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

    private func toggleColumn(_ column: AccountTypeColumn) {
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

    private var hasActiveFilters: Bool { !statusFilters.isEmpty }

    private func filterBinding(for column: AccountTypeColumn) -> Binding<Set<String>>? {
        column == .isActive ? $statusFilters : nil
    }

    private func filterOptions(for column: AccountTypeColumn) -> [String] {
        column == .isActive ? ["Active", "Inactive"] : []
    }

    private func filterChip(text: String, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.caption)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.indigo.opacity(0.12))
        .clipShape(Capsule())
    }

    private func clearFilters() {
        statusFilters.removeAll()
    }

    private func ensureFiltersWithinVisibleColumns() {
        if !visibleColumns.contains(.isActive) {
            statusFilters.removeAll()
        }
    }

    private func sortColumn(from column: AccountTypeColumn) -> SortColumn {
        switch column {
        case .name: return .name
        case .code: return .code
        case .description: return .description
        case .isActive: return .isActive
        }
    }

    private func toggleSort(for column: AccountTypeColumn) {
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

    private func loadAccountTypes() {
        let currentId = selectedType?.id
        accountTypes = dbManager.fetchAccountTypes(activeOnly: false).map { type in
            AccountTypeItem(
                id: type.id,
                code: type.code,
                name: type.name,
                description: type.description ?? "",
                isActive: type.isActive
            )
        }
        if let currentId, let match = accountTypes.first(where: { $0.id == currentId }) {
            selectedType = match
        }
    }

    private func confirmDelete(_ type: AccountTypeItem) {
        let result = dbManager.canDeleteAccountType(id: type.id)
        guard result.canDelete else {
            #if os(macOS)
                let alert = NSAlert()
                alert.messageText = "Cannot Delete Account Type"
                alert.informativeText = result.message
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
            #else
                print("⚠️ Cannot delete account type: \(result.message)")
            #endif
            typeToDelete = nil
            return
        }
        performDelete(type)
    }

    private func performDelete(_ type: AccountTypeItem) {
        let success = dbManager.deleteAccountType(id: type.id)
        if success {
            loadAccountTypes()
            selectedType = nil
            typeToDelete = nil
        }
    }

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
}

private struct AccountTypeRowView: View {
    let type: AccountTypeItem
    let columns: [AccountTypeColumn]
    let fontConfig: MaintenanceTableFontConfig
    let rowPadding: CGFloat
    let isSelected: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    let widthFor: (AccountTypeColumn) -> CGFloat

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
                .fill(isSelected ? Color.indigo.opacity(0.12) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.indigo.opacity(0.3) : Color.clear, lineWidth: 1)
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
                    NSPasteboard.general.setString(type.name, forType: .string)
                }
                Button("Copy Code") {
                    NSPasteboard.general.setString(type.code, forType: .string)
                }
            }
        #endif
            .animation(.easeInOut(duration: 0.2), value: isSelected)
    }

    @ViewBuilder
    private func columnView(for column: AccountTypeColumn) -> some View {
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
        case .isActive:
            HStack(spacing: 6) {
                Circle()
                    .fill(type.isActive ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: max(fontConfig.badge, 8), height: max(fontConfig.badge, 8))
                Text(type.statusLabel)
                    .font(.system(size: fontConfig.secondary, weight: .medium))
                    .foregroundColor(type.isActive ? .green : .secondary)
            }
            .frame(width: widthFor(.isActive), alignment: .center)
        }
    }
}

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

private struct AccountTypeParticle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var size: CGFloat
    var opacity: Double
}

private struct AccountTypesParticleBackground: View {
    @State private var particles: [AccountTypeParticle] = []

    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                Circle()
                    .fill(Color.indigo.opacity(0.03))
                    .frame(width: particle.size, height: particle.size)
                    .position(particle.position)
                    .opacity(particle.opacity)
            }
        }
        .onAppear {
            createParticles()
            animateParticles()
        }
    }

    private func createParticles() {
        particles = (0 ..< 15).map { _ in
            AccountTypeParticle(
                position: CGPoint(x: CGFloat.random(in: 0 ... 1200), y: CGFloat.random(in: 0 ... 800)),
                size: CGFloat.random(in: 2 ... 8),
                opacity: Double.random(in: 0.1 ... 0.2)
            )
        }
    }

    private func animateParticles() {
        withAnimation(.linear(duration: 30).repeatForever(autoreverses: false)) {
            for index in particles.indices {
                particles[index].position.y -= 1000
                particles[index].opacity = Double.random(in: 0.05 ... 0.15)
            }
        }
    }
}

struct AccountTypesView_Previews: PreviewProvider {
    static var previews: some View {
        AccountTypesView().environmentObject(DatabaseManager())
    }
}
