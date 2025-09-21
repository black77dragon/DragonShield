// DragonShield/Views/InstitutionsView.swift
// MARK: - Version 1.5
// MARK: - History
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

import SwiftUI
import Foundation
#if os(macOS)
import AppKit
#endif


private let isoRegionIdentifiers: [String] = Locale.Region.isoRegions.map(\.identifier)
private let isoRegionIdentifierSet: Set<String> = Set(isoRegionIdentifiers)


fileprivate struct TableFontConfig {
    let nameSize: CGFloat
    let secondarySize: CGFloat
    let headerSize: CGFloat
    let badgeSize: CGFloat
}

private enum InstitutionTableColumn: String, CaseIterable, Codable {
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

    @State private var columnFractions: [InstitutionTableColumn: CGFloat]
    @State private var resolvedColumnWidths: [InstitutionTableColumn: CGFloat]
    @State private var visibleColumns: Set<InstitutionTableColumn>
    @State private var selectedFontSize: TableFontSize
    @State private var didRestoreColumnFractions = false
    @State private var availableTableWidth: CGFloat = 0
    @State private var dragContext: ColumnDragContext? = nil

    @State private var headerOpacity: Double = 0
    @State private var contentOffset: CGFloat = 30
    @State private var buttonsOpacity: Double = 0
    @State private var hasHydratedPreferences = false
    @State private var isHydratingPreferences = false

    private static let visibleColumnsKey = "InstitutionsView.visibleColumns.v1"
    private static let legacyFontSizeKey = "InstitutionsView.tableFontSize.v1"
    private static let legacyColumnFractionsKey = "InstitutionsView.columnFractions.v1"
    private let headerBackground = Color(red: 230.0/255.0, green: 242.0/255.0, blue: 1.0)

    enum SortColumn: String, CaseIterable {
        case name, bic, type, currency, country, website, contact, status
    }

    private static let columnOrder: [InstitutionTableColumn] = [.name, .bic, .type, .currency, .country, .website, .contact, .notes, .status]
    private static let defaultVisibleColumns: Set<InstitutionTableColumn> = [.name, .bic, .type, .currency, .country, .notes, .status]
    private static let requiredColumns: Set<InstitutionTableColumn> = [.name]

    private enum TableFontSize: String, CaseIterable {
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
            switch self {
            case .xSmall: return 12
            case .small: return 13.5
            case .medium: return 15
            case .large: return 16.5
            case .xLarge: return 18
            }
        }

