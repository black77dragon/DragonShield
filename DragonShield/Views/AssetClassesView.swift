import SwiftUI
#if os(macOS)
    import AppKit
#endif

private enum AssetClassColumn: String, CaseIterable, Codable, MaintenanceTableColumn {
    case code
    case name
    case description

    var title: String {
        switch self {
        case .code: return "Code"
        case .name: return "Name"
        case .description: return "Description"
        }
    }

    var menuTitle: String { title }
}

private struct AssetClassItem: Identifiable, Equatable {
    let id: Int
    let code: String
    let name: String
    let description: String
}

struct AssetClassesView: View {
    @EnvironmentObject var dbManager: DatabaseManager

    @State private var assetClasses: [AssetClassItem] = []
    @State private var selectedClass: AssetClassItem? = nil
    @State private var searchText = ""
    @State private var showAddSheet = false
    @State private var showEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var classToDelete: AssetClassItem? = nil
    @State private var deletionInfo: (canDelete: Bool, subClassCount: Int, instrumentCount: Int, positionReportCount: Int)? = nil

    @State private var sortColumn: SortColumn = .name
    @State private var sortAscending: Bool = true
    @StateObject private var tableModel = ResizableTableViewModel<AssetClassColumn>(configuration: AssetClassesView.tableConfiguration)

    @State private var headerOpacity: Double = 0
    @State private var contentOffset: CGFloat = 30
    @State private var buttonsOpacity: Double = 0

    private static let visibleColumnsKey = "AssetClassesView.visibleColumns.v2"
    fileprivate static let columnTextInset: CGFloat = DSLayout.spaceS

    private enum SortColumn: String, CaseIterable {
        case code
        case name
        case description
    }

