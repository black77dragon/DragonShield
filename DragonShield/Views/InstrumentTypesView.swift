// DragonShield/Views/AssetSubClassesView.swift
// MARK: - Version 1.3
// - 1.2 -> 1.3: Harmonized with the DragonShield Design System (DS-004).

import SwiftUI
#if os(macOS)
    import AppKit
#endif
import UniformTypeIdentifiers

private enum AssetSubClassColumn: String, CaseIterable, Codable, MaintenanceTableColumn {
    case name
    case assetClass
    case code
    case description
    case status

    var title: String {
        switch self {
        case .name: return "Name"
        case .assetClass: return "Asset Class"
        case .code: return "Code"
        case .description: return "Description"
        case .status: return "Status"
        }
    }

    var menuTitle: String { title }
}

private struct AssetSubClass: Identifiable, Equatable {
    let id: Int
    let classId: Int
    let classDescription: String
    let code: String
    let name: String
    let description: String
    let isActive: Bool
}

struct AssetSubClassesView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @State private var subClasses: [AssetSubClass] = []
    @State private var showAddTypeSheet = false
    @State private var showEditTypeSheet = false
    @State private var selectedSubClass: AssetSubClass? = nil
    @State private var showDeleteResultAlert = false
    @State private var deleteResultMessage = ""
    @State private var showDeleteSuccessToast = false
    @State private var showExportErrorAlert = false
    @State private var exportErrorMessage = ""
    @State private var showExportSuccessToast = false
    @State private var exportToastMessage = ""
    @State private var searchText = ""
    @State private var sortColumn: AssetSubClassColumn = .name
    @State private var sortAscending: Bool = true

    @StateObject private var tableModel = ResizableTableViewModel<AssetSubClassColumn>(configuration: AssetSubClassesView.tableConfiguration)

    @State private var headerOpacity: Double = 0
    @State private var contentOffset: CGFloat = 30
    @State private var buttonsOpacity: Double = 0

    private static let tableConfiguration: MaintenanceTableConfiguration<AssetSubClassColumn> = {
        #if os(macOS)
            MaintenanceTableConfiguration(
                preferenceKind: .assetSubClasses,
                columnOrder: AssetSubClassColumn.allCases,
                defaultVisibleColumns: Set(AssetSubClassColumn.allCases),
                requiredColumns: [.name],
                defaultColumnWidths: [
                    .name: 220,
                    .assetClass: 220,
                    .code: 120,
                    .description: 280,
                    .status: 120,
                ],
                minimumColumnWidths: [
                    .name: 180,
                    .assetClass: 160,
                    .code: 100,
                    .description: 220,
                    .status: 100,
                ],
                visibleColumnsDefaultsKey: "AssetSubClassesView.visibleColumns.v1",
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
                preferenceKind: .assetSubClasses,
                columnOrder: AssetSubClassColumn.allCases,
                defaultVisibleColumns: Set(AssetSubClassColumn.allCases),
                requiredColumns: [.name],
                defaultColumnWidths: [
                    .name: 220,
                    .assetClass: 220,
                    .code: 120,
                    .description: 280,
                    .status: 120,
                ],
                minimumColumnWidths: [
                    .name: 180,
                    .assetClass: 160,
                    .code: 100,
                    .description: 220,
                    .status: 100,
                ],
                visibleColumnsDefaultsKey: "AssetSubClassesView.visibleColumns.v1",
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

    private var visibleColumns: Set<AssetSubClassColumn> { tableModel.visibleColumns }
    private var selectedFontSize: MaintenanceTableFontSize { tableModel.selectedFontSize }
    private var fontSizeBinding: Binding<MaintenanceTableFontSize> {
        Binding(
            get: { tableModel.selectedFontSize },
            set: { tableModel.selectedFontSize = $0 }
        )
    }

    private var filteredSubClasses: [AssetSubClass] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let base: [AssetSubClass]
        if trimmed.isEmpty {
            base = subClasses
        } else {
            let query = trimmed.lowercased()
            base = subClasses.filter { type in
                type.name.lowercased().contains(query) ||
                    type.code.lowercased().contains(query) ||
                    type.description.lowercased().contains(query) ||
                    type.classDescription.lowercased().contains(query)
            }
        }

        return base
    }

    private var sortedSubClasses: [AssetSubClass] {
        let sorted = filteredSubClasses.sorted { lhs, rhs in
            switch sortColumn {
            case .name:
                let cmp = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
                if cmp != .orderedSame { return cmp == .orderedAscending }
                return lhs.classDescription.localizedCaseInsensitiveCompare(rhs.classDescription) == .orderedAscending
            case .assetClass:
                let cmp = lhs.classDescription.localizedCaseInsensitiveCompare(rhs.classDescription)
                if cmp != .orderedSame { return cmp == .orderedAscending }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            case .code:
                let lhsCode = lhs.code.uppercased()
                let rhsCode = rhs.code.uppercased()
                if lhsCode != rhsCode { return lhsCode < rhsCode }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            case .description:
                let cmp = lhs.description.localizedCaseInsensitiveCompare(rhs.description)
                if cmp != .orderedSame { return cmp == .orderedAscending }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            case .status:
                if lhs.isActive == rhs.isActive {
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
                return lhs.isActive && !rhs.isActive
            }
        }
        return sortAscending ? sorted : Array(sorted.reversed())
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
            loadSubClasses()
            ensureValidSortColumn()
            animateEntrance()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshAssetSubClasses"))) { _ in
            loadSubClasses()
        }
        .onChange(of: tableModel.visibleColumns) { _, _ in
            ensureValidSortColumn()
        }
        .sheet(isPresented: $showAddTypeSheet) {
            AddAssetSubClassView().environmentObject(dbManager)
        }
        .sheet(isPresented: $showEditTypeSheet) {
            if let type = selectedSubClass {
                EditAssetSubClassView(typeId: type.id).environmentObject(dbManager)
            }
        }
        .alert("Delete Failed", isPresented: $showDeleteResultAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteResultMessage)
        }
        .alert("Export Failed", isPresented: $showExportErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportErrorMessage)
        }
        .toast(isPresented: $showDeleteSuccessToast, message: "Asset subclass deleted")
        .toast(isPresented: $showExportSuccessToast, message: exportToastMessage.isEmpty ? "Instrument types exported" : exportToastMessage)
    }

    private var headerSection: some View {
        HStack(alignment: .center, spacing: DSLayout.spaceM) {
            VStack(alignment: .leading, spacing: DSLayout.spaceXS) {
                HStack(spacing: DSLayout.spaceS) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(DSColor.accentMain)
                    Text("Instrument Types")
                        .dsHeaderLarge()
                }

                Text("Organize instrument types (asset subclasses) and link them to asset classes.")
                    .dsBody()
                    .foregroundColor(DSColor.textSecondary)
            }

            Spacer()

            HStack(spacing: DSLayout.spaceS) {
                statPill(title: "Total", value: "\(subClasses.count)", color: DSColor.textSecondary)
                statPill(title: "Active", value: "\(subClasses.filter { $0.isActive }.count)", color: DSColor.accentSuccess)
                statPill(title: "Inactive", value: "\(subClasses.filter { !$0.isActive }.count)", color: DSColor.accentWarning)
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
                    if visibleColumns != AssetSubClassesView.tableConfiguration.defaultVisibleColumns || selectedFontSize != .medium {
                        Button("Reset View", action: resetTablePreferences)
                            .buttonStyle(DSButtonStyle(type: .ghost, size: .small))
                    }
                }

                if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Showing \(filteredSubClasses.count) of \(subClasses.count) types")
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

            TextField("Search instrument types", text: $searchText)
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
                if filteredSubClasses.isEmpty {
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
            rows: sortedSubClasses,
            rowSpacing: CGFloat(dbManager.tableRowSpacing),
            showHorizontalIndicators: true,
            rowContent: { type, context in
                AssetSubClassRowView(
                    type: type,
                    columns: context.columns,
                    fontConfig: context.fontConfig,
                    rowPadding: CGFloat(dbManager.tableRowPadding),
                    isSelected: selectedSubClass?.id == type.id,
                    onTap: {
                        selectedSubClass = type
                    },
                    onEdit: {
                        selectedSubClass = type
                        showEditTypeSheet = true
                    },
                    widthFor: { context.widthForColumn($0) }
                )
            },
            headerContent: { column, fontConfig in
                assetSubClassHeaderContent(for: column, fontConfig: fontConfig)
            }
        )
    }

    private func assetSubClassHeaderContent(for column: AssetSubClassColumn, fontConfig: MaintenanceTableFontConfig) -> some View {
        let sortOption = sortOption(for: column)
        let isActiveSort = sortOption.map { $0 == sortColumn } ?? false

        return HStack(spacing: DSLayout.spaceXS) {
            if let sortOption {
                Button {
                    if isActiveSort {
                        sortAscending.toggle()
                    } else {
                        sortColumn = sortOption
                        sortAscending = true
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(column.title)
                            .font(.system(size: fontConfig.header, weight: .semibold))
                            .foregroundColor(DSColor.textPrimary)
                        if isActiveSort {
                            Image(systemName: "triangle.fill")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(DSColor.accentMain)
                                .rotationEffect(.degrees(sortAscending ? 0 : 180))
                        }
                    }
                }
                .buttonStyle(.plain)
            } else {
                Text(column.title)
                    .font(.system(size: fontConfig.header, weight: .semibold))
                    .foregroundColor(DSColor.textPrimary)
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: DSLayout.spaceM) {
            Image(systemName: searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "tray" : "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(DSColor.textSecondary)

            VStack(spacing: DSLayout.spaceXS) {
                Text(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "No instrument types yet" : "No matches found")
                    .dsHeaderSmall()
                    .foregroundColor(DSColor.textPrimary)

                Text(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?
                    "Create your first instrument type to classify instruments." :
                    "Adjust your search terms or clear filters.")
                    .dsBody()
                    .foregroundColor(DSColor.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button { showAddTypeSheet = true } label: {
                    Label("Add Instrument Type", systemImage: "plus")
                }
                .buttonStyle(DSButtonStyle(type: .primary))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 220)
    }

    private var actionBar: some View {
        DSCard {
            HStack(spacing: DSLayout.spaceS) {
                Button { showAddTypeSheet = true } label: {
                    Label("Add Instrument Type", systemImage: "plus")
                }
                .buttonStyle(DSButtonStyle(type: .primary))

                Button {
                    if selectedSubClass != nil {
                        showEditTypeSheet = true
                    }
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .buttonStyle(DSButtonStyle(type: .secondary))
                .disabled(selectedSubClass == nil)

                Button {
                    if let type = selectedSubClass {
                        handleDelete(type)
                    }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .buttonStyle(DSButtonStyle(type: .destructive))
                .disabled(selectedSubClass == nil)

                Button(action: exportInstrumentTypes) {
                    Label("Export Types", systemImage: "arrow.down.doc")
                }
                .buttonStyle(DSButtonStyle(type: .secondary))
                .disabled(subClasses.isEmpty)

                Spacer()

                if let type = selectedSubClass {
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

    private var columnsMenu: some View {
        Menu {
            ForEach(AssetSubClassColumn.allCases, id: \.self) { column in
                let isVisible = visibleColumns.contains(column)
                Button {
                    toggleColumn(column)
                } label: {
                    Label(column.menuTitle, systemImage: isVisible ? "checkmark" : "")
                }
                .disabled(isVisible && (visibleColumns.count == 1 || AssetSubClassesView.tableConfiguration.requiredColumns.contains(column)))
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

    private func toggleColumn(_ column: AssetSubClassColumn) {
        tableModel.toggleColumn(column)
        ensureValidSortColumn()
    }

    private func resetVisibleColumns() {
        tableModel.resetVisibleColumns()
        ensureValidSortColumn()
    }

    private func resetTablePreferences() {
        tableModel.resetTablePreferences()
        ensureValidSortColumn()
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

    private func loadSubClasses() {
        let currentId = selectedSubClass?.id
        subClasses = dbManager.fetchInstrumentTypes().map { item in
            AssetSubClass(
                id: item.id,
                classId: item.classId,
                classDescription: item.classDescription,
                code: item.code,
                name: item.name,
                description: item.description,
                isActive: item.isActive
            )
        }
        if let currentId, let match = subClasses.first(where: { $0.id == currentId }) {
            selectedSubClass = match
        }
    }

    private func handleDelete(_ type: AssetSubClass) {
        let result = dbManager.deleteInstrumentType(id: type.id)

        if result.success {
            loadSubClasses()
            selectedSubClass = nil
            showDeleteSuccessToast = true
        } else {
            if !result.usage.isEmpty {
                let detail = result.usage
                    .map { "\($0.count) row(s) in \($0.table).\($0.field)" }
                    .joined(separator: ", ")
                deleteResultMessage = "Cannot delete — referenced by " + detail
            } else {
                deleteResultMessage = "Failed to delete asset subclass."
            }
            showDeleteResultAlert = true
        }
    }

    private func sortOption(for column: AssetSubClassColumn) -> AssetSubClassColumn? {
        column
    }

    private func ensureValidSortColumn() {
        if !visibleColumns.contains(sortColumn) {
            if let fallback = tableModel.activeColumns.compactMap({ sortOption(for: $0) }).first {
                sortColumn = fallback
            } else {
                sortColumn = .name
            }
        }
    }

    private func exportInstrumentTypes() {
        #if os(macOS)
            let types = dbManager.fetchInstrumentTypes()
            let tableText = instrumentTypesTableText(from: types)

            let panel = NSSavePanel()
            panel.allowedContentTypes = [UTType.plainText]
            panel.canCreateDirectories = true
            panel.nameFieldStringValue = "dragonshield_instrument_types.txt"
            panel.title = "Export Instrument Types"

            if panel.runModal() == .OK, let url = panel.url {
                do {
                    try tableText.write(to: url, atomically: true, encoding: .utf8)
                    exportToastMessage = "Saved \(types.count) types to \(url.lastPathComponent)"
                    showExportSuccessToast = true
                } catch {
                    exportErrorMessage = "Unable to save file: \(error.localizedDescription)"
                    showExportErrorAlert = true
                }
            }
        #else
            exportErrorMessage = "Instrument type export is only available on macOS."
            showExportErrorAlert = true
        #endif
    }

    private func instrumentTypesTableText(
        from types: [(id: Int, classId: Int, classDescription: String, code: String, name: String, description: String, isActive: Bool)]
    ) -> String {
        let headers = ["Instrument Type Name", "Asset Class", "Code", "Description"]
        let sanitizedRows = types.map { type in
            [
                cleaned(type.name),
                cleaned(type.classDescription),
                cleaned(type.code),
                cleaned(type.description),
            ]
        }
        return makeTextTable(headers: headers, rows: sanitizedRows)
    }

    private func cleaned(_ value: String) -> String {
        value.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func makeTextTable(headers: [String], rows: [[String]]) -> String {
        let allRows = [headers] + rows
        let columnWidths = (0 ..< headers.count).map { index in
            allRows.map { $0[index].count }.max() ?? 0
        }

        var lines: [String] = []
        lines.append(formatRow(headers, widths: columnWidths))
        lines.append(columnWidths.map { String(repeating: "-", count: $0) }.joined(separator: "-+-"))

        if rows.isEmpty {
            lines.append("(no instrument types found)")
        } else {
            lines.append(contentsOf: rows.map { formatRow($0, widths: columnWidths) })
        }

        return lines.joined(separator: "\n")
    }

    private func formatRow(_ columns: [String], widths: [Int]) -> String {
        zip(columns, widths).map { value, width in
            value.padding(toLength: width, withPad: " ", startingAt: 0)
        }
        .joined(separator: " | ")
    }

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

private struct AssetSubClassRowView: View {
    let type: AssetSubClass
    let columns: [AssetSubClassColumn]
    let fontConfig: MaintenanceTableFontConfig
    let rowPadding: CGFloat
    let isSelected: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    let widthFor: (AssetSubClassColumn) -> CGFloat

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
        .onTapGesture(count: 2) {
            onEdit()
        }
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
    private func columnView(for column: AssetSubClassColumn) -> some View {
        switch column {
        case .name:
            Text(type.name)
                .font(.system(size: fontConfig.primary, weight: .medium))
                .foregroundColor(DSColor.textPrimary)
                .padding(.leading, DSLayout.spaceM)
                .padding(.trailing, DSLayout.spaceS)
                .frame(width: widthFor(.name), alignment: .leading)
        case .assetClass:
            Text(type.classDescription)
                .font(.system(size: fontConfig.secondary))
                .foregroundColor(DSColor.textSecondary)
                .padding(.horizontal, DSLayout.spaceS)
                .frame(width: widthFor(.assetClass), alignment: .leading)
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
        case .status:
            HStack(spacing: DSLayout.spaceXS) {
                Circle()
                    .fill(type.isActive ? DSColor.accentSuccess : DSColor.accentWarning)
                    .frame(width: max(fontConfig.badge, 8), height: max(fontConfig.badge, 8))
                Text(type.isActive ? "Active" : "Inactive")
                    .font(.system(size: fontConfig.secondary, weight: .medium))
                    .foregroundColor(type.isActive ? DSColor.accentSuccess : DSColor.accentWarning)
            }
            .frame(width: widthFor(.status), alignment: .center)
        }
    }
}

struct AddAssetSubClassView: View {
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject var dbManager: DatabaseManager

    @State private var assetClasses: [(id: Int, name: String)] = []
    @State private var selectedClassId: Int = 0

    @State private var typeName = ""
    @State private var typeCode = ""
    @State private var typeDescription = ""
    @State private var isActive = true
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false

    private var isValid: Bool {
        !assetClasses.isEmpty && selectedClassId != 0 &&
            !typeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !typeCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            formHeader(
                title: "New Instrument Type",
                subtitle: "Create an asset subclass and connect it to an asset class.",
                isValid: isValid,
                isLoading: isLoading,
                onSave: saveInstrumentType,
                onCancel: { presentationMode.wrappedValue.dismiss() }
            )

            Divider().overlay(DSColor.border)

            ScrollView {
                DSCard {
                    formFields(accent: DSColor.accentMain)
                }
                .padding(DSLayout.spaceM)
            }
        }
        .frame(width: 640, height: 540)
        .background(DSColor.background)
        .onAppear {
            loadAssetClasses()
        }
        .alert("Unable to Save", isPresented: $showingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    private func formFields(accent: Color) -> some View {
        VStack(alignment: .leading, spacing: DSLayout.spaceL) {
            formSectionHeader(title: "Type Information", icon: "folder.fill", color: accent)

            VStack(spacing: DSLayout.spaceM) {
                assetClassPicker(accent: accent)

                typeFormField(
                    title: "Type Name",
                    placeholder: "e.g., Exchange Traded Funds",
                    icon: "textformat",
                    text: $typeName,
                    isRequired: true
                )

                typeFormField(
                    title: "Type Code",
                    placeholder: "e.g., ETF",
                    icon: "number",
                    text: $typeCode,
                    isRequired: true,
                    autoUppercase: true
                )

                typeFormField(
                    title: "Description",
                    placeholder: "Brief description of this asset type",
                    icon: "text.alignleft",
                    text: $typeDescription,
                    isRequired: false
                )

                statusToggle(isOn: $isActive, accent: accent)
            }
        }
    }

    private func assetClassPicker(accent: Color) -> some View {
        VStack(alignment: .leading, spacing: DSLayout.spaceXS) {
            Text("Asset Class*")
                .dsBodySmall()
                .foregroundColor(DSColor.textSecondary)

            Menu {
                ForEach(assetClasses, id: \.id) { cls in
                    Button(cls.name) { selectedClassId = cls.id }
                }
            } label: {
                HStack {
                    Text(assetClasses.first(where: { $0.id == selectedClassId })?.name ?? "Select Asset Class")
                        .foregroundColor(DSColor.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(DSColor.textSecondary)
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
            .menuStyle(.borderlessButton)
        }
    }

    private func statusToggle(isOn: Binding<Bool>, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: DSLayout.spaceXS) {
            Text("Status")
                .dsBodySmall()
                .foregroundColor(DSColor.textSecondary)

            Toggle("Active", isOn: isOn)
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
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func saveInstrumentType() {
        guard isValid else {
            alertMessage = "Please fill in all required fields"
            showingAlert = true
            return
        }

        isLoading = true

        let success = dbManager.addInstrumentType(
            classId: selectedClassId,
            code: typeCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
            name: typeName.trimmingCharacters(in: .whitespacesAndNewlines),
            description: typeDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            isActive: isActive
        )

        DispatchQueue.main.async {
            isLoading = false
            if success {
                NotificationCenter.default.post(name: NSNotification.Name("RefreshAssetSubClasses"), object: nil)
                presentationMode.wrappedValue.dismiss()
            } else {
                alertMessage = "Failed to add asset subclass. Please try again."
                showingAlert = true
            }
        }
    }

    private func loadAssetClasses() {
        let classes = dbManager.fetchAssetClasses()
        assetClasses = classes
        if let first = classes.first {
            selectedClassId = first.id
        }
    }
}

struct EditAssetSubClassView: View {
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject var dbManager: DatabaseManager
    let typeId: Int

    @State private var assetClasses: [(id: Int, name: String)] = []
    @State private var selectedClassId: Int = 0

    @State private var typeName = ""
    @State private var typeCode = ""
    @State private var typeDescription = ""
    @State private var isActive = true
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false

    @State private var hasChanges = false

    @State private var originalName = ""
    @State private var originalCode = ""
    @State private var originalDescription = ""
    @State private var originalIsActive = true
    @State private var originalClassId = 0

    private var isValid: Bool {
        !assetClasses.isEmpty && selectedClassId != 0 &&
            !typeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !typeCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            formHeader(
                title: "Edit Instrument Type",
                subtitle: "Update the details for this asset subclass.",
                isValid: isValid && hasChanges,
                isLoading: isLoading,
                onSave: saveEditInstrumentType,
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
                    formFields(accent: DSColor.accentWarning)
                }
                .padding(DSLayout.spaceM)
            }
        }
        .frame(width: 640, height: 560)
        .background(DSColor.background)
        .onAppear {
            loadAssetClasses()
            loadTypeData()
        }
        .alert("Unable to Save", isPresented: $showingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    private func formFields(accent: Color) -> some View {
        VStack(alignment: .leading, spacing: DSLayout.spaceL) {
            formSectionHeader(title: "Type Information", icon: "folder.fill", color: accent)

            VStack(spacing: DSLayout.spaceM) {
                assetClassPicker(accent: accent)

                typeFormField(
                    title: "Type Name",
                    placeholder: "e.g., Exchange Traded Funds",
                    icon: "textformat",
                    text: $typeName,
                    isRequired: true
                )
                .onChange(of: typeName) { _, _ in detectChanges() }

                typeFormField(
                    title: "Type Code",
                    placeholder: "e.g., ETF",
                    icon: "number",
                    text: $typeCode,
                    isRequired: true,
                    autoUppercase: true
                )
                .onChange(of: typeCode) { _, _ in detectChanges() }

                typeFormField(
                    title: "Description",
                    placeholder: "Brief description of this asset type",
                    icon: "text.alignleft",
                    text: $typeDescription,
                    isRequired: false
                )
                .onChange(of: typeDescription) { _, _ in detectChanges() }

                statusToggle(isOn: $isActive, accent: accent)
                    .onChange(of: isActive) { _, _ in detectChanges() }
            }
        }
    }

    private func assetClassPicker(accent: Color) -> some View {
        VStack(alignment: .leading, spacing: DSLayout.spaceXS) {
            Text("Asset Class*")
                .dsBodySmall()
                .foregroundColor(DSColor.textSecondary)

            Menu {
                ForEach(assetClasses, id: \.id) { cls in
                    Button(cls.name) { selectedClassId = cls.id; detectChanges() }
                }
            } label: {
                HStack {
                    Text(assetClasses.first(where: { $0.id == selectedClassId })?.name ?? "Select Asset Class")
                        .foregroundColor(DSColor.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(DSColor.textSecondary)
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
            .menuStyle(.borderlessButton)
        }
    }

    private func statusToggle(isOn: Binding<Bool>, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: DSLayout.spaceXS) {
            Text("Status")
                .dsBodySmall()
                .foregroundColor(DSColor.textSecondary)

            Toggle("Active", isOn: isOn)
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
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func detectChanges() {
        hasChanges = typeName != originalName ||
            typeCode != originalCode ||
            typeDescription != originalDescription ||
            isActive != originalIsActive ||
            selectedClassId != originalClassId
    }

    private func saveEditInstrumentType() {
        guard isValid && hasChanges else { return }

        isLoading = true

        let success = dbManager.updateInstrumentType(
            id: typeId,
            classId: selectedClassId,
            code: typeCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
            name: typeName.trimmingCharacters(in: .whitespacesAndNewlines),
            description: typeDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            isActive: isActive
        )

        DispatchQueue.main.async {
            isLoading = false

            if success {
                originalName = typeName
                originalCode = typeCode
                originalDescription = typeDescription
                originalIsActive = isActive
                originalClassId = selectedClassId
                detectChanges()

                NotificationCenter.default.post(name: NSNotification.Name("RefreshAssetSubClasses"), object: nil)

                presentationMode.wrappedValue.dismiss()
            } else {
                alertMessage = "Failed to update asset subclass. Please try again."
                showingAlert = true
            }
        }
    }

    private func loadTypeData() {
        if let details = dbManager.fetchInstrumentTypeDetails(id: typeId) {
            typeName = details.name
            typeCode = details.code
            typeDescription = details.description
            isActive = details.isActive
            selectedClassId = details.classId

            originalName = typeName
            originalCode = typeCode
            originalDescription = typeDescription
            originalIsActive = isActive
            originalClassId = details.classId

            detectChanges()
        }
    }

    private func loadAssetClasses() {
        assetClasses = dbManager.fetchAssetClasses()
        if assetClasses.isEmpty { return }
        if selectedClassId == 0 { selectedClassId = assetClasses.first!.id }
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
        case .alertFirstButtonReturn:
            saveEditInstrumentType()
        case .alertSecondButtonReturn:
            presentationMode.wrappedValue.dismiss()
        default:
            break
        }
    }
}

private func formHeader(
    title: String,
    subtitle: String,
    isValid: Bool,
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
                Text(isLoading ? "Saving..." : "Save")
            }
        }
        .buttonStyle(DSButtonStyle(type: .primary))
        .disabled(!isValid || isLoading)
    }
    .padding(DSLayout.spaceM)
}

private func formSectionHeader(title: String, icon: String, color: Color) -> some View {
    HStack(spacing: DSLayout.spaceS) {
        Image(systemName: icon)
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(color)
        Text(title)
            .dsHeaderSmall()
    }
}

private func typeFormField(
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
