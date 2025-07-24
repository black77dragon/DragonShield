import SwiftUI

struct AccountsNeedingUpdateTile: DashboardTile {
    init() {}
    static let tileID = "staleAccounts"
    static let tileName = "Accounts Needing Update"
    static let iconName = "exclamationmark.triangle"

    @EnvironmentObject var dbManager: DatabaseManager
    @StateObject private var viewModel = StaleAccountsViewModel()
    @State private var showRed = false
    @State private var showAmber = false
    @State private var showGreen = false

    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd MMM yyyy"
        return f
    }()

    private enum StaleCategory {
        case red, amber, green
    }

    private func category(for date: Date?) -> StaleCategory? {
        guard let date else { return nil }
        let days = viewModel.daysSince(date)
        if days > 60 { return .red }
        if days > 30 { return .amber }
        return .green
    }

    private func rowColor(for date: Date?) -> Color {
        switch category(for: date) {
        case .red?:
            return Color.error.opacity(0.2)
        case .amber?:
            return Color.warning.opacity(0.2)
        case .green?:
            return Color.success.opacity(0.2)
        case nil:
            return .clear
        }
    }

    var body: some View {
        DashboardCard(title: Self.tileName,
                      headerIcon: Image(systemName: "calendar")) {
            if viewModel.staleAccounts.isEmpty {
                Text("All accounts up to date ✅")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                contentList
            }
        }
        .onAppear {
            viewModel.loadStaleAccounts(db: dbManager)
        }
    }

    @ViewBuilder
    private var contentList: some View {
        let rows = viewModel.staleAccounts
        let redRows = rows.filter { category(for: $0.earliestInstrumentLastUpdatedAt) == .red }
        let amberRows = rows.filter { category(for: $0.earliestInstrumentLastUpdatedAt) == .amber }
        let greenRows = rows.filter { category(for: $0.earliestInstrumentLastUpdatedAt) == .green }

        Group {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    DisclosureGroup(isExpanded: $showRed) {
                        listBody(redRows)
                    } label: {
                        summaryRow(title: "Over 2 months", count: redRows.count, color: .error)
                    }

                    DisclosureGroup(isExpanded: $showAmber) {
                        listBody(amberRows)
                    } label: {
                        summaryRow(title: "1-2 months", count: amberRows.count, color: .warning)
                    }

                    DisclosureGroup(isExpanded: $showGreen) {
                        listBody(greenRows)
                    } label: {
                        summaryRow(title: "<1 month", count: greenRows.count, color: .success)
                    }
                }
            }
            .frame(maxHeight: rows.count > 6 ? 220 : .infinity)
        }
    }

    private func listBody(_ rows: [DatabaseManager.AccountData]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(rows) { account in
                HStack {
                    Text(account.accountName)
                    Spacer()
                    if let date = account.earliestInstrumentLastUpdatedAt {
                        Text(Self.displayFormatter.string(from: date))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 2)
                .padding(.horizontal, 4)
                .background(rowColor(for: account.earliestInstrumentLastUpdatedAt))
                .cornerRadius(4)
            }
        }
    }

    private func summaryRow(title: String, count: Int, color: Color) -> some View {
        HStack {
            Text("\(title) (\(count))")
            Spacer()
        }
        .padding(4)
        .background(color.opacity(0.2))
        .cornerRadius(4)
    }
}
