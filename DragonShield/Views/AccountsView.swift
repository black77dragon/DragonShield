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

import SwiftUI
import Foundation
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

    @State private var sortColumn: SortColumn = .name
    @State private var sortAscending: Bool = true

    @StateObject private var tableModel = ResizableTableViewModel<AccountTableColumn>(configuration: AccountsView.tableConfiguration)

    @State private var headerOpacity: Double = 0
    @State private var contentOffset: CGFloat = 30
    @State private var buttonsOpacity: Double = 0

    private static let visibleColumnsKey = "AccountsView.visibleColumns.v1"
    private static let columnOrder: [AccountTableColumn] = [
        .name, .number, .institution, .bic, .type, .currency, .portfolio, .status, .earliestUpdate, .openingDate, .closingDate, .notes
    ]
    private static let defaultVisibleColumns: Set<AccountTableColumn> = [
        .name, .institution, .type, .currency, .portfolio, .status, .earliestUpdate
    ]
    private static let requiredColumns: Set<AccountTableColumn> = [.name]
    private static let headerBackground = Color(red: 230.0/255.0, green: 242.0/255.0, blue: 1.0)
    fileprivate static let columnHandleWidth: CGFloat = 10
    fileprivate static let columnHandleHitSlop: CGFloat = 8
    fileprivate static let columnTextInset: CGFloat = 12

    private var secondaryActionTint: Color {
#if os(macOS)
        Color(nsColor: .systemGray)
#else
        Color(UIColor.systemGray4)
#endif
    }

    private static let defaultColumnWidths: [AccountTableColumn: CGFloat] = [
        .name: 280,
        .number: 180,
        .institution: 220,
        .bic: 140,
        .type: 180,
        .currency: 110,
        .portfolio: 140,
        .status: 140,
        .earliestUpdate: 170,
        .openingDate: 150,
        .closingDate: 150,
        .notes: 80
    ]

    private static let minimumColumnWidths: [AccountTableColumn: CGFloat] = [
        .name: 220,
        .number: 140,
        .institution: 180,
        .bic: 120,
        .type: 140,
        .currency: 90,
        .portfolio: 120,
        .status: 120,
        .earliestUpdate: 140,
        .openingDate: 120,
        .closingDate: 120,
        .notes: 60
    ]

#if os(macOS)
    fileprivate static let columnResizeCursor: NSCursor = {
        let size = NSSize(width: 8, height: 24)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()
        let barWidth: CGFloat = 2
        let barRect = NSRect(x: (size.width - barWidth) / 2, y: 0, width: barWidth, height: size.height)
        NSColor.systemBlue.setFill()
        barRect.fill()
        image.unlockFocus()
        return NSCursor(image: image, hotSpot: NSPoint(x: size.width / 2, y: size.height / 2))
    }()
