// DragonShield/Views/InstitutionsView.swift

// MARK: - Version 2.0

// MARK: - History

// - 1.5 -> 2.0: Adopted design-system styling and shared maintenance-table UX for list, filters, and forms.
// - 1.4 -> 1.5: Adopted instrument-style table UX (column picker, font sizing, per-column sorting, filters, and persistent column widths).
// - 1.3 -> 1.4: Delete action now removes the institution from the database
//                permanently and clears the current selection.
// - 1.2 -> 1.3: Added action bar with Edit/Delete buttons and double-click to
//                edit, matching the AccountTypes maintenance UX.
// - 1.1 -> 1.2: Added add/edit/delete notifications and dependency check
//                on delete. List now refreshes automatically.
// - 1.0 -> 1.1: Fixed List selection error by requiring InstitutionData
//                to conform to Hashable.
// - Initial creation: Manage Institutions table using same design as other maintenance views.

import Foundation
import SwiftUI
#if os(macOS)
    import AppKit
#endif

private let isoRegionIdentifiers: [String] = Locale.Region.isoRegions.map(\.identifier)
private let isoRegionIdentifierSet: Set<String> = Set(isoRegionIdentifiers)

private enum InstitutionTableColumn: String, CaseIterable, Codable, MaintenanceTableColumn {
    case name, bic, type, currency, country, website, contact, notes, status

    var title: String {
        switch self {
        case .name: return "Name"
        case .bic: return "BIC"
        case .type: return "Type"
        case .currency: return "Cur"
        case .country: return "Country"
        case .website: return "Website"
        case .contact: return "Contact"
        case .notes: return ""
        case .status: return "Status"
        }
    }

    var menuTitle: String {
        switch self {
        case .notes: return "Notes"
        default:
            let base = title
            return base.isEmpty ? rawValue.capitalized : base
        }
    }
}

struct InstitutionsView: View {
    @EnvironmentObject var dbManager: DatabaseManager

    @State private var institutions: [DatabaseManager.InstitutionData] = []
    @State private var selectedInstitution: DatabaseManager.InstitutionData? = nil
    @State private var searchText = ""

    @State private var showAddSheet = false
    @State private var showEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var institutionToDelete: DatabaseManager.InstitutionData? = nil

    @State private var typeFilters: Set<String> = []
    @State private var currencyFilters: Set<String> = []
    @State private var statusFilters: Set<String> = []

    @State private var sortColumn: SortColumn = .name
    @State private var sortAscending: Bool = true

    @StateObject private var tableModel = ResizableTableViewModel<InstitutionTableColumn>(configuration: InstitutionsView.tableConfiguration)

    @State private var headerOpacity: Double = 0
    @State private var contentOffset: CGFloat = 30
    @State private var buttonsOpacity: Double = 0

    private static let visibleColumnsKey = "InstitutionsView.visibleColumns.v1"

    private enum SortColumn: String, CaseIterable {
        case name, bic, type, currency, country, website, contact, status
    }

    private static let columnOrder: [InstitutionTableColumn] = [.name, .bic, .type, .currency, .country, .website, .contact, .notes, .status]
    private static let defaultVisibleColumns: Set<InstitutionTableColumn> = [.name, .bic, .type, .currency, .country, .notes, .status]
    private static let requiredColumns: Set<InstitutionTableColumn> = [.name]

    private static let defaultColumnWidths: [InstitutionTableColumn: CGFloat] = [
        .name: 280,
        .bic: 140,
        .type: 160,
        .currency: 100,
        .country: 120,
        .website: 220,
        .contact: 220,
        .notes: 60,
        .status: 140,
    ]

    private static let minimumColumnWidths: [InstitutionTableColumn: CGFloat] = [
        .name: 220,
        .bic: 120,
        .type: 120,
        .currency: 80,
        .country: 100,
        .website: 160,
        .contact: 160,
        .notes: 48,
        .status: 110,
    ]

    fileprivate static let columnTextInset: CGFloat = DSLayout.spaceS
    fileprivate static let columnHandleWidth: CGFloat = 10
    fileprivate static let columnHandleHitSlop: CGFloat = 8

    #if os(macOS)
        fileprivate static let columnResizeCursor: NSCursor = {
            let size = NSSize(width: 8, height: 24)
            let image = NSImage(size: size)
            image.lockFocus()
            NSColor.clear.setFill()
            NSRect(origin: .zero, size: size).fill()
            let barWidth: CGFloat = 2
            let barRect = NSRect(x: (size.width - barWidth) / 2, y: 0, width: barWidth, height: size.height)
            NSColor(DSColor.accentMain).setFill()
            barRect.fill()
            image.unlockFocus()
            return NSCursor(image: image, hotSpot: NSPoint(x: size.width / 2, y: size.height / 2))
        }()
    #endif

