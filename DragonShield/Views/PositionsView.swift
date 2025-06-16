// DragonShield/Views/PositionsView.swift
// MARK: - Version 1.3 (2025-06-16)
// MARK: - History
// - 1.2 -> 1.3: Break up complex expressions for compiler and clarify filtering.
// - 1.1 -> 1.2: Updated to use global PositionReportData type.
// - 1.0 -> 1.1: Display live PositionReports data from database.
// - Initial creation: Displays positions with upload and report dates.

import SwiftUI

struct PositionsView: View {
    @EnvironmentObject var dbManager: DatabaseManager

    @State private var positions: [PositionReportData] = []
    @State private var selectedPosition: PositionReportData? = nil
    @State private var searchText = ""

    @State private var headerOpacity: Double = 0
    @State private var contentOffset: CGFloat = 30

    var filteredPositions: [PositionReportData] {
        guard !searchText.isEmpty else { return positions }
        let query = searchText.lowercased()
        return positions.filter { position in
            let matchesInstrument = position.instrumentName.lowercased().contains(query)
            let matchesAccount = position.accountName.lowercased().contains(query)
            let matchesId = String(position.id).contains(query)
            let matchesSession = position.importSessionId.map { String($0).contains(query) } ?? false
            return matchesInstrument || matchesAccount || matchesId || matchesSession
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
            }
        }
        .onAppear {
            loadPositions()
            animateEntrance()
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
                let rowSpacing = CGFloat(dbManager.tableRowSpacing)
                let padding = CGFloat(dbManager.tableRowPadding)
                LazyVStack(spacing: rowSpacing) {
                    ForEach(filteredPositions) { position in
                        ModernPositionRowView(
                            position: position,
                            isSelected: selectedPosition?.id == position.id,
                            rowPadding: padding,
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
            Text("Instrument").font(.system(size: 14, weight: .semibold)).foregroundColor(.gray).frame(maxWidth: .infinity, alignment: .leading)
            Text("Qty").font(.system(size: 14, weight: .semibold)).foregroundColor(.gray).frame(width: 60, alignment: .trailing)
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

    private func loadPositions() {
        positions = dbManager.fetchPositionReports()
    }

    private func animateEntrance() {
        withAnimation(.easeOut(duration: 0.6).delay(0.1)) { headerOpacity = 1.0 }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3)) { contentOffset = 0 }
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

            let sessionId = position.importSessionId.map(String.init) ?? "-"
            Text(sessionId)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .leading)

            Text(position.accountName)
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