#endif

    private static let tableConfiguration: MaintenanceTableConfiguration<AccountTableColumn> = {
#if os(macOS)
        MaintenanceTableConfiguration(
            preferenceKind: .accounts,
            columnOrder: columnOrder,
            defaultVisibleColumns: defaultVisibleColumns,
            requiredColumns: requiredColumns,
            defaultColumnWidths: defaultColumnWidths,
            minimumColumnWidths: minimumColumnWidths,
            visibleColumnsDefaultsKey: visibleColumnsKey,
            columnHandleWidth: columnHandleWidth,
            columnHandleHitSlop: columnHandleHitSlop,
            columnTextInset: columnTextInset,
            headerBackground: headerBackground,
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
            preferenceKind: .accounts,
            columnOrder: columnOrder,
            defaultVisibleColumns: defaultVisibleColumns,
            requiredColumns: requiredColumns,
            defaultColumnWidths: defaultColumnWidths,
            minimumColumnWidths: minimumColumnWidths,
            visibleColumnsDefaultsKey: visibleColumnsKey,
            columnHandleWidth: columnHandleWidth,
            columnHandleHitSlop: columnHandleHitSlop,
            columnTextInset: columnTextInset,
            headerBackground: headerBackground,
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

    enum SortColumn: String, CaseIterable {
        case name, number, institution, bic, type, currency, portfolio, status, earliestUpdate, openingDate, closingDate
    }

    private var fontConfig: MaintenanceTableFontConfig { tableModel.fontConfig }
    private var selectedFontSize: MaintenanceTableFontSize { tableModel.selectedFontSize }
    private var activeColumns: [AccountTableColumn] { tableModel.activeColumns }
    private var visibleColumns: Set<AccountTableColumn> { tableModel.visibleColumns }

    private var fontSizeBinding: Binding<MaintenanceTableFontSize> {
        Binding(
            get: { tableModel.selectedFontSize },
            set: { tableModel.selectedFontSize = $0 }
        )
    }

    private var filteredAccounts: [DatabaseManager.AccountData] {
        var result = accounts
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedQuery.isEmpty {
            let query = trimmedQuery.lowercased()
            result = result.filter { account in
                let haystack: [String] = [
                    account.accountName,
                    account.accountNumber,
                    account.institutionName,
                    account.institutionBic ?? "",
                    account.accountType,
                    account.currencyCode,
                    account.notes ?? ""
                ].map { $0.lowercased() }
                return haystack.contains { !$0.isEmpty && $0.contains(query) }
            }
        }
        if !typeFilters.isEmpty {
            result = result.filter { typeFilters.contains(normalized($0.accountType)) }
        }
        if !currencyFilters.isEmpty {
            result = result.filter { currencyFilters.contains(normalized($0.currencyCode)) }
        }
        if !statusFilters.isEmpty {
            result = result.filter { statusFilters.contains(statusLabel(for: $0.isActive)) }
        }
        return result
    }

    private var sortedAccounts: [DatabaseManager.AccountData] {
        filteredAccounts.sorted { lhs, rhs in
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

    private var statsSourceAccounts: [DatabaseManager.AccountData] {
        isFiltering ? filteredAccounts : accounts
    }

    private var totalStatValue: String {
        statValue(current: statsSourceAccounts.count, total: accounts.count)
    }

    private var activeStatValue: String {
        let current = statsSourceAccounts.filter { $0.isActive }.count
        let total = accounts.filter { $0.isActive }.count
        return statValue(current: current, total: total)
    }

    private var portfolioStatValue: String {
        let current = statsSourceAccounts.filter { $0.includeInPortfolio }.count
        let total = accounts.filter { $0.includeInPortfolio }.count
        return statValue(current: current, total: total)
    }

    private func statValue(current: Int, total: Int) -> String {
        guard total > 0 else { return "0" }
        return current == total ? "\(total)" : "\(current)/\(total)"
    }

    var body: some View {
        ZStack {
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

            VStack(spacing: 0) {
                modernHeader
                searchAndStats
                accountsContent
                modernActionBar
            }
        }
        .onAppear {
            tableModel.connect(to: dbManager)
            loadData()
            animateEntrance()
            ensureFiltersetsWithinVisibleColumns()
            ensureValidSortColumn()
        }
        .onChange(of: tableModel.visibleColumns) { _, _ in
            ensureFiltersetsWithinVisibleColumns()
            ensureValidSortColumn()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshAccounts"))) { _ in
            loadData()
        }
        .sheet(isPresented: $showAddAccountSheet) {
            AddAccountView().environmentObject(dbManager)
        }
        .sheet(isPresented: $showEditAccountSheet) {
            if let account = selectedAccount {
                EditAccountView(accountId: account.id).environmentObject(dbManager)
            }
        }
        .confirmationDialog("Account Action", isPresented: $showingDeleteAlert, titleVisibility: .visible) {
            Button("Disable Account", role: .destructive) {
                if let account = accountToDelete {
                    confirmDisable(account)
                }
            }
            Button("Delete Account", role: .destructive) {
                if let account = accountToDelete {
                    confirmDelete(account)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            if let account = accountToDelete {
                Text("Choose whether to disable or permanently delete '\(account.accountName)' (\(account.accountNumber)). Accounts can only be modified if no instruments are linked.")
            }
        }
        .alert("Refresh", isPresented: $showRefreshAlert) {
            Button("OK") { showRefreshAlert = false }
        } message: {
            Text(refreshMessage)
        }
    }

    private func normalizeDateForSort(_ date: Date?, ascending: Bool) -> Date {
        guard let date else { return ascending ? Date.distantFuture : Date.distantPast }
        return date
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

    private func ascendingSort(lhs: DatabaseManager.AccountData, rhs: DatabaseManager.AccountData) -> Bool {
        switch sortColumn {
        case .name:
            return compareAscending(lhs.accountName, rhs.accountName)
        case .number:
            return compareAscending(lhs.accountNumber, rhs.accountNumber)
        case .institution:
            return compareAscending(lhs.institutionName, rhs.institutionName)
        case .bic:
            return compareAscending(normalized(lhs.institutionBic), normalized(rhs.institutionBic))
        case .type:
            return compareAscending(lhs.accountType, rhs.accountType)
        case .currency:
            return compareAscending(lhs.currencyCode, rhs.currencyCode)
        case .portfolio:
            if lhs.includeInPortfolio == rhs.includeInPortfolio {
                return compareAscending(lhs.accountName, rhs.accountName)
            }
            return lhs.includeInPortfolio && !rhs.includeInPortfolio
        case .status:
            if lhs.isActive == rhs.isActive {
                return compareAscending(lhs.accountName, rhs.accountName)
            }
            return lhs.isActive && !rhs.isActive
        case .earliestUpdate:
            let left = normalizeDateForSort(lhs.earliestInstrumentLastUpdatedAt, ascending: true)
            let right = normalizeDateForSort(rhs.earliestInstrumentLastUpdatedAt, ascending: true)
            if left == right {
                return compareAscending(lhs.accountName, rhs.accountName)
            }
            return left < right
        case .openingDate:
            let left = normalizeDateForSort(lhs.openingDate, ascending: true)
            let right = normalizeDateForSort(rhs.openingDate, ascending: true)
            if left == right {
                return compareAscending(lhs.accountName, rhs.accountName)
            }
            return left < right
        case .closingDate:
            let left = normalizeDateForSort(lhs.closingDate, ascending: true)
            let right = normalizeDateForSort(rhs.closingDate, ascending: true)
            if left == right {
                return compareAscending(lhs.accountName, rhs.accountName)
            }
            return left < right
        }
    }

    private func descendingSort(lhs: DatabaseManager.AccountData, rhs: DatabaseManager.AccountData) -> Bool {
        switch sortColumn {
        case .name:
            return compareDescending(lhs.accountName, rhs.accountName)
        case .number:
            return compareDescending(lhs.accountNumber, rhs.accountNumber)
        case .institution:
            return compareDescending(lhs.institutionName, rhs.institutionName)
        case .bic:
            return compareDescending(normalized(lhs.institutionBic), normalized(rhs.institutionBic))
        case .type:
            return compareDescending(lhs.accountType, rhs.accountType)
        case .currency:
            return compareDescending(lhs.currencyCode, rhs.currencyCode)
        case .portfolio:
            if lhs.includeInPortfolio == rhs.includeInPortfolio {
                return compareDescending(lhs.accountName, rhs.accountName)
            }
            return !lhs.includeInPortfolio && rhs.includeInPortfolio
        case .status:
            if lhs.isActive == rhs.isActive {
                return compareDescending(lhs.accountName, rhs.accountName)
            }
            return !lhs.isActive && rhs.isActive
        case .earliestUpdate:
            let left = normalizeDateForSort(lhs.earliestInstrumentLastUpdatedAt, ascending: false)
            let right = normalizeDateForSort(rhs.earliestInstrumentLastUpdatedAt, ascending: false)
            if left == right {
                return compareDescending(lhs.accountName, rhs.accountName)
            }
            return left > right
        case .openingDate:
            let left = normalizeDateForSort(lhs.openingDate, ascending: false)
            let right = normalizeDateForSort(rhs.openingDate, ascending: false)
            if left == right {
                return compareDescending(lhs.accountName, rhs.accountName)
            }
            return left > right
        case .closingDate:
            let left = normalizeDateForSort(lhs.closingDate, ascending: false)
            let right = normalizeDateForSort(rhs.closingDate, ascending: false)
            if left == right {
                return compareDescending(lhs.accountName, rhs.accountName)
            }
            return left > right
        }
    }

    private var modernHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    Image(systemName: "building.columns.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.blue)
                    Text("Accounts")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(colors: [.black, .gray], startPoint: .top, endPoint: .bottom)
                        )
                }
                Text("Manage brokerage, bank, and exchange accounts")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            Spacer()

            HStack(spacing: 16) {
                modernStatCard(title: "Total", value: totalStatValue, icon: "number.circle.fill", color: .blue)
                modernStatCard(title: "Active", value: activeStatValue, icon: "checkmark.circle.fill", color: .green)
                modernStatCard(title: "In Portfolio", value: portfolioStatValue, icon: "briefcase.fill", color: .purple)
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
                TextField("Search accounts...", text: $searchText)
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

            if isFiltering {
                HStack {
                    Text("Found \(sortedAccounts.count) of \(accounts.count) accounts")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                }

                if !typeFilters.isEmpty || !currencyFilters.isEmpty || !statusFilters.isEmpty {
                    HStack(spacing: 8) {
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
        .padding(.horizontal, 24)
    }

    private var accountsContent: some View {
        VStack(spacing: 12) {
            tableControls
            if sortedAccounts.isEmpty {
                emptyStateView
                    .offset(y: contentOffset)
            } else {
                accountsTable
                    .offset(y: contentOffset)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }

    private var tableControls: some View {
        HStack(spacing: 12) {
            columnsMenu
            fontSizePicker
            Spacer()
            if visibleColumns != AccountsView.defaultVisibleColumns || selectedFontSize != .medium {
                Button("Reset View", action: resetTablePreferences)
                    .buttonStyle(.link)
            }
        }
        .padding(.horizontal, 4)
        .font(.system(size: 12))
    }

    private var columnsMenu: some View {
        Menu {
            ForEach(AccountsView.columnOrder, id: \.self) { column in
                let isVisible = visibleColumns.contains(column)
                Button {
                    toggleColumn(column)
                } label: {
                    Label(column.menuTitle, systemImage: isVisible ? "checkmark" : "")
                }
                .disabled(isVisible && (visibleColumns.count == 1 || AccountsView.requiredColumns.contains(column)))
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
        .frame(maxWidth: 260)
        .labelsHidden()
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            VStack(spacing: 16) {
                Image(systemName: searchText.isEmpty ? "building.columns" : "magnifyingglass")
                    .font(.system(size: 64))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.gray.opacity(0.5), .gray.opacity(0.3)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                VStack(spacing: 8) {
                    Text(searchText.isEmpty ? "No accounts yet" : "No matching accounts")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray)
                    Text(searchText.isEmpty ? "Add your first account to get started." : "Try adjusting your search or filters.")
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                if searchText.isEmpty {
                    Button {
                        showAddAccountSheet = true
                    } label: {
                        Label("Add Account", systemImage: "plus")
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
                            .foregroundColor(.black)
                        if isActiveSort {
                            Image(systemName: "triangle.fill")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.accentColor)
                                .rotationEffect(.degrees(sortAscending ? 0 : 180))
                        }
                    }
                }
                .buttonStyle(.plain)
            } else if column == .notes {
                Image(systemName: "note.text")
                    .font(.system(size: fontConfig.header, weight: .semibold))
                    .foregroundColor(.black)
                    .help("Notes")
            } else {
                Text(column.title)
                    .font(.system(size: fontConfig.header, weight: .semibold))
                    .foregroundColor(.black)
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
                        .foregroundColor(binding.wrappedValue.isEmpty ? .gray : .accentColor)
                }
                .menuStyle(BorderlessButtonMenuStyle())
            }
        }
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
        .background(Color.blue.opacity(0.1))
        .clipShape(Capsule())
    }

    private var modernActionBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1)

            HStack(spacing: 16) {
                Button {
                    showAddAccountSheet = true
                } label: {
                    Label("Add Account", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.67, green: 0.89, blue: 0.67))
                .foregroundColor(.black)

                Button {
                    isRefreshing = true
                    dbManager.refreshEarliestInstrumentTimestamps { result in
                        isRefreshing = false
                        switch result {
                        case .success(let count):
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

    private func sortOption(for column: AccountTableColumn) -> SortColumn? {
        switch column {
        case .name: return .name
        case .number: return .number
        case .institution: return .institution
        case .bic: return .bic
        case .type: return .type
        case .currency: return .currency
        case .portfolio: return .portfolio
        case .status: return .status
        case .earliestUpdate: return .earliestUpdate
        case .openingDate: return .openingDate
        case .closingDate: return .closingDate
        case .notes: return nil
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
        let currentColumn = tableColumn(for: sortColumn)
        if !visibleColumns.contains(currentColumn) {
            if let fallback = activeColumns.compactMap(sortOption(for:)).first {
                sortColumn = fallback
            } else {
                sortColumn = .name
            }
        }
    }

    private func tableColumn(for sortColumn: SortColumn) -> AccountTableColumn {
        switch sortColumn {
        case .name: return .name
        case .number: return .number
        case .institution: return .institution
        case .bic: return .bic
        case .type: return .type
        case .currency: return .currency
        case .portfolio: return .portfolio
        case .status: return .status
        case .earliestUpdate: return .earliestUpdate
        case .openingDate: return .openingDate
        case .closingDate: return .closingDate
        }
    }
    private func ensureFiltersetsWithinVisibleColumns() {
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

fileprivate struct ModernAccountRowView: View {
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
                .fill(isSelected ? Color.blue.opacity(0.1) : Color.clear)
                .overlay(
                    Rectangle()
                        .stroke(isSelected ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        )
        .overlay(
            Rectangle()
                .fill(Color.black.opacity(0.06))
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
                    .foregroundColor(.primary)
                Text("Number: \(account.accountNumber)")
                    .font(.system(size: max(10, fontConfig.badge), design: .monospaced))
                    .foregroundColor(.secondary)
                if let bic = account.institutionBic, !bic.isEmpty {
                    Text("BIC: \(bic)")
                        .font(.system(size: max(10, fontConfig.badge)))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.leading, AccountsView.columnTextInset)
            .padding(.trailing, 8)
            .frame(width: widthFor(.name), alignment: .leading)
        case .number:
            Text(account.accountNumber)
                .font(.system(size: fontConfig.secondary, design: .monospaced))
                .foregroundColor(.secondary)
                .padding(.leading, AccountsView.columnTextInset)
                .padding(.trailing, 8)
                .frame(width: widthFor(.number), alignment: .leading)
        case .institution:
            Text(account.institutionName)
                .font(.system(size: fontConfig.secondary))
                .foregroundColor(.secondary)
                .padding(.leading, AccountsView.columnTextInset)
                .padding(.trailing, 8)
                .frame(width: widthFor(.institution), alignment: .leading)
        case .bic:
            Text(account.institutionBic ?? "--")
                .font(.system(size: fontConfig.secondary, design: .monospaced))
                .foregroundColor(.secondary)
                .padding(.leading, AccountsView.columnTextInset)
                .padding(.trailing, 8)
                .frame(width: widthFor(.bic), alignment: .leading)
        case .type:
            Text(account.accountType)
                .font(.system(size: fontConfig.secondary))
                .foregroundColor(.secondary)
                .padding(.leading, AccountsView.columnTextInset)
                .padding(.trailing, 8)
                .frame(width: widthFor(.type), alignment: .leading)
        case .currency:
            Text(account.currencyCode)
                .font(.system(size: fontConfig.badge, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.blue.opacity(0.12))
                .clipShape(Capsule())
                .padding(.leading, AccountsView.columnTextInset)
                .padding(.trailing, 8)
                .frame(width: widthFor(.currency), alignment: .leading)
        case .portfolio:
            HStack(spacing: 6) {
                Image(systemName: account.includeInPortfolio ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(account.includeInPortfolio ? .green : .gray)
                Text(account.includeInPortfolio ? "Included" : "Excluded")
                    .font(.system(size: fontConfig.secondary, weight: .medium))
                    .foregroundColor(account.includeInPortfolio ? .green : .secondary)
            }
            .padding(.leading, AccountsView.columnTextInset)
            .padding(.trailing, 8)
            .frame(width: widthFor(.portfolio), alignment: .leading)
        case .status:
            HStack(spacing: 6) {
                Circle()
                    .fill(account.isActive ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Text(account.isActive ? "Active" : "Inactive")
                    .font(.system(size: fontConfig.secondary, weight: .medium))
                    .foregroundColor(account.isActive ? .green : .orange)
            }
            .frame(width: widthFor(.status), alignment: .center)
        case .earliestUpdate:
            Text(displayDate(account.earliestInstrumentLastUpdatedAt))
                .font(.system(size: fontConfig.secondary))
                .foregroundColor(.secondary)
                .padding(.leading, AccountsView.columnTextInset)
                .padding(.trailing, 8)
                .frame(width: widthFor(.earliestUpdate), alignment: .leading)
        case .openingDate:
            Text(displayDate(account.openingDate))
                .font(.system(size: fontConfig.secondary))
                .foregroundColor(.secondary)
                .padding(.leading, AccountsView.columnTextInset)
                .padding(.trailing, 8)
                .frame(width: widthFor(.openingDate), alignment: .leading)
        case .closingDate:
            Text(displayDate(account.closingDate))
                .font(.system(size: fontConfig.secondary))
                .foregroundColor(account.isActive ? .secondary : .orange)
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
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(PlainButtonStyle())
            .popover(isPresented: $showNote) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes")
                        .font(.headline)
                    Text(note)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
                .frame(width: 260)
            }
        } else {
            Image(systemName: "note.text")
                .foregroundColor(.gray.opacity(0.3))
        }
    }

    private func displayDate(_ date: Date?) -> String {
        guard let date else { return "—" }
        return DateFormatter.userFacingFormatter.string(from: date)
    }
}

extension DateFormatter {
    fileprivate static let userFacingFormatter: DateFormatter = {
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
    // MODIFIED: Use selectedAccountTypeId and availableAccountTypes
    @State private var selectedAccountTypeId: Int? = nil
    @State private var availableAccountTypes: [DatabaseManager.AccountTypeData] = []
    
    @State private var currencyCode: String = ""
    @State private var setOpeningDate: Bool = false
    @State private var openingDateInput: Date = Date()
    @State private var setClosingDate: Bool = false
    @State private var closingDateInput: Date = Date()
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
            LinearGradient(colors: [Color(red: 0.98, green: 0.99, blue: 1.0), Color(red: 0.95, green: 0.97, blue: 0.99)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            VStack(spacing: 0) { addModernHeader; addModernContent; }
        }.frame(width: 650, height: 820).clipShape(RoundedRectangle(cornerRadius: 20)).shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
        .scaleEffect(formScale).onAppear { loadInitialData(); animateAddEntrance(); }
        .alert("Result", isPresented: $showingAlert) { Button("OK") { if alertMessage.contains("✅") { animateAddExit() } else { showingAlert = false } } } message: { Text(alertMessage) }
    }

    private var addModernHeader: some View {
        HStack {
            Button { animateAddExit() } label: { Image(systemName: "xmark").modifier(ModernSubtleButton()) }; Spacer()
            HStack(spacing: 12) { Image(systemName: "plus.circle.fill").font(.system(size: 24)).foregroundColor(.blue); Text("Add Account").font(.system(size: 24, weight: .bold, design: .rounded)).foregroundStyle(LinearGradient(colors: [.black, .gray], startPoint: .top, endPoint: .bottom)) }; Spacer()
            Button { saveAccount() } label: { HStack(spacing: 8) { if isLoading { ProgressView().progressViewStyle(.circular).tint(.white).scaleEffect(0.8) } else { Image(systemName: "checkmark").font(.system(size: 14, weight: .bold)) }; Text(isLoading ? "Saving..." : "Save") .font(.system(size: 14, weight: .semibold)) }.modifier(ModernPrimaryButton(color: .blue, isDisabled: isLoading || !isValid)) }
        }.padding(.horizontal, 24).padding(.vertical, 20).opacity(headerOpacity)
    }
    
    private func animateAddEntrance() {
        withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) { formScale = 1.0 }
        withAnimation(.easeOut(duration: 0.6).delay(0.2)) { headerOpacity = 1.0 }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4)) { sectionsOffset = 0 }
    }
    private func animateAddExit() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { formScale = 0.9; headerOpacity = 0; sectionsOffset = 50; }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { presentationMode.wrappedValue.dismiss() }
    }
    
    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 20))
                .foregroundStyle(LinearGradient(colors: [color, color.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
            Text(title).font(.system(size: 18, weight: .semibold, design: .rounded)).foregroundColor(.black.opacity(0.8))
            Spacer()
        }
    }

    private func addModernTextField(title: String, text: Binding<String>, placeholder: String, icon: String, isRequired: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon).foregroundColor(.gray)
                Text(title + (isRequired ? "*" : "")).font(.system(size: 14, weight: .medium)).foregroundColor(.black.opacity(0.7))
            }
            TextField(placeholder, text: text)
                .padding(.horizontal, 16).padding(.vertical, 12).background(Color.white.opacity(0.8)).clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && isRequired && !isValid && showingAlert ? Color.red.opacity(0.6) : Color.gray.opacity(0.3), lineWidth: 1))
            if text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && isRequired && !isValid && showingAlert {
                Text("\(title.replacingOccurrences(of: "*", with: "")) is required.").font(.caption).foregroundColor(.red.opacity(0.8)).padding(.horizontal, 4)
            }
        }
    }

    // MODIFIED: Replaced accountType TextField with a Picker
private var accountTypePickerField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "briefcase.fill").foregroundColor(.gray)
                Text("Account Type*").font(.system(size: 14, weight: .medium)).foregroundColor(.black.opacity(0.7))
            }
            Picker("Account Type*", selection: $selectedAccountTypeId) {
                Text("Select Account Type...").tag(nil as Int?) // Optional tag for placeholder
                ForEach(availableAccountTypes) { type in
                    Text(type.name).tag(type.id as Int?)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .padding(.horizontal, 16).padding(.vertical, 12).background(Color.white.opacity(0.8)).clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(selectedAccountTypeId == nil && !isValid && showingAlert ? Color.red.opacity(0.6) : Color.gray.opacity(0.3), lineWidth: 1))
            if selectedAccountTypeId == nil && !isValid && showingAlert {
                Text("Account Type is required.").font(.caption).foregroundColor(.red.opacity(0.8)).padding(.horizontal, 4)
            }
        }
    }


    // Picker for selecting the associated institution - used in Add/Edit forms
    private var institutionPickerField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "building.2.fill").foregroundColor(.gray)
                Text("Institution*")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.black.opacity(0.7))
            }
            Picker("Institution*", selection: $selectedInstitutionId) {
                Text("Select Institution...").tag(nil as Int?)
                ForEach(availableInstitutions) { inst in
                    Text(inst.name).tag(inst.id as Int?)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        selectedInstitutionId == nil && !isValid && showingAlert ?
                            Color.red.opacity(0.6) : Color.gray.opacity(0.3),
                        lineWidth: 1
                    )
            )
            if selectedInstitutionId == nil && !isValid && showingAlert {
                Text("Institution is required.")
                    .font(.caption)
                    .foregroundColor(.red.opacity(0.8))
                    .padding(.horizontal, 4)
            }
        }
    }

    
    private var addModernContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 20) {
                    sectionHeader(title: "Account Details", icon: "pencil.and.scribble", color: .blue)
                    addModernTextField(title: "Account Name*", text: $accountName, placeholder: "e.g., Main Trading Account", icon: "tag.fill", isRequired: true)
                    institutionPickerField
                    addModernTextField(title: "Account Number*", text: $accountNumber, placeholder: "e.g., U1234567", icon: "number.square.fill", isRequired: true)
                    accountTypePickerField // MODIFIED: Using Picker
                }.modifier(ModernFormSection(color: .blue))
                VStack(alignment: .leading, spacing: 20) {
                    sectionHeader(title: "Financial & Dates", icon: "calendar.badge.clock", color: .green)
                    currencyPickerField
                    Toggle(isOn: $setOpeningDate.animation()) { Text("Set Opening Date") }.modifier(ModernToggleStyle(tint: .green))
                    if setOpeningDate {
                        DatePicker(selection: $openingDateInput, displayedComponents: .date) { HStack { Image(systemName: "calendar.badge.plus").foregroundColor(.gray); Text("Opening Date") .font(.system(size: 14, weight: .medium)).foregroundColor(.black.opacity(0.7)) } }
                        .padding(.horizontal, 16).padding(.vertical, 12).background(Color.white.opacity(0.8)).clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3), lineWidth: 1)).shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                        .transition(.asymmetric(insertion: .scale(scale: 0.95, anchor: .top).combined(with: .opacity), removal: .opacity))
                    }
                    Toggle(isOn: $setClosingDate.animation()) { Text("Set Closing Date") }.modifier(ModernToggleStyle(tint: .orange))
                    if setClosingDate {
                        DatePicker(selection: $closingDateInput, in: (setOpeningDate ? openingDateInput... : Date.distantPast...), displayedComponents: .date) { HStack { Image(systemName: "calendar.badge.minus").foregroundColor(.gray); Text("Closing Date") .font(.system(size: 14, weight: .medium)).foregroundColor(.black.opacity(0.7)) } }
                        .padding(.horizontal, 16).padding(.vertical, 12).background(Color.white.opacity(0.8)).clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3), lineWidth: 1)).shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                        .transition(.asymmetric(insertion: .scale(scale: 0.95, anchor: .top).combined(with: .opacity), removal: .opacity))
                        if setOpeningDate && closingDateInput < openingDateInput && setClosingDate { Text("Closing date must be on or after opening date.").font(.caption).foregroundColor(.red).padding(.leading, 16) }
                    }
                    HStack {
                        Image(systemName: "clock.badge.checkmark").foregroundColor(.gray)
                        Text("Earliest Instrument Update")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.black.opacity(0.7))
                        Spacer()
                        if let d = earliestInstrumentDate {
                            Text(DateFormatter.swissDate.string(from: d))
                                .foregroundColor(.gray)
                        } else {
                            Text("N/A").foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                }.modifier(ModernFormSection(color: .green))
                VStack(alignment: .leading, spacing: 20) {
                    sectionHeader(title: "Settings & Notes", icon: "gearshape.fill", color: .purple)
                    Toggle(isOn: $includeInPortfolio) { Text("Include in Portfolio Calculations") }.modifier(ModernToggleStyle(tint: .purple))
                    Toggle(isOn: $isActive) { Text("Account is Active") }.modifier(ModernToggleStyle(tint: .green))
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { Image(systemName: "note.text").foregroundColor(.gray); Text("Notes").font(.system(size: 14, weight: .medium)).foregroundColor(.black.opacity(0.7)) }
                        TextEditor(text: $notes).frame(minHeight: 80, maxHeight: 150).font(.system(size: 16)).padding(12)
                            .background(Color.white.opacity(0.8)).clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3), lineWidth: 1)).shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                    }
                }.modifier(ModernFormSection(color: .purple))
            }.padding(.horizontal, 24).padding(.bottom, 100)
        }.offset(y: sectionsOffset)
    }
    private var currencyPickerField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Image(systemName: "dollarsign.circle.fill").foregroundColor(.gray); Text("Default Currency*").font(.system(size: 14, weight: .medium)).foregroundColor(.black.opacity(0.7)) }
            Picker("Default Currency*", selection: $currencyCode) { Text("Select Currency...").tag(""); ForEach(availableCurrencies, id: \.code) { curr in Text("\(curr.name) (\(curr.code))").tag(curr.code) } }
            .pickerStyle(MenuPickerStyle()).padding(.horizontal, 16).padding(.vertical, 12).background(Color.white.opacity(0.8)).clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(currencyCode.isEmpty && !isValid && showingAlert ? Color.red.opacity(0.6) : Color.gray.opacity(0.3), lineWidth: 1))
            if currencyCode.isEmpty && !isValid && showingAlert { Text("Currency is required.").font(.caption).foregroundColor(.red.opacity(0.8)).padding(.horizontal, 4) }
        }
    }
    private func loadInitialData() {
        availableCurrencies = dbManager.fetchActiveCurrencies()
        availableAccountTypes = dbManager.fetchAccountTypes(activeOnly: true)
        availableInstitutions = dbManager.fetchInstitutions(activeOnly: true)
        if let chfCurrency = availableCurrencies.first(where: {$0.code == "CHF"}) { currencyCode = chfCurrency.code } else if let firstCurrency = availableCurrencies.first { currencyCode = firstCurrency.code }
        if let firstInst = availableInstitutions.first { selectedInstitutionId = firstInst.id }
        // Optionally set a default account type if desired, e.g., the first one
        // if !availableAccountTypes.isEmpty { selectedAccountTypeId = availableAccountTypes[0].id }
        setOpeningDate = false; openingDateInput = Date(); setClosingDate = false; closingDateInput = Date();
        earliestInstrumentDate = nil
    }
    private func saveAccount() {
        guard isValid, let typeId = selectedAccountTypeId, let instId = selectedInstitutionId else {
            var errorMsg = "Please fill all mandatory fields (*)."; if setClosingDate && setOpeningDate && closingDateInput < openingDateInput { errorMsg += "\nClosing date cannot be before opening date." }; if selectedAccountTypeId == nil { errorMsg += "\nAccount Type is required."}
            alertMessage = errorMsg; showingAlert = true; return
        }
        isLoading = true
        let finalOpeningDate: Date? = setOpeningDate ? openingDateInput : nil; let finalClosingDate: Date? = setClosingDate ? closingDateInput : nil
        let success = dbManager.addAccount(
            accountName: accountName.trimmingCharacters(in: .whitespacesAndNewlines),
            institutionId: instId,
            accountNumber: accountNumber.trimmingCharacters(in: .whitespacesAndNewlines),
            accountTypeId: typeId, // Pass selected ID
            currencyCode: currencyCode,
            openingDate: finalOpeningDate,
            closingDate: finalClosingDate,
            includeInPortfolio: includeInPortfolio,
            isActive: isActive,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        isLoading = false
        if success { alertMessage = "✅ Account '\(accountName)' added successfully!"; NotificationCenter.default.post(name: NSNotification.Name("RefreshAccounts"), object: nil);
        } else { alertMessage = "❌ Failed to add account. Please try again."; if alertMessage.contains("UNIQUE constraint failed: Accounts.account_number") { alertMessage = "❌ Failed to add account: Account Number must be unique."} }
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
    // MODIFIED: Use selectedAccountTypeId and availableAccountTypes
    @State private var selectedAccountTypeId: Int? = nil
    @State private var availableAccountTypes: [DatabaseManager.AccountTypeData] = []
    
    @State private var currencyCode: String = "";
    @State private var setOpeningDate: Bool = false; @State private var openingDateInput: Date = Date(); @State private var setClosingDate: Bool = false; @State private var closingDateInput: Date = Date();
    @State private var earliestInstrumentDate: Date? = nil
    @State private var includeInPortfolio: Bool = true; @State private var isActive: Bool = true; @State private var notes: String = "";
    @State private var originalData: DatabaseManager.AccountData? = nil; @State private var availableCurrencies: [(code: String, name: String, symbol: String)] = [];
    @State private var originalSetOpeningDate: Bool = false; @State private var originalOpeningDateInput: Date = Date(); @State private var originalSetClosingDate: Bool = false; @State private var originalClosingDateInput: Date = Date();
    @State private var showingAlert = false; @State private var alertMessage = ""; @State private var isLoading = false; @State private var hasChanges = false;
    @State private var formScale: CGFloat = 0.9; @State private var headerOpacity: Double = 0; @State private var sectionsOffset: CGFloat = 50;

    init(accountId: Int) { self.accountId = accountId }
    var isValid: Bool {
        !accountName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        selectedInstitutionId != nil &&
        !accountNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        selectedAccountTypeId != nil &&
        !currencyCode.isEmpty &&
        (setClosingDate ? (setOpeningDate ? closingDateInput >= openingDateInput : true) : true)
    }
    private func detectChanges() {
        guard let original = originalData, let originalAccTypeId = original.accountTypeId as Int? else { hasChanges = true; return } // Ensure originalData and ID are valid
        let co: Date? = setOpeningDate ? openingDateInput : nil; let oo: Date? = originalSetOpeningDate ? originalOpeningDateInput : nil;
        let cc: Date? = setClosingDate ? closingDateInput : nil; let oc: Date? = originalSetClosingDate ? originalClosingDateInput : nil;
        hasChanges = accountName != original.accountName ||
                         selectedInstitutionId != original.institutionId ||
                         accountNumber != original.accountNumber ||
                         selectedAccountTypeId != originalAccTypeId || // MODIFIED
                         currencyCode != original.currencyCode ||
                         co != oo ||
                         cc != oc ||
                         includeInPortfolio != original.includeInPortfolio ||
                         isActive != original.isActive ||
                         notes != (original.notes ?? "")
    }

    var body: some View {
       ZStack {
            LinearGradient(colors: [Color(red: 0.97, green: 0.98, blue: 1.0), Color(red: 0.94, green: 0.96, blue: 0.99)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            VStack(spacing: 0) { editModernHeader; changeIndicator; editModernContent; }
        }.frame(width: 650, height: 820).clipShape(RoundedRectangle(cornerRadius: 20)).shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
        .scaleEffect(formScale).onAppear { loadAccountData(); animateEditEntrance(); }
        .alert("Result", isPresented: $showingAlert) { Button("OK") { showingAlert = false } } message: { Text(alertMessage) }
        .onChange(of: accountName) { _,_ in detectChanges() }.onChange(of: selectedInstitutionId) { _,_ in detectChanges() }.onChange(of: accountNumber) { _,_ in detectChanges() }
        .onChange(of: selectedAccountTypeId) { _,_ in detectChanges() } // MODIFIED
        .onChange(of: currencyCode) { _,_ in detectChanges() }
        .onChange(of: setOpeningDate) { _,_ in detectChanges() }.onChange(of: openingDateInput) { _,_ in detectChanges() }.onChange(of: setClosingDate) { _,_ in detectChanges() }.onChange(of: closingDateInput) { _,_ in detectChanges() }
        .onChange(of: includeInPortfolio) { _,_ in detectChanges() }.onChange(of: isActive) { _,_ in detectChanges() }.onChange(of: notes) { _,_ in detectChanges() }
    }

    private var editModernHeader: some View {
        HStack {
            Button { if hasChanges { showUnsavedChangesAlert() } else { animateEditExit() } } label: { Image(systemName: "xmark").modifier(ModernSubtleButton()) }; Spacer()
            HStack(spacing: 12) { Image(systemName: "pencil.line").font(.system(size: 24)).foregroundColor(.orange); Text("Edit Account").font(.system(size: 24, weight: .bold, design: .rounded)).foregroundStyle(LinearGradient(colors: [.black, .gray], startPoint: .top, endPoint: .bottom)) }; Spacer()
            Button { saveAccountChanges() } label: { HStack(spacing: 8) { if isLoading { ProgressView().progressViewStyle(.circular).tint(.white).scaleEffect(0.8) } else { Image(systemName: hasChanges ? "checkmark.circle.fill" : "checkmark").font(.system(size: 14, weight: .bold)) }; Text(isLoading ? "Saving..." : "Save Changes").font(.system(size: 14, weight: .semibold)) }.modifier(ModernPrimaryButton(color: .orange, isDisabled: isLoading || !isValid || !hasChanges)) }
        }.padding(.horizontal, 24).padding(.vertical, 20).opacity(headerOpacity)
    }
    private var changeIndicator: some View {
        HStack { if hasChanges { HStack(spacing: 8) { Image(systemName: "circle.fill").font(.system(size: 8)).foregroundColor(.orange); Text("Unsaved changes").font(.caption).foregroundColor(.orange) }.padding(.horizontal, 12).padding(.vertical, 4).background(Color.orange.opacity(0.1)).clipShape(Capsule()).overlay(Capsule().stroke(Color.orange.opacity(0.3), lineWidth: 1)).transition(.opacity.combined(with: .scale)) }; Spacer() }.padding(.horizontal, 24).animation(.spring(response: 0.5, dampingFraction: 0.8), value: hasChanges)
    }

    private func animateEditEntrance() {
        withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) { formScale = 1.0 }
        withAnimation(.easeOut(duration: 0.6).delay(0.2)) { headerOpacity = 1.0 }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4)) { sectionsOffset = 0 }
    }
    private func animateEditExit() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { formScale = 0.9; headerOpacity = 0; sectionsOffset = 50; }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { presentationMode.wrappedValue.dismiss() }
    }

    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 20))
                .foregroundStyle(LinearGradient(colors: [color, color.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
            Text(title).font(.system(size: 18, weight: .semibold, design: .rounded)).foregroundColor(.black.opacity(0.8))
            Spacer()
        }
    }
    
    private func editModernTextField(title: String, text: Binding<String>, placeholder: String, icon: String, isRequired: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon).foregroundColor(.gray)
                Text(title + (isRequired ? "*" : "")).font(.system(size: 14, weight: .medium)).foregroundColor(.black.opacity(0.7))
            }
            TextField(placeholder, text: text)
                .padding(.horizontal, 16).padding(.vertical, 12).background(Color.white.opacity(0.8)).clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && isRequired && !isValid && showingAlert ? Color.red.opacity(0.6) : Color.gray.opacity(0.3), lineWidth: 1))
            if text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && isRequired && !isValid && showingAlert {
                Text("\(title.replacingOccurrences(of: "*", with: "")) is required.").font(.caption).foregroundColor(.red.opacity(0.8)).padding(.horizontal, 4)
            }
        }
    }
    
    // MODIFIED: Replaced accountType TextField with a Picker
    private var accountTypePickerField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "briefcase.fill").foregroundColor(.gray)
                Text("Account Type*").font(.system(size: 14, weight: .medium)).foregroundColor(.black.opacity(0.7))
            }
            Picker("Account Type*", selection: $selectedAccountTypeId) {
                Text("Select Account Type...").tag(nil as Int?)
                ForEach(availableAccountTypes) { type in
                    Text(type.name).tag(type.id as Int?)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .padding(.horizontal, 16).padding(.vertical, 12).background(Color.white.opacity(0.8)).clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(selectedAccountTypeId == nil && !isValid && showingAlert ? Color.red.opacity(0.6) : Color.gray.opacity(0.3), lineWidth: 1))
            if selectedAccountTypeId == nil && !isValid && showingAlert {
                Text("Account Type is required.").font(.caption).foregroundColor(.red.opacity(0.8)).padding(.horizontal, 4)
            }
        }
    }

    // Picker for selecting the associated institution when editing an account
    private var institutionPickerField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "building.2.fill").foregroundColor(.gray)
                Text("Institution*")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.black.opacity(0.7))
            }
            Picker("Institution*", selection: $selectedInstitutionId) {
                Text("Select Institution...").tag(nil as Int?)
                ForEach(availableInstitutions) { inst in
                    Text(inst.name).tag(inst.id as Int?)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        selectedInstitutionId == nil && !isValid && showingAlert ?
                            Color.red.opacity(0.6) : Color.gray.opacity(0.3),
                        lineWidth: 1
                    )
            )
            if selectedInstitutionId == nil && !isValid && showingAlert {
                Text("Institution is required.")
                    .font(.caption)
                    .foregroundColor(.red.opacity(0.8))
                    .padding(.horizontal, 4)
            }
        }
    }

    private var editModernContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 20) {
                    sectionHeader(title: "Account Details", icon: "pencil.and.scribble", color: .orange)
                    editModernTextField(title: "Account Name*", text: $accountName, placeholder: "e.g., Main Trading Account", icon: "tag.fill", isRequired: true)
                    institutionPickerField
                    editModernTextField(title: "Account Number*", text: $accountNumber, placeholder: "e.g., U1234567", icon: "number.square.fill", isRequired: true)
                    accountTypePickerField // MODIFIED: Using Picker
                }.modifier(ModernFormSection(color: .orange))
                VStack(alignment: .leading, spacing: 20) {
                    sectionHeader(title: "Financial & Dates", icon: "calendar.badge.clock", color: .green)
                    currencyPickerField
                    Toggle(isOn: $setOpeningDate.animation()) { Text("Set Opening Date") }.modifier(ModernToggleStyle(tint: .green))
                    if setOpeningDate {
                        DatePicker(selection: $openingDateInput, displayedComponents: .date) { HStack { Image(systemName: "calendar.badge.plus").foregroundColor(.gray); Text("Opening Date") .font(.system(size: 14, weight: .medium)).foregroundColor(.black.opacity(0.7)) } }
                        .padding(.horizontal, 16).padding(.vertical, 12).background(Color.white.opacity(0.8)).clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3), lineWidth: 1)).shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                        .transition(.asymmetric(insertion: .scale(scale: 0.95, anchor: .top).combined(with: .opacity), removal: .opacity))
                    }
                    Toggle(isOn: $setClosingDate.animation()) { Text("Set Closing Date") }.modifier(ModernToggleStyle(tint: .orange))
                    if setClosingDate {
                        DatePicker(selection: $closingDateInput, in: (setOpeningDate ? openingDateInput... : Date.distantPast...), displayedComponents: .date) { HStack { Image(systemName: "calendar.badge.minus").foregroundColor(.gray); Text("Closing Date") .font(.system(size: 14, weight: .medium)).foregroundColor(.black.opacity(0.7)) } }
                        .padding(.horizontal, 16).padding(.vertical, 12).background(Color.white.opacity(0.8)).clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3), lineWidth: 1)).shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                        .transition(.asymmetric(insertion: .scale(scale: 0.95, anchor: .top).combined(with: .opacity), removal: .opacity))
                        if setOpeningDate && closingDateInput < openingDateInput && setClosingDate { Text("Closing date must be on or after opening date.").font(.caption).foregroundColor(.red).padding(.leading, 16) }
                    }
                    HStack {
                        Image(systemName: "clock.badge.checkmark").foregroundColor(.gray)
                        Text("Earliest Instrument Update")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.black.opacity(0.7))
                        Spacer()
                        if let d = earliestInstrumentDate {
                            Text(DateFormatter.swissDate.string(from: d))
                                .foregroundColor(.gray)
                        } else {
                            Text("N/A").foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                }.modifier(ModernFormSection(color: .green))
                VStack(alignment: .leading, spacing: 20) {
                    sectionHeader(title: "Settings & Notes", icon: "gearshape.fill", color: .purple)
                    Toggle(isOn: $includeInPortfolio) { Text("Include in Portfolio Calculations") }.modifier(ModernToggleStyle(tint: .purple))
                    Toggle(isOn: $isActive) { Text("Account is Active") }.modifier(ModernToggleStyle(tint: .green))
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { Image(systemName: "note.text").foregroundColor(.gray); Text("Notes").font(.system(size: 14, weight: .medium)).foregroundColor(.black.opacity(0.7)) }
                        TextEditor(text: $notes).frame(minHeight: 80, maxHeight: 150).font(.system(size: 16)).padding(12)
                            .background(Color.white.opacity(0.8)).clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3), lineWidth: 1)).shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                    }
                }.modifier(ModernFormSection(color: .purple))
            }.padding(.horizontal, 24).padding(.bottom, 100)
        }.offset(y: sectionsOffset)
    }
    private var currencyPickerField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Image(systemName: "dollarsign.circle.fill").foregroundColor(.gray); Text("Default Currency*").font(.system(size: 14, weight: .medium)).foregroundColor(.black.opacity(0.7)) }
            Picker("Default Currency*", selection: $currencyCode) { Text("Select Currency...").tag(""); ForEach(availableCurrencies, id: \.code) { curr in Text("\(curr.name) (\(curr.code))").tag(curr.code) } }
            .pickerStyle(MenuPickerStyle()).padding(.horizontal, 16).padding(.vertical, 12).background(Color.white.opacity(0.8)).clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(currencyCode.isEmpty && !isValid && showingAlert ? Color.red.opacity(0.6) : Color.gray.opacity(0.3), lineWidth: 1))
            if currencyCode.isEmpty && !isValid && showingAlert { Text("Currency is required.").font(.caption).foregroundColor(.red.opacity(0.8)).padding(.horizontal, 4) }
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
            selectedAccountTypeId = details.accountTypeId; // Set selected ID for Picker
            currencyCode = details.currencyCode;
            if let oDate = details.openingDate { openingDateInput = oDate; setOpeningDate = true } else { setOpeningDate = false; openingDateInput = Date() }
            if let cDate = details.closingDate { closingDateInput = cDate; setClosingDate = true } else { setClosingDate = false; closingDateInput = Date() }
            earliestInstrumentDate = details.earliestInstrumentLastUpdatedAt
            includeInPortfolio = details.includeInPortfolio; isActive = details.isActive; notes = details.notes ?? "";
            originalData = details; originalSetOpeningDate = setOpeningDate; originalOpeningDateInput = openingDateInput; originalSetClosingDate = setClosingDate; originalClosingDateInput = closingDateInput;
            detectChanges() // Initial check after loading
        } else { alertMessage = "❌ Error: Could not load account details."; showingAlert = true }
    }
    private func showUnsavedChangesAlert() {
        let alert = NSAlert(); alert.messageText = "Unsaved Changes"; alert.informativeText = "You have unsaved changes. Are you sure you want to close?"; alert.addButton(withTitle: "Save & Close"); alert.addButton(withTitle: "Discard & Close"); alert.addButton(withTitle: "Cancel"); alert.alertStyle = .warning
        let response = alert.runModal(); if response == .alertFirstButtonReturn { saveAccountChanges() } else if response == .alertSecondButtonReturn { animateEditExit() }
    }
    func saveAccountChanges() {
        guard isValid, let typeId = selectedAccountTypeId, let _ = selectedInstitutionId else {
            var errorMsg = "Please fill all mandatory fields (*)."; if setClosingDate && setOpeningDate && closingDateInput < openingDateInput { errorMsg += "\nClosing date cannot be before opening date." }; if selectedAccountTypeId == nil {errorMsg += "\nAccount Type is required."}
            alertMessage = errorMsg; showingAlert = true; return
        }
        guard hasChanges else { animateEditExit(); return } // Only save if there are changes
        isLoading = true
        let finalOpeningDate: Date? = setOpeningDate ? openingDateInput : nil
        let finalClosingDate: Date? = setClosingDate ? closingDateInput : nil
        
        let success = dbManager.updateAccount(
            id: accountId,
            accountName: accountName.trimmingCharacters(in: .whitespacesAndNewlines),
            institutionId: selectedInstitutionId!,
            accountNumber: accountNumber.trimmingCharacters(in: .whitespacesAndNewlines),
            accountTypeId: typeId, // Pass selected ID
            currencyCode: currencyCode,
            openingDate: finalOpeningDate,
            closingDate: finalClosingDate,
            includeInPortfolio: includeInPortfolio,
            isActive: isActive,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        isLoading = false
        if success {
            // Reload originalData to correctly reflect the saved state for subsequent 'hasChanges' checks
            if let currentDetails = dbManager.fetchAccountDetails(id: accountId) {
                originalData = currentDetails
                selectedAccountTypeId = currentDetails.accountTypeId // ensure this is also updated for comparison
                if let oDate = currentDetails.openingDate { originalOpeningDateInput = oDate; originalSetOpeningDate = true } else { originalSetOpeningDate = false }
                if let cDate = currentDetails.closingDate { originalClosingDateInput = cDate; originalSetClosingDate = true } else { originalSetClosingDate = false }
            }
            detectChanges() // Re-evaluate hasChanges, should be false now
            NotificationCenter.default.post(name: NSNotification.Name("RefreshAccounts"), object: nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { animateEditExit() }
        } else { alertMessage = "❌ Failed to update account. Please try again."; if alertMessage.contains("UNIQUE constraint failed: Accounts.account_number") { alertMessage = "❌ Failed to update account: Account Number must be unique."}; showingAlert = true }
    }
}
