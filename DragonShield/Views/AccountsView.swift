// DragonShield/Views/AccountsView.swift

// MARK: - Version 1.7

// MARK: - History

// - 1.6 -> 1.7: Adopted Institutions/Instruments table UX with resizable columns, filters, and persisted preferences.
// - 1.4 -> 1.5: Accounts now reference Institutions. Added picker fields.
// - 1.5 -> 1.6: Added institution picker to Edit view to resolve compile error.
// - 1.3 -> 1.4: Updated deprecated onChange modifiers to new syntax for macOS 14.0+.
// - 1.2 -> 1.3: Updated Add/Edit views to use Picker for AccountType based on normalized schema.
// - 1.2 (Corrected - Full): Ensured all helper views like accountsContent, emptyStateView, accountsTable are fully defined within AccountsView. Provided full implementations for helper functions in Add/Edit views and fixed animation function signatures.
// - 1.1 -> 1.2: Updated Add/Edit views to include institutionBic, optional openingDate, and optional closingDate.
// - 1.0 -> 1.1: Fixed EditAccountView initializer access level and incorrect String.trim() calls. Corrected onChange usage in text fields.

import Foundation
import SwiftUI
#if os(macOS)
    import AppKit
#elseif canImport(UIKit)
    import UIKit
#endif

private enum AccountTableColumn: String, CaseIterable, Codable, MaintenanceTableColumn {
    case name
    case number
    case institution
    case bic
    case type
    case currency
    case portfolio
    case status
    case earliestUpdate
    case openingDate
    case closingDate
    case notes

