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

    private func warningNeeded(for date: Date) -> Bool {
        viewModel.daysSince(date) > 30
    }

    var body: some View {
        DashboardCard(title: Self.tileName) {
            if viewModel.staleAccounts.isEmpty {
                Text("All accounts up to date ✅")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                contentList
            }
        }
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
        .onAppear {
            viewModel.loadStaleAccounts(db: dbManager)
        }
    }

    @ViewBuilder
    private var contentList: some View {
        let rows = viewModel.staleAccounts
        Group {
            if rows.count > 6 {
                ScrollView { listBody(rows) }
            } else {
                listBody(rows)
            }
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
                        if warningNeeded(for: date) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                        }
                    }
                }
                .padding(.vertical, 2)
                .padding(.horizontal, 4)
                .background(idx == 0 ? Color.yellow.opacity(0.2) : Color.clear)
                .cornerRadius(4)
            }
        }
    }
}