    fileprivate static let tableConfiguration: MaintenanceTableConfiguration<InstitutionTableColumn> = {
        #if os(macOS)
            MaintenanceTableConfiguration(
                preferenceKind: .institutions,
                columnOrder: columnOrder,
                defaultVisibleColumns: defaultVisibleColumns,
                requiredColumns: requiredColumns,
                defaultColumnWidths: defaultColumnWidths,
                minimumColumnWidths: minimumColumnWidths,
                visibleColumnsDefaultsKey: visibleColumnsKey,
                columnHandleWidth: columnHandleWidth,
                columnHandleHitSlop: columnHandleHitSlop,
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
                columnResizeCursor: columnResizeCursor
            )
        #else
            MaintenanceTableConfiguration(
                preferenceKind: .institutions,
                columnOrder: columnOrder,
                defaultVisibleColumns: defaultVisibleColumns,
                requiredColumns: requiredColumns,
                defaultColumnWidths: defaultColumnWidths,
                minimumColumnWidths: minimumColumnWidths,
                visibleColumnsDefaultsKey: visibleColumnsKey,
                columnHandleWidth: columnHandleWidth,
                columnHandleHitSlop: columnHandleHitSlop,
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

    private var visibleColumns: Set<InstitutionTableColumn> { tableModel.visibleColumns }
    private var activeColumns: [InstitutionTableColumn] { tableModel.activeColumns }
    private var fontConfig: MaintenanceTableFontConfig { tableModel.fontConfig }
    private var fontSizeBinding: Binding<MaintenanceTableFontSize> {
        Binding(get: { tableModel.selectedFontSize }, set: { tableModel.selectedFontSize = $0 })
    }
    private var selectedFontSize: MaintenanceTableFontSize { tableModel.selectedFontSize }

    private var filteredInstitutions: [DatabaseManager.InstitutionData] {
        var result = institutions
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedQuery.isEmpty {
            let query = trimmedQuery.lowercased()
            result = result.filter { inst in
                let haystack: [String] = [
                    inst.name,
                    inst.bic ?? "",
                    inst.type ?? "",
                    inst.defaultCurrency ?? "",
                    inst.countryCode ?? "",
                    inst.website ?? "",
                    inst.contactInfo ?? "",
                    inst.notes ?? "",
                ].map { $0.lowercased() }
                return haystack.contains { !$0.isEmpty && $0.contains(query) }
            }
        }
        if !typeFilters.isEmpty {
            result = result.filter { inst in
                let value = normalized(inst.type)
                return !value.isEmpty && typeFilters.contains(value)
            }
        }
        if !currencyFilters.isEmpty {
            result = result.filter { inst in
                let value = normalized(inst.defaultCurrency)
                return !value.isEmpty && currencyFilters.contains(value)
            }
        }
        if !statusFilters.isEmpty {
            result = result.filter { inst in
                statusFilters.contains(statusLabel(for: inst.isActive))
            }
        }
        return result
    }

    private var sortedInstitutions: [DatabaseManager.InstitutionData] {
        filteredInstitutions.sorted { lhs, rhs in
            if sortAscending {
                return ascendingSort(lhs: lhs, rhs: rhs)
            } else {
                return descendingSort(lhs: lhs, rhs: rhs)
            }
        }
    }

    private var isFiltering: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !typeFilters.isEmpty || !currencyFilters.isEmpty || !statusFilters.isEmpty
    }

    private var statsSourceInstitutions: [DatabaseManager.InstitutionData] {
        isFiltering ? filteredInstitutions : institutions
    }

    private var totalStatValue: String {
        statValue(current: statsSourceInstitutions.count, total: institutions.count)
    }

    private var activeStatValue: String {
        let currentActive = statsSourceInstitutions.filter { $0.isActive }.count
        let totalActive = institutions.filter { $0.isActive }.count
        return statValue(current: currentActive, total: totalActive)
    }

    private var currencyStatValue: String {
        statValue(current: uniqueCurrencyCount(in: statsSourceInstitutions), total: uniqueCurrencyCount(in: institutions))
    }

    private func uniqueCurrencyCount(in list: [DatabaseManager.InstitutionData]) -> Int {
        let values = list.compactMap { normalized($0.defaultCurrency) }.filter { !$0.isEmpty }
        return Set(values).count
    }

    private func statValue(current: Int, total: Int) -> String {
        guard total > 0 else { return "0" }
        return isFiltering ? "\(current) / \(total)" : "\(current)"
    }

    var body: some View {
        ZStack {
            DSColor.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                modernHeader
                searchAndStats
                institutionsContent
                modernActionBar
            }
        }
        .onAppear {
            tableModel.connect(to: dbManager)
            tableModel.recalcColumnWidths(shouldPersist: false)
            ensureFiltersWithinVisibleColumns()
            ensureValidSortColumn()
            loadData()
            animateEntrance()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshInstitutions"))) { _ in
            loadData()
        }
        .onChange(of: tableModel.visibleColumns) { _, _ in
            ensureFiltersWithinVisibleColumns()
            ensureValidSortColumn()
        }
        .sheet(isPresented: $showAddSheet) { AddInstitutionView().environmentObject(dbManager) }
        .sheet(isPresented: $showEditSheet) {
            if let inst = selectedInstitution {
                EditInstitutionView(institutionId: inst.id).environmentObject(dbManager)
            }
        }
        .alert(isPresented: $showingDeleteAlert) {
            guard let inst = institutionToDelete else {
                return Alert(title: Text("Error"), message: Text("No institution selected."), dismissButton: .default(Text("OK")))
            }

            let deleteInfo = dbManager.canDeleteInstitution(id: inst.id)

            if deleteInfo.0 {
                return Alert(
                    title: Text("Delete Institution"),
                    message: Text("Are you sure you want to delete '\(inst.name)'?"),
                    primaryButton: .destructive(Text("Delete")) {
                        performDelete(inst)
                    },
                    secondaryButton: .cancel { institutionToDelete = nil }
                )
            } else {
                return Alert(
                    title: Text("Cannot Delete Institution"),
                    message: Text(deleteInfo.2),
                    dismissButton: .default(Text("OK")) { institutionToDelete = nil }
                )
            }
        }
    }

