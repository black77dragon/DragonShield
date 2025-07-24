import SwiftUI

struct AccountsNeedingUpdateTile: DashboardTile {
    init() {}
    static let tileID = "staleAccounts"
    static let tileName = "Accounts Needing Update"
    static let iconName = "exclamationmark.triangle"

    @EnvironmentObject var dbManager: DatabaseManager
    @StateObject private var viewModel = StaleAccountsViewModel()

    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd MMM yyyy"
        return f
    }()

    private func rowColor(for date: Date?) -> Color {
        guard let date else { return .clear }
        let days = viewModel.daysSince(date)
        if days > 60 { return Color.red.opacity(0.2) }
        if days > 30 { return Color.orange.opacity(0.2) }
        return Color.green.opacity(0.2)
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
        Group {
            ScrollView { listBody(rows) }
                .frame(maxHeight: rows.count > 6 ? 220 : .infinity)
        }
    }

    private func listBody(_ rows: [DatabaseManager.AccountData]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { idx, account in
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
}