    private static let tableConfiguration: MaintenanceTableConfiguration<AssetClassColumn> = {
        #if os(macOS)
            MaintenanceTableConfiguration(
                preferenceKind: .assetClasses,
                columnOrder: AssetClassColumn.allCases,
                defaultVisibleColumns: Set(AssetClassColumn.allCases),
                requiredColumns: [.name, .code],
                defaultColumnWidths: [
                    .code: 140,
                    .name: 260,
                    .description: 420
                ],
                minimumColumnWidths: [
                    .code: 110,
                    .name: 220,
                    .description: 300
                ],
                visibleColumnsDefaultsKey: visibleColumnsKey,
                columnHandleWidth: 10,
                columnHandleHitSlop: 8,
                columnTextInset: columnTextInset,
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
                preferenceKind: .assetClasses,
                columnOrder: AssetClassColumn.allCases,
                defaultVisibleColumns: Set(AssetClassColumn.allCases),
                requiredColumns: [.name, .code],
                defaultColumnWidths: [
                    .code: 140,
                    .name: 260,
                    .description: 420
                ],
                minimumColumnWidths: [
                    .code: 110,
                    .name: 220,
                    .description: 300
                ],
                visibleColumnsDefaultsKey: visibleColumnsKey,
                columnHandleWidth: 10,
                columnHandleHitSlop: 8,
                columnTextInset: columnTextInset,
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
    private var visibleColumns: Set<AssetClassColumn> { tableModel.visibleColumns }
    private var fontSizeBinding: Binding<MaintenanceTableFontSize> {
        Binding(
            get: { tableModel.selectedFontSize },
            set: { tableModel.selectedFontSize = $0 }
        )
    }

    private var filteredClasses: [AssetClassItem] {
        var result = assetClasses
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedQuery.isEmpty {
            let query = trimmedQuery.lowercased()
            result = result.filter { item in
                item.name.lowercased().contains(query) ||
                    item.code.lowercased().contains(query) ||
                    item.description.lowercased().contains(query)
            }
        }
        return result
    }

    private var sortedClasses: [AssetClassItem] {
        let base = filteredClasses
        guard base.count > 1 else { return base }

        let sorted = base.sorted { lhs, rhs in
            switch sortColumn {
            case .code:
                return compare(lhs.code, rhs.code)
            case .name:
                return compare(lhs.name, rhs.name)
            case .description:
                return compare(lhs.description, rhs.description)
            }
        }

        return sortAscending ? sorted : Array(sorted.reversed())
    }

    var body: some View {
        ZStack {
            DSColor.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                modernHeader
                searchAndStats
                classesContent
                modernActionBar
            }
        }
        .onAppear {
            tableModel.connect(to: dbManager)
            tableModel.recalcColumnWidths(shouldPersist: false)
            loadAssetClasses()
            animateEntrance()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshAssetClasses"))) { _ in
            loadAssetClasses()
        }
        .sheet(isPresented: $showAddSheet) {
            AddAssetClassView().environmentObject(dbManager)
        }
        .sheet(isPresented: $showEditSheet) {
            if let item = selectedClass {
                EditAssetClassView(classId: item.id).environmentObject(dbManager)
            }
        }
        .alert("Delete Asset Class", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {
                classToDelete = nil
                deletionInfo = nil
            }
            if let info = deletionInfo, !info.canDelete {
                Button("Purge & Delete", role: .destructive) {
                    if let item = classToDelete {
                        purgeAndDelete(item)
                    }
                }
            } else {
                Button("Delete", role: .destructive) {
                    if let item = classToDelete {
                        performDelete(item)
                    }
                }
            }
        } message: {
            if let item = classToDelete, let info = deletionInfo {
                if info.canDelete {
                    Text("Are you sure you want to delete \(item.name)?")
                } else {
                    Text("\(item.name) has \(info.subClassCount) subclass(es), \(info.instrumentCount) instrument(s), and \(info.positionReportCount) position report(s). Purge related data before deleting?")
                }
            }
        }
    }

    private var modernHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: DSLayout.spaceXS) {
                HStack(spacing: DSLayout.spaceM) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 32))
                        .foregroundColor(DSColor.accentMain)

                    Text("Asset Classes")
                        .dsHeaderLarge()
                        .foregroundColor(DSColor.textPrimary)
                }

                Text("Manage your high-level asset categories")
                    .dsBody()
                    .foregroundColor(DSColor.textSecondary)
            }

            Spacer()

            HStack(spacing: DSLayout.spaceL) {
                modernStatCard(
                    title: "Total",
                    value: "\(assetClasses.count)",
                    icon: "number.circle.fill",
                    color: DSColor.accentMain
                )
            }
        }
        .padding(.horizontal, DSLayout.spaceL)
        .padding(.vertical, DSLayout.spaceL)
        .opacity(headerOpacity)
    }

    private var searchAndStats: some View {
        VStack(spacing: DSLayout.spaceM) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(DSColor.textSecondary)

                TextField("Search asset classes...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.ds.body)

                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(DSColor.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DSLayout.spaceM)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: DSLayout.radiusM)
                    .fill(DSColor.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: DSLayout.radiusM)
                            .stroke(DSColor.border, lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)

            if !searchText.isEmpty {
                HStack {
                    Text("Found \(filteredClasses.count) of \(assetClasses.count) classes")
                        .dsCaption()
                        .foregroundColor(DSColor.textSecondary)
                    Spacer()
                }
            }
        }
        .padding(.horizontal, DSLayout.spaceL)
        .offset(y: contentOffset)
    }

    private var classesContent: some View {
        VStack(spacing: DSLayout.spaceM) {
            tableControls
            if sortedClasses.isEmpty {
                emptyStateView
            } else {
                classesTable
            }
        }
        .padding(.horizontal, DSLayout.spaceL)
        .padding(.top, DSLayout.spaceS)
        .offset(y: contentOffset)
    }

    private var tableControls: some View {
        HStack(spacing: DSLayout.spaceM) {
            columnsMenu
            fontSizePicker
            Spacer()
            if visibleColumns != AssetClassesView.tableConfiguration.defaultVisibleColumns || selectedFontSize != .medium {
                Button("Reset View", action: resetTablePreferences)
                    .buttonStyle(.link)
                    .font(.ds.caption)
            }
        }
        .padding(.horizontal, 4)
    }

    private var columnsMenu: some View {
        Menu {
            ForEach(AssetClassColumn.allCases, id: \.self) { column in
                let isVisible = visibleColumns.contains(column)
                Button {
                    tableModel.toggleColumn(column)
                } label: {
                    Label(column.menuTitle, systemImage: isVisible ? "checkmark" : "")
                }
                .disabled(isVisible && (visibleColumns.count == 1 || AssetClassesView.tableConfiguration.requiredColumns.contains(column)))
            }
            Divider()
            Button("Reset Columns", action: resetVisibleColumns)
        } label: {
            Label("Columns", systemImage: "slider.horizontal.3")
                .font(.ds.caption)
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

    private var classesTable: some View {
        MaintenanceTableView(
            model: tableModel,
            rows: sortedClasses,
            rowSpacing: DSLayout.tableRowSpacing,
            showHorizontalIndicators: true,
            rowContent: { assetClass, context in
                AssetClassRowView(
                    assetClass: assetClass,
                    columns: context.columns,
                    fontConfig: context.fontConfig,
                    rowPadding: DSLayout.tableRowPadding,
                    isSelected: selectedClass?.id == assetClass.id,
                    onTap: { selectedClass = assetClass },
                    onEdit: {
                        selectedClass = assetClass
                        showEditSheet = true
                    },
                    widthFor: { context.widthForColumn($0) }
                )
            },
            headerContent: { column, fontConfig in
                assetClassHeaderContent(for: column, fontConfig: fontConfig)
            }
        )
    }

    private var emptyStateView: some View {
        VStack(spacing: DSLayout.spaceL) {
            Spacer()
            VStack(spacing: DSLayout.spaceM) {
                Image(systemName: searchText.isEmpty ? "folder" : "magnifyingglass")
                    .font(.system(size: 64))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [DSColor.textTertiary, DSColor.textTertiary.opacity(0.5)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                VStack(spacing: DSLayout.spaceS) {
                    Text(searchText.isEmpty ? "No asset classes yet" : "No matching asset classes")
                        .dsHeaderMedium()
                        .foregroundColor(DSColor.textSecondary)

                    Text(searchText.isEmpty ? "Add your first asset class to categorize your assets" : "Try adjusting your search.")
                        .dsBody()
                        .foregroundColor(DSColor.textTertiary)
                        .multilineTextAlignment(.center)
                }

                if searchText.isEmpty {
                    Button { showAddSheet = true } label: {
                        Label("Add Asset Class", systemImage: "plus")
                    }
                    .buttonStyle(DSButtonStyle(type: .primary))
                    .padding(.top, DSLayout.spaceS)
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var modernActionBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(DSColor.border)
                .frame(height: 1)

            HStack(spacing: DSLayout.spaceM) {
                Button { showAddSheet = true } label: {
                    Label("Add Asset Class", systemImage: "plus")
                }
                .buttonStyle(DSButtonStyle(type: .primary))

                if selectedClass != nil {
                    Button {
                        showEditSheet = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .buttonStyle(DSButtonStyle(type: .secondary))

                    Button {
                        if let assetClass = selectedClass {
                            classToDelete = assetClass
                            deletionInfo = dbManager.canDeleteAssetClass(id: assetClass.id)
                            showingDeleteAlert = true
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .buttonStyle(DSButtonStyle(type: .destructive))
                }

                Spacer()

                if let assetClass = selectedClass {
                    HStack(spacing: DSLayout.spaceS) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(DSColor.accentMain)
                        Text("Selected: \(assetClass.name)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(DSColor.textSecondary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(DSColor.surfaceSecondary)
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, DSLayout.spaceL)
            .padding(.vertical, DSLayout.spaceL - DSLayout.spaceS)
            .background(DSColor.surface)
        }
        .opacity(buttonsOpacity)
    }

    private func assetClassHeaderContent(for column: AssetClassColumn, fontConfig: MaintenanceTableFontConfig) -> some View {
        let targetSort = sortColumn(from: column)
        let isActiveSort = sortColumn == targetSort

        return Button(action: { toggleSort(for: column) }) {
            HStack(spacing: 4) {
                Text(column.title)
                    .font(.system(size: fontConfig.header, weight: .semibold))
                    .foregroundColor(DSColor.textPrimary)
                Image(systemName: "triangle.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(isActiveSort ? DSColor.accentMain : DSColor.textTertiary)
                    .rotationEffect(.degrees(isActiveSort && !sortAscending ? 180 : 0))
                    .opacity(isActiveSort ? 1 : 0)
            }
        }
        .buttonStyle(.plain)
    }

    private func resetVisibleColumns() {
        tableModel.resetVisibleColumns()
    }

    private func resetTablePreferences() {
        tableModel.resetTablePreferences()
    }

    private func sortColumn(from column: AssetClassColumn) -> SortColumn {
        switch column {
        case .code: return .code
        case .name: return .name
        case .description: return .description
        }
    }

    private func toggleSort(for column: AssetClassColumn) {
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

    private func loadAssetClasses() {
        let currentId = selectedClass?.id
        assetClasses = dbManager.fetchAssetClassesDetailed().map { data in
            AssetClassItem(
                id: data.id,
                code: data.code,
                name: data.name,
                description: data.description ?? ""
            )
        }
        if let currentId, let match = assetClasses.first(where: { $0.id == currentId }) {
            selectedClass = match
        } else if selectedClass != nil {
            selectedClass = nil
        }
    }

    private func performDelete(_ assetClass: AssetClassItem) {
        let success = dbManager.deleteAssetClass(id: assetClass.id)
        if success {
            loadAssetClasses()
            selectedClass = nil
            classToDelete = nil
            deletionInfo = nil
        }
    }

    private func purgeAndDelete(_ assetClass: AssetClassItem) {
        let purged = dbManager.purgeAssetClass(id: assetClass.id)
        guard purged else { return }
        let info = dbManager.canDeleteAssetClass(id: assetClass.id)
        deletionInfo = info
        if info.canDelete {
            performDelete(assetClass)
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

private struct AssetClassRowView: View {
    let assetClass: AssetClassItem
    let columns: [AssetClassColumn]
    let fontConfig: MaintenanceTableFontConfig
    let rowPadding: CGFloat
    let isSelected: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    let widthFor: (AssetClassColumn) -> CGFloat

    var body: some View {
        HStack(spacing: 0) {
            ForEach(columns, id: \.self) { column in
                columnView(for: column)
            }
        }
        .padding(.trailing, 12)
        .padding(.vertical, max(rowPadding, 8))
        .background(
            Rectangle()
                .fill(isSelected ? DSColor.surfaceHighlight : Color.clear)
                .overlay(
                    Rectangle()
                        .stroke(isSelected ? DSColor.accentMain.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        )
        .overlay(
            Rectangle()
                .fill(DSColor.border)
                .frame(height: 1),
            alignment: .bottom
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .onTapGesture(count: 2) { onEdit() }
        #if os(macOS)
            .contextMenu {
                Button("Edit", action: onEdit)
                Button("Select", action: onTap)
                Divider()
                Button("Copy Name") {
                    NSPasteboard.general.setString(assetClass.name, forType: .string)
                }
                Button("Copy Code") {
                    NSPasteboard.general.setString(assetClass.code, forType: .string)
                }
            }
        #endif
            .animation(.easeInOut(duration: 0.2), value: isSelected)
    }

    @ViewBuilder
    private func columnView(for column: AssetClassColumn) -> some View {
        switch column {
        case .code:
            Text(assetClass.code)
                .font(.system(size: fontConfig.secondary, design: .monospaced))
                .foregroundColor(DSColor.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(DSColor.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: DSLayout.radiusS))
                .padding(.leading, AssetClassesView.columnTextInset)
                .padding(.trailing, 8)
                .frame(width: widthFor(.code), alignment: .leading)
        case .name:
            Text(assetClass.name)
                .font(.system(size: fontConfig.primary, weight: .medium))
                .foregroundColor(DSColor.textPrimary)
                .padding(.leading, AssetClassesView.columnTextInset)
                .padding(.trailing, 8)
                .frame(width: widthFor(.name), alignment: .leading)
        case .description:
            Text(assetClass.description)
                .font(.system(size: fontConfig.secondary))
                .foregroundColor(DSColor.textSecondary)
                .lineLimit(2)
                .padding(.leading, AssetClassesView.columnTextInset)
                .padding(.trailing, 8)
                .frame(width: widthFor(.description), alignment: .leading)
        }
    }
}

// MARK: - Add Asset Class View

struct AddAssetClassView: View {
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject var dbManager: DatabaseManager

    @State private var code = ""
    @State private var name = ""
    @State private var description = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false

    @State private var formScale: CGFloat = 0.9
    @State private var headerOpacity: Double = 0
    @State private var sectionsOffset: CGFloat = 50

    private var isValid: Bool {
        !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            DSColor.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                addHeader
                addContent
            }
        }
        .frame(width: 560, height: 460)
        .clipShape(RoundedRectangle(cornerRadius: DSLayout.radiusL))
        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
        .scaleEffect(formScale)
        .onAppear { animateEntrance() }
        .alert("Result", isPresented: $showingAlert) {
            Button("OK") {
                if alertMessage.hasPrefix("✅") {
                    animateExit()
                }
            }
        } message: {
            Text(alertMessage)
        }
    }

    private var addHeader: some View {
        HStack {
            Button { animateExit() } label: {
                Image(systemName: "xmark")
                    .foregroundColor(DSColor.textSecondary)
                    .padding(8)
                    .background(DSColor.surfaceSecondary)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: DSLayout.spaceS) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 24))
                    .foregroundColor(DSColor.accentMain)

                Text("Add Asset Class")
                    .dsHeaderLarge()
                    .foregroundColor(DSColor.textPrimary)
            }

            Spacer()

            Button { save() } label: {
                HStack(spacing: DSLayout.spaceS) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                    }

                    Text(isLoading ? "Saving..." : "Save")
                        .dsBodySmall()
                        .fontWeight(.semibold)
                }
            }
            .buttonStyle(DSButtonStyle(type: .primary))
            .disabled(!isValid || isLoading)
        }
        .padding(.horizontal, DSLayout.spaceL)
        .padding(.vertical, DSLayout.spaceL)
        .opacity(headerOpacity)
    }

    private var addContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSLayout.spaceL) {
                VStack(alignment: .leading, spacing: DSLayout.spaceM) {
                    sectionHeader(title: "Class Information", icon: "folder.fill", color: DSColor.accentMain)
                    VStack(spacing: DSLayout.spaceM) {
                        modernTextField(title: "Class Code", text: $code, placeholder: "e.g., EQTY", icon: "number", isRequired: true, autoUppercase: true)
                        modernTextField(title: "Class Name", text: $name, placeholder: "e.g., Equity", icon: "textformat", isRequired: true)
                        modernTextField(title: "Description", text: $description, placeholder: "Optional", icon: "text.justify")
                    }
                }
                .padding(DSLayout.spaceM)
                .background(DSColor.surface)
                .cornerRadius(DSLayout.radiusM)
                .overlay(RoundedRectangle(cornerRadius: DSLayout.radiusM).stroke(DSColor.border, lineWidth: 1))
            }
            .padding(.horizontal, DSLayout.spaceL)
            .padding(.bottom, DSLayout.spaceL)
        }
        .offset(y: sectionsOffset)
    }

    private func save() {
        guard isValid else { return }
        isLoading = true
        let ok = dbManager.addAssetClass(
            code: code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        isLoading = false
        if ok {
            NotificationCenter.default.post(name: NSNotification.Name("RefreshAssetClasses"), object: nil)
            alertMessage = "✅ Asset class added"
            showingAlert = true
        } else {
            alertMessage = "❌ Failed to add asset class"
            showingAlert = true
        }
    }

    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: DSLayout.spaceM) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
            Text(title)
                .dsHeaderSmall()
                .foregroundColor(DSColor.textPrimary)
            Spacer()
        }
    }

    private func modernTextField(title: String, text: Binding<String>, placeholder: String, icon: String, isRequired: Bool = false, autoUppercase: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: DSLayout.spaceXS) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(DSColor.textSecondary)
                Text(title + (isRequired ? "*" : ""))
                    .dsBodySmall()
                    .foregroundColor(DSColor.textSecondary)
                Spacer()
            }

            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .padding(DSLayout.spaceS)
                .background(DSColor.surfaceSecondary)
                .cornerRadius(DSLayout.radiusS)
                .overlay(
                    RoundedRectangle(cornerRadius: DSLayout.radiusS)
                        .stroke(DSColor.border, lineWidth: 1)
                )
                .onChange(of: text.wrappedValue) { _, newValue in
                    if autoUppercase {
                        text.wrappedValue = newValue.uppercased()
                    }
                }
        }
    }

    private func animateEntrance() {
        withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) { formScale = 1.0 }
        withAnimation(.easeOut(duration: 0.6).delay(0.2)) { headerOpacity = 1.0 }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4)) { sectionsOffset = 0 }
    }

    private func animateExit() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            formScale = 0.9
            headerOpacity = 0
            sectionsOffset = 50
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - Edit Asset Class View