        var secondarySize: CGFloat { baseSize - 1 }
        var badgeSize: CGFloat { baseSize - 2 }
        var headerSize: CGFloat { baseSize - 1 }
    }

    private static let defaultColumnWidths: [InstitutionTableColumn: CGFloat] = [
        .name: 280,
        .bic: 140,
        .type: 160,
        .currency: 100,
        .country: 120,
        .website: 220,
        .contact: 220,
        .notes: 60,
        .status: 140
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
        .status: 110
    ]

    private static let initialColumnFractions: [InstitutionTableColumn: CGFloat] = {
        let total = defaultColumnWidths.values.reduce(0, +)
        guard total > 0 else {
            let fallback = 1.0 / CGFloat(InstitutionTableColumn.allCases.count)
            return InstitutionTableColumn.allCases.reduce(into: [:]) { $0[$1] = fallback }
        }
        return InstitutionTableColumn.allCases.reduce(into: [:]) { result, column in
            let width = defaultColumnWidths[column] ?? 0
            result[column] = max(0.0001, width / total)
        }
    }()

    fileprivate static let columnHandleWidth: CGFloat = 10
    fileprivate static let columnHandleHitSlop: CGFloat = 8
    fileprivate static let columnTextInset: CGFloat = 12

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

    private struct ColumnDragContext {
        let primary: InstitutionTableColumn
        let neighbor: InstitutionTableColumn
        let primaryBaseWidth: CGFloat
        let neighborBaseWidth: CGFloat
    }

    init() {
        let defaults = InstitutionsView.initialColumnFractions
        _columnFractions = State(initialValue: defaults)
        _resolvedColumnWidths = State(initialValue: InstitutionsView.defaultColumnWidths)

        if let storedVisible = UserDefaults.standard.array(forKey: InstitutionsView.visibleColumnsKey) as? [String] {
            let set = Set(storedVisible.compactMap(InstitutionTableColumn.init(rawValue:)))
            _visibleColumns = State(initialValue: set.isEmpty ? InstitutionsView.defaultVisibleColumns : set)
        } else {
            _visibleColumns = State(initialValue: InstitutionsView.defaultVisibleColumns)
        }
        _selectedFontSize = State(initialValue: .medium)
    }

    private var fontConfig: TableFontConfig {
        TableFontConfig(
            nameSize: selectedFontSize.baseSize,
            secondarySize: max(11, selectedFontSize.secondarySize),
            headerSize: selectedFontSize.headerSize,
            badgeSize: max(10, selectedFontSize.badgeSize)
        )
    }

    private var activeColumns: [InstitutionTableColumn] {
        let set = visibleColumns.intersection(InstitutionsView.columnOrder)
        let ordered = InstitutionsView.columnOrder.filter { set.contains($0) }
        return ordered.isEmpty ? [.name] : ordered
    }

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
                    inst.notes ?? ""
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

            InstitutionsParticleBackground()

            VStack(spacing: 0) {
                modernHeader
                searchAndStats
                institutionsContent
                modernActionBar
            }
        }
        .onAppear {
            hydratePreferencesIfNeeded()
            loadData()
            animateEntrance()
            if !didRestoreColumnFractions {
                restoreColumnFractions()
                didRestoreColumnFractions = true
                recalcColumnWidths()
            }
        }
        .onChange(of: selectedFontSize) {
            persistFontSize()
        }
        .onReceive(dbManager.$institutionsTableFontSize) { newValue in
            guard !isHydratingPreferences, let size = TableFontSize(rawValue: newValue), size != selectedFontSize else { return }
            isHydratingPreferences = true
            print("📥 [institutions] Received font size update from configuration: \(newValue)")
            selectedFontSize = size
            DispatchQueue.main.async { isHydratingPreferences = false }
        }
        .onReceive(dbManager.$institutionsTableColumnFractions) { newValue in
            guard !isHydratingPreferences else { return }
            isHydratingPreferences = true
            print("📥 [institutions] Received column fractions from configuration: \(newValue)")
            let restored = restoreFromStoredColumnFractions(newValue)
            if restored {
                didRestoreColumnFractions = true
                recalcColumnWidths()
            }
            DispatchQueue.main.async { isHydratingPreferences = false }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshInstitutions"))) { _ in
            loadData()
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
                    message: Text("Are you sure you want to delete '\\(inst.name)'?"),
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

    var isValid: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let currValid = defaultCurrency.isEmpty || defaultCurrency.count == 3
        let countryValid = countryCode.isEmpty || countryCode.count == 2
        return !trimmedName.isEmpty && currValid && countryValid
    }

    var body: some View {
        VStack {
            Text("Add Institution").font(.headline)
            Form {
                TextField("Name", text: $name)
                TextField("BIC", text: $bic)
                TextField("Type", text: $type)
                TextField("Website", text: $website)
                TextField("Contact Info", text: $contactInfo)
                Picker("Default Currency", selection: $defaultCurrency) {
                    Text("None").tag("")
                    ForEach(availableCurrencies, id: \.code) { curr in
                        Text("\\(curr.code)").tag(curr.code)
                    }
                }
                Picker("Country", selection: $countryCode) {
                    Text("None").tag("")
                    ForEach(availableCountries, id: \.self) { code in
                        Text("\\(flagEmoji(code)) \\(code)").tag(code)
                    }
                }
                Text("Notes")
                TextEditor(text: $notes)
                    .frame(height: 60)
                Toggle("Active", isOn: $isActive)
            }
            HStack {
                Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                Spacer()
                Button("Save") { save() }.disabled(!isValid)
            }.padding()
        }
        .padding().frame(width: 400, height: 500)
        .onAppear {
            availableCurrencies = dbManager.fetchActiveCurrencies()
            availableCountries = Locale.Region.isoRegions.map(\.identifier).sorted()
        }
        .alert("Result", isPresented: $showingAlert) { Button("OK") { if alertMessage.hasPrefix("✅") { presentationMode.wrappedValue.dismiss() } } } message: { Text(alertMessage) }
    }

    private func save() {
        let newId = dbManager.addInstitution(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            bic: bic.isEmpty ? nil : bic,
            type: type.isEmpty ? nil : type,
            website: website.isEmpty ? nil : website,
            contactInfo: contactInfo.isEmpty ? nil : contactInfo,
            defaultCurrency: defaultCurrency.isEmpty ? nil : defaultCurrency,
            countryCode: countryCode.isEmpty ? nil : countryCode,
            notes: notes.isEmpty ? nil : notes,
            isActive: isActive)
        if let id = newId {
            NotificationCenter.default.post(name: NSNotification.Name("RefreshInstitutions"), object: nil)
            onAdd?(id)
            alertMessage = "✅ Added"
        } else {
            alertMessage = "❌ Failed"
        }
        showingAlert = true
    }
}

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

    var isValid: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let currValid = defaultCurrency.isEmpty || defaultCurrency.count == 3
        let countryValid = countryCode.isEmpty || countryCode.count == 2
        return !trimmedName.isEmpty && currValid && countryValid
    }

    var body: some View {
        VStack {
            Text("Edit Institution").font(.headline)
            Form {
                TextField("Name", text: $name)
                TextField("BIC", text: $bic)
                TextField("Type", text: $type)
                TextField("Website", text: $website)
                TextField("Contact Info", text: $contactInfo)
                Picker("Default Currency", selection: $defaultCurrency) {
                    Text("None").tag("")
                    ForEach(availableCurrencies, id: \.code) { curr in
                        Text("\\(curr.code)").tag(curr.code)
                    }
                }
                Picker("Country", selection: $countryCode) {
                    Text("None").tag("")
                    ForEach(availableCountries, id: \.self) { code in
                        Text("\\(flagEmoji(code)) \\(code)").tag(code)
                    }
                }
                Text("Notes")
                TextEditor(text: $notes)
                    .frame(height: 60)
                Toggle("Active", isOn: $isActive)
            }
            HStack {
                Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                Spacer()
                Button("Save") { save() }.disabled(!isValid)
            }.padding()
        }
        .padding().frame(width: 400, height: 500)
        .onAppear {
            if !loaded { load() }
            availableCurrencies = dbManager.fetchActiveCurrencies()
            availableCountries = Locale.Region.isoRegions.map(\.identifier).sorted()
        }
        .alert("Result", isPresented: $showingAlert) { Button("OK") { if alertMessage.hasPrefix("✅") { presentationMode.wrappedValue.dismiss() } } } message: { Text(alertMessage) }
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
            isActive: isActive)
        if success {
            NotificationCenter.default.post(name: NSNotification.Name("RefreshInstitutions"), object: nil)
            alertMessage = "✅ Updated"
        } else {
            alertMessage = "❌ Failed"
        }
        showingAlert = true
    }
}