    private func normalized(_ value: String?) -> String {
        value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func statusLabel(for isActive: Bool) -> String {
        isActive ? "Active" : "Inactive"
    }

    private func compareAscending(_ lhs: String, _ rhs: String) -> Bool {
        let result = lhs.localizedCaseInsensitiveCompare(rhs)
        if result == .orderedSame {
            return lhs < rhs
        }
        return result == .orderedAscending
    }

    private func compareDescending(_ lhs: String, _ rhs: String) -> Bool {
        let result = lhs.localizedCaseInsensitiveCompare(rhs)
        if result == .orderedSame {
            return lhs > rhs
        }
        return result == .orderedDescending
    }

    private func ascendingSort(lhs: DatabaseManager.InstitutionData, rhs: DatabaseManager.InstitutionData) -> Bool {
        switch sortColumn {
        case .name:
            return compareAscending(lhs.name, rhs.name)
        case .bic:
            let l = normalized(lhs.bic)
            let r = normalized(rhs.bic)
            let comparison = l.localizedCaseInsensitiveCompare(r)
            if comparison == .orderedSame {
                return compareAscending(lhs.name, rhs.name)
            }
            return comparison == .orderedAscending
        case .type:
            let l = normalized(lhs.type)
            let r = normalized(rhs.type)
            let comparison = l.localizedCaseInsensitiveCompare(r)
            if comparison == .orderedSame {
                return compareAscending(lhs.name, rhs.name)
            }
            return comparison == .orderedAscending
        case .currency:
            let l = normalized(lhs.defaultCurrency)
            let r = normalized(rhs.defaultCurrency)
            let comparison = l.localizedCaseInsensitiveCompare(r)
            if comparison == .orderedSame {
                return compareAscending(lhs.name, rhs.name)
            }
            return comparison == .orderedAscending
        case .country:
            let l = normalized(lhs.countryCode)
            let r = normalized(rhs.countryCode)
            let comparison = l.localizedCaseInsensitiveCompare(r)
            if comparison == .orderedSame {
                return compareAscending(lhs.name, rhs.name)
            }
            return comparison == .orderedAscending
        case .website:
            let l = normalized(lhs.website)
            let r = normalized(rhs.website)
            let comparison = l.localizedCaseInsensitiveCompare(r)
            if comparison == .orderedSame {
                return compareAscending(lhs.name, rhs.name)
            }
            return comparison == .orderedAscending
        case .contact:
            let l = normalized(lhs.contactInfo)
            let r = normalized(rhs.contactInfo)
            let comparison = l.localizedCaseInsensitiveCompare(r)
            if comparison == .orderedSame {
                return compareAscending(lhs.name, rhs.name)
            }
            return comparison == .orderedAscending
        case .status:
            if lhs.isActive == rhs.isActive {
                return compareAscending(lhs.name, rhs.name)
            }
            return lhs.isActive && !rhs.isActive
        }
    }

    private func descendingSort(lhs: DatabaseManager.InstitutionData, rhs: DatabaseManager.InstitutionData) -> Bool {
        switch sortColumn {
        case .name:
            return compareDescending(lhs.name, rhs.name)
        case .bic:
            let l = normalized(lhs.bic)
            let r = normalized(rhs.bic)
            let comparison = l.localizedCaseInsensitiveCompare(r)
            if comparison == .orderedSame {
                return compareDescending(lhs.name, rhs.name)
            }
            return comparison == .orderedDescending
        case .type:
            let l = normalized(lhs.type)
            let r = normalized(rhs.type)
            let comparison = l.localizedCaseInsensitiveCompare(r)
            if comparison == .orderedSame {
                return compareDescending(lhs.name, rhs.name)
            }
            return comparison == .orderedDescending
        case .currency:
            let l = normalized(lhs.defaultCurrency)
            let r = normalized(rhs.defaultCurrency)
            let comparison = l.localizedCaseInsensitiveCompare(r)
            if comparison == .orderedSame {
                return compareDescending(lhs.name, rhs.name)
            }
            return comparison == .orderedDescending
        case .country:
            let l = normalized(lhs.countryCode)
            let r = normalized(rhs.countryCode)
            let comparison = l.localizedCaseInsensitiveCompare(r)
            if comparison == .orderedSame {
                return compareDescending(lhs.name, rhs.name)
            }
            return comparison == .orderedDescending
        case .website:
            let l = normalized(lhs.website)
            let r = normalized(rhs.website)
            let comparison = l.localizedCaseInsensitiveCompare(r)
            if comparison == .orderedSame {
                return compareDescending(lhs.name, rhs.name)
            }
            return comparison == .orderedDescending
        case .contact:
            let l = normalized(lhs.contactInfo)
            let r = normalized(rhs.contactInfo)
            let comparison = l.localizedCaseInsensitiveCompare(r)
            if comparison == .orderedSame {
                return compareDescending(lhs.name, rhs.name)
            }
            return comparison == .orderedDescending
        case .status:
            if lhs.isActive == rhs.isActive {
                return compareDescending(lhs.name, rhs.name)
            }
            return !lhs.isActive && rhs.isActive
        }
    }

    private func loadData() {
        institutions = dbManager.fetchInstitutions(activeOnly: false)
    }

    private func performDelete(_ inst: DatabaseManager.InstitutionData) {
        let success = dbManager.deleteInstitution(id: inst.id)
        if success {
            loadData()
            selectedInstitution = nil
            institutionToDelete = nil
        }
    }
}

// MARK: - View Building Blocks

private extension InstitutionsView {
    var modernHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: DSLayout.spaceXS) {
                HStack(spacing: DSLayout.spaceM) {
                    Image(systemName: "building.2.crop.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(DSColor.accentMain)
                    Text("Institutions")
                        .dsHeaderLarge()
                        .foregroundColor(DSColor.textPrimary)
                }
                Text("Manage banks, brokers, and other financial institutions")
                    .dsBody()
                    .foregroundColor(DSColor.textSecondary)
            }

            Spacer()

            HStack(spacing: DSLayout.spaceL) {
                modernStatCard(title: "Total", value: totalStatValue, icon: "number.circle.fill", color: DSColor.accentMain)
                modernStatCard(title: "Active", value: activeStatValue, icon: "checkmark.circle.fill", color: DSColor.accentSuccess)
                modernStatCard(title: "Currencies", value: currencyStatValue, icon: "dollarsign.circle.fill", color: DSColor.textSecondary)
            }
        }
        .padding(.horizontal, DSLayout.spaceL)
        .padding(.vertical, DSLayout.spaceL)
        .opacity(headerOpacity)
    }

    var searchAndStats: some View {
        VStack(spacing: DSLayout.spaceM) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(DSColor.textSecondary)

                TextField("Search institutions...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.ds.body)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(DSColor.textSecondary)
                    }
                    .buttonStyle(PlainButtonStyle())
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
            .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)

            if isFiltering {
                VStack(alignment: .leading, spacing: DSLayout.spaceS) {
                    Text("Found \(sortedInstitutions.count) of \(institutions.count) institutions")
                        .dsCaption()
                        .foregroundColor(DSColor.textSecondary)

                    HStack(spacing: DSLayout.spaceS) {
                        ForEach(Array(typeFilters), id: \.self) { value in
                            filterChip(text: value) { typeFilters.remove(value) }
                        }
                        ForEach(Array(currencyFilters), id: \.self) { value in
                            filterChip(text: value) { currencyFilters.remove(value) }
                        }
                        ForEach(Array(statusFilters), id: \.self) { value in
                            filterChip(text: value) { statusFilters.remove(value) }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, DSLayout.spaceL)
    }

    var institutionsContent: some View {
        VStack(spacing: DSLayout.spaceM) {
            tableControls
            if sortedInstitutions.isEmpty {
                emptyStateView
                    .offset(y: contentOffset)
            } else {
                institutionsTable
                    .offset(y: contentOffset)
            }
        }
        .padding(.horizontal, DSLayout.spaceL)
        .padding(.top, DSLayout.spaceS)
    }

    var tableControls: some View {
        HStack(spacing: DSLayout.spaceM) {
            columnsMenu
            fontSizePicker
            if isFiltering {
                Button("Reset Filters") {
                    typeFilters.removeAll()
                    currencyFilters.removeAll()
                    statusFilters.removeAll()
                }
                .buttonStyle(.link)
                .font(.ds.caption)
            }
            Spacer()
            if visibleColumns != InstitutionsView.defaultVisibleColumns || selectedFontSize != .medium {
                Button("Reset View", action: resetTablePreferences)
                    .buttonStyle(.link)
                    .font(.ds.caption)
            }
        }
        .padding(.horizontal, 4)
    }

    var columnsMenu: some View {
        Menu {
            ForEach(InstitutionsView.columnOrder, id: \.self) { column in
                let isVisible = visibleColumns.contains(column)
                Button {
                    toggleColumn(column)
                } label: {
                    Label(column.menuTitle, systemImage: isVisible ? "checkmark" : "")
                }
                .disabled(isVisible && (visibleColumns.count == 1 || InstitutionsView.requiredColumns.contains(column)))
            }
            Divider()
            Button("Reset Columns", action: resetVisibleColumns)
        } label: {
            Label("Columns", systemImage: "slider.horizontal.3")
                .font(.ds.caption)
        }
    }

    var fontSizePicker: some View {
        Picker("Font Size", selection: fontSizeBinding) {
            ForEach(MaintenanceTableFontSize.allCases, id: \.self) { size in
                Text(size.label).tag(size)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 260)
        .labelsHidden()
    }

    var emptyStateView: some View {
        VStack(spacing: DSLayout.spaceL) {
            Spacer()

            VStack(spacing: DSLayout.spaceM) {
                Image(systemName: searchText.isEmpty ? "building.2" : "magnifyingglass")
                    .font(.system(size: 64))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [DSColor.textTertiary, DSColor.textTertiary.opacity(0.5)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                VStack(spacing: DSLayout.spaceS) {
                    Text(searchText.isEmpty ? "No institutions yet" : "No matching institutions")
                        .dsHeaderMedium()
                        .foregroundColor(DSColor.textSecondary)

                    Text(searchText.isEmpty ? "Add your first institution to get started." : "Try adjusting your search or filters.")
                        .dsBody()
                        .foregroundColor(DSColor.textTertiary)
                        .multilineTextAlignment(.center)
                }

                if searchText.isEmpty {
                    Button {
                        showAddSheet = true
                    } label: {
                        Label("Add Institution", systemImage: "plus")
                    }
                    .buttonStyle(DSButtonStyle(type: .primary))
                    .padding(.top, DSLayout.spaceS)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var institutionsTable: some View {
        MaintenanceTableView(
            model: tableModel,
            rows: sortedInstitutions,
            rowSpacing: 0,
            showHorizontalIndicators: true,
            rowContent: { institution, context in
                ModernInstitutionRowView(
                    institution: institution,
                    columns: context.columns,
                    fontConfig: context.fontConfig,
                    rowPadding: DSLayout.tableRowPadding,
                    isSelected: selectedInstitution?.id == institution.id,
                    onTap: { selectedInstitution = institution },
                    onEdit: {
                        selectedInstitution = institution
                        showEditSheet = true
                    },
                    widthFor: { context.widthForColumn($0) }
                )
            },
            headerContent: { column, fontConfig in
                institutionsHeaderContent(for: column, fontConfig: fontConfig)
            }
        )
    }

    func institutionsHeaderContent(for column: InstitutionTableColumn, fontConfig: MaintenanceTableFontConfig) -> some View {
        let sortOption = sortOption(for: column)
        let isActiveSort = sortOption.map { $0 == sortColumn } ?? false
        let filterBinding = filterBinding(for: column)
        let filterOptions = filterValues(for: column)

        return HStack(spacing: 6) {
            if let sortOption {
                Button(action: {
                    if isActiveSort {
                        sortAscending.toggle()
                    } else {
                        sortColumn = sortOption
                        sortAscending = true
                    }
                }) {
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
            } else if column == .notes {
                Image(systemName: "note.text")
                    .font(.system(size: fontConfig.header, weight: .semibold))
                    .foregroundColor(DSColor.textPrimary)
                    .help("Notes")
            } else {
                Text(column.title)
                    .font(.system(size: fontConfig.header, weight: .semibold))
                    .foregroundColor(DSColor.textPrimary)
            }

            if let binding = filterBinding, !filterOptions.isEmpty {
                Menu {
                    ForEach(filterOptions, id: \.self) { value in
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
                        .foregroundColor(binding.wrappedValue.isEmpty ? DSColor.textTertiary : DSColor.accentMain)
                }
                .menuStyle(BorderlessButtonMenuStyle())
            }
        }
    }

    func filterChip(text: String, onRemove: @escaping () -> Void) -> some View {
        DSBadge(text: text, color: DSColor.accentMain)
            .overlay(alignment: .trailing) {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(DSColor.textOnAccent)
                        .padding(.leading, 4)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 2)
            }
    }

    var modernActionBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(DSColor.border)
                .frame(height: 1)

            HStack(spacing: DSLayout.spaceM) {
                Button {
                    showAddSheet = true
                } label: {
                    Label("Add Institution", systemImage: "plus")
                }
                .buttonStyle(DSButtonStyle(type: .primary))

                if selectedInstitution != nil {
                    Button {
                        showEditSheet = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .buttonStyle(DSButtonStyle(type: .secondary))

                    Button {
                        if let inst = selectedInstitution {
                            institutionToDelete = inst
                            showingDeleteAlert = true
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .buttonStyle(DSButtonStyle(type: .destructive))
                }

                Spacer()

                if let selectedName = selectedInstitution?.name {
                    HStack(spacing: DSLayout.spaceXS) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(DSColor.accentMain)
                        Text("Selected: \(selectedName)")
                            .dsBodySmall()
                            .foregroundColor(DSColor.textSecondary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, DSLayout.spaceM)
                    .padding(.vertical, DSLayout.spaceS)
                    .background(DSColor.surfaceSecondary)
                    .cornerRadius(DSLayout.radiusM)
                }
            }
            .padding(.horizontal, DSLayout.spaceL)
            .padding(.vertical, DSLayout.spaceM)
            .background(DSColor.surface)
        }
        .opacity(buttonsOpacity)
    }

    func modernStatCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: DSLayout.spaceXS) {
            HStack(spacing: DSLayout.spaceXS) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(color)
                Text(title)
                    .font(.ds.caption)
                    .foregroundColor(DSColor.textSecondary)
            }

            Text(value)
                .font(.ds.headerSmall)
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
        .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 1)
    }

    func animateEntrance() {
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

    private func filterBinding(for column: InstitutionTableColumn) -> Binding<Set<String>>? {
        switch column {
        case .type: return $typeFilters
        case .currency: return $currencyFilters
        case .status: return $statusFilters
        default: return nil
        }
    }

    private func filterValues(for column: InstitutionTableColumn) -> [String] {
        switch column {
        case .type:
            return Array(Set(institutions.map { normalized($0.type) }.filter { !$0.isEmpty })).sorted()
        case .currency:
            return Array(Set(institutions.map { normalized($0.defaultCurrency) }.filter { !$0.isEmpty })).sorted()
        case .status:
            return ["Active", "Inactive"]
        default:
            return []
        }
    }

    private func sortOption(for column: InstitutionTableColumn) -> SortColumn? {
        switch column {
        case .name: return .name
        case .bic: return .bic
        case .type: return .type
        case .currency: return .currency
        case .country: return .country
        case .website: return .website
        case .contact: return .contact
        case .status: return .status
        case .notes: return nil
        }
    }

    private func toggleColumn(_ column: InstitutionTableColumn) {
        tableModel.toggleColumn(column)
        ensureFiltersWithinVisibleColumns()
        ensureValidSortColumn()
    }

    private func resetVisibleColumns() {
        tableModel.resetVisibleColumns()
        ensureFiltersWithinVisibleColumns()
        ensureValidSortColumn()
    }

    private func resetTablePreferences() {
        tableModel.resetTablePreferences()
        ensureFiltersWithinVisibleColumns()
        ensureValidSortColumn()
    }

    private func ensureValidSortColumn() {
        let currentColumn = tableColumn(for: sortColumn)
        if !visibleColumns.contains(currentColumn) {
            if let fallback = tableModel.activeColumns.compactMap(sortOption(for:)).first {
                sortColumn = fallback
            } else {
                sortColumn = .name
            }
        }
    }

    private func ensureFiltersWithinVisibleColumns() {
        if !visibleColumns.contains(.type) {
            typeFilters.removeAll()
        }
        if !visibleColumns.contains(.currency) {
            currencyFilters.removeAll()
        }
        if !visibleColumns.contains(.status) {
            statusFilters.removeAll()
        }
    }

    private func tableColumn(for sortColumn: SortColumn) -> InstitutionTableColumn {
        switch sortColumn {
        case .name: return .name
        case .bic: return .bic
        case .type: return .type
        case .currency: return .currency
        case .country: return .country
        case .website: return .website
        case .contact: return .contact
        case .status: return .status
        }
    }
}

// MARK: - Add Institution

struct AddInstitutionView: View {
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject var dbManager: DatabaseManager
    var onAdd: ((Int) -> Void)? = nil

    @State private var name = ""
    @State private var bic = ""
    @State private var type = ""
    @State private var website = ""
    @State private var contactInfo = ""
    @State private var defaultCurrency = ""
    @State private var countryCode = ""
    @State private var notes = ""
    @State private var availableCurrencies: [(code: String, name: String, symbol: String)] = []
    @State private var availableCountries: [String] = []
    @State private var isActive = true
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    @State private var formScale: CGFloat = 0.96
    @State private var headerOpacity: Double = 0
    @State private var contentOffset: CGFloat = 32

    var isValid: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let currValid = defaultCurrency.isEmpty || defaultCurrency.count == 3
        let countryValid = countryCode.isEmpty || countryCode.count == 2
        return !trimmedName.isEmpty && currValid && countryValid
    }

    var body: some View {
        ZStack {
            DSColor.background
                .ignoresSafeArea()
            VStack(spacing: 0) {
                formHeader(title: "Add Institution", icon: "building.2.fill", actionTitle: "Save", actionIcon: "checkmark", isLoading: isLoading) {
                    save()
                }
                ScrollView {
                    formContent
                        .padding(.horizontal, DSLayout.spaceL)
                        .padding(.bottom, DSLayout.spaceL)
                        .offset(y: contentOffset)
                }
            }
        }
        .frame(width: 620, height: 720)
        .clipShape(RoundedRectangle(cornerRadius: DSLayout.radiusL))
        .shadow(color: Color.black.opacity(0.1), radius: 18, x: 0, y: 8)
        .scaleEffect(formScale)
        .onAppear {
            availableCurrencies = dbManager.fetchActiveCurrencies()
            availableCountries = Locale.Region.isoRegions.map(\.identifier).sorted()
            animateEntrance()
        }
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

    private var formContent: some View {
        VStack(alignment: .leading, spacing: DSLayout.spaceL) {
            formSection(title: "Details", icon: "info.circle", color: DSColor.accentMain) {
                labeledField(title: "Name*", placeholder: "Bank / broker name", icon: "building.2", text: $name, isRequired: true)
                labeledField(title: "BIC", placeholder: "Optional BIC", icon: "barcode.viewfinder", text: $bic)
                labeledField(title: "Type", placeholder: "e.g. Broker, Bank", icon: "square.grid.2x2", text: $type)
            }

            formSection(title: "Contact", icon: "link", color: DSColor.textSecondary) {
                labeledField(title: "Website", placeholder: "https://...", icon: "globe", text: $website)
                labeledField(title: "Contact Info", placeholder: "Team / phone / email", icon: "person.text.rectangle", text: $contactInfo)
            }

            formSection(title: "Location & Currency", icon: "map", color: DSColor.textSecondary) {
                currencyPicker
                countryPicker
            }

            formSection(title: "Notes", icon: "note.text", color: DSColor.textSecondary) {
                TextEditor(text: $notes)
                    .frame(minHeight: 90)
                    .padding(DSLayout.spaceS)
                    .background(DSColor.surfaceSecondary)
                    .cornerRadius(DSLayout.radiusS)
                    .overlay(RoundedRectangle(cornerRadius: DSLayout.radiusS).stroke(DSColor.border, lineWidth: 1))
            }

            Toggle("Active", isOn: $isActive)
                .toggleStyle(.switch)
                .font(.ds.body)
        }
    }

    private var currencyPicker: some View {
        VStack(alignment: .leading, spacing: DSLayout.spaceXS) {
            labelRow(title: "Default Currency", icon: "dollarsign.circle")
            Picker("Default Currency", selection: $defaultCurrency) {
                Text("None").tag("")
                ForEach(availableCurrencies, id: \.code) { curr in
                    Text("\(curr.code) – \(curr.name)").tag(curr.code)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DSLayout.spaceS)
            .background(DSColor.surfaceSecondary)
            .cornerRadius(DSLayout.radiusS)
            .overlay(RoundedRectangle(cornerRadius: DSLayout.radiusS).stroke(DSColor.border, lineWidth: 1))
        }
    }

    private var countryPicker: some View {
        VStack(alignment: .leading, spacing: DSLayout.spaceXS) {
            labelRow(title: "Country", icon: "flag")
            Picker("Country", selection: $countryCode) {
                Text("None").tag("")
                ForEach(availableCountries, id: \.self) { code in
                    Text("\(flagEmoji(code)) \(code)").tag(code)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DSLayout.spaceS)
            .background(DSColor.surfaceSecondary)
            .cornerRadius(DSLayout.radiusS)
            .overlay(RoundedRectangle(cornerRadius: DSLayout.radiusS).stroke(DSColor.border, lineWidth: 1))
        }
    }

    @ViewBuilder
    private func formHeader(title: String, icon: String, actionTitle: String, actionIcon: String, isLoading: Bool, action: @escaping () -> Void) -> some View {
        HStack {
            Button {
                animateExit()
            } label: {
                Image(systemName: "xmark")
                    .foregroundColor(DSColor.textSecondary)
                    .padding(8)
                    .background(DSColor.surfaceSecondary)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: DSLayout.spaceS) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(DSColor.accentMain)
                Text(title)
                    .dsHeaderLarge()
                    .foregroundColor(DSColor.textPrimary)
            }

            Spacer()

            Button {
                guard isValid else {
                    alertMessage = "Please fill the required fields."
                    showingAlert = true
                    return
                }
                action()
            } label: {
                HStack(spacing: DSLayout.spaceS) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: actionIcon)
                            .font(.system(size: 14, weight: .bold))
                    }
                    Text(isLoading ? "Saving..." : actionTitle)
                        .dsBodySmall()
                        .fontWeight(.semibold)
                }
            }
            .buttonStyle(DSButtonStyle(type: .primary))
            .disabled(isLoading || !isValid)
        }
        .padding(.horizontal, DSLayout.spaceL)
        .padding(.vertical, DSLayout.spaceL)
        .opacity(headerOpacity)
    }

    private func formSection(title: String, icon: String, color: Color, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: DSLayout.spaceS) {
            HStack(spacing: DSLayout.spaceS) {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .dsHeaderSmall()
                    .foregroundColor(DSColor.textPrimary)
            }
            VStack(spacing: DSLayout.spaceS) {
                content()
            }
            .padding(DSLayout.spaceM)
            .background(DSColor.surface)
            .cornerRadius(DSLayout.radiusL)
            .overlay(RoundedRectangle(cornerRadius: DSLayout.radiusL).stroke(DSColor.border, lineWidth: 1))
        }
    }

    private func labelRow(title: String, icon: String) -> some View {
        HStack(spacing: DSLayout.spaceS) {
            Image(systemName: icon)
                .foregroundColor(DSColor.textSecondary)
            Text(title)
                .dsBodySmall()
                .foregroundColor(DSColor.textSecondary)
        }
    }

    private func labeledField(title: String, placeholder: String, icon: String, text: Binding<String>, isRequired: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: DSLayout.spaceXS) {
            labelRow(title: title, icon: icon)
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .padding(DSLayout.spaceS)
                .background(DSColor.surfaceSecondary)
                .cornerRadius(DSLayout.radiusS)
                .overlay(
                    RoundedRectangle(cornerRadius: DSLayout.radiusS)
                        .stroke(
                            isRequired && text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isValid ? DSColor.accentError : DSColor.border,
                            lineWidth: 1
                        )
                )
        }
    }

    private func animateEntrance() {
        withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) { formScale = 1.0 }
        withAnimation(.easeOut(duration: 0.6).delay(0.2)) { headerOpacity = 1.0 }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4)) { contentOffset = 0 }
    }

    private func animateExit() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            formScale = 0.96
            headerOpacity = 0
            contentOffset = 32
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            presentationMode.wrappedValue.dismiss()
        }
    }

    private func save() {
        guard isValid else {
            alertMessage = "Please fill the required fields."
            showingAlert = true
            return
        }
        isLoading = true
        let newId = dbManager.addInstitution(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            bic: bic.isEmpty ? nil : bic,
            type: type.isEmpty ? nil : type,
            website: website.isEmpty ? nil : website,
            contactInfo: contactInfo.isEmpty ? nil : contactInfo,
            defaultCurrency: defaultCurrency.isEmpty ? nil : defaultCurrency,
            countryCode: countryCode.isEmpty ? nil : countryCode,
            notes: notes.isEmpty ? nil : notes,
            isActive: isActive
        )
        isLoading = false
        if let id = newId {
            NotificationCenter.default.post(name: NSNotification.Name("RefreshInstitutions"), object: nil)
            onAdd?(id)
            alertMessage = "✅ Added"
        } else {
            alertMessage = "❌ Failed to add institution"
        }
        showingAlert = true
    }
}

