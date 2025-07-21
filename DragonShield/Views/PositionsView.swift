// DragonShield/Views/PositionsView.swift
// MARK: - Version 1.2 (2025-06-16)
// MARK: - History
// - 1.1 -> 1.2: Updated to use global PositionReportData type.
// - 1.0 -> 1.1: Display live PositionReports data from database.
// - Initial creation: Displays positions with upload and report dates.

import SwiftUI

struct PositionsView: View {
    @EnvironmentObject var dbManager: DatabaseManager

    @State private var positions: [PositionReportData] = []
    @State private var selectedRows = Set<PositionReportData.ID>()
    @State private var searchText = ""

    @State private var institutions: [DatabaseManager.InstitutionData] = []
    @State private var selectedInstitutionIds: Set<Int> = []
    @State private var showingDeleteAlert = false
    @State private var showDeleteSuccessToast = false
    @State private var showAddSheet = false
    @State private var showEditSheet = false
    @State private var positionToEdit: PositionReportData? = nil
    @State private var positionToDelete: PositionReportData? = nil
    @State private var showDeleteSingleAlert = false
    @State private var buttonsOpacity: Double = 0

    @State private var headerOpacity: Double = 0
    @State private var contentOffset: CGFloat = 30

    @State private var sortOrder = [KeyPathComparator(\PositionReportData.accountName)]

    @StateObject private var viewModel = PositionsViewModel()

    enum Column: String, CaseIterable, Identifiable {
        case notes, account, institution, instrument, currency, quantity
        case purchase, current, valueOriginal, valueChf, dates, actions

        var id: String { rawValue }

        var title: String {
            switch self {
            case .notes: return "Notes"
            case .account: return "Account"
            case .institution: return "Institution"
            case .instrument: return "Instrument"
            case .currency: return "Currency"
            case .quantity: return "Qty"
            case .purchase: return "Purchase"
            case .current: return "Current"
            case .valueOriginal: return "Position Value (Original Currency)"
            case .valueChf: return "Position Value (CHF)"
            case .dates: return "Dates"
            case .actions: return "Actions"
            }
        }
    }

    private static let requiredColumns: Set<Column> = [.account, .instrument]

    @AppStorage(UserDefaultsKeys.positionsVisibleColumns)
    private var persistedColumnsData: Data = Data()

    @AppStorage(UserDefaultsKeys.positionsFontSize)
    private var fontSize: Double = 13

    @State private var visibleColumns: Set<Column> = Set(Column.allCases)
    @State private var showSettingsPopover = false

    init() {
        if let data = UserDefaults.standard.data(forKey: UserDefaultsKeys.positionsVisibleColumns),
           let strings = try? JSONDecoder().decode([String].self, from: data) {
            let decoded = Set(strings.compactMap(Column.init(rawValue:)))
            _visibleColumns = State(initialValue: decoded.union(Self.requiredColumns))
        } else {
            _visibleColumns = State(initialValue: Set(Column.allCases))
        }
    }

