import SwiftUI

struct AccountsNeedingUpdateTile: DashboardTile {
    init() {}
    static let tileID = "staleAccounts"
    static let tileName = "Accounts Needing Update"
    static let iconName = "exclamationmark.triangle"

    @EnvironmentObject var dbManager: DatabaseManager
    @Environment(\.openWindow) private var openWindow
    @StateObject private var viewModel = StaleAccountsViewModel()
    @State private var showRed = false
    @State private var showAmber = false
    @State private var showGreen = false
    @State private var refreshing = false
    @State private var showCheckmark = false
    @State private var refreshError: String?

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
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(Self.tileName)
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
                Text(String(redCount))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Theme.primaryAccent)
            }

            if viewModel.staleAccounts.isEmpty {
                Text("All accounts up to date ✅")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                contentList
            }
        }
        .padding(DashboardTileLayout.tilePadding)
        .dashboardTileBackground(cornerRadius: 12)
        .overlay(alignment: .leading) { Rectangle().fill(Color.numberRed).frame(width: 4).cornerRadius(2) }
        .overlay(alignment: .topTrailing) { refreshButton }
        .onAppear {
            viewModel.loadStaleAccounts(db: dbManager)
            showRed = true
            showAmber = true
        }
        .alert("Error", isPresented: Binding(
            get: { refreshError != nil },
            set: { if !$0 { refreshError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(refreshError ?? "")
        }
    }

    private var redCount: Int {
        viewModel.staleAccounts.filter { category(for: $0.earliestInstrumentLastUpdatedAt) == .red }.count
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
                        summaryRow(title: "<1 month / today", count: greenRows.count, color: .success)
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
                .onTapGesture {
                    openWindow(id: "accountDetail", value: account.id)
                }
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

    private var refreshButton: some View {
        Button(action: performRefresh) {
            Group {
                if refreshing {
                    ProgressView()
                        .controlSize(.small)
                } else if showCheckmark {
                    Image(systemName: "checkmark")
                        .transition(.scale)
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .frame(width: 16, height: 16)
            .foregroundColor(.blue)
        }
        .buttonStyle(PlainButtonStyle())
        .help("Refresh Instrument Timestamps")
        .accessibilityLabel("Refresh Instrument Timestamps")
        .disabled(refreshing)
        .opacity(refreshing ? 0.4 : 1)
    }

    private func performRefresh() {
        refreshing = true
        dbManager.refreshEarliestInstrumentTimestamps { result in
            refreshing = false
            switch result {
            case .success:
                showCheckmark = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    showCheckmark = false
                }
                viewModel.loadStaleAccounts(db: dbManager)
            case let .failure(err):
                refreshError = err.localizedDescription
            }
        }
    }
}
