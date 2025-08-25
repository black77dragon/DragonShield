import SwiftUI

final class UnusedInstrumentsTileViewModel: ObservableObject {
    @Published var items: [UnusedInstrument] = []
    @Published var totalCount: Int? = nil
    @Published var errorMessage: String? = nil
    private static let limit = 500

    func load(db: DatabaseManager) {
        DispatchQueue.global().async {
            let repo = InstrumentUsageRepository(dbManager: db)
            do {
                let all = try repo.unusedStrict()
                DispatchQueue.main.async {
                    self.process(all: all)
                    self.errorMessage = nil
                }
            } catch InstrumentUsageRepositoryError.noSnapshot {
                DispatchQueue.main.async {
                    self.items = []
                    self.totalCount = nil
                    self.errorMessage = "No snapshot available"
                }
            } catch {
                DispatchQueue.main.async {
                    self.items = []
                    self.totalCount = nil
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func process(all: [UnusedInstrument]) {
        let limited = Self.sortedLimited(all)
        self.items = limited
        self.totalCount = all.count
    }

    static func sortedLimited(_ list: [UnusedInstrument]) -> [UnusedInstrument] {
        let sorted = list.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return Array(sorted.prefix(limit))
    }

    var hasMore: Bool {
        if let count = totalCount {
            return count > Self.limit
        }
        return false
    }
}

struct UnusedInstrumentsTile: DashboardTile {
    init() {}
    static let tileID = "unusedInstruments"
    static let tileName = "Unused Instruments"
    static let iconName = "tray"

    @EnvironmentObject var dbManager: DatabaseManager
    @StateObject private var viewModel = UnusedInstrumentsTileViewModel()
    @State private var showReport = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(Self.tileName)
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
                Text(viewModel.totalCount.map(String.init) ?? "—")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Theme.primaryAccent)
            }
            .contentShape(Rectangle())
            .onTapGesture { showReport = true }

            if let message = viewModel.errorMessage {
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else if viewModel.totalCount == 0 {
                Text("No unused instruments 🎉")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DashboardTileLayout.rowSpacing) {
                        ForEach(viewModel.items) { item in
                            Text(item.name)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .frame(height: DashboardTileLayout.rowHeight, alignment: .leading)
                                .help(item.name)
                        }
                        if viewModel.hasMore {
                            Text("+ more…")
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .frame(height: DashboardTileLayout.rowHeight, alignment: .leading)
                        }
                    }
                    .padding(.vertical, DashboardTileLayout.rowSpacing)
                }
                .frame(maxHeight: viewModel.items.count > 12 ? 220 : .infinity)
                .scrollIndicators(.visible)
                .textSelection(.disabled)
            }
        }
        .padding(DashboardTileLayout.tilePadding)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
        .onAppear { viewModel.load(db: dbManager) }
        .sheet(isPresented: $showReport) {
            UnusedInstrumentsReportView {
                showReport = false
            }
        }
    }
}

