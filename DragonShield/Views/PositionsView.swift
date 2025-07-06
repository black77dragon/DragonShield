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
    @State private var selectedPosition: PositionReportData? = nil
    @State private var searchText = ""

    @State private var institutions: [DatabaseManager.InstitutionData] = []
    @State private var selectedInstitutionId: Int? = nil
    @State private var showingDeleteAlert = false
    @State private var buttonsOpacity: Double = 0

    @State private var headerOpacity: Double = 0
    @State private var contentOffset: CGFloat = 30

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
                positionsContent
                modernActionBar
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

    private var positionsContent: some View {
        VStack(spacing: 0) {
            modernTableHeader
            ScrollView {
                LazyVStack(spacing: CGFloat(dbManager.tableRowSpacing)) {
                    ForEach(filteredPositions) { position in
                        ModernPositionRowView(
                            position: position,
                            isSelected: selectedPosition?.id == position.id,
                            rowPadding: CGFloat(dbManager.tableRowPadding),
                            onTap: { selectedPosition = position }
                        )
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
    }

    private var modernTableHeader: some View {
        HStack {
            Text("ID").font(.system(size: 14, weight: .semibold)).foregroundColor(.gray).frame(width: 50, alignment: .leading)
            Text("Session").font(.system(size: 14, weight: .semibold)).foregroundColor(.gray).frame(width: 70, alignment: .leading)
            Text("Account").font(.system(size: 14, weight: .semibold)).foregroundColor(.gray).frame(width: 150, alignment: .leading)
            Text("Institution").font(.system(size: 14, weight: .semibold)).foregroundColor(.gray).frame(width: 150, alignment: .leading)
            Text("Instrument").font(.system(size: 14, weight: .semibold)).foregroundColor(.gray).frame(maxWidth: .infinity, alignment: .leading)
            Text("Qty").font(.system(size: 14, weight: .semibold)).foregroundColor(.gray).frame(width: 60, alignment: .trailing)
            Text("Purchase").font(.system(size: 14, weight: .semibold)).foregroundColor(.gray).frame(width: 70, alignment: .trailing)
            Text("Current").font(.system(size: 14, weight: .semibold)).foregroundColor(.gray).frame(width: 70, alignment: .trailing)
            Text("Uploaded").font(.system(size: 14, weight: .semibold)).foregroundColor(.gray).frame(width: 110, alignment: .center)
            Text("Report").font(.system(size: 14, weight: .semibold)).foregroundColor(.gray).frame(width: 110, alignment: .center)
        }
        .padding(.horizontal, CGFloat(dbManager.tableRowPadding))
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
        .padding(.bottom, 1)
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

    private var modernActionBar: some View {
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

                if selectedInstitutionId != nil {
                    Button {
                        showingDeleteAlert = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                            Text("Delete Positions")
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
            .background(.regularMaterial)
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
}

struct ModernPositionRowView: View {
    let position: PositionReportData
    let isSelected: Bool
    let rowPadding: CGFloat
    let onTap: () -> Void

    private static var dateFormatter: DateFormatter = DateFormatter.iso8601DateOnly
    private static var dateTimeFormatter: DateFormatter = DateFormatter.iso8601DateTime

    var body: some View {
        HStack {
            Text(String(position.id))
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(.primary)
                .frame(width: 50, alignment: .leading)

            Text(position.importSessionId.map { String($0) } ?? "-")
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .leading)

            Text(position.accountName)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .frame(width: 150, alignment: .leading)

            Text(position.institutionName)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .frame(width: 150, alignment: .leading)

            Text(position.instrumentName)
                .font(.system(size: 14))
                .foregroundColor(.primary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(String(format: "%.2f", position.quantity))
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(.primary)
                .frame(width: 60, alignment: .trailing)

            if let p = position.purchasePrice {
                Text(String(format: "%.2f", p))
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.primary)
                    .frame(width: 70, alignment: .trailing)
            } else {
                Text("-")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 70, alignment: .trailing)
            }

            if let cp = position.currentPrice {
                Text(String(format: "%.2f", cp))
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.primary)
                    .frame(width: 70, alignment: .trailing)
            } else {
                Text("-")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 70, alignment: .trailing)
            }

            Text(position.uploadedAt, formatter: Self.dateTimeFormatter)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 110, alignment: .center)

            Text(position.reportDate, formatter: Self.dateFormatter)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 110, alignment: .center)
        }
        .padding(.horizontal, rowPadding)
        .padding(.vertical, rowPadding / 1.8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.blue.opacity(0.1) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