struct EditAssetClassView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dbManager: DatabaseManager
    let classId: Int

    @State private var code = ""
    @State private var name = ""
    @State private var description = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false

    @State private var formScale: CGFloat = 0.9
    @State private var headerOpacity: Double = 0
    @State private var sectionsOffset: CGFloat = 50
    @State private var hasChanges = false
    @State private var originalCode = ""
    @State private var originalName = ""
    @State private var originalDescription = ""

    private var isValid: Bool {
        !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            DSColor.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                editHeader
                editContent
            }
        }
        .frame(width: 580, height: 480)
        .clipShape(RoundedRectangle(cornerRadius: DSLayout.radiusL))
        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
        .scaleEffect(formScale)
        .onAppear {
            loadData()
            animateEntrance()
        }
        .alert("Result", isPresented: $showingAlert) {
            Button("OK") { showingAlert = false }
        } message: {
            Text(alertMessage)
        }
        .onChange(of: code) { _, _ in detectChanges() }
        .onChange(of: name) { _, _ in detectChanges() }
        .onChange(of: description) { _, _ in detectChanges() }
    }

    private var editHeader: some View {
        HStack {
            Button { animateExit() } label: {
                Image(systemName: "xmark")
                    .foregroundColor(DSColor.textSecondary)
                    .padding(8)
                    .background(DSColor.surfaceSecondary)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: DSLayout.spaceS) {
                Image(systemName: "folder.badge.gearshape")
                    .font(.system(size: 24))
                    .foregroundColor(DSColor.accentWarning)

                Text("Edit Asset Class")
                    .dsHeaderLarge()
                    .foregroundColor(DSColor.textPrimary)
            }

            Spacer()

            Button { save() } label: {
                HStack(spacing: DSLayout.spaceS) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: hasChanges ? "checkmark.circle.fill" : "checkmark")
                            .font(.system(size: 14, weight: .bold))
                    }

                    Text(isLoading ? "Saving..." : "Save Changes")
                        .dsBodySmall()
                        .fontWeight(.semibold)
                }
            }
            .buttonStyle(DSButtonStyle(type: .primary))
            .disabled(!isValid || !hasChanges || isLoading)
        }
        .padding(.horizontal, DSLayout.spaceL)
        .padding(.vertical, DSLayout.spaceL)
        .opacity(headerOpacity)
    }

    private var editContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSLayout.spaceL) {
                VStack(alignment: .leading, spacing: DSLayout.spaceM) {
                    sectionHeader(title: "Class Information", icon: "folder.fill", color: DSColor.accentWarning)
                    VStack(spacing: DSLayout.spaceM) {
                        modernTextField(title: "Class Code", text: $code, placeholder: "e.g., EQTY", icon: "number", isRequired: true, autoUppercase: true)
                        modernTextField(title: "Class Name", text: $name, placeholder: "e.g., Equity", icon: "textformat", isRequired: true)
                        modernTextField(title: "Description", text: $description, placeholder: "", icon: "text.justify")
                    }
                }
                .padding(DSLayout.spaceM)
                .background(DSColor.surface)
                .cornerRadius(DSLayout.radiusM)
                .overlay(RoundedRectangle(cornerRadius: DSLayout.radiusM).stroke(DSColor.border, lineWidth: 1))
            }
            .padding(.horizontal, DSLayout.spaceL)
            .padding(.bottom, DSLayout.spaceL)
        }
        .offset(y: sectionsOffset)
    }

    private func loadData() {
        guard let data = dbManager.fetchAssetClassDetails(id: classId) else { return }
        code = data.code
        name = data.name
        description = data.description ?? ""
        originalCode = code
        originalName = name
        originalDescription = description
        detectChanges()
    }

    private func detectChanges() {
        hasChanges = code != originalCode ||
            name != originalName ||
            description != originalDescription
    }

    private func save() {
        guard isValid, hasChanges else { return }
        isLoading = true
        let ok = dbManager.updateAssetClass(
            id: classId,
            code: code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        isLoading = false
        if ok {
            NotificationCenter.default.post(name: NSNotification.Name("RefreshAssetClasses"), object: nil)
            animateExit()
        } else {
            alertMessage = "❌ Failed to update asset class"
            showingAlert = true
        }
    }

    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: DSLayout.spaceM) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
            Text(title)
                .dsHeaderSmall()
                .foregroundColor(DSColor.textPrimary)
            Spacer()
        }
    }

    private func modernTextField(title: String, text: Binding<String>, placeholder: String, icon: String, isRequired: Bool = false, autoUppercase: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: DSLayout.spaceXS) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(DSColor.textSecondary)
                Text(title + (isRequired ? "*" : ""))
                    .dsBodySmall()
                    .foregroundColor(DSColor.textSecondary)
                Spacer()
            }

            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .padding(DSLayout.spaceS)
                .background(DSColor.surfaceSecondary)
                .cornerRadius(DSLayout.radiusS)
                .overlay(
                    RoundedRectangle(cornerRadius: DSLayout.radiusS)
                        .stroke(DSColor.border, lineWidth: 1)
                )
                .onChange(of: text.wrappedValue) { _, newValue in
                    if autoUppercase {
                        text.wrappedValue = newValue.uppercased()
                    }
                }
        }
    }

    private func animateEntrance() {
        withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) { formScale = 1.0 }
        withAnimation(.easeOut(duration: 0.6).delay(0.2)) { headerOpacity = 1.0 }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4)) { sectionsOffset = 0 }
    }

    private func animateExit() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            formScale = 0.9
            headerOpacity = 0
            sectionsOffset = 50
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            dismiss()
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
                .dsCaption()
                .foregroundColor(DSColor.textSecondary)
        }

        Text(value)
            .font(.system(size: 18, weight: .bold))
            .foregroundColor(DSColor.textPrimary)
    }
    .padding(.horizontal, DSLayout.spaceM)
    .padding(.vertical, DSLayout.spaceS)
    .background(
        RoundedRectangle(cornerRadius: DSLayout.radiusM)
            .fill(DSColor.surface)
            .overlay(
                RoundedRectangle(cornerRadius: DSLayout.radiusM)
                    .stroke(DSColor.border, lineWidth: 1)
            )
    )
    .shadow(color: color.opacity(0.08), radius: 3, x: 0, y: 1)
}

struct AssetClassesView_Previews: PreviewProvider {
    static var previews: some View {
        AssetClassesView().environmentObject(DatabaseManager())
    }
}