    private static let chfFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        f.groupingSeparator = "'"
        f.usesGroupingSeparator = true
        f.roundingMode = .down
        return f
    }()

    var sortedPositions: [PositionReportData] {
        filteredPositions.sorted(using: sortOrder)
    }

    var selectedInstitutionNames: [String] {
        institutions.filter { selectedInstitutionIds.contains($0.id) }.map { $0.name }
    }

    var filteredPositions: [PositionReportData] {
        var result = positions
        if !searchText.isEmpty {
            result = result.filter { position in
                position.instrumentName.localizedCaseInsensitiveContains(searchText) ||
                position.accountName.localizedCaseInsensitiveContains(searchText) ||
                String(position.id).contains(searchText) ||
                (position.importSessionId.map { String($0).contains(searchText) } ?? false)
            }
        }
        if !selectedInstitutionIds.isEmpty {
            result = result.filter { pos in
                selectedInstitutionNames.contains(pos.institutionName)
            }
        }
        return result
    }

    var selectedPositionsTotalCHF: Double {
        filteredPositions.reduce(0) { sum, pos in
            if let valOpt = viewModel.positionValueCHF[pos.id], let val = valOpt {
                return sum + val
            }
            return sum
        }
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
                addButtonBar
                positionsContent
                dangerZone
            }
        }
        .onAppear {
            loadPositions()
            loadInstitutions()
            viewModel.calculateValues(positions: positions, db: dbManager)
            animateEntrance()
        }
        .alert("Delete Positions", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                let ids = Array(selectedInstitutionIds)
                _ = dbManager.deletePositionReports(institutionIds: ids)
                selectedInstitutionIds.removeAll()
                loadPositions()
                showDeleteSuccessToast = true
            }
        } message: {
            if !selectedInstitutionIds.isEmpty {
                let names = selectedInstitutionNames.joined(separator: ", ")
                let count = positions.filter { selectedInstitutionNames.contains($0.institutionName) }.count
                Text("Delete \(count) positions for \(names)? This action cannot be undone.")
            }
        }
        .alert("Delete Position", isPresented: $showDeleteSingleAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let p = positionToDelete {
                    _ = dbManager.deletePositionReport(id: p.id)
                    loadPositions()
                }
            }
        } message: {
            if let p = positionToDelete {
                Text("Delete position #\(p.id)?")
            }
        }
        .sheet(isPresented: $showAddSheet) {
            PositionFormView(position: nil) {
                loadPositions()
            }
            .environmentObject(dbManager)
        }
        .sheet(item: $positionToEdit) { item in
            PositionFormView(position: item) {
                loadPositions()
            }
            .environmentObject(dbManager)
        }
        .toast(isPresented: $viewModel.showErrorToast, message: "Failed to fetch exchange rates.")
        .toast(isPresented: $showDeleteSuccessToast, message: "Positions deleted")
        .onChange(of: visibleColumns) {
            persistVisibleColumns()
        }
    }

    // MARK: - Modern Header
    private var modernHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    Image(systemName: "tablecells")
                        .font(.system(size: 32))
                        .foregroundColor(.blue)
                    Text("Positions")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                }
                Text("Current holdings with report details")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            Spacer()
            HStack(spacing: 16) {
                modernStatCard(title: "Total", value: "\(positions.count)", icon: "number.circle.fill", color: .blue)
                ZStack {
                    modernStatCard(title: "Total Asset Value (CHF)",
                                   value: Self.chfFormatter.string(from: NSNumber(value: viewModel.totalAssetValueCHF)) ?? "0",
                                   icon: "sum", color: .blue)
                    if viewModel.calculating {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.1))
                        ProgressView()
                    }
                }
                modernStatCard(title: "Selected Value (CHF)",
                               value: Self.chfFormatter.string(from: NSNumber(value: selectedPositionsTotalCHF)) ?? "0",
                               icon: "tray.full", color: .blue)
                Button {
                    viewModel.calculateValues(positions: positions, db: dbManager)
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .padding(6)
                }
                .background(Color.blue.opacity(0.1))
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.blue.opacity(0.3), lineWidth: 1))
                .buttonStyle(ScaleButtonStyle())
                .disabled(viewModel.calculating)

                Button {
                    showSettingsPopover.toggle()
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .padding(6)
                }
                .background(Color.blue.opacity(0.1))
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.blue.opacity(0.3), lineWidth: 1))
                .buttonStyle(ScaleButtonStyle())
                .popover(isPresented: $showSettingsPopover, arrowEdge: .bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Columns")
                            .font(.headline)
                        ForEach(Column.allCases) { column in
                            Toggle(column.title, isOn: Binding(
                                get: { visibleColumns.contains(column) },
                                set: { newValue in
                                    if newValue {
                                        visibleColumns.insert(column)
                                    } else if !Self.requiredColumns.contains(column) {
                                        visibleColumns.remove(column)
                                    }
                                }
                            ))
                            .disabled(Self.requiredColumns.contains(column))
                        }
                        Divider()
                        VStack(alignment: .leading) {
                            Text("Font Size: \(Int(fontSize)) pt")
                            Slider(value: $fontSize, in: 7...14, step: 1)
                                .frame(width: 160)
                        }
                    }
                    .padding()
                    .frame(width: 220)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .opacity(headerOpacity)
        .offset(y: contentOffset)
    }

    private var addButtonBar: some View {
        HStack {
            Button {
                showAddSheet = true
            } label: {
                Label("Add Position", systemImage: "plus")
            }
            .buttonStyle(PrimaryButtonStyle())
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
        .opacity(buttonsOpacity)
    }


    private var positionsContent: some View {
        let data = sortedPositions
        return Table(data, selection: $selectedRows, sortOrder: $sortOrder) {
            if visibleColumns.contains(.notes) {
                TableColumn("") { (position: PositionReportData) in
                    if let notes = position.notes, !notes.isEmpty {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                            .help("Contains notes")
                            .accessibilityLabel("Contains notes")
                            .frame(width: 20)
                    } else {
                        Color.clear.frame(width: 20)
                    }
                }
                .width(min: 24, ideal: 24)
            }

            Group {
                if visibleColumns.contains(.account) {
                    TableColumn("Account", sortUsing: KeyPathComparator(\PositionReportData.accountName)) { (position: PositionReportData) in
                        Text(position.accountName)
                            .font(.system(size: fontSize))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .width(min: 160, ideal: 180)
                }

                if visibleColumns.contains(.institution) {
                    TableColumn("Institution", sortUsing: KeyPathComparator(\PositionReportData.institutionName)) { (position: PositionReportData) in
                        Text(position.institutionName)
                            .font(.system(size: fontSize))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .width(min: 160, ideal: 180)
                }

                if visibleColumns.contains(.instrument) {
                    TableColumn("Instrument", sortUsing: KeyPathComparator(\PositionReportData.instrumentName)) { (position: PositionReportData) in
                        Text(position.instrumentName)
                            .font(.system(size: fontSize))
                            .foregroundColor(.primary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .width(min: 160, ideal: 200)
                }

                if visibleColumns.contains(.currency) {
                    TableColumn("Currency", sortUsing: KeyPathComparator(\PositionReportData.instrumentCurrency)) { (position: PositionReportData) in
                        Text(position.instrumentCurrency)
                            .font(.system(size: fontSize, weight: .semibold, design: .monospaced))
                            .foregroundColor(colorForCurrency(position.instrumentCurrency))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .width(min: 60, ideal: 70)
                }

                if visibleColumns.contains(.quantity) {
                    TableColumn("Qty", sortUsing: KeyPathComparator(\PositionReportData.quantity)) { (position: PositionReportData) in
                        Text(String(format: "%.2f", position.quantity))
                            .font(.system(size: fontSize, design: .monospaced))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .width(min: 70, ideal: 80)
                }

                if visibleColumns.contains(.purchase) {
                    TableColumn("Purchase", sortUsing: KeyPathComparator(\PositionReportData.purchasePrice)) { (position: PositionReportData) in
                        if let p = position.purchasePrice {
                            Text(String(format: "%.2f", p))
                                .font(.system(size: fontSize, design: .monospaced))
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        } else {
                            Text("-")
                                .font(.system(size: fontSize, design: .monospaced))
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                    .width(min: 80, ideal: 90)
                }

                if visibleColumns.contains(.current) {
                    TableColumn("Current", sortUsing: KeyPathComparator(\PositionReportData.currentPrice)) { (position: PositionReportData) in
                        if let cp = position.currentPrice {
                            Text(String(format: "%.2f", cp))
                                .font(.system(size: fontSize, design: .monospaced))
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        } else {
                            Text("-")
                                .font(.system(size: fontSize, design: .monospaced))
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                    .width(min: 80, ideal: 90)
                }

                if visibleColumns.contains(.valueOriginal) {
                    TableColumn("Position Value (Original Currency)") { (position: PositionReportData) in
                        if let value = viewModel.positionValueOriginal[position.id] {
                            let symbol = viewModel.currencySymbols[position.instrumentCurrency.uppercased()] ?? position.instrumentCurrency
                            Text(String(format: "%.2f %@", value, symbol))
                                .font(.system(size: fontSize, design: .monospaced))
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        } else {
                            Text("-")
                                .font(.system(size: fontSize, design: .monospaced))
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                    .width(min: 180, ideal: 200)
                }

                if visibleColumns.contains(.valueChf) {
                    TableColumn("Position Value (CHF)") { (position: PositionReportData) in
                        if let opt = viewModel.positionValueCHF[position.id] {
                            if let value = opt {
                                Text(String(format: "%.2f CHF", value))
                                    .font(.system(size: fontSize, design: .monospaced))
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            } else {
                                Text("-")
                                    .font(.system(size: fontSize, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        } else {
                            Text("-")
                                .font(.system(size: fontSize, design: .monospaced))
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                    .width(min: 150, ideal: 170)
                }
            }

            Group {
                if visibleColumns.contains(.dates) {
                    TableColumn("Dates", sortUsing: KeyPathComparator(\PositionReportData.uploadedAt)) { (position: PositionReportData) in
                        VStack {
                            if let iu = position.instrumentUpdatedAt {
                                Text(iu, formatter: DateFormatter.iso8601DateOnly)
                            }
                            Text(position.reportDate, formatter: DateFormatter.iso8601DateOnly)
                            Text(position.uploadedAt, formatter: DateFormatter.iso8601DateTime)
                        }
                        .font(.system(size: fontSize))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .width(min: 120, ideal: 140)
                }

                if visibleColumns.contains(.actions) {
                    TableColumn("Actions") { (position: PositionReportData) in
                        HStack(spacing: 8) {
                            Button(action: { positionToEdit = position }) { Image(systemName: "pencil") }
                                .buttonStyle(PlainButtonStyle())
                            Button(action: { positionToDelete = position; showDeleteSingleAlert = true }) { Image(systemName: "trash") }
                                .buttonStyle(PlainButtonStyle())
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .width(min: 60, ideal: 60)
                }
            }
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .font(.system(size: fontSize))
        .padding(24)
        .background(Theme.surface)
        .cornerRadius(8)
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

    private var dangerZone: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1)

            HStack(spacing: 16) {
                Menu {
                    ForEach(institutions, id: \.id) { inst in
                        Button {
                            if selectedInstitutionIds.contains(inst.id) {
                                selectedInstitutionIds.remove(inst.id)
                            } else {
                                selectedInstitutionIds.insert(inst.id)
                            }
                        } label: {
                            HStack {
                                Text(inst.name)
                                if selectedInstitutionIds.contains(inst.id) {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text(selectedInstitutionIds.isEmpty ? "Select Institutions" : "\(selectedInstitutionIds.count) Selected")
                            .font(.system(size: 14, weight: .medium))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .medium))
                    }
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
                    showingDeleteAlert = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                        Text("Delete Positions")
                    }
                }
                .buttonStyle(DestructiveButtonStyle())
                .disabled(selectedInstitutionIds.isEmpty)

                Spacer()

                if !selectedInstitutionIds.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                        Text(selectedInstitutionNames.joined(separator: ", "))
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
            .background(Theme.surface)
        }
        .opacity(buttonsOpacity)
    }

    private func loadPositions() {
        positions = dbManager.fetchPositionReports()
        viewModel.calculateValues(positions: positions, db: dbManager)
    }

    private func loadInstitutions() {
        institutions = dbManager.fetchInstitutions()
    }

    private func animateEntrance() {
        withAnimation(.easeOut(duration: 0.6).delay(0.1)) { headerOpacity = 1.0 }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3)) { contentOffset = 0 }
        withAnimation(.easeOut(duration: 0.4).delay(0.5)) { buttonsOpacity = 1.0 }
    }


    private func colorForCurrency(_ code: String) -> Color {
        switch code.uppercased() {
        case "USD": return .green
        case "CHF": return .red
        default: return .primary
        }
    }

    private func persistVisibleColumns() {
        let arr = visibleColumns.map { $0.rawValue }
        if let data = try? JSONEncoder().encode(arr) {
            persistedColumnsData = data
        }
    }
}


