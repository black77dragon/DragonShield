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
    @State private var selectedInstitutionId: Int? = nil
    @State private var showingDeleteAlert = false
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

    struct PositionValueOriginalComparator: SortComparator, Hashable {
        let viewModel: PositionsViewModel
        var order: SortOrder = .forward

        static func == (
            lhs: PositionValueOriginalComparator,
            rhs: PositionValueOriginalComparator
        ) -> Bool {
            ObjectIdentifier(lhs.viewModel) == ObjectIdentifier(rhs.viewModel) &&
                lhs.order == rhs.order
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(ObjectIdentifier(viewModel))
            hasher.combine(order)
        }

        func compare(_ lhs: PositionReportData, _ rhs: PositionReportData) -> ComparisonResult {
            let left = viewModel.positionValueOriginal[lhs.id]
            let right = viewModel.positionValueOriginal[rhs.id]
            return compareOptional(left, right)
        }

        private func compareOptional(_ lhs: Double?, _ rhs: Double?) -> ComparisonResult {
            switch (lhs, rhs) {
            case let (l?, r?):
                if l == r { return .orderedSame }
                if order == .forward {
                    return l < r ? .orderedAscending : .orderedDescending
                } else {
                    return l > r ? .orderedAscending : .orderedDescending
                }
            case (nil, nil):
                return .orderedSame
            case (nil, _):
                return order == .forward ? .orderedAscending : .orderedDescending
            case (_, nil):
                return order == .forward ? .orderedDescending : .orderedAscending
            }
        }
    }

    struct PositionValueCHFComparator: SortComparator, Hashable {
        let viewModel: PositionsViewModel
        var order: SortOrder = .forward

        static func == (
            lhs: PositionValueCHFComparator,
            rhs: PositionValueCHFComparator
        ) -> Bool {
            ObjectIdentifier(lhs.viewModel) == ObjectIdentifier(rhs.viewModel) &&
                lhs.order == rhs.order
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(ObjectIdentifier(viewModel))
            hasher.combine(order)
        }

        func compare(_ lhs: PositionReportData, _ rhs: PositionReportData) -> ComparisonResult {
            let left = viewModel.positionValueCHF[lhs.id] ?? nil
            let right = viewModel.positionValueCHF[rhs.id] ?? nil
            return compareOptional(left, right)
        }

        private func compareOptional(_ lhs: Double?, _ rhs: Double?) -> ComparisonResult {
            switch (lhs, rhs) {
            case let (l?, r?):
                if l == r { return .orderedSame }
                if order == .forward {
                    return l < r ? .orderedAscending : .orderedDescending
                } else {
                    return l > r ? .orderedAscending : .orderedDescending
                }
            case (nil, nil):
                return .orderedSame
            case (nil, _):
                return order == .forward ? .orderedAscending : .orderedDescending
            case (_, nil):
                return order == .forward ? .orderedDescending : .orderedAscending
            }
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

    var filteredPositions: [PositionReportData] {
        if searchText.isEmpty { return positions }
        return positions.filter { position in
            position.instrumentName.localizedCaseInsensitiveContains(searchText) ||
            position.accountName.localizedCaseInsensitiveContains(searchText) ||
            String(position.id).contains(searchText) ||
            (position.importSessionId.map { String($0).contains(searchText) } ?? false)
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
                if let id = selectedInstitutionId {
                    _ = dbManager.deletePositionReports(institutionIds: [id])
                    loadPositions()
                }
            }
        } message: {
            if let id = selectedInstitutionId,
               let name = institutions.first(where: { $0.id == id })?.name {
                Text("Are you sure you want to delete all positions for \(name)? This action cannot be undone.")
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
            notesColumn
            mainColumns
            valueColumns
            footerColumns
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .padding(24)
        .background(Theme.surface)
        .cornerRadius(8)
    }

    private var notesColumn: some TableColumnContent {
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
    }

    private var mainColumns: some TableColumnContent {
        (
            TableColumn("Account", sortUsing: KeyPathComparator(\PositionReportData.accountName)) { (position: PositionReportData) in
            Text(position.accountName)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minWidth: 150, idealWidth: 150, maxWidth: .infinity, alignment: .leading)
            },

            TableColumn("Institution", sortUsing: KeyPathComparator(\PositionReportData.institutionName)) { (position: PositionReportData) in
            Text(position.institutionName)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minWidth: 150, idealWidth: 150, maxWidth: .infinity, alignment: .leading)
            },

            TableColumn("Instrument", sortUsing: KeyPathComparator(\PositionReportData.instrumentName)) { (position: PositionReportData) in
            Text(position.instrumentName)
                .font(.system(size: 14))
                .foregroundColor(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            },

            TableColumn("Currency", sortUsing: KeyPathComparator(\PositionReportData.instrumentCurrency)) { (position: PositionReportData) in
            Text(position.instrumentCurrency)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(colorForCurrency(position.instrumentCurrency))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minWidth: 60, idealWidth: 60, maxWidth: .infinity, alignment: .center)
            },

            TableColumn("Qty", sortUsing: KeyPathComparator(\PositionReportData.quantity)) { (position: PositionReportData) in
            Text(String(format: "%.2f", position.quantity))
                .font(.system(size: 14, design: .monospaced))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minWidth: 60, idealWidth: 60, maxWidth: .infinity, alignment: .trailing)
            },

            TableColumn("Purchase", sortUsing: KeyPathComparator(\PositionReportData.purchasePrice)) { (position: PositionReportData) in
            if let p = position.purchasePrice {
                Text(String(format: "%.2f", p))
                    .font(.system(size: 14, design: .monospaced))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minWidth: 70, idealWidth: 70, maxWidth: .infinity, alignment: .trailing)
            } else {
                Text("-")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minWidth: 70, idealWidth: 70, maxWidth: .infinity, alignment: .trailing)
            }
            },

            TableColumn("Current", sortUsing: KeyPathComparator(\PositionReportData.currentPrice)) { (position: PositionReportData) in
            if let cp = position.currentPrice {
                Text(String(format: "%.2f", cp))
                    .font(.system(size: 14, design: .monospaced))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minWidth: 70, idealWidth: 70, maxWidth: .infinity, alignment: .trailing)
            } else {
                Text("-")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minWidth: 70, idealWidth: 70, maxWidth: .infinity, alignment: .trailing)
            }
            }
        )
    }

    private var valueColumns: some TableColumnContent {
    (
        TableColumn(
            "Position Value (Original Currency)",
            sortUsing: PositionValueOriginalComparator(viewModel: viewModel)
        ) { (position: PositionReportData) in
            if let value = viewModel.positionValueOriginal[position.id] {
                let symbol = viewModel.currencySymbols[position.instrumentCurrency.uppercased()] ?? position.instrumentCurrency
                Text(String(format: "%.2f %@", value, symbol))
                    .font(.system(size: 14, design: .monospaced))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minWidth: 110, idealWidth: 110, maxWidth: .infinity, alignment: .trailing)
            } else {
                Text("-")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minWidth: 110, idealWidth: 110, maxWidth: .infinity, alignment: .trailing)
            }
        }

        TableColumn(
            "Position Value (CHF)",
            sortUsing: PositionValueCHFComparator(viewModel: viewModel)
        ) { (position: PositionReportData) in
            if let opt = viewModel.positionValueCHF[position.id] {
                if let value = opt {
                    Text(String(format: "%.2f CHF", value))
                        .font(.system(size: 14, design: .monospaced))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(minWidth: 110, idealWidth: 110, maxWidth: .infinity, alignment: .trailing)
                } else {
                    Text("-")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(minWidth: 110, idealWidth: 110, maxWidth: .infinity, alignment: .trailing)
                }
            } else {
                Text("-")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minWidth: 110, idealWidth: 110, maxWidth: .infinity, alignment: .trailing)
            }
        }
    )
    }
    private var footerColumns: some TableColumnContent {
    (
        TableColumn("Dates", sortUsing: KeyPathComparator(\PositionReportData.uploadedAt)) { (position: PositionReportData) in
            VStack {
                if let iu = position.instrumentUpdatedAt {
                    Text(iu, formatter: DateFormatter.iso8601DateOnly)
                }
                Text(position.reportDate, formatter: DateFormatter.iso8601DateOnly)
                Text(position.uploadedAt, formatter: DateFormatter.iso8601DateTime)
            }
            .font(.system(size: 12))
            .foregroundColor(.secondary)
            .frame(minWidth: 110, idealWidth: 110, maxWidth: .infinity, alignment: .center)
        }

        TableColumn("Actions") { (position: PositionReportData) in
            HStack(spacing: 8) {
                Button(action: { positionToEdit = position }) { Image(systemName: "pencil") }
                    .buttonStyle(PlainButtonStyle())
                Button(action: { positionToDelete = position; showDeleteSingleAlert = true }) { Image(systemName: "trash") }
                    .buttonStyle(PlainButtonStyle())
            }
            .frame(width: 50)
        }
    )
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
                        Button(inst.name) {
                            selectedInstitutionId = inst.id
                        }
                    }
                } label: {
                    HStack {
                        Text(selectedInstitutionId.flatMap { id in
                            institutions.first { $0.id == id }?.name
                        } ?? "Select Institution")
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

                if let id = selectedInstitutionId,
                   let inst = institutions.first(where: { $0.id == id }) {
                    Button {
                        showingDeleteAlert = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                            Text("Wipe All Positions for \(inst.name)")
                        }
                    }
                    .buttonStyle(DestructiveButtonStyle())
                }

                Spacer()

                if let id = selectedInstitutionId,
                   let inst = institutions.first(where: { $0.id == id }) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                        Text("Selected: \(inst.name)")
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
}