// MARK: - Edit Institution

struct EditInstitutionView: View {
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject var dbManager: DatabaseManager
    let institutionId: Int

    @State private var name = ""
    @State private var bic = ""
    @State private var type = ""
    @State private var website = ""
    @State private var contactInfo = ""
    @State private var defaultCurrency = ""
    @State private var countryCode = ""
    @State private var notes = ""
    @State private var availableCurrencies: [(code: String, name: String, symbol: String)] = []
    @State private var availableCountries: [String] = []
    @State private var isActive = true
    @State private var loaded = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    @State private var formScale: CGFloat = 0.96
    @State private var headerOpacity: Double = 0
    @State private var contentOffset: CGFloat = 32

    var isValid: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let currValid = defaultCurrency.isEmpty || defaultCurrency.count == 3
        let countryValid = countryCode.isEmpty || countryCode.count == 2
        return !trimmedName.isEmpty && currValid && countryValid
    }

    var body: some View {
        ZStack {
            DSColor.background
                .ignoresSafeArea()
            VStack(spacing: 0) {
                formHeader(title: "Edit Institution", icon: "pencil", actionTitle: "Save Changes", actionIcon: "checkmark") {
                    save()
                }
                ScrollView {
                    formContent
                        .padding(.horizontal, DSLayout.spaceL)
                        .padding(.bottom, DSLayout.spaceL)
                        .offset(y: contentOffset)
                }
            }
        }
        .frame(width: 620, height: 720)
        .clipShape(RoundedRectangle(cornerRadius: DSLayout.radiusL))
        .shadow(color: Color.black.opacity(0.1), radius: 18, x: 0, y: 8)
        .scaleEffect(formScale)
        .onAppear {
            if !loaded { load() }
            availableCurrencies = dbManager.fetchActiveCurrencies()
            availableCountries = Locale.Region.isoRegions.map(\.identifier).sorted()
            animateEntrance()
        }
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

    private var formContent: some View {
        VStack(alignment: .leading, spacing: DSLayout.spaceL) {
            formSection(title: "Details", icon: "info.circle", color: DSColor.accentMain) {
                labeledField(title: "Name*", placeholder: "Bank / broker name", icon: "building.2", text: $name, isRequired: true)
                labeledField(title: "BIC", placeholder: "Optional BIC", icon: "barcode.viewfinder", text: $bic)
                labeledField(title: "Type", placeholder: "e.g. Broker, Bank", icon: "square.grid.2x2", text: $type)
            }

            formSection(title: "Contact", icon: "link", color: DSColor.textSecondary) {
                labeledField(title: "Website", placeholder: "https://...", icon: "globe", text: $website)
                labeledField(title: "Contact Info", placeholder: "Team / phone / email", icon: "person.text.rectangle", text: $contactInfo)
            }

            formSection(title: "Location & Currency", icon: "map", color: DSColor.textSecondary) {
                currencyPicker
                countryPicker
            }

            formSection(title: "Notes", icon: "note.text", color: DSColor.textSecondary) {
                TextEditor(text: $notes)
                    .frame(minHeight: 90)
                    .padding(DSLayout.spaceS)
                    .background(DSColor.surfaceSecondary)
                    .cornerRadius(DSLayout.radiusS)
                    .overlay(RoundedRectangle(cornerRadius: DSLayout.radiusS).stroke(DSColor.border, lineWidth: 1))
            }

            Toggle("Active", isOn: $isActive)
                .toggleStyle(.switch)
                .font(.ds.body)
        }
    }

    private var currencyPicker: some View {
        VStack(alignment: .leading, spacing: DSLayout.spaceXS) {
            labelRow(title: "Default Currency", icon: "dollarsign.circle")
            Picker("Default Currency", selection: $defaultCurrency) {
                Text("None").tag("")
                ForEach(availableCurrencies, id: \.code) { curr in
                    Text("\(curr.code) – \(curr.name)").tag(curr.code)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DSLayout.spaceS)
            .background(DSColor.surfaceSecondary)
            .cornerRadius(DSLayout.radiusS)
            .overlay(RoundedRectangle(cornerRadius: DSLayout.radiusS).stroke(DSColor.border, lineWidth: 1))
        }
    }

    private var countryPicker: some View {
        VStack(alignment: .leading, spacing: DSLayout.spaceXS) {
            labelRow(title: "Country", icon: "flag")
            Picker("Country", selection: $countryCode) {
                Text("None").tag("")
                ForEach(availableCountries, id: \.self) { code in
                    Text("\(flagEmoji(code)) \(code)").tag(code)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DSLayout.spaceS)
            .background(DSColor.surfaceSecondary)
            .cornerRadius(DSLayout.radiusS)
            .overlay(RoundedRectangle(cornerRadius: DSLayout.radiusS).stroke(DSColor.border, lineWidth: 1))
        }
    }

    @ViewBuilder
    private func formHeader(title: String, icon: String, actionTitle: String, actionIcon: String, action: @escaping () -> Void) -> some View {
        HStack {
            Button {
                animateExit()
            } label: {
                Image(systemName: "xmark")
                    .foregroundColor(DSColor.textSecondary)
                    .padding(8)
                    .background(DSColor.surfaceSecondary)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: DSLayout.spaceS) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(DSColor.accentMain)
                Text(title)
                    .dsHeaderLarge()
                    .foregroundColor(DSColor.textPrimary)
            }

            Spacer()

            Button {
                guard isValid else {
                    alertMessage = "Please fill the required fields."
                    showingAlert = true
                    return
                }
                action()
            } label: {
                HStack(spacing: DSLayout.spaceS) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: actionIcon)
                            .font(.system(size: 14, weight: .bold))
                    }
                    Text(isLoading ? "Saving..." : actionTitle)
                        .dsBodySmall()
                        .fontWeight(.semibold)
                }
            }
            .buttonStyle(DSButtonStyle(type: .primary))
            .disabled(isLoading || !isValid)
        }
        .padding(.horizontal, DSLayout.spaceL)
        .padding(.vertical, DSLayout.spaceL)
        .opacity(headerOpacity)
    }

    private func formSection(title: String, icon: String, color: Color, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: DSLayout.spaceS) {
            HStack(spacing: DSLayout.spaceS) {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .dsHeaderSmall()
                    .foregroundColor(DSColor.textPrimary)
            }
            VStack(spacing: DSLayout.spaceS) {
                content()
            }
            .padding(DSLayout.spaceM)
            .background(DSColor.surface)
            .cornerRadius(DSLayout.radiusL)
            .overlay(RoundedRectangle(cornerRadius: DSLayout.radiusL).stroke(DSColor.border, lineWidth: 1))
        }
    }

    private func labelRow(title: String, icon: String) -> some View {
        HStack(spacing: DSLayout.spaceS) {
            Image(systemName: icon)
                .foregroundColor(DSColor.textSecondary)
            Text(title)
                .dsBodySmall()
                .foregroundColor(DSColor.textSecondary)
        }
    }

    private func labeledField(title: String, placeholder: String, icon: String, text: Binding<String>, isRequired: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: DSLayout.spaceXS) {
            labelRow(title: title, icon: icon)
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .padding(DSLayout.spaceS)
                .background(DSColor.surfaceSecondary)
                .cornerRadius(DSLayout.radiusS)
                .overlay(
                    RoundedRectangle(cornerRadius: DSLayout.radiusS)
                        .stroke(
                            isRequired && text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isValid ? DSColor.accentError : DSColor.border,
                            lineWidth: 1
                        )
                )
        }
    }

    private func animateEntrance() {
        withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) { formScale = 1.0 }
        withAnimation(.easeOut(duration: 0.6).delay(0.2)) { headerOpacity = 1.0 }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4)) { contentOffset = 0 }
    }

    private func animateExit() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            formScale = 0.96
            headerOpacity = 0
            contentOffset = 32
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            presentationMode.wrappedValue.dismiss()
        }
    }

    private func load() {
        if let inst = dbManager.fetchInstitutionDetails(id: institutionId) {
            name = inst.name
            bic = inst.bic ?? ""
            type = inst.type ?? ""
            website = inst.website ?? ""
            contactInfo = inst.contactInfo ?? ""
            defaultCurrency = inst.defaultCurrency ?? ""
            countryCode = inst.countryCode ?? ""
            notes = inst.notes ?? ""
            isActive = inst.isActive
            loaded = true
        }
    }

    private func save() {
        guard isValid else {
            alertMessage = "Please fill the required fields."
            showingAlert = true
            return
        }
        isLoading = true
        let success = dbManager.updateInstitution(
            id: institutionId,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            bic: bic.isEmpty ? nil : bic,
            type: type.isEmpty ? nil : type,
            website: website.isEmpty ? nil : website,
            contactInfo: contactInfo.isEmpty ? nil : contactInfo,
            defaultCurrency: defaultCurrency.isEmpty ? nil : defaultCurrency,
            countryCode: countryCode.isEmpty ? nil : countryCode,
            notes: notes.isEmpty ? nil : notes,
            isActive: isActive
        )
        isLoading = false
        if success {
            NotificationCenter.default.post(name: NSNotification.Name("RefreshInstitutions"), object: nil)
            alertMessage = "✅ Updated"
        } else {
            alertMessage = "❌ Failed to update institution"
        }
        showingAlert = true
    }
}