    var title: String {
        switch self {
        case .name: return "Account"
        case .number: return "Number"
        case .institution: return "Institution"
        case .bic: return "BIC"
        case .type: return "Type"
        case .currency: return "Cur"
        case .portfolio: return "Portfolio"
        case .status: return "Status"
        case .earliestUpdate: return "Earliest Updated"
        case .openingDate: return "Opened"
        case .closingDate: return "Closed"
        case .notes: return ""
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

struct AccountsView: View {
    @EnvironmentObject var dbManager: DatabaseManager

    @State private var accounts: [DatabaseManager.AccountData] = []
    @State private var selectedAccount: DatabaseManager.AccountData? = nil

    @State private var searchText = ""
    @State private var typeFilters: Set<String> = []
    @State private var currencyFilters: Set<String> = []
    @State private var statusFilters: Set<String> = []

    @State private var showAddAccountSheet = false
    @State private var showEditAccountSheet = false
    @State private var showingDeleteAlert = false
    @State private var accountToDelete: DatabaseManager.AccountData? = nil
    @State private var isRefreshing = false
    @State private var showRefreshAlert = false
    @State private var refreshMessage: String = ""

    @State private var sortColumn: AccountTableColumn = .name
    @State private var sortAscending: Bool = true

    @StateObject private var tableModel = ResizableTableViewModel<AccountTableColumn>(configuration: AccountsView.tableConfiguration)

    @State private var headerOpacity: Double = 0
    @State private var contentOffset: CGFloat = 30
    @State private var buttonsOpacity: Double = 0

    private static let visibleColumnsKey = "AccountsView.visibleColumns.v1"
    private static let columnOrder: [AccountTableColumn] = [
        .name, .number, .institution, .bic, .type, .currency, .portfolio, .status, .earliestUpdate, .openingDate, .closingDate, .notes,
    ]
    private static let defaultVisibleColumns: Set<AccountTableColumn> = [
        .name, .institution, .type, .currency, .portfolio, .status, .earliestUpdate,
    ]
    private static let requiredColumns: Set<AccountTableColumn> = [.name]
    
    fileprivate static let tableConfiguration = MaintenanceTableConfiguration<AccountTableColumn>(
        preferenceKind: .accounts,
        columnOrder: columnOrder,
        defaultVisibleColumns: defaultVisibleColumns,
        requiredColumns: requiredColumns,
        defaultColumnWidths: [
            .name: 200,
            .number: 120,
            .institution: 150,
            .bic: 100,
            .type: 100,
            .currency: 60,
            .portfolio: 100,
            .status: 80,
            .earliestUpdate: 120,
            .openingDate: 100,
            .closingDate: 100,
            .notes: 60
        ],
        minimumColumnWidths: [
            .name: 150,
            .number: 100,
            .institution: 120,
            .bic: 80,
            .type: 80,
            .currency: 50,
            .portfolio: 80,
            .status: 60,
            .earliestUpdate: 100,
            .openingDate: 90,
            .closingDate: 90,
            .notes: 40
        ],
        visibleColumnsDefaultsKey: "AccountsView.visibleColumns.v1",
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
    private static let headerBackground = DSColor.surfaceSecondary
    fileprivate static let columnHandleWidth: CGFloat = 10
    fileprivate static let columnHandleHitSlop: CGFloat = 8
    fileprivate static let columnTextInset: CGFloat = DSLayout.spaceS

    private var secondaryActionTint: Color {
        DSColor.textSecondary
    }

    // ... (existing column widths)

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

    // ... (existing tableConfiguration)

    private var totalStatValue: String {
        String(accounts.count)
    }
    
    private var activeStatValue: String {
        String(accounts.filter { $0.isActive }.count)
    }
    
    private var portfolioStatValue: String {
        String(accounts.filter { $0.includeInPortfolio }.count)
    }
    
    private var isFiltering: Bool {
        !searchText.isEmpty || !typeFilters.isEmpty || !currencyFilters.isEmpty || !statusFilters.isEmpty
    }
    
    private var sortedAccounts: [DatabaseManager.AccountData] {
        let filtered = accounts.filter { account in
            if !searchText.isEmpty {
                if !account.accountName.localizedCaseInsensitiveContains(searchText) &&
                   !account.accountNumber.localizedCaseInsensitiveContains(searchText) &&
                   !account.institutionName.localizedCaseInsensitiveContains(searchText) {
                    return false
                }
            }
            if !typeFilters.isEmpty && !typeFilters.contains(normalized(account.accountType)) { return false }
            if !currencyFilters.isEmpty && !currencyFilters.contains(normalized(account.currencyCode)) { return false }
            if !statusFilters.isEmpty {
                let status = account.isActive ? "Active" : "Inactive"
                if !statusFilters.contains(status) { return false }
            }
            return true
        }
        
        return filtered.sorted { a, b in
            switch sortColumn {
            case .name: return sortAscending ? a.accountName < b.accountName : a.accountName > b.accountName
            case .number: return sortAscending ? a.accountNumber < b.accountNumber : a.accountNumber > b.accountNumber
            case .institution: return sortAscending ? a.institutionName < b.institutionName : a.institutionName > b.institutionName
            case .bic: return sortAscending ? (a.institutionBic ?? "") < (b.institutionBic ?? "") : (a.institutionBic ?? "") > (b.institutionBic ?? "")
            case .type: return sortAscending ? a.accountType < b.accountType : a.accountType > b.accountType
            case .currency: return sortAscending ? a.currencyCode < b.currencyCode : a.currencyCode > b.currencyCode
            case .portfolio: return sortAscending ? (a.includeInPortfolio && !b.includeInPortfolio) : (!a.includeInPortfolio && b.includeInPortfolio)
            case .status: return sortAscending ? (a.isActive && !b.isActive) : (!a.isActive && b.isActive)
            case .earliestUpdate:
                let d1 = a.earliestInstrumentLastUpdatedAt ?? Date.distantPast
                let d2 = b.earliestInstrumentLastUpdatedAt ?? Date.distantPast
                return sortAscending ? d1 < d2 : d1 > d2
            case .openingDate:
                let d1 = a.openingDate ?? Date.distantPast
                let d2 = b.openingDate ?? Date.distantPast
                return sortAscending ? d1 < d2 : d1 > d2
            case .closingDate:
                let d1 = a.closingDate ?? Date.distantPast
                let d2 = b.closingDate ?? Date.distantPast
                return sortAscending ? d1 < d2 : d1 > d2
            case .notes: return true
            }
        }
    }
    
    private func normalized(_ string: String) -> String {
        string.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var fontSizeBinding: Binding<MaintenanceTableFontSize> {
        $tableModel.selectedFontSize
    }

    var body: some View {
        ZStack {
            DSColor.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                modernHeader
                searchAndStats
                accountsContent
                modernActionBar
            }
        }
        .onAppear {
            loadData()
            animateEntrance()
        }
        .sheet(isPresented: $showAddAccountSheet) {
            AddAccountView()
                .environmentObject(dbManager)
        }
        .sheet(isPresented: $showEditAccountSheet) {
            if let account = selectedAccount {
                EditAccountView(accountId: account.id)
                    .environmentObject(dbManager)
            }
        }
        .onChange(of: showingDeleteAlert) { _, newValue in
            if newValue {
                if let account = accountToDelete {
                    confirmDelete(account)
                }
                showingDeleteAlert = false
            }
        }
        .alert("Refresh Result", isPresented: $showRefreshAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(refreshMessage)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshAccounts"))) { _ in
            loadData()
        }
    }

    // ... (existing helper functions)

    private var modernHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: DSLayout.spaceXS) {
                HStack(spacing: DSLayout.spaceM) {
                    Image(systemName: "building.columns.fill")
                        .font(.system(size: 32))
                        .foregroundColor(DSColor.accentMain)
                    Text("Accounts")
                        .dsHeaderLarge()
                        .foregroundColor(DSColor.textPrimary)
                }
                Text("Manage brokerage, bank, and exchange accounts")
                    .dsBody()
                    .foregroundColor(DSColor.textSecondary)
            }

            Spacer()

            HStack(spacing: DSLayout.spaceL) {
                modernStatCard(title: "Total", value: totalStatValue, icon: "number.circle.fill", color: DSColor.accentMain)
                modernStatCard(title: "Active", value: activeStatValue, icon: "checkmark.circle.fill", color: DSColor.accentSuccess)
                modernStatCard(title: "In Portfolio", value: portfolioStatValue, icon: "briefcase.fill", color: DSColor.textSecondary)
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
                TextField("Search accounts...", text: $searchText)
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
                HStack {
                    Text("Found \(sortedAccounts.count) of \(accounts.count) accounts")
                        .dsCaption()
                        .foregroundColor(DSColor.textSecondary)
                    Spacer()
                }

                if !typeFilters.isEmpty || !currencyFilters.isEmpty || !statusFilters.isEmpty {
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
            }
        }
        .padding(.horizontal, DSLayout.spaceL)
    }

    private var accountsContent: some View {
        VStack(spacing: DSLayout.spaceM) {
            tableControls
            if sortedAccounts.isEmpty {
                emptyStateView
                    .offset(y: contentOffset)
            } else {
                accountsTable
                    .offset(y: contentOffset)
            }
        }
        .padding(.horizontal, DSLayout.spaceL)
        .padding(.top, DSLayout.spaceS)
    }

    private var tableControls: some View {
        HStack(spacing: DSLayout.spaceM) {
            columnsMenu
            fontSizePicker
            Spacer()
            if tableModel.visibleColumns != AccountsView.defaultVisibleColumns || tableModel.selectedFontSize != .medium {
                Button("Reset View", action: resetTablePreferences)
                    .buttonStyle(.link)
                    .font(.ds.caption)
            }
        }
        .padding(.horizontal, 4)
    }

    private var columnsMenu: some View {
        Menu {
            ForEach(AccountsView.columnOrder, id: \.self) { column in
                let isVisible = tableModel.visibleColumns.contains(column)
                Button {
                    toggleColumn(column)
                } label: {
                    Label(column.menuTitle, systemImage: isVisible ? "checkmark" : "")
                }
                .disabled(isVisible && (tableModel.visibleColumns.count == 1 || AccountsView.requiredColumns.contains(column)))
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
        .frame(maxWidth: 260)
        .labelsHidden()
    }

    private var emptyStateView: some View {
        VStack(spacing: DSLayout.spaceL) {
            Spacer()
            VStack(spacing: DSLayout.spaceM) {
                Image(systemName: searchText.isEmpty ? "building.columns" : "magnifyingglass")
                    .font(.system(size: 64))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [DSColor.textTertiary, DSColor.textTertiary.opacity(0.5)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                VStack(spacing: DSLayout.spaceS) {
                    Text(searchText.isEmpty ? "No accounts yet" : "No matching accounts")
                        .dsHeaderMedium()
                        .foregroundColor(DSColor.textSecondary)
                    Text(searchText.isEmpty ? "Add your first account to get started." : "Try adjusting your search or filters.")
                        .dsBody()
                        .foregroundColor(DSColor.textTertiary)
                        .multilineTextAlignment(.center)
                }
                if searchText.isEmpty {
                    Button {
                        showAddAccountSheet = true
                    } label: {
                        Label("Add Account", systemImage: "plus")
                    }
                    .buttonStyle(DSButtonStyle(type: .primary))
                    .padding(.top, DSLayout.spaceS)
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var accountsTable: some View {
        MaintenanceTableView(
            model: tableModel,
            rows: sortedAccounts,
            rowSpacing: 0,
            showHorizontalIndicators: true,
            rowContent: { account, context in
                ModernAccountRowView(
                    account: account,
                    columns: context.columns,
                    fontConfig: context.fontConfig,
                    rowPadding: CGFloat(dbManager.tableRowPadding),
                    isSelected: selectedAccount?.id == account.id,
                    onTap: {
                        selectedAccount = account
                    },
                    onEdit: {
                        selectedAccount = account
                        showEditAccountSheet = true
                    },
                    widthFor: { context.widthForColumn($0) }
                )
            },
            headerContent: { column, fontConfig in
                accountsHeaderContent(for: column, fontConfig: fontConfig)
            }
        )
    }

    private func accountsHeaderContent(for column: AccountTableColumn, fontConfig: MaintenanceTableFontConfig) -> some View {
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

    private func filterChip(text: String, onRemove: @escaping () -> Void) -> some View {
        DSBadge(text: text, color: DSColor.accentMain)
            .overlay(
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(DSColor.textOnAccent)
                }
                .padding(.leading, 4)
                , alignment: .trailing
            )
    }

    private var modernActionBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(DSColor.border)
                .frame(height: 1)

            HStack(spacing: DSLayout.spaceM) {
                Button {
                    showAddAccountSheet = true
                } label: {
                    Label("Add Account", systemImage: "plus")
                }
                .buttonStyle(DSButtonStyle(type: .primary))

                Button {
                    isRefreshing = true
                    dbManager.refreshEarliestInstrumentTimestamps { result in
                        isRefreshing = false
                        switch result {
                        case let .success(count):
                            refreshMessage = "✅ Updated earliest timestamps for \(count) accounts."
                        case .failure:
                            refreshMessage = "❌ Failed to refresh timestamps."
                        }
                        showRefreshAlert = true
                        loadData()
                    }
                } label: {
                    HStack(spacing: 6) {
                        if isRefreshing {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text("Refresh Instrument Timestamps")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(secondaryActionTint)
                .foregroundColor(.primary)
                .disabled(isRefreshing)

                if selectedAccount != nil {
                    Button {
                        showEditAccountSheet = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(secondaryActionTint)
                    .foregroundColor(.primary)

                    Button {
                        if let acc = selectedAccount {
                            accountToDelete = acc
                            showingDeleteAlert = true
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(secondaryActionTint)
                    .foregroundColor(.primary)
                }

                Spacer()

                if let account = selectedAccount {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                        Text("Selected: \(account.accountName)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.05))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(.regularMaterial)
        }
        .opacity(buttonsOpacity)
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

    private func loadData() {
        accounts = dbManager.fetchAccounts()
    }

    private func filterBinding(for column: AccountTableColumn) -> Binding<Set<String>>? {
        switch column {
        case .type:
            return $typeFilters
        case .currency:
            return $currencyFilters
        case .status:
            return $statusFilters
        default:
            return nil
        }
    }

    private func filterValues(for column: AccountTableColumn) -> [String] {
        switch column {
        case .type:
            return Array(Set(accounts.map { normalized($0.accountType) }.filter { !$0.isEmpty })).sorted()
        case .currency:
            return Array(Set(accounts.map { normalized($0.currencyCode) }.filter { !$0.isEmpty })).sorted()
        case .status:
            return ["Active", "Inactive"]
        default:
            return []
        }
    }

    private func sortOption(for column: AccountTableColumn) -> AccountTableColumn? {
        switch column {
        case .notes: return nil
        default: return column
        }
    }

    private func toggleColumn(_ column: AccountTableColumn) {
        tableModel.toggleColumn(column)
        ensureFiltersetsWithinVisibleColumns()
        ensureValidSortColumn()
    }

    private func resetVisibleColumns() {
        tableModel.resetVisibleColumns()
        ensureFiltersetsWithinVisibleColumns()
        ensureValidSortColumn()
    }

    private func resetTablePreferences() {
        tableModel.resetTablePreferences()
        ensureFiltersetsWithinVisibleColumns()
        ensureValidSortColumn()
    }

    private func ensureValidSortColumn() {
        if !tableModel.visibleColumns.contains(sortColumn) {
            if let fallback = tableModel.activeColumns.compactMap({ sortOption(for: $0) }).first {
                sortColumn = fallback
            } else {
                sortColumn = .name
            }
        }
    }



    private func ensureFiltersetsWithinVisibleColumns() {
        if !tableModel.visibleColumns.contains(AccountTableColumn.type) {
            typeFilters.removeAll()
        }
        if !tableModel.visibleColumns.contains(AccountTableColumn.currency) {
            currencyFilters.removeAll()
        }
        if !tableModel.visibleColumns.contains(AccountTableColumn.status) {
            statusFilters.removeAll()
        }
    }

    private func confirmDisable(_ account: DatabaseManager.AccountData) {
        let result = dbManager.canDeleteAccount(id: account.id)
        if result.canDelete {
            let alert = NSAlert()
            alert.messageText = "Disable Account"
            alert.informativeText = "Are you sure you want to disable '\\(account.accountName)'?"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Disable")
            alert.addButton(withTitle: "Cancel")
            if alert.runModal() == .alertFirstButtonReturn {
                if dbManager.disableAccount(id: account.id) {
                    loadData()
                    selectedAccount = nil
                    accountToDelete = nil
                }
            }
        } else {
            let alert = NSAlert()
            alert.messageText = "Cannot Disable Account"
            alert.informativeText = result.message
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    private func confirmDelete(_ account: DatabaseManager.AccountData) {
        let result = dbManager.canDeleteAccount(id: account.id)
        if result.canDelete {
            let alert = NSAlert()
            alert.messageText = "Delete Account"
            alert.informativeText = "Are you sure you want to permanently delete '\\(account.accountName)'?"
            alert.alertStyle = .critical
            alert.addButton(withTitle: "Delete")
            alert.addButton(withTitle: "Cancel")
            if alert.runModal() == .alertFirstButtonReturn {
                if dbManager.deleteAccount(id: account.id) {
                    loadData()
                    selectedAccount = nil
                    accountToDelete = nil
                }
            }
        } else {
            let alert = NSAlert()
            alert.messageText = "Cannot Delete Account"
            alert.informativeText = result.message
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}

private struct ModernAccountRowView: View {
    let account: DatabaseManager.AccountData
    let columns: [AccountTableColumn]
    let fontConfig: MaintenanceTableFontConfig
    let rowPadding: CGFloat
    let isSelected: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    let widthFor: (AccountTableColumn) -> CGFloat

    @State private var showNote = false

    var body: some View {
        HStack(spacing: 0) {
            ForEach(columns, id: \.self) { column in
                columnView(for: column)
            }
        }
        .padding(.trailing, 12)
        .padding(.vertical, max(4, rowPadding))
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
        .onTapGesture(count: 2) {
            onTap()
            onEdit()
        }
        .contextMenu {
            Button("Edit Account", action: onEdit)
            Button("Select Account", action: onTap)
            #if os(macOS)
                Divider()
                Button("Copy Account Number") {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(account.accountNumber, forType: .string)
                }
                Button("Copy Institution") {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(account.institutionName, forType: .string)
                }
            #endif
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }

    @ViewBuilder
    private func columnView(for column: AccountTableColumn) -> some View {
        switch column {
        case .name:
            VStack(alignment: .leading, spacing: 2) {
                Text(account.accountName)
                    .font(.system(size: fontConfig.primary, weight: .medium))
                    .foregroundColor(DSColor.textPrimary)
                Text("Number: \(account.accountNumber)")
                    .font(.system(size: max(10, fontConfig.badge), design: .monospaced))
                    .foregroundColor(DSColor.textSecondary)
                if let bic = account.institutionBic, !bic.isEmpty {
                    Text("BIC: \(bic)")
                        .font(.system(size: max(10, fontConfig.badge)))
                        .foregroundColor(DSColor.textTertiary)
                }
            }
            .padding(.leading, AccountsView.columnTextInset)
            .padding(.trailing, 8)
            .frame(width: widthFor(.name), alignment: .leading)
        case .number:
            Text(account.accountNumber)
                .font(.system(size: fontConfig.secondary, design: .monospaced))
                .foregroundColor(DSColor.textSecondary)
                .padding(.leading, AccountsView.columnTextInset)
                .padding(.trailing, 8)
                .frame(width: widthFor(.number), alignment: .leading)
        case .institution:
            Text(account.institutionName)
                .font(.system(size: fontConfig.secondary))
                .foregroundColor(DSColor.textSecondary)
                .padding(.leading, AccountsView.columnTextInset)
                .padding(.trailing, 8)
                .frame(width: widthFor(.institution), alignment: .leading)
        case .bic:
            Text(account.institutionBic ?? "--")
                .font(.system(size: fontConfig.secondary, design: .monospaced))
                .foregroundColor(DSColor.textSecondary)
                .padding(.leading, AccountsView.columnTextInset)
                .padding(.trailing, 8)
                .frame(width: widthFor(.bic), alignment: .leading)
        case .type:
            Text(account.accountType)
                .font(.system(size: fontConfig.secondary))
                .foregroundColor(DSColor.textSecondary)
                .padding(.leading, AccountsView.columnTextInset)
                .padding(.trailing, 8)
                .frame(width: widthFor(.type), alignment: .leading)
        case .currency:
            Text(account.currencyCode)
                .font(.system(size: fontConfig.badge, weight: .semibold))
                .foregroundColor(DSColor.textOnAccent)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(DSColor.accentMain)
                .clipShape(Capsule())
                .padding(.leading, AccountsView.columnTextInset)
                .padding(.trailing, 8)
                .frame(width: widthFor(.currency), alignment: .leading)
        case .portfolio:
            HStack(spacing: 6) {
                Image(systemName: account.includeInPortfolio ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(account.includeInPortfolio ? DSColor.accentSuccess : DSColor.textTertiary)
                Text(account.includeInPortfolio ? "Included" : "Excluded")
                    .font(.system(size: fontConfig.secondary, weight: .medium))
                    .foregroundColor(account.includeInPortfolio ? DSColor.accentSuccess : DSColor.textSecondary)
            }
            .padding(.leading, AccountsView.columnTextInset)
            .padding(.trailing, 8)
            .frame(width: widthFor(.portfolio), alignment: .leading)
        case .status:
            HStack(spacing: 6) {
                Circle()
                    .fill(account.isActive ? DSColor.accentSuccess : DSColor.accentWarning)
                    .frame(width: 8, height: 8)
                Text(account.isActive ? "Active" : "Inactive")
                    .font(.system(size: fontConfig.secondary, weight: .medium))
                    .foregroundColor(account.isActive ? DSColor.accentSuccess : DSColor.accentWarning)
            }
            .frame(width: widthFor(.status), alignment: .center)
        case .earliestUpdate:
            Text(displayDate(account.earliestInstrumentLastUpdatedAt))
                .font(.system(size: fontConfig.secondary))
                .foregroundColor(DSColor.textSecondary)
                .padding(.leading, AccountsView.columnTextInset)
                .padding(.trailing, 8)
                .frame(width: widthFor(.earliestUpdate), alignment: .leading)
        case .openingDate:
            Text(displayDate(account.openingDate))
                .font(.system(size: fontConfig.secondary))
                .foregroundColor(DSColor.textSecondary)
                .padding(.leading, AccountsView.columnTextInset)
                .padding(.trailing, 8)
                .frame(width: widthFor(.openingDate), alignment: .leading)
        case .closingDate:
            Text(displayDate(account.closingDate))
                .font(.system(size: fontConfig.secondary))
                .foregroundColor(account.isActive ? DSColor.textSecondary : DSColor.accentWarning)
                .padding(.leading, AccountsView.columnTextInset)
                .padding(.trailing, 8)
                .frame(width: widthFor(.closingDate), alignment: .leading)
        case .notes:
            notesColumn
                .frame(width: widthFor(.notes), alignment: .center)
        }
    }

    private var trimmedNote: String? {
        account.notes?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @ViewBuilder
    private var notesColumn: some View {
        if let note = trimmedNote, !note.isEmpty {
            Button { showNote = true } label: {
                Image(systemName: "note.text")
                    .foregroundColor(DSColor.accentMain)
            }
            .buttonStyle(PlainButtonStyle())
            .popover(isPresented: $showNote) {
                VStack(alignment: .leading, spacing: DSLayout.spaceS) {
                    Text("Notes")
                        .dsHeaderSmall()
                        .foregroundColor(DSColor.textPrimary)
                    Text(note)
                        .dsBody()
                        .foregroundColor(DSColor.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(DSLayout.spaceM)
                .frame(width: 260)
                .background(DSColor.surface)
            }
        } else {
            Image(systemName: "note.text")
                .foregroundColor(DSColor.textTertiary)
        }
    }

    private func displayDate(_ date: Date?) -> String {
        guard let date else { return "—" }
        return DateFormatter.userFacingFormatter.string(from: date)
    }
}

private extension DateFormatter {
    static let userFacingFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}

// Add Account View - MODIFIED
struct AddAccountView: View {
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject var dbManager: DatabaseManager

    @State private var accountName: String = ""
    @State private var selectedInstitutionId: Int? = nil
    @State private var availableInstitutions: [DatabaseManager.InstitutionData] = []
    @State private var accountNumber: String = ""
    @State private var selectedAccountTypeId: Int? = nil
    @State private var availableAccountTypes: [DatabaseManager.AccountTypeData] = []

    @State private var currencyCode: String = ""
    @State private var setOpeningDate: Bool = false
    @State private var openingDateInput: Date = .init()
    @State private var setClosingDate: Bool = false
    @State private var closingDateInput: Date = .init()
    @State private var earliestInstrumentDate: Date? = nil
    @State private var includeInPortfolio: Bool = true
    @State private var isActive: Bool = true
    @State private var notes: String = ""
    @State private var availableCurrencies: [(code: String, name: String, symbol: String)] = []
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    @State private var formScale: CGFloat = 0.9
    @State private var headerOpacity: Double = 0
    @State private var sectionsOffset: CGFloat = 50

    var isValid: Bool {
        !accountName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            selectedInstitutionId != nil &&
            !accountNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            selectedAccountTypeId != nil &&
            !currencyCode.isEmpty &&
            (setClosingDate ? (setOpeningDate ? closingDateInput >= openingDateInput : true) : true)
    }

    var body: some View {
        ZStack {
            DSColor.background
                .ignoresSafeArea()
            VStack(spacing: 0) {
                addModernHeader
                addModernContent
            }
        }
        .frame(width: 650, height: 820)
        .clipShape(RoundedRectangle(cornerRadius: DSLayout.radiusL))
        .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
        .scaleEffect(formScale)
        .onAppear {
            loadInitialData()
            animateAddEntrance()
        }
        .alert("Result", isPresented: $showingAlert) {
            Button("OK") {
                if alertMessage.contains("✅") {
                    animateAddExit()
                } else {
                    showingAlert = false
                }
            }
        } message: {
            Text(alertMessage)
        }
    }

    private var addModernHeader: some View {
        HStack {
            Button {
                animateAddExit()
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
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(DSColor.accentMain)
                Text("Add Account")
                    .dsHeaderLarge()
                    .foregroundColor(DSColor.textPrimary)
            }

            Spacer()

            Button {
                saveAccount()
            } label: {
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
            .disabled(isLoading || !isValid)
            .disabled(isLoading || !isValid)
        }
        .padding(.horizontal, DSLayout.spaceL)
        .padding(.vertical, DSLayout.spaceL)
        .opacity(headerOpacity)
    }

    private func animateAddEntrance() {
        withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) { formScale = 1.0 }
        withAnimation(.easeOut(duration: 0.6).delay(0.2)) { headerOpacity = 1.0 }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4)) { sectionsOffset = 0 }
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

    private func addModernTextField(title: String, text: Binding<String>, placeholder: String, icon: String, isRequired: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: DSLayout.spaceXS) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(DSColor.textSecondary)
                Text(title + (isRequired ? "*" : ""))
                    .dsBodySmall()
                    .foregroundColor(DSColor.textSecondary)
            }
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .padding(DSLayout.spaceS)
                .background(DSColor.surfaceSecondary)
                .cornerRadius(DSLayout.radiusS)
                .overlay(
                    RoundedRectangle(cornerRadius: DSLayout.radiusS)
                        .stroke(
                            text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && isRequired && !isValid && showingAlert ? DSColor.accentError : DSColor.border,
                            lineWidth: 1
                        )
                )
            if text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && isRequired && !isValid && showingAlert {
                Text("\(title.replacingOccurrences(of: "*", with: "")) is required.")
                    .dsCaption()
                    .foregroundColor(DSColor.accentError)
                    .padding(.horizontal, 4)
            }
        }
    }

    private var accountTypePickerField: some View {
        VStack(alignment: .leading, spacing: DSLayout.spaceXS) {
            HStack {
                Image(systemName: "briefcase.fill")
                    .foregroundColor(DSColor.textSecondary)
                Text("Account Type*")
                    .dsBodySmall()
                    .foregroundColor(DSColor.textSecondary)
            }
            Picker("Account Type*", selection: $selectedAccountTypeId) {
                Text("Select Account Type...").tag(nil as Int?)
                ForEach(availableAccountTypes) { type in
                    Text(type.name).tag(type.id as Int?)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .padding(DSLayout.spaceS)
            .background(DSColor.surfaceSecondary)
            .cornerRadius(DSLayout.radiusS)
            .overlay(
                RoundedRectangle(cornerRadius: DSLayout.radiusS)
                    .stroke(selectedAccountTypeId == nil && !isValid && showingAlert ? DSColor.accentError : DSColor.border, lineWidth: 1)
            )
            if selectedAccountTypeId == nil && !isValid && showingAlert {
                Text("Account Type is required.")
                    .dsCaption()
                    .foregroundColor(DSColor.accentError)
                    .padding(.horizontal, 4)
            }
        }
    }

    private var institutionPickerField: some View {
        VStack(alignment: .leading, spacing: DSLayout.spaceXS) {
            HStack {
                Image(systemName: "building.2.fill")
                    .foregroundColor(DSColor.textSecondary)
                Text("Institution*")
                    .dsBodySmall()
                    .foregroundColor(DSColor.textSecondary)
            }
            Picker("Institution*", selection: $selectedInstitutionId) {
                Text("Select Institution...").tag(nil as Int?)
                ForEach(availableInstitutions) { inst in
                    Text(inst.name).tag(inst.id as Int?)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .padding(DSLayout.spaceS)
            .background(DSColor.surfaceSecondary)
            .cornerRadius(DSLayout.radiusS)
            .overlay(
                RoundedRectangle(cornerRadius: DSLayout.radiusS)
                    .stroke(selectedInstitutionId == nil && !isValid && showingAlert ? DSColor.accentError : DSColor.border, lineWidth: 1)
            )
            if selectedInstitutionId == nil && !isValid && showingAlert {
                Text("Institution is required.")
                    .dsCaption()
                    .foregroundColor(DSColor.accentError)
                    .padding(.horizontal, 4)
            }
        }
    }

    private var addModernContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSLayout.spaceL) {
                VStack(alignment: .leading, spacing: DSLayout.spaceM) {
                    sectionHeader(title: "Account Details", icon: "pencil.and.scribble", color: DSColor.accentMain)
                    addModernTextField(title: "Account Name*", text: $accountName, placeholder: "e.g., Main Trading Account", icon: "tag.fill", isRequired: true)
                    institutionPickerField
                    addModernTextField(title: "Account Number*", text: $accountNumber, placeholder: "e.g., U1234567", icon: "number.square.fill", isRequired: true)
                    accountTypePickerField
                }
                .padding(DSLayout.spaceM)
                .background(DSColor.surface)
                .cornerRadius(DSLayout.radiusM)
                .overlay(RoundedRectangle(cornerRadius: DSLayout.radiusM).stroke(DSColor.border, lineWidth: 1))

                VStack(alignment: .leading, spacing: DSLayout.spaceM) {
                    sectionHeader(title: "Financial & Dates", icon: "calendar.badge.clock", color: DSColor.accentSuccess)
                    currencyPickerField
                    Toggle(isOn: $setOpeningDate.animation()) {
                        Text("Set Opening Date")
                            .dsBody()
                            .foregroundColor(DSColor.textPrimary)
                    }
                    .toggleStyle(.switch)
                    
                    if setOpeningDate {
                        DatePicker(selection: $openingDateInput, displayedComponents: .date) {
                            HStack {
                                Image(systemName: "calendar.badge.plus")
                                    .foregroundColor(DSColor.textSecondary)
                                Text("Opening Date")
                                    .dsBodySmall()
                                    .foregroundColor(DSColor.textSecondary)
                            }
                        }
                        .padding(DSLayout.spaceS)
                        .background(DSColor.surfaceSecondary)
                        .cornerRadius(DSLayout.radiusS)
                        .overlay(RoundedRectangle(cornerRadius: DSLayout.radiusS).stroke(DSColor.border, lineWidth: 1))
                    }
                    
                    Toggle(isOn: $setClosingDate.animation()) {
                        Text("Set Closing Date")
                            .dsBody()
                            .foregroundColor(DSColor.textPrimary)
                    }
                    .toggleStyle(.switch)
                    
                    if setClosingDate {
                        DatePicker(selection: $closingDateInput, in: setOpeningDate ? openingDateInput... : Date.distantPast..., displayedComponents: .date) {
                            HStack {
                                Image(systemName: "calendar.badge.minus")
                                    .foregroundColor(DSColor.textSecondary)
                                Text("Closing Date")
                                    .dsBodySmall()
                                    .foregroundColor(DSColor.textSecondary)
                            }
                        }
                        .padding(DSLayout.spaceS)
                        .background(DSColor.surfaceSecondary)
                        .cornerRadius(DSLayout.radiusS)
                        .overlay(RoundedRectangle(cornerRadius: DSLayout.radiusS).stroke(DSColor.border, lineWidth: 1))
                        
                        if setOpeningDate && closingDateInput < openingDateInput && setClosingDate {
                            Text("Closing date must be on or after opening date.")
                                .dsCaption()
                                .foregroundColor(DSColor.accentError)
                                .padding(.leading, DSLayout.spaceM)
                        }
                    }
                    
                    HStack {
                        Image(systemName: "clock.badge.checkmark")
                            .foregroundColor(DSColor.textSecondary)
                        Text("Earliest Instrument Update")
                            .dsBodySmall()
                            .foregroundColor(DSColor.textSecondary)
                        Spacer()
                        if let d = earliestInstrumentDate {
                            Text(DateFormatter.swissDate.string(from: d))
                                .dsMonoSmall()
                                .foregroundColor(DSColor.textTertiary)
                        } else {
                            Text("N/A")
                                .dsMonoSmall()
                                .foregroundColor(DSColor.textTertiary)
                        }
                    }
                    .padding(DSLayout.spaceS)
                    .background(DSColor.surfaceSecondary)
                    .cornerRadius(DSLayout.radiusS)
                    .overlay(RoundedRectangle(cornerRadius: DSLayout.radiusS).stroke(DSColor.border, lineWidth: 1))
                }
                .padding(DSLayout.spaceM)
                .background(DSColor.surface)
                .cornerRadius(DSLayout.radiusM)
                .overlay(RoundedRectangle(cornerRadius: DSLayout.radiusM).stroke(DSColor.border, lineWidth: 1))

                VStack(alignment: .leading, spacing: DSLayout.spaceM) {
                    sectionHeader(title: "Settings & Notes", icon: "gearshape.fill", color: DSColor.textSecondary)
                    Toggle(isOn: $includeInPortfolio) {
                        Text("Include in Portfolio Calculations")
                            .dsBody()
                            .foregroundColor(DSColor.textPrimary)
                    }
                    .toggleStyle(.switch)
                    
                    Toggle(isOn: $isActive) {
                        Text("Account is Active")
                            .dsBody()
                            .foregroundColor(DSColor.textPrimary)
                    }
                    .toggleStyle(.switch)
                    
                    VStack(alignment: .leading, spacing: DSLayout.spaceXS) {
                        HStack {
                            Image(systemName: "note.text")
                                .foregroundColor(DSColor.textSecondary)
                            Text("Notes")
                                .dsBodySmall()
                                .foregroundColor(DSColor.textSecondary)
                        }
                        TextEditor(text: $notes)
                            .frame(minHeight: 80, maxHeight: 150)
                            .font(.ds.body)
                            .padding(DSLayout.spaceS)
                            .background(DSColor.surfaceSecondary)
                            .cornerRadius(DSLayout.radiusS)
                            .overlay(RoundedRectangle(cornerRadius: DSLayout.radiusS).stroke(DSColor.border, lineWidth: 1))
                    }
                }
                .padding(DSLayout.spaceM)
                .background(DSColor.surface)
                .cornerRadius(DSLayout.radiusM)
                .overlay(RoundedRectangle(cornerRadius: DSLayout.radiusM).stroke(DSColor.border, lineWidth: 1))
            }
            .padding(.horizontal, DSLayout.spaceL)
            .padding(.bottom, 100)
        }
        .offset(y: sectionsOffset)
    }

    private var currencyPickerField: some View {
        VStack(alignment: .leading, spacing: DSLayout.spaceXS) {
            HStack {
                Image(systemName: "dollarsign.circle.fill")
                    .foregroundColor(DSColor.textSecondary)
                Text("Default Currency*")
                    .dsBodySmall()
                    .foregroundColor(DSColor.textSecondary)
            }
            Picker("Default Currency*", selection: $currencyCode) {
                Text("Select Currency...").tag("")
                ForEach(availableCurrencies, id: \.code) { curr in
                    Text("\(curr.name) (\(curr.code))").tag(curr.code)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .padding(DSLayout.spaceS)
            .background(DSColor.surfaceSecondary)
            .cornerRadius(DSLayout.radiusS)
            .overlay(
                RoundedRectangle(cornerRadius: DSLayout.radiusS)
                    .stroke(currencyCode.isEmpty && !isValid && showingAlert ? DSColor.accentError : DSColor.border, lineWidth: 1)
            )
            if currencyCode.isEmpty && !isValid && showingAlert {
                Text("Currency is required.")
                    .dsCaption()
                    .foregroundColor(DSColor.accentError)
                    .padding(.horizontal, 4)
            }
        }
    }

    private func loadInitialData() {
        availableCurrencies = dbManager.fetchActiveCurrencies()
        availableAccountTypes = dbManager.fetchAccountTypes(activeOnly: true)
        availableInstitutions = dbManager.fetchInstitutions(activeOnly: true)
        if let chfCurrency = availableCurrencies.first(where: { $0.code == "CHF" }) {
            currencyCode = chfCurrency.code
        } else if let firstCurrency = availableCurrencies.first {
            currencyCode = firstCurrency.code
        }
        if let firstInst = availableInstitutions.first {
            selectedInstitutionId = firstInst.id
        }
        setOpeningDate = false
        openingDateInput = Date()
        setClosingDate = false
        closingDateInput = Date()
        earliestInstrumentDate = nil
    }

    private func saveAccount() {
        guard isValid, let typeId = selectedAccountTypeId, let instId = selectedInstitutionId else {
            var errorMsg = "Please fill all mandatory fields (*)."
            if setClosingDate, setOpeningDate, closingDateInput < openingDateInput {
                errorMsg += "\nClosing date cannot be before opening date."
            }
            if selectedAccountTypeId == nil {
                errorMsg += "\nAccount Type is required."
            }
            alertMessage = errorMsg
            showingAlert = true
            return
        }
        isLoading = true
        let finalOpeningDate: Date? = setOpeningDate ? openingDateInput : nil
        let finalClosingDate: Date? = setClosingDate ? closingDateInput : nil
        let success = dbManager.addAccount(
            accountName: accountName.trimmingCharacters(in: .whitespacesAndNewlines),
            institutionId: instId,
            accountNumber: accountNumber.trimmingCharacters(in: .whitespacesAndNewlines),
            accountTypeId: typeId,
            currencyCode: currencyCode,
            openingDate: finalOpeningDate,
            closingDate: finalClosingDate,
            includeInPortfolio: includeInPortfolio,
            isActive: isActive,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        isLoading = false
        if success {
            alertMessage = "✅ Account '\(accountName)' added successfully!"
            NotificationCenter.default.post(name: NSNotification.Name("RefreshAccounts"), object: nil)
        } else {
            alertMessage = "❌ Failed to add account. Please try again."
            if alertMessage.contains("UNIQUE constraint failed: Accounts.account_number") {
                alertMessage = "❌ Failed to add account: Account Number must be unique."
            }
        }
        showingAlert = true
    }
}

// Edit Account View - MODIFIED
struct EditAccountView: View {
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject var dbManager: DatabaseManager
    let accountId: Int

    @State private var accountName: String = ""
    @State private var selectedInstitutionId: Int? = nil
    @State private var availableInstitutions: [DatabaseManager.InstitutionData] = []
    @State private var accountNumber: String = ""
    @State private var selectedAccountTypeId: Int? = nil
    @State private var availableAccountTypes: [DatabaseManager.AccountTypeData] = []

    @State private var currencyCode: String = ""
    @State private var setOpeningDate: Bool = false
    @State private var openingDateInput: Date = .init()
    @State private var setClosingDate: Bool = false
    @State private var closingDateInput: Date = .init()
    @State private var earliestInstrumentDate: Date? = nil
    @State private var includeInPortfolio: Bool = true
    @State private var isActive: Bool = true
    @State private var notes: String = ""
    @State private var originalData: DatabaseManager.AccountData? = nil
    @State private var availableCurrencies: [(code: String, name: String, symbol: String)] = []
    @State private var originalSetOpeningDate: Bool = false
    @State private var originalOpeningDateInput: Date = .init()
    @State private var originalSetClosingDate: Bool = false
    @State private var originalClosingDateInput: Date = .init()
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    @State private var hasChanges = false
    @State private var formScale: CGFloat = 0.9
    @State private var headerOpacity: Double = 0
    @State private var sectionsOffset: CGFloat = 50

    init(accountId: Int) {
        self.accountId = accountId
    }

    var isValid: Bool {
        !accountName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            selectedInstitutionId != nil &&
            !accountNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            selectedAccountTypeId != nil &&
            !currencyCode.isEmpty &&
            (setClosingDate ? (setOpeningDate ? closingDateInput >= openingDateInput : true) : true)
    }

    private func detectChanges() {
        guard let original = originalData, let originalAccTypeId = original.accountTypeId as Int? else {
            hasChanges = true
            return
        }
        let co: Date? = setOpeningDate ? openingDateInput : nil
        let oo: Date? = originalSetOpeningDate ? originalOpeningDateInput : nil
        let cc: Date? = setClosingDate ? closingDateInput : nil
        let oc: Date? = originalSetClosingDate ? originalClosingDateInput : nil
        hasChanges = accountName != original.accountName ||
            selectedInstitutionId != original.institutionId ||
            accountNumber != original.accountNumber ||
            selectedAccountTypeId != originalAccTypeId ||
            currencyCode != original.currencyCode ||
            co != oo ||
            cc != oc ||
            includeInPortfolio != original.includeInPortfolio ||
            isActive != original.isActive ||
            notes != (original.notes ?? "")
    }

    var body: some View {
        ZStack {
            DSColor.background
                .ignoresSafeArea()
            VStack(spacing: 0) {
                editModernHeader
                changeIndicator
                editModernContent
            }
        }
        .frame(width: 650, height: 820)
        .clipShape(RoundedRectangle(cornerRadius: DSLayout.radiusL))
        .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
        .scaleEffect(formScale)
        .onAppear {
            loadAccountData()
            animateEditEntrance()
        }
        .alert("Result", isPresented: $showingAlert) {
            Button("OK") {
                showingAlert = false
            }
        } message: {
            Text(alertMessage)
        }
        .onChange(of: accountName) { _, _ in detectChanges() }
        .onChange(of: selectedInstitutionId) { _, _ in detectChanges() }
        .onChange(of: accountNumber) { _, _ in detectChanges() }
        .onChange(of: selectedAccountTypeId) { _, _ in detectChanges() }
        .onChange(of: currencyCode) { _, _ in detectChanges() }
        .onChange(of: setOpeningDate) { _, _ in detectChanges() }
        .onChange(of: openingDateInput) { _, _ in detectChanges() }
        .onChange(of: setClosingDate) { _, _ in detectChanges() }
        .onChange(of: closingDateInput) { _, _ in detectChanges() }
        .onChange(of: includeInPortfolio) { _, _ in detectChanges() }
        .onChange(of: isActive) { _, _ in detectChanges() }
        .onChange(of: notes) { _, _ in detectChanges() }
    }

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
                    .foregroundColor(DSColor.textSecondary)
                    .padding(8)
                    .background(DSColor.surfaceSecondary)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: DSLayout.spaceS) {
                Image(systemName: "pencil.line")
                    .font(.system(size: 24))
                    .foregroundColor(DSColor.accentWarning)
                Text("Edit Account")
                    .dsHeaderLarge()
                    .foregroundColor(DSColor.textPrimary)
            }

            Spacer()

            Button {
                saveAccountChanges()
            } label: {
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
            .disabled(isLoading || !isValid || !hasChanges)
            .disabled(isLoading || !isValid || !hasChanges)
        }
        .padding(.horizontal, DSLayout.spaceL)
        .padding(.vertical, DSLayout.spaceL)
        .opacity(headerOpacity)
    }

    private var changeIndicator: some View {
        HStack {
            if hasChanges {
                HStack(spacing: DSLayout.spaceXS) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 8))
                        .foregroundColor(DSColor.accentWarning)
                    Text("Unsaved changes")
                        .dsCaption()
                        .foregroundColor(DSColor.accentWarning)
                }
                .padding(.horizontal, DSLayout.spaceS)
                .padding(.vertical, 4)
                .background(DSColor.accentWarning.opacity(0.1))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(DSColor.accentWarning.opacity(0.3), lineWidth: 1))
                .transition(.opacity.combined(with: .scale))
            }
            Spacer()
        }
        .padding(.horizontal, DSLayout.spaceL)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: hasChanges)
    }

    private func animateEditEntrance() {
        withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) { formScale = 1.0 }
        withAnimation(.easeOut(duration: 0.6).delay(0.2)) { headerOpacity = 1.0 }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4)) { sectionsOffset = 0 }
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

    private func editModernTextField(title: String, text: Binding<String>, placeholder: String, icon: String, isRequired: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: DSLayout.spaceXS) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(DSColor.textSecondary)
                Text(title + (isRequired ? "*" : ""))
                    .dsBodySmall()
                    .foregroundColor(DSColor.textSecondary)
            }
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .padding(DSLayout.spaceS)
                .background(DSColor.surfaceSecondary)
                .cornerRadius(DSLayout.radiusS)
                .overlay(
                    RoundedRectangle(cornerRadius: DSLayout.radiusS)
                        .stroke(
                            text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && isRequired && !isValid && showingAlert ? DSColor.accentError : DSColor.border,
                            lineWidth: 1
                        )
                )
            if text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && isRequired && !isValid && showingAlert {
                Text("\(title.replacingOccurrences(of: "*", with: "")) is required.")
                    .dsCaption()
                    .foregroundColor(DSColor.accentError)
                    .padding(.horizontal, 4)
            }
        }
    }

    private var accountTypePickerField: some View {
        VStack(alignment: .leading, spacing: DSLayout.spaceXS) {
            HStack {
                Image(systemName: "briefcase.fill")
                    .foregroundColor(DSColor.textSecondary)
                Text("Account Type*")
                    .dsBodySmall()
                    .foregroundColor(DSColor.textSecondary)
            }
            Picker("Account Type*", selection: $selectedAccountTypeId) {
                Text("Select Account Type...").tag(nil as Int?)
                ForEach(availableAccountTypes) { type in
                    Text(type.name).tag(type.id as Int?)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .padding(DSLayout.spaceS)
            .background(DSColor.surfaceSecondary)
            .cornerRadius(DSLayout.radiusS)
            .overlay(
                RoundedRectangle(cornerRadius: DSLayout.radiusS)
                    .stroke(selectedAccountTypeId == nil && !isValid && showingAlert ? DSColor.accentError : DSColor.border, lineWidth: 1)
            )
            if selectedAccountTypeId == nil && !isValid && showingAlert {
                Text("Account Type is required.")
                    .dsCaption()
                    .foregroundColor(DSColor.accentError)
                    .padding(.horizontal, 4)
            }
        }
    }

    private var institutionPickerField: some View {
        VStack(alignment: .leading, spacing: DSLayout.spaceXS) {
            HStack {
                Image(systemName: "building.2.fill")
                    .foregroundColor(DSColor.textSecondary)
                Text("Institution*")
                    .dsBodySmall()
                    .foregroundColor(DSColor.textSecondary)
            }
            Picker("Institution*", selection: $selectedInstitutionId) {
                Text("Select Institution...").tag(nil as Int?)
                ForEach(availableInstitutions) { inst in
                    Text(inst.name).tag(inst.id as Int?)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .padding(DSLayout.spaceS)
            .background(DSColor.surfaceSecondary)
            .cornerRadius(DSLayout.radiusS)
            .overlay(
                RoundedRectangle(cornerRadius: DSLayout.radiusS)
                    .stroke(selectedInstitutionId == nil && !isValid && showingAlert ? DSColor.accentError : DSColor.border, lineWidth: 1)
            )
            if selectedInstitutionId == nil && !isValid && showingAlert {
                Text("Institution is required.")
                    .dsCaption()
                    .foregroundColor(DSColor.accentError)
                    .padding(.horizontal, 4)
            }
        }
    }

    private var editModernContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSLayout.spaceL) {
                VStack(alignment: .leading, spacing: DSLayout.spaceM) {
                    sectionHeader(title: "Account Details", icon: "pencil.and.scribble", color: DSColor.accentWarning)
                    editModernTextField(title: "Account Name*", text: $accountName, placeholder: "e.g., Main Trading Account", icon: "tag.fill", isRequired: true)
                    institutionPickerField
                    editModernTextField(title: "Account Number*", text: $accountNumber, placeholder: "e.g., U1234567", icon: "number.square.fill", isRequired: true)
                    accountTypePickerField
                }
                .padding(DSLayout.spaceM)
                .background(DSColor.surface)
                .cornerRadius(DSLayout.radiusM)
                .overlay(RoundedRectangle(cornerRadius: DSLayout.radiusM).stroke(DSColor.border, lineWidth: 1))

                VStack(alignment: .leading, spacing: DSLayout.spaceM) {
                    sectionHeader(title: "Financial & Dates", icon: "calendar.badge.clock", color: DSColor.accentSuccess)
                    currencyPickerField
                    Toggle(isOn: $setOpeningDate.animation()) {
                        Text("Set Opening Date")
                            .dsBody()
                            .foregroundColor(DSColor.textPrimary)
                    }
                    .toggleStyle(.switch)
                    
                    if setOpeningDate {
                        DatePicker(selection: $openingDateInput, displayedComponents: .date) {
                            HStack {
                                Image(systemName: "calendar.badge.plus")
                                    .foregroundColor(DSColor.textSecondary)
                                Text("Opening Date")
                                    .dsBodySmall()
                                    .foregroundColor(DSColor.textSecondary)
                            }
                        }
                        .padding(DSLayout.spaceS)
                        .background(DSColor.surfaceSecondary)
                        .cornerRadius(DSLayout.radiusS)
                        .overlay(RoundedRectangle(cornerRadius: DSLayout.radiusS).stroke(DSColor.border, lineWidth: 1))
                    }
                    
                    Toggle(isOn: $setClosingDate.animation()) {
                        Text("Set Closing Date")
                            .dsBody()
                            .foregroundColor(DSColor.textPrimary)
                    }
                    .toggleStyle(.switch)
                    
                    if setClosingDate {
                        DatePicker(selection: $closingDateInput, in: setOpeningDate ? openingDateInput... : Date.distantPast..., displayedComponents: .date) {
                            HStack {
                                Image(systemName: "calendar.badge.minus")
                                    .foregroundColor(DSColor.textSecondary)
                                Text("Closing Date")
                                    .dsBodySmall()
                                    .foregroundColor(DSColor.textSecondary)
                            }
                        }
                        .padding(DSLayout.spaceS)
                        .background(DSColor.surfaceSecondary)
                        .cornerRadius(DSLayout.radiusS)
                        .overlay(RoundedRectangle(cornerRadius: DSLayout.radiusS).stroke(DSColor.border, lineWidth: 1))
                        
                        if setOpeningDate && closingDateInput < openingDateInput && setClosingDate {
                            Text("Closing date must be on or after opening date.")
                                .dsCaption()
                                .foregroundColor(DSColor.accentError)
                                .padding(.leading, DSLayout.spaceM)
                        }
                    }
                    
                    HStack {
                        Image(systemName: "clock.badge.checkmark")
                            .foregroundColor(DSColor.textSecondary)
                        Text("Earliest Instrument Update")
                            .dsBodySmall()
                            .foregroundColor(DSColor.textSecondary)
                        Spacer()
                        if let d = earliestInstrumentDate {
                            Text(DateFormatter.swissDate.string(from: d))
                                .dsMonoSmall()
                                .foregroundColor(DSColor.textTertiary)
                        } else {
                            Text("N/A")
                                .dsMonoSmall()
                                .foregroundColor(DSColor.textTertiary)
                        }
                    }
                    .padding(DSLayout.spaceS)
                    .background(DSColor.surfaceSecondary)
                    .cornerRadius(DSLayout.radiusS)
                    .overlay(RoundedRectangle(cornerRadius: DSLayout.radiusS).stroke(DSColor.border, lineWidth: 1))
                }
                .padding(DSLayout.spaceM)
                .background(DSColor.surface)
                .cornerRadius(DSLayout.radiusM)
                .overlay(RoundedRectangle(cornerRadius: DSLayout.radiusM).stroke(DSColor.border, lineWidth: 1))

                VStack(alignment: .leading, spacing: DSLayout.spaceM) {
                    sectionHeader(title: "Settings & Notes", icon: "gearshape.fill", color: DSColor.textSecondary)
                    Toggle(isOn: $includeInPortfolio) {
                        Text("Include in Portfolio Calculations")
                            .dsBody()
                            .foregroundColor(DSColor.textPrimary)
                    }
                    .toggleStyle(.switch)
                    
                    Toggle(isOn: $isActive) {
                        Text("Account is Active")
                            .dsBody()
                            .foregroundColor(DSColor.textPrimary)
                    }
                    .toggleStyle(.switch)
                    
                    VStack(alignment: .leading, spacing: DSLayout.spaceXS) {
                        HStack {
                            Image(systemName: "note.text")
                                .foregroundColor(DSColor.textSecondary)
                            Text("Notes")
                                .dsBodySmall()
                                .foregroundColor(DSColor.textSecondary)
                        }
                        TextEditor(text: $notes)
                            .frame(minHeight: 80, maxHeight: 150)
                            .font(.ds.body)
                            .padding(DSLayout.spaceS)
                            .background(DSColor.surfaceSecondary)
                            .cornerRadius(DSLayout.radiusS)
                            .overlay(RoundedRectangle(cornerRadius: DSLayout.radiusS).stroke(DSColor.border, lineWidth: 1))
                    }
                }
                .padding(DSLayout.spaceM)
                .background(DSColor.surface)
                .cornerRadius(DSLayout.radiusM)
                .overlay(RoundedRectangle(cornerRadius: DSLayout.radiusM).stroke(DSColor.border, lineWidth: 1))
            }
            .padding(.horizontal, DSLayout.spaceL)
            .padding(.bottom, 100)
        }
        .offset(y: sectionsOffset)
    }

    private var currencyPickerField: some View {
        VStack(alignment: .leading, spacing: DSLayout.spaceXS) {
            HStack {
                Image(systemName: "dollarsign.circle.fill")
                    .foregroundColor(DSColor.textSecondary)
                Text("Default Currency*")
                    .dsBodySmall()
                    .foregroundColor(DSColor.textSecondary)
            }
            Picker("Default Currency*", selection: $currencyCode) {
                Text("Select Currency...").tag("")
                ForEach(availableCurrencies, id: \.code) { curr in
                    Text("\(curr.name) (\(curr.code))").tag(curr.code)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .padding(DSLayout.spaceS)
            .background(DSColor.surfaceSecondary)
            .cornerRadius(DSLayout.radiusS)
            .overlay(
                RoundedRectangle(cornerRadius: DSLayout.radiusS)
                    .stroke(currencyCode.isEmpty && !isValid && showingAlert ? DSColor.accentError : DSColor.border, lineWidth: 1)
            )
            if currencyCode.isEmpty && !isValid && showingAlert {
                Text("Currency is required.")
                    .dsCaption()
                    .foregroundColor(DSColor.accentError)
                    .padding(.horizontal, 4)
            }
        }
    }

    func loadAccountData() {
        availableCurrencies = dbManager.fetchActiveCurrencies()
        availableAccountTypes = dbManager.fetchAccountTypes(activeOnly: true)
        availableInstitutions = dbManager.fetchInstitutions(activeOnly: true)

        if let details = dbManager.fetchAccountDetails(id: accountId) {
            accountName = details.accountName
            selectedInstitutionId = details.institutionId
            accountNumber = details.accountNumber
            selectedAccountTypeId = details.accountTypeId
            currencyCode = details.currencyCode
            if let oDate = details.openingDate {
                openingDateInput = oDate
                setOpeningDate = true
            } else {
                setOpeningDate = false
                openingDateInput = Date()
            }
            if let cDate = details.closingDate {
                closingDateInput = cDate
                setClosingDate = true
            } else {
                setClosingDate = false
                closingDateInput = Date()
            }
            earliestInstrumentDate = details.earliestInstrumentLastUpdatedAt
            includeInPortfolio = details.includeInPortfolio
            isActive = details.isActive
            notes = details.notes ?? ""
            originalData = details
            originalSetOpeningDate = setOpeningDate
            originalOpeningDateInput = openingDateInput
            originalSetClosingDate = setClosingDate
            originalClosingDateInput = closingDateInput
            detectChanges()
        } else {
            alertMessage = "❌ Error: Could not load account details."
            showingAlert = true
        }
    }

    private func showUnsavedChangesAlert() {
        let alert = NSAlert()
        alert.messageText = "Unsaved Changes"
        alert.informativeText = "You have unsaved changes. Are you sure you want to close?"
        alert.addButton(withTitle: "Save & Close")
        alert.addButton(withTitle: "Discard & Close")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            saveAccountChanges()
        } else if response == .alertSecondButtonReturn {
            animateEditExit()
        }
    }

    func saveAccountChanges() {
        guard isValid, let typeId = selectedAccountTypeId, let _ = selectedInstitutionId else {
            var errorMsg = "Please fill all mandatory fields (*)."
            if setClosingDate, setOpeningDate, closingDateInput < openingDateInput {
                errorMsg += "\nClosing date cannot be before opening date."
            }
            if selectedAccountTypeId == nil {
                errorMsg += "\nAccount Type is required."
            }
            alertMessage = errorMsg
            showingAlert = true
            return
        }
        guard hasChanges else {
            animateEditExit()
            return
        }
        isLoading = true
        let finalOpeningDate: Date? = setOpeningDate ? openingDateInput : nil
        let finalClosingDate: Date? = setClosingDate ? closingDateInput : nil

        let success = dbManager.updateAccount(
            id: accountId,
            accountName: accountName.trimmingCharacters(in: .whitespacesAndNewlines),
            institutionId: selectedInstitutionId!,
            accountNumber: accountNumber.trimmingCharacters(in: .whitespacesAndNewlines),
            accountTypeId: typeId,
            currencyCode: currencyCode,
            openingDate: finalOpeningDate,
            closingDate: finalClosingDate,
            includeInPortfolio: includeInPortfolio,
            isActive: isActive,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        isLoading = false
        if success {
            if let currentDetails = dbManager.fetchAccountDetails(id: accountId) {
                originalData = currentDetails
                selectedAccountTypeId = currentDetails.accountTypeId
                if let oDate = currentDetails.openingDate {
                    originalOpeningDateInput = oDate
                    originalSetOpeningDate = true
                } else {
                    originalSetOpeningDate = false
                }
                if let cDate = currentDetails.closingDate {
                    originalClosingDateInput = cDate
                    originalSetClosingDate = true
                } else {
                    originalSetClosingDate = false
                }
            }
            detectChanges()
            NotificationCenter.default.post(name: NSNotification.Name("RefreshAccounts"), object: nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                animateEditExit()
            }
        } else {
            alertMessage = "❌ Failed to update account. Please try again."
            if alertMessage.contains("UNIQUE constraint failed: Accounts.account_number") {
                alertMessage = "❌ Failed to update account: Account Number must be unique."
            }
            showingAlert = true
        }
    }
}
