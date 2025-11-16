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
        items = limited
        totalCount = all.count
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
    @State private var editingInstrumentId: Int? = nil

    private func listHeight(for count: Int, hasMore: Bool) -> CGFloat {
        let rows = count + (hasMore ? 1 : 0)
        let spacing = DashboardTileLayout.rowSpacing
        guard rows > 0 else { return DashboardTileLayout.rowHeight + spacing * 2 }
        let rowsHeight = CGFloat(rows) * DashboardTileLayout.rowHeight
        let spacingHeight = CGFloat(max(0, rows - 1)) * spacing
        // include top/bottom padding from the VStack
        return rowsHeight + spacingHeight + spacing * 2
    }

    // Extract row to ease the type-checker
    private func rowView(_ item: UnusedInstrument) -> some View {
        Text(item.name)
            .foregroundColor(Theme.primaryAccent)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: DashboardTileLayout.rowHeight, alignment: .leading)
            .help("Open instrument maintenance (double‑click)")
            .onTapGesture(count: 2) { editingInstrumentId = item.instrumentId }
    }

    private var editBinding: Binding<Ident?> {
        Binding<Ident?>(
            get: { editingInstrumentId.map { Ident(value: $0) } },
            set: { newVal in editingInstrumentId = newVal?.value }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(Self.tileName)
                    .font(.system(size: 17, weight: .semibold))
                Text("Warning")
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.paleRed)
                    .foregroundColor(.numberRed)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.numberRed.opacity(0.6), lineWidth: 1))
                    .cornerRadius(10)
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
                        ForEach(viewModel.items, content: rowView)
                        if viewModel.hasMore {
                            Text("+ more…")
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .frame(height: DashboardTileLayout.rowHeight, alignment: .leading)
                        }
                    }
                    .padding(.vertical, DashboardTileLayout.rowSpacing)
                }
                .frame(height: listHeight(for: viewModel.items.count, hasMore: viewModel.hasMore))
                .scrollIndicators(.visible)
                .textSelection(.disabled)
            }
        }
        .padding(DashboardTileLayout.tilePadding)
        .dashboardTileBackground(cornerRadius: 12)
        .overlay(alignment: .leading) {
            Rectangle().fill(Color.numberRed).frame(width: 4).cornerRadius(2)
        }
        .onAppear { viewModel.load(db: dbManager) }
        .sheet(isPresented: $showReport) {
            UnusedInstrumentsReportView {
                showReport = false
            }
        }
        .sheet(item: editBinding) { ident in
            InstrumentEditView(instrumentId: ident.value)
                .environmentObject(dbManager)
        }
    }
}

private struct Ident: Identifiable { let value: Int; var id: Int { value } }