// MARK: - Table Row

private struct ModernInstitutionRowView: View {
    let institution: DatabaseManager.InstitutionData
    let columns: [InstitutionTableColumn]
    let fontConfig: MaintenanceTableFontConfig
    let rowPadding: CGFloat
    let isSelected: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    let widthFor: (InstitutionTableColumn) -> CGFloat

    @State private var showNote = false

    var body: some View {
        HStack(spacing: 0) {
            ForEach(columns, id: \.self) { column in
                columnView(for: column)
            }
        }
        .padding(.trailing, DSLayout.spaceM)
        .padding(.vertical, max(4, rowPadding))
        .background(
            Rectangle()
                .fill(isSelected ? DSColor.accentMain.opacity(0.08) : Color.clear)
        )
        .overlay(
            Rectangle()
                .fill(DSColor.border)
                .frame(height: 1),
            alignment: .bottom
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .onTapGesture(count: 2) {
            onTap()
            onEdit()
        }
        .contextMenu {
            Button("Edit Institution", action: onEdit)
            Button("Select Institution", action: onTap)
            Divider()
            #if os(macOS)
                Button("Copy Name") {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(institution.name, forType: .string)
                }
                if let bic = institution.bic {
                    Button("Copy BIC") {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(bic, forType: .string)
                    }
                }
            #endif
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }

    @ViewBuilder
    private func columnView(for column: InstitutionTableColumn) -> some View {
        switch column {
        case .name:
            Text(institution.name)
                .font(.system(size: fontConfig.primary, weight: .medium))
                .foregroundColor(DSColor.textPrimary)
                .padding(.leading, InstitutionsView.columnTextInset)
                .padding(.trailing, DSLayout.spaceS)
                .frame(width: widthFor(.name), alignment: .leading)
        case .bic:
            Text(institution.bic ?? "--")
                .font(.system(size: fontConfig.secondary, design: .monospaced))
                .foregroundColor(DSColor.textSecondary)
                .padding(.leading, InstitutionsView.columnTextInset)
                .padding(.trailing, DSLayout.spaceS)
                .frame(width: widthFor(.bic), alignment: .leading)
        case .type:
            Text(institution.type ?? "--")
                .font(.system(size: fontConfig.secondary))
                .foregroundColor(DSColor.textSecondary)
                .padding(.leading, InstitutionsView.columnTextInset)
                .padding(.trailing, DSLayout.spaceS)
                .frame(width: widthFor(.type), alignment: .leading)
        case .currency:
            let currency = institution.defaultCurrency ?? "--"
            Text(currency.isEmpty ? "--" : currency)
                .font(.system(size: fontConfig.badge, weight: .semibold))
                .foregroundColor(DSColor.textPrimary)
                .padding(.horizontal, DSLayout.spaceS)
                .padding(.vertical, 2)
                .background(DSColor.accentMain.opacity(currency.isEmpty ? 0.06 : 0.12))
                .clipShape(Capsule())
                .padding(.leading, InstitutionsView.columnTextInset)
                .padding(.trailing, DSLayout.spaceS)
                .frame(width: widthFor(.currency), alignment: .leading)
        case .country:
            countryColumn
                .padding(.leading, InstitutionsView.columnTextInset)
                .padding(.trailing, DSLayout.spaceS)
                .frame(width: widthFor(.country), alignment: .leading)
        case .website:
            Text(websiteDisplay)
                .font(.system(size: fontConfig.secondary))
                .foregroundColor(DSColor.textSecondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.leading, InstitutionsView.columnTextInset)
                .padding(.trailing, DSLayout.spaceS)
                .frame(width: widthFor(.website), alignment: .leading)
        case .contact:
            Text(contactDisplay)
                .font(.system(size: fontConfig.secondary))
                .foregroundColor(DSColor.textSecondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.leading, InstitutionsView.columnTextInset)
                .padding(.trailing, DSLayout.spaceS)
                .frame(width: widthFor(.contact), alignment: .leading)
        case .notes:
            notesColumn
                .frame(width: widthFor(.notes), alignment: .center)
        case .status:
            HStack(spacing: DSLayout.spaceXS) {
                Circle()
                    .fill(institution.isActive ? DSColor.accentSuccess : DSColor.accentWarning)
                    .frame(width: 8, height: 8)
                Text(institution.isActive ? "Active" : "Inactive")
                    .font(.system(size: fontConfig.secondary, weight: .medium))
                    .foregroundColor(institution.isActive ? DSColor.accentSuccess : DSColor.accentWarning)
            }
            .frame(width: widthFor(.status), alignment: .center)
        }
    }

    private struct CountryPresentation {
        let flag: String?
        let name: String
        let code: String?

        var accessibilityLabel: String {
            guard let code = code, code.caseInsensitiveCompare(name) != .orderedSame else { return name }
            return "\(name), \(code)"
        }
    }

    @ViewBuilder
    private var countryColumn: some View {
        if let info = countryPresentation {
            HStack(spacing: DSLayout.spaceXS) {
                if let flag = info.flag {
                    Text(flag)
                        .accessibilityHidden(true)
                }
                Text(info.name)
                    .foregroundColor(DSColor.textSecondary)
            }
            .font(.system(size: fontConfig.secondary))
            .accessibilityElement(children: .combine)
            .accessibilityLabel(info.accessibilityLabel)
        } else {
            Text("--")
                .font(.system(size: fontConfig.secondary))
                .foregroundColor(DSColor.textSecondary)
        }
    }

    private var countryPresentation: CountryPresentation? {
        guard let raw = institution.countryCode?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty, raw != "--" else { return nil }
        if let code = normalizedRegionCode(from: raw) {
            let localized = localizedName(forRegionCode: code)
            let flag = flagEmoji(code)
            return CountryPresentation(flag: flag.isEmpty ? nil : flag, name: localized, code: code)
        }
        if let legacy = parseLegacyCountryField(raw) {
            return legacy
        }
        if let cleanedName = sanitizedCountryName(from: raw), !cleanedName.isEmpty {
            return CountryPresentation(flag: nil, name: cleanedName, code: nil)
        }
        return CountryPresentation(flag: nil, name: raw, code: nil)
    }

    private func parseLegacyCountryField(_ raw: String) -> CountryPresentation? {
        let flag = extractFlag(from: raw)
        let nameCandidate = sanitizedCountryName(from: raw)

        if flag == nil, nameCandidate == nil { return nil }

        if let flag = flag {
            let code = regionCode(fromFlag: flag)
            let localized = code.flatMap { localizedName(forRegionCode: $0) } ?? nameCandidate ?? raw
            return CountryPresentation(flag: flag, name: localized, code: code)
        }

        if let name = nameCandidate {
            if let code = matchRegionCode(forName: name) {
                let flag = flagEmoji(code)
                let localized = localizedName(forRegionCode: code)
                return CountryPresentation(flag: flag.isEmpty ? nil : flag, name: localized, code: code)
            }
            return CountryPresentation(flag: nil, name: name, code: nil)
        }

        return nil
    }

    private var websiteDisplay: String {
        guard let website = institution.website?.trimmingCharacters(in: .whitespacesAndNewlines), !website.isEmpty else { return "--" }
        if let url = URL(string: website), let host = url.host {
            return host
        }
        if let url = URL(string: "https://\(website)"), let host = url.host {
            return host
        }
        return website
    }

    private var contactDisplay: String {
        let value = institution.contactInfo?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (value?.isEmpty ?? true) ? "--" : value!
    }

    @ViewBuilder
    private var notesColumn: some View {
        if let note = institution.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
            Button(action: { showNote = true }) {
                Image(systemName: "note.text")
                    .font(.system(size: 14))
                    .foregroundColor(DSColor.accentMain)
            }
            .buttonStyle(PlainButtonStyle())
            .alert("Note", isPresented: $showNote) {
                Button("Close", role: .cancel) {}
            } message: {
                Text(note)
            }
        } else {
            Image(systemName: "note.text")
                .font(.system(size: 14))
                .foregroundColor(DSColor.textTertiary)
        }
    }
}

// MARK: - Country Helpers

private func normalizedRegionCode(from raw: String) -> String? {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    let separators = CharacterSet(charactersIn: " -_/|.,")
    let uppercase = trimmed.uppercased()
    let uppercaseComponents = uppercase.components(separatedBy: separators).filter { !$0.isEmpty }
    let tokens = ([uppercase] + uppercaseComponents)
        .map { $0.filter { ("A" ... "Z").contains($0) } }
        .filter { !$0.isEmpty }

    for candidate in tokens where candidate.count == 2 {
        if isoRegionIdentifierSet.contains(candidate) {
            return candidate
        }
    }

    if let flag = extractFlag(from: trimmed), let code = regionCode(fromFlag: flag) {
        return code
    }

    if let name = sanitizedCountryName(from: trimmed), let code = matchRegionCode(forName: name) {
        return code
    }

    if let fallback = tokens.first(where: { $0.count >= 2 }) {
        let prefix = String(fallback.prefix(2))
        if isoRegionIdentifierSet.contains(prefix) {
            return prefix
        }
    }

    if uppercase.count >= 2 {
        let prefix = String(uppercase.prefix(2))
        if isoRegionIdentifierSet.contains(prefix) {
            return prefix
        }
    }

    return nil
}

private func flagEmoji(_ code: String) -> String {
    let upper = code.uppercased()
    guard upper.count == 2 else { return "" }
    var scalars = String.UnicodeScalarView()
    for scalar in upper.unicodeScalars {
        guard (65 ... 90).contains(scalar.value), let flagScalar = UnicodeScalar(127_397 + scalar.value) else { return "" }
        scalars.append(flagScalar)
    }
    return String(scalars)
}

private func extractFlag(from raw: String) -> String? {
    var buffer = String.UnicodeScalarView()
    for scalar in raw.unicodeScalars {
        let value = scalar.value
        if (127_462 ... 127_487).contains(value) {
            buffer.append(scalar)
            if buffer.count == 2 {
                return String(buffer)
            }
        } else {
            buffer.removeAll(keepingCapacity: false)
        }
    }
    return nil
}

private func regionCode(fromFlag flag: String) -> String? {
    let scalars = flag.unicodeScalars.filter { (127_462 ... 127_487).contains($0.value) }
    guard scalars.count == 2 else { return nil }
    var code = ""
    for scalar in scalars {
        let value = scalar.value - 127_397
        guard let letter = UnicodeScalar(value) else { return nil }
        code.append(Character(letter))
    }
    return code
}

private func sanitizedCountryName(from raw: String) -> String? {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    let separators = CharacterSet(charactersIn: "/|")
    let parentheses = CharacterSet(charactersIn: "()[]{}")
    let segments = trimmed.components(separatedBy: separators)

    for segment in segments.reversed() {
        let cleaned = segment.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: parentheses)
        guard !cleaned.isEmpty else { continue }
        if extractFlag(from: cleaned) != nil { continue }
        return cleaned
    }

    return nil
}

private func matchRegionCode(forName candidate: String) -> String? {
    let key = normalizedCountryLookupKey(candidate)
    guard !key.isEmpty else { return nil }

    enum LookupCache {
        static let english = build(locale: Locale(identifier: "en_US"))
        static let current = build(locale: Locale.current)

        static func build(locale: Locale) -> [String: String] {
            var map: [String: String] = [:]
            for code in isoRegionIdentifiers {
                if let name = locale.localizedString(forRegionCode: code) {
                    let key = normalizedCountryLookupKey(name)
                    if !key.isEmpty {
                        map[key] = code
                    }
                }
            }
            return map
        }
    }

    return LookupCache.current[key] ?? LookupCache.english[key]
}

private func localizedName(forRegionCode code: String) -> String {
    for locale in [Locale.current, Locale(identifier: "en_US"), Locale(identifier: "en_GB")] {
        if let name = locale.localizedString(forRegionCode: code) {
            return name
        }
    }
    return code
}

private func normalizedCountryLookupKey(_ value: String) -> String {
    value
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US"))
}
