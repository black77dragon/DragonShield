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

    enum SortKey { case account, institution, instrument, currency, quantity, purchasePrice, currentPrice, uploadedAt, reportDate }
    @State private var sortDescriptor: (key: SortKey, ascending: Bool) = (.account, true)

    var sortedPositions: [PositionReportData] {
        filteredPositions.sorted { lhs, rhs in
            func compare<T: Comparable>(_ a: T, _ b: T) -> Bool {
                sortDescriptor.ascending ? a < b : a > b
            }
            switch sortDescriptor.key {
            case .account:
                return compare(lhs.accountName, rhs.accountName)
            case .institution:
                return compare(lhs.institutionName, rhs.institutionName)
            case .instrument:
                return compare(lhs.instrumentName, rhs.instrumentName)
            case .currency:
                return compare(lhs.instrumentCurrency, rhs.instrumentCurrency)
            case .quantity:
                return compare(lhs.quantity, rhs.quantity)
            case .purchasePrice:
                return compare(lhs.purchasePrice ?? 0, rhs.purchasePrice ?? 0)
            case .currentPrice:
                return compare(lhs.currentPrice ?? 0, rhs.currentPrice ?? 0)
            case .uploadedAt:
                return compare(lhs.uploadedAt, rhs.uploadedAt)
            case .reportDate:
                return compare(lhs.reportDate, rhs.reportDate)
            }
        }
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
        return Table(data, selection: $selectedRows) {
            positionColumns
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .padding(24)
        .background(Theme.surface)
        .cornerRadius(8)
    }

    @ViewBuilder
    private var positionColumns: some View {
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

        Group {
            TableColumn(header: { headerLabel("Account", key: .account) }) { (position: PositionReportData) in
                Text(position.accountName)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minWidth: 150, idealWidth: 150, maxWidth: .infinity, alignment: .leading)
            }

            TableColumn(header: { headerLabel("Institution", key: .institution) }) { (position: PositionReportData) in
                Text(position.institutionName)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minWidth: 150, idealWidth: 150, maxWidth: .infinity, alignment: .leading)
            }

            TableColumn(header: { headerLabel("Instrument", key: .instrument) }) { (position: PositionReportData) in
                Text(position.instrumentName)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            TableColumn(header: { headerLabel("Currency", key: .currency) }) { (position: PositionReportData) in
                Text(position.instrumentCurrency)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(colorForCurrency(position.instrumentCurrency))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minWidth: 60, idealWidth: 60, maxWidth: .infinity, alignment: .center)
            }

            TableColumn(header: { headerLabel("Qty", key: .quantity) }) { (position: PositionReportData) in
                Text(String(format: "%.2f", position.quantity))
                    .font(.system(size: 14, design: .monospaced))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minWidth: 60, idealWidth: 60, maxWidth: .infinity, alignment: .trailing)
            }

            TableColumn(header: { headerLabel("Purchase", key: .purchasePrice) }) { (position: PositionReportData) in
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
            }

            TableColumn(header: { headerLabel("Current", key: .currentPrice) }) { (position: PositionReportData) in
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
        }

        Group {
            TableColumn(header: { headerLabel("Dates", key: .uploadedAt) }) { (position: PositionReportData) in
                VStack {
                    Text(position.uploadedAt, formatter: DateFormatter.iso8601DateTime)
                    Text(position.reportDate, formatter: DateFormatter.iso8601DateOnly)
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
    }

    private func loadInstitutions() {
        institutions = dbManager.fetchInstitutions()
    }

    private func animateEntrance() {
        withAnimation(.easeOut(duration: 0.6).delay(0.1)) { headerOpacity = 1.0 }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3)) { contentOffset = 0 }
        withAnimation(.easeOut(duration: 0.4).delay(0.5)) { buttonsOpacity = 1.0 }
    }

    private func headerLabel(_ title: String, key: SortKey) -> some View {
        HStack(spacing: 2) {
            Text(title)
            if sortDescriptor.key == key {
                Image(systemName: sortDescriptor.ascending ? "chevron.up" : "chevron.down")
            }
        }
        .onTapGesture {
            if sortDescriptor.key == key {
                sortDescriptor.ascending.toggle()
            } else {
                sortDescriptor = (key, true)
            }
        }
    }

    private func colorForCurrency(_ code: String) -> Color {
        switch code.uppercased() {
        case "USD": return .green
        case "CHF": return .red
        default: return .primary
        }
    }
}