private extension InstitutionsView {
    var modernHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    Image(systemName: "building.2.crop.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.blue)
                    Text("Institutions")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(LinearGradient(colors: [.black, .gray], startPoint: .top, endPoint: .bottom))
                }
                Text("Manage financial institutions")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            Spacer()

            HStack(spacing: 16) {
                modernStatCard(
                    title: "Total",
                    value: totalStatValue,
                    icon: "number.circle.fill",
                    color: .blue
                )

                modernStatCard(
                    title: "Active",
                    value: activeStatValue,
                    icon: "checkmark.circle.fill",
                    color: .green
                )

                modernStatCard(
                    title: "Currencies",
                    value: currencyStatValue,
                    icon: "dollarsign.circle.fill",
                    color: .purple
                )
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .opacity(headerOpacity)
    }

    var searchAndStats: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)

                TextField("Search institutions...", text: $searchText)
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

            if !searchText.isEmpty || !typeFilters.isEmpty || !currencyFilters.isEmpty || !statusFilters.isEmpty {
                HStack {
                    Text("Found \\(sortedInstitutions.count) of \\(institutions.count) institutions")
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

    var institutionsContent: some View {
        VStack(spacing: 12) {
            tableControls
            if sortedInstitutions.isEmpty {
                emptyStateView
                    .offset(y: contentOffset)
            } else {
                institutionsTable
                    .offset(y: contentOffset)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }

    var tableControls: some View {
        HStack(spacing: 12) {
            columnsMenu
            fontSizePicker
            Spacer()
            if visibleColumns != InstitutionsView.defaultVisibleColumns || selectedFontSize != .medium {
                Button("Reset View", action: resetTablePreferences)
                    .buttonStyle(.link)
            }
        }
        .padding(.horizontal, 4)
        .font(.system(size: 12))
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
        }
    }

    var fontSizePicker: some View {
        Picker("Font Size", selection: $selectedFontSize) {
            ForEach(TableFontSize.allCases, id: \.self) { size in
                Text(size.label).tag(size)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 260)
        .labelsHidden()
    }

    var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: searchText.isEmpty ? "building.2" : "magnifyingglass")
                    .font(.system(size: 64))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.gray.opacity(0.5), .gray.opacity(0.3)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                VStack(spacing: 8) {
                    Text(searchText.isEmpty ? "No institutions yet" : "No matching institutions")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray)

                    Text(searchText.isEmpty ? "Add your first institution to get started." : "Try adjusting your search terms or filters.")
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }

                if searchText.isEmpty {
                    Button { showAddSheet = true } label: {
                        Label("Add Institution", systemImage: "plus")
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

    var institutionsTable: some View {
        GeometryReader { proxy in
            let availableWidth = max(proxy.size.width, 0)
            let targetWidth = max(availableWidth, totalMinimumWidth())

            ScrollView(.horizontal, showsIndicators: true) {
                VStack(spacing: 0) {
                    modernTableHeader
                    institutionsTableRows
                }
                .frame(width: targetWidth, alignment: .leading)
            }
            .frame(width: availableWidth, alignment: .leading)
            .onAppear {
                updateAvailableWidth(targetWidth)
            }
            .onChange(of: proxy.size.width) { _, newWidth in
                updateAvailableWidth(max(newWidth, totalMinimumWidth()))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 0)
    }

    var institutionsTableRows: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(sortedInstitutions) { inst in
                    ModernInstitutionRowView(
                        institution: inst,
                        columns: activeColumns,
                        fontConfig: fontConfig,
                        rowPadding: CGFloat(dbManager.tableRowPadding),
                        isSelected: selectedInstitution?.id == inst.id,
                        onTap: {
                            selectedInstitution = inst
                        },
                        onEdit: {
                            selectedInstitution = inst
                            showEditSheet = true
                        },
                        widthFor: { width(for: $0) }
                    )
                }
            }
        }
        .background(
            Rectangle()
                .fill(.regularMaterial)
                .overlay(Rectangle().stroke(Color.gray.opacity(0.12), lineWidth: 1))
        )
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        .frame(width: max(availableTableWidth, totalMinimumWidth()), alignment: .leading)
    }

    var modernTableHeader: some View {
        HStack(spacing: 0) {
            ForEach(activeColumns, id: \.self) { column in
                headerCell(for: column)
                    .frame(width: width(for: column), alignment: .leading)
            }
        }
        .padding(.trailing, 12)
        .padding(.vertical, 2)
        .background(
            Rectangle()
                .fill(headerBackground)
                .overlay(Rectangle().stroke(Color.blue.opacity(0.15), lineWidth: 1))
        )
        .frame(width: max(availableTableWidth, totalMinimumWidth()), alignment: .leading)
    }

    func headerCell(for column: InstitutionTableColumn) -> some View {
        let leadingTarget = leadingHandleTarget(for: column)
        let isLast = isLastActiveColumn(column)
        let sortOption = sortOption(for: column)
        let isActiveSort = sortOption.map { $0 == sortColumn } ?? false
        let filterBinding = filterBinding(for: column)
        let filterOptions = filterValues(for: column)

        return ZStack(alignment: .leading) {
            if let target = leadingTarget {
                resizeHandle(for: target)
            }
            if isLast {
                resizeHandle(for: column)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            HStack(spacing: 6) {
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
                                .font(.system(size: fontConfig.headerSize, weight: .semibold))
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
                        .font(.system(size: fontConfig.headerSize, weight: .semibold))
                        .foregroundColor(.black)
                        .help("Notes")
                } else {
                    Text(column.title)
                        .font(.system(size: fontConfig.headerSize, weight: .semibold))
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
            .padding(.leading, InstitutionsView.columnTextInset + (leadingTarget == nil ? 0 : InstitutionsView.columnHandleWidth))
            .padding(.trailing, isLast ? InstitutionsView.columnHandleWidth + 8 : 8)
        }
    }

    func resizeHandle(for column: InstitutionTableColumn) -> some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: InstitutionsView.columnHandleWidth + InstitutionsView.columnHandleHitSlop * 2,
                   height: 28)
            .offset(x: -InstitutionsView.columnHandleHitSlop)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
#if os(macOS)
                        InstitutionsView.columnResizeCursor.set()
#endif
                        guard availableTableWidth > 0 else { return }
                        if dragContext?.primary != column {
                            beginDrag(for: column)
                        }
                        updateDrag(for: column, translation: value.translation.width)
                    }
                    .onEnded { _ in
                        finalizeDrag()
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
                    InstitutionsView.columnResizeCursor.set()
                } else {
                    NSCursor.arrow.set()
                }
            }
#endif
    }

    func filterChip(text: String, onRemove: @escaping () -> Void) -> some View {
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

    var modernActionBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1)

            HStack(spacing: 16) {
                Button { showAddSheet = true } label: {
                    Label("Add Institution", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.67, green: 0.89, blue: 0.67))
                .foregroundColor(.black)

                if selectedInstitution != nil {
                    Button { showEditSheet = true } label: {
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
                        if let inst = selectedInstitution {
                            institutionToDelete = inst
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

                if let selectedName = selectedInstitution?.name {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                        Text("Selected: \(selectedName)")
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

    func modernStatCard(title: String, value: String, icon: String, color: Color) -> some View {
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

    func sortOption(for column: InstitutionTableColumn) -> SortColumn? {
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

    func filterBinding(for column: InstitutionTableColumn) -> Binding<Set<String>>? {
        switch column {
        case .type: return $typeFilters
        case .currency: return $currencyFilters
        case .status: return $statusFilters
        default: return nil
        }
    }

    func filterValues(for column: InstitutionTableColumn) -> [String] {
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

    func minimumWidth(for column: InstitutionTableColumn) -> CGFloat {
        InstitutionsView.minimumColumnWidths[column] ?? 60
    }

    func width(for column: InstitutionTableColumn) -> CGFloat {
        guard visibleColumns.contains(column) else { return 0 }
        return resolvedColumnWidths[column] ?? InstitutionsView.defaultColumnWidths[column] ?? minimumWidth(for: column)
    }

    func totalMinimumWidth() -> CGFloat {
        activeColumns.reduce(0) { $0 + minimumWidth(for: $1) }
    }

    func updateAvailableWidth(_ width: CGFloat) {
        let targetWidth = max(width, totalMinimumWidth())
        guard targetWidth.isFinite, targetWidth > 0 else { return }
        print("📏 [institutions] updateAvailableWidth(width=\(width), target=\(targetWidth))")

        if !didRestoreColumnFractions {
            restoreColumnFractions()
            didRestoreColumnFractions = true
        }

        if abs(availableTableWidth - targetWidth) < 0.5 { return }

        availableTableWidth = targetWidth
        print("📏 [institutions] Stored availableTableWidth=\(availableTableWidth)")
        adjustResolvedWidths(for: targetWidth)
        persistColumnFractions()
    }

    func adjustResolvedWidths(for availableWidth: CGFloat) {
        guard availableWidth > 0 else { return }
        let fractions = normalizedFractions()
        var remainingColumns = activeColumns
        var remainingWidth = availableWidth
        var remainingFraction = remainingColumns.reduce(0) { $0 + (fractions[$1] ?? 0) }
        var resolved: [InstitutionTableColumn: CGFloat] = [:]

        while !remainingColumns.isEmpty {
            var clamped: [InstitutionTableColumn] = []
            for column in remainingColumns {
                let fraction = fractions[column] ?? 0
                guard fraction > 0 else { continue }
                let proposed = remainingFraction > 0 ? remainingWidth * fraction / remainingFraction : 0
                let minWidth = minimumWidth(for: column)
                if proposed < minWidth - 0.5 {
                    resolved[column] = minWidth
                    remainingWidth = max(0, remainingWidth - minWidth)
                    remainingFraction -= fraction
                    clamped.append(column)
                }
            }
            if clamped.isEmpty { break }
            remainingColumns.removeAll { clamped.contains($0) }
            if remainingFraction <= 0 { break }
        }

        if !remainingColumns.isEmpty {
            if remainingFraction > 0 {
                for column in remainingColumns {
                    let fraction = fractions[column] ?? 0
                    let share = remainingWidth * fraction / remainingFraction
                    let minWidth = minimumWidth(for: column)
                    resolved[column] = max(minWidth, share)
                }
            } else {
                let share = remainingColumns.isEmpty ? 0 : remainingWidth / CGFloat(remainingColumns.count)
                for column in remainingColumns {
                    resolved[column] = max(minimumWidth(for: column), share)
                }
            }
        }

        balanceResolvedWidths(&resolved, targetWidth: availableWidth)
        for column in InstitutionsView.columnOrder {
            if !visibleColumns.contains(column) {
                resolved[column] = 0
            } else if resolved[column] == nil {
                resolved[column] = minimumWidth(for: column)
            }
        }
        resolvedColumnWidths = resolved
        print("📐 [institutions] Resolved column widths: \(resolvedColumnWidths)")

        var updatedFractions: [InstitutionTableColumn: CGFloat] = [:]
        let safeWidth = max(availableWidth, 1)
        for column in InstitutionsView.columnOrder {
            let widthValue = resolved[column] ?? 0
            updatedFractions[column] = max(0.0001, widthValue / safeWidth)
        }
        columnFractions = normalizedFractions(updatedFractions)
    }

    func balanceResolvedWidths(_ resolved: inout [InstitutionTableColumn: CGFloat], targetWidth: CGFloat) {
        let currentTotal = resolved.values.reduce(0, +)
        let difference = targetWidth - currentTotal
        guard abs(difference) > 0.5 else { return }

        if difference > 0 {
            if let column = activeColumns.first {
                resolved[column, default: minimumWidth(for: column)] += difference
            }
        } else {
            var remainingDifference = difference
            var adjustable = activeColumns.filter {
                let current = resolved[$0] ?? minimumWidth(for: $0)
                return current - minimumWidth(for: $0) > 0.5
            }

            while remainingDifference < -0.5, !adjustable.isEmpty {
                let share = remainingDifference / CGFloat(adjustable.count)
                var columnsAtMinimum: [InstitutionTableColumn] = []
                for column in adjustable {
                    let minWidth = minimumWidth(for: column)
                    let current = resolved[column] ?? minWidth
                    let adjusted = max(minWidth, current + share)
                    resolved[column] = adjusted
                    remainingDifference -= (adjusted - current)
                    if adjusted - minWidth < 0.5 {
                        columnsAtMinimum.append(column)
                    }
                    if remainingDifference >= -0.5 { break }
                }
                adjustable.removeAll { columnsAtMinimum.contains($0) }
                if adjustable.isEmpty { break }
            }
        }
    }

    func normalizedFractions(_ input: [InstitutionTableColumn: CGFloat]? = nil) -> [InstitutionTableColumn: CGFloat] {
        let source = input ?? columnFractions
        let active = activeColumns
        var result: [InstitutionTableColumn: CGFloat] = [:]
        guard !active.isEmpty else {
            for column in InstitutionsView.columnOrder { result[column] = 0 }
            return result
        }
        let total = active.reduce(0) { $0 + max(0, source[$1] ?? 0) }
        if total <= 0 {
            let share = 1.0 / CGFloat(active.count)
            for column in InstitutionsView.columnOrder {
                result[column] = active.contains(column) ? share : 0
            }
            return result
        }
        for column in InstitutionsView.columnOrder {
            if active.contains(column) {
                result[column] = max(0.0001, source[column] ?? 0) / total
            } else {
                result[column] = 0
            }
        }
        return result
    }

    func defaultFractions() -> [InstitutionTableColumn: CGFloat] {
        normalizedFractions(InstitutionsView.initialColumnFractions)
    }

    func persistColumnFractions() {
        guard !isHydratingPreferences else {
            print("ℹ️ [institutions] Skipping persistColumnFractions during hydration")
            return
        }
        isHydratingPreferences = true
        let payload = columnFractions.reduce(into: [String: Double]()) { result, entry in
            guard entry.value.isFinite else { return }
            result[entry.key.rawValue] = Double(entry.value)
        }
        print("💾 [institutions] Persisting column fractions: \(payload)")
        dbManager.setTableColumnFractions(payload, for: .institutions)
        DispatchQueue.main.async { isHydratingPreferences = false }
    }

    func restoreColumnFractions() {
        if restoreFromStoredColumnFractions(dbManager.tableColumnFractions(for: .institutions)) {
            print("📥 [institutions] Applied stored column fractions from configuration table")
            return
        }

        if let legacy = dbManager.legacyTableColumnFractions(for: .institutions) {
            let typed = typedFractions(from: legacy)
            guard !typed.isEmpty else {
                dbManager.clearLegacyTableColumnFractions(for: .institutions)
                return
            }
            columnFractions = normalizedFractions(typed)
            dbManager.setTableColumnFractions(legacy, for: .institutions)
            dbManager.clearLegacyTableColumnFractions(for: .institutions)
            print("♻️ [institutions] Migrated legacy column fractions to configuration table")
            return
        }

        columnFractions = defaultFractions()
        print("ℹ️ [institutions] Using default column fractions")
    }

    @discardableResult
    func restoreFromStoredColumnFractions(_ stored: [String: Double]) -> Bool {
        let restored = typedFractions(from: stored)
        guard !restored.isEmpty else {
            print("⚠️ [institutions] Stored column fractions empty or invalid")
            return false
        }
        columnFractions = normalizedFractions(restored)
        print("🎯 [institutions] Restored column fractions: \(restored)")
        return true
    }

    private func typedFractions(from raw: [String: Double]) -> [InstitutionTableColumn: CGFloat] {
        raw.reduce(into: [InstitutionTableColumn: CGFloat]()) { result, entry in
            guard let column = InstitutionTableColumn(rawValue: entry.key), entry.value.isFinite else { return }
            let fraction = max(0, entry.value)
            if fraction > 0 { result[column] = CGFloat(fraction) }
        }
    }

    func hydratePreferencesIfNeeded() {
        guard !hasHydratedPreferences else { return }
        hasHydratedPreferences = true
        isHydratingPreferences = true

        migrateLegacyFontIfNeeded()

        let storedFont = dbManager.tableFontSize(for: .institutions)
        if let storedSize = TableFontSize(rawValue: storedFont) {
            print("📥 [institutions] Applying stored font size: \(storedSize.rawValue)")
            selectedFontSize = storedSize
        }

        DispatchQueue.main.async { isHydratingPreferences = false }
    }

    func migrateLegacyFontIfNeeded() {
        guard let legacy = dbManager.legacyTableFontSize(for: .institutions) else { return }
        if dbManager.tableFontSize(for: .institutions) != legacy {
            print("♻️ [institutions] Migrating legacy font size \(legacy) to configuration table")
            dbManager.setTableFontSize(legacy, for: .institutions)
        }
        dbManager.clearLegacyTableFontSize(for: .institutions)
    }

    func persistVisibleColumns() {
        let ordered = InstitutionsView.columnOrder.filter { visibleColumns.contains($0) }
        UserDefaults.standard.set(ordered.map { $0.rawValue }, forKey: InstitutionsView.visibleColumnsKey)
    }

    func persistFontSize() {
        guard !isHydratingPreferences else {
            print("ℹ️ [institutions] Skipping persistFontSize during hydration")
            return
        }
        isHydratingPreferences = true
        print("💾 [institutions] Persisting font size: \(selectedFontSize.rawValue)")
        dbManager.setTableFontSize(selectedFontSize.rawValue, for: .institutions)
        DispatchQueue.main.async { isHydratingPreferences = false }
    }

    func ensureValidSortColumn() {
        let currentColumn = tableColumn(for: sortColumn)
        if !visibleColumns.contains(currentColumn) {
            if let fallback = activeColumns.compactMap(sortOption(for:)).first {
                sortColumn = fallback
            } else {
                sortColumn = .name
            }
        }
    }

    func tableColumn(for sortColumn: SortColumn) -> InstitutionTableColumn {
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

    func toggleColumn(_ column: InstitutionTableColumn) {
        var newSet = visibleColumns
        if newSet.contains(column) {
            if InstitutionsView.requiredColumns.contains(column) { return }
            if newSet.count <= 1 { return }
            newSet.remove(column)
        } else {
            newSet.insert(column)
        }
        visibleColumns = newSet
        persistVisibleColumns()
        ensureValidSortColumn()
        recalcColumnWidths()
    }

    func resetVisibleColumns() {
        visibleColumns = InstitutionsView.defaultVisibleColumns
        persistVisibleColumns()
        ensureValidSortColumn()
        recalcColumnWidths()
    }

    func resetTablePreferences() {
        visibleColumns = InstitutionsView.defaultVisibleColumns
        selectedFontSize = .medium
        persistVisibleColumns()
        persistFontSize()
        ensureValidSortColumn()
        recalcColumnWidths()
    }

    func recalcColumnWidths() {
        let width = max(availableTableWidth, totalMinimumWidth())
        guard availableTableWidth > 0 else {
            print("ℹ️ [institutions] Skipping recalcColumnWidths — available width not ready")
            return
        }
        print("🔧 [institutions] Recalculating column layout with availableWidth=\(availableTableWidth)")
        adjustResolvedWidths(for: width)
        persistColumnFractions()
    }

    func isLastActiveColumn(_ column: InstitutionTableColumn) -> Bool {
        activeColumns.last == column
    }

    func leadingHandleTarget(for column: InstitutionTableColumn) -> InstitutionTableColumn? {
        let columns = activeColumns
        guard let index = columns.firstIndex(of: column) else { return nil }
        if index == 0 {
            return column
        }
        return columns[index - 1]
    }

    func beginDrag(for column: InstitutionTableColumn) {
        guard let neighbor = neighborColumn(for: column) else { return }
        let primaryWidth = resolvedColumnWidths[column] ?? (InstitutionsView.defaultColumnWidths[column] ?? minimumWidth(for: column))
        let neighborWidth = resolvedColumnWidths[neighbor] ?? (InstitutionsView.defaultColumnWidths[neighbor] ?? minimumWidth(for: neighbor))
        dragContext = ColumnDragContext(primary: column, neighbor: neighbor, primaryBaseWidth: primaryWidth, neighborBaseWidth: neighborWidth)
    }

    func updateDrag(for column: InstitutionTableColumn, translation: CGFloat) {
        guard let context = dragContext, context.primary == column else { return }
        let totalWidth = max(availableTableWidth, 1)
        let minPrimary = minimumWidth(for: context.primary)
        let minNeighbor = minimumWidth(for: context.neighbor)
        let combined = context.primaryBaseWidth + context.neighborBaseWidth

        var newPrimary = context.primaryBaseWidth + translation
        let maximumPrimary = combined - minNeighbor
        newPrimary = min(max(newPrimary, minPrimary), maximumPrimary)
        let newNeighbor = combined - newPrimary

        var updatedFractions = columnFractions
        updatedFractions[context.primary] = max(0.0001, newPrimary / totalWidth)
        updatedFractions[context.neighbor] = max(0.0001, newNeighbor / totalWidth)
        columnFractions = normalizedFractions(updatedFractions)
        adjustResolvedWidths(for: totalWidth)
    }

    func finalizeDrag() {
        dragContext = nil
        persistColumnFractions()
    }

    func neighborColumn(for column: InstitutionTableColumn) -> InstitutionTableColumn? {
        let columns = activeColumns
        guard let index = columns.firstIndex(of: column) else { return nil }
        if index < columns.count - 1 {
            return columns[index + 1]
        } else if index > 0 {
            return columns[index - 1]
        }
        return nil
    }
}

fileprivate struct ModernInstitutionRowView: View {
    let institution: DatabaseManager.InstitutionData
    let columns: [InstitutionTableColumn]
    let fontConfig: TableFontConfig
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
                .font(.system(size: fontConfig.nameSize, weight: .medium))
                .foregroundColor(.primary)
                .padding(.leading, InstitutionsView.columnTextInset)
                .padding(.trailing, 8)
                .frame(width: widthFor(.name), alignment: .leading)
        case .bic:
            Text(institution.bic ?? "--")
                .font(.system(size: fontConfig.secondarySize, design: .monospaced))
                .foregroundColor(.secondary)
                .padding(.leading, InstitutionsView.columnTextInset)
                .padding(.trailing, 8)
                .frame(width: widthFor(.bic), alignment: .leading)
        case .type:
            Text(institution.type ?? "--")
                .font(.system(size: fontConfig.secondarySize))
                .foregroundColor(.secondary)
                .padding(.leading, InstitutionsView.columnTextInset)
                .padding(.trailing, 8)
                .frame(width: widthFor(.type), alignment: .leading)
        case .currency:
            let currency = institution.defaultCurrency ?? "--"
            Text(currency.isEmpty ? "--" : currency)
                .font(.system(size: fontConfig.badgeSize, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.blue.opacity(currency.isEmpty ? 0.06 : 0.12))
                .clipShape(Capsule())
                .padding(.leading, InstitutionsView.columnTextInset)
                .padding(.trailing, 8)
                .frame(width: widthFor(.currency), alignment: .leading)
        case .country:
            countryColumn
                .padding(.leading, InstitutionsView.columnTextInset)
                .padding(.trailing, 8)
                .frame(width: widthFor(.country), alignment: .leading)
        case .website:
            Text(websiteDisplay)
                .font(.system(size: fontConfig.secondarySize))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.leading, InstitutionsView.columnTextInset)
                .padding(.trailing, 8)
                .frame(width: widthFor(.website), alignment: .leading)
        case .contact:
            Text(contactDisplay)
                .font(.system(size: fontConfig.secondarySize))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.leading, InstitutionsView.columnTextInset)
                .padding(.trailing, 8)
                .frame(width: widthFor(.contact), alignment: .leading)
        case .notes:
            notesColumn
                .frame(width: widthFor(.notes), alignment: .center)
        case .status:
            HStack(spacing: 6) {
                Circle()
                    .fill(institution.isActive ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Text(institution.isActive ? "Active" : "Inactive")
                    .font(.system(size: fontConfig.secondarySize, weight: .medium))
                    .foregroundColor(institution.isActive ? .green : .orange)
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
            HStack(spacing: 6) {
                if let flag = info.flag {
                    Text(flag)
                        .accessibilityHidden(true)
                }
                Text(info.name)
                    .foregroundColor(.secondary)
            }
            .font(.system(size: fontConfig.secondarySize))
            .accessibilityElement(children: .combine)
            .accessibilityLabel(info.accessibilityLabel)
        } else {
            Text("--")
                .font(.system(size: fontConfig.secondarySize))
                .foregroundColor(.secondary)
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
        if let url = URL(string: "https://\\(website)") , let host = url.host {
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
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(PlainButtonStyle())
            .alert("Note", isPresented: $showNote) {
                Button("Close", role: .cancel) { }
            } message: {
                Text(note)
            }
        } else {
            Image(systemName: "note.text")
                .font(.system(size: 14))
                .foregroundColor(.gray.opacity(0.3))
        }
    }
}

private func normalizedRegionCode(from raw: String) -> String? {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    let separators = CharacterSet(charactersIn: " -_/|.,")
    let uppercase = trimmed.uppercased()
    let uppercaseComponents = uppercase.components(separatedBy: separators).filter { !$0.isEmpty }
    let tokens = ([uppercase] + uppercaseComponents)
        .map { $0.filter { ("A"..."Z").contains($0) } }
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
        guard (65...90).contains(scalar.value), let flagScalar = UnicodeScalar(127397 + scalar.value) else { return "" }
        scalars.append(flagScalar)
    }
    return String(scalars)
}

private func extractFlag(from raw: String) -> String? {
    var buffer = String.UnicodeScalarView()
    for scalar in raw.unicodeScalars {
        let value = scalar.value
        if (127462...127487).contains(value) {
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
    let scalars = flag.unicodeScalars.filter { (127462...127487).contains($0.value) }
    guard scalars.count == 2 else { return nil }
    var code = ""
    for scalar in scalars {
        let value = scalar.value - 127397
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

    struct LookupCache {
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

struct InstitutionParticle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var size: CGFloat
    var opacity: Double
}

struct InstitutionsParticleBackground: View {
    @State private var particles: [InstitutionParticle] = []

    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                Circle()
                    .fill(Color.blue.opacity(0.03))
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
        particles = (0..<15).map { _ in
            InstitutionParticle(
                position: CGPoint(x: CGFloat.random(in: 0...1200), y: CGFloat.random(in: 0...800)),
                size: CGFloat.random(in: 2...8),
                opacity: Double.random(in: 0.1...0.2)
            )
        }
    }

    private func animateParticles() {
        withAnimation(.linear(duration: 30).repeatForever(autoreverses: false)) {
            for index in particles.indices {
                particles[index].position.x += CGFloat.random(in: -40...40)
                particles[index].position.y += CGFloat.random(in: -40...40)
            }
        }
    }
}
