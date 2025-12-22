#if os(iOS)
    import SwiftUI

    /// Mobile entry point for portfolio reports.
    /// Presents the Asset Management Report with the same data and formatting as desktop.
    struct ReportsMenuView: View {
        @EnvironmentObject private var dbManager: DatabaseManager
        @EnvironmentObject private var preferences: AppPreferences
        @State private var accountCount: Int = 0
        @State private var positionsAsOf: Date?

        private static let dateFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateStyle = .medium
            f.timeStyle = .none
            return f
        }()

        var body: some View {
            List {
                Section(header: Text("Portfolio Reports")) {
                    NavigationLink {
                        AssetManagementReportView()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "chart.bar.doc.horizontal")
                                .foregroundColor(.accentColor)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Asset Management Report")
                                    .font(.headline)
                                Text("Uses snapshot accounts and the as-of date below.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    if !hasPositionsTable {
                        Text("Import a snapshot that includes PositionReports to view holdings.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section(header: Text("Snapshot Filters")) {
                    HStack {
                        Label("As of date", systemImage: "calendar")
                        Spacer()
                        Text(formattedAsOfDate)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Label("Base currency", systemImage: "coloncurrencysign.circle")
                        Spacer()
                        Text(preferences.baseCurrency.uppercased())
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Label("Accounts", systemImage: "person.3.fill")
                        Spacer()
                        Text("\(accountCount)")
                            .foregroundColor(.secondary)
                    }
                    if let posDate = positionsAsOf {
                        HStack {
                            Label("Positions as of", systemImage: "clock")
                            Spacer()
                            Text(Self.dateFormatter.string(from: posDate))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Reports")
            .onAppear(perform: reloadSnapshotMeta)
        }

        private var hasPositionsTable: Bool {
            dbManager.tableExistsIOS("PositionReports")
        }

        private var formattedAsOfDate: String {
            Self.dateFormatter.string(from: preferences.asOfDate)
        }

        private func reloadSnapshotMeta() {
            let positions = dbManager.fetchPositionReportsSafe()
            accountCount = Set(positions.map(\.accountName)).count
            positionsAsOf = hasPositionsTable ? dbManager.positionsAsOfDate() : nil
        }
    }
#endif
