import SwiftUI
import Combine

struct UnthemedInstrument: Identifiable {
    let id: Int
    let name: String
}

final class UnthemedInstrumentsTileViewModel: ObservableObject {
    @Published var items: [UnthemedInstrument] = []
    @Published var isLoading = false

    func load(db: DatabaseManager) {
        if isLoading { return }
        isLoading = true
        DispatchQueue.global().async {
            let rows = db.fetchInstrumentsWithoutThemes()
            let mapped = rows.map { UnthemedInstrument(id: $0.id, name: $0.name) }
            DispatchQueue.main.async {
                self.items = mapped
                self.isLoading = false
            }
        }
    }
}

struct UnthemedInstrumentsTile: DashboardTile {
    init() {}
    static let tileID = "unthemedInstruments"
    static let tileName = "Instruments Without Theme"
    static let iconName = "square.fill.on.square.fill"

    @EnvironmentObject var dbManager: DatabaseManager
    @StateObject private var viewModel = UnthemedInstrumentsTileViewModel()
    @State private var editingInstrumentId: Int? = nil

    private func rowView(_ item: UnthemedInstrument) -> some View {
        Text(item.name)
            .foregroundColor(Theme.primaryAccent)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: DashboardTileLayout.rowHeight, alignment: .leading)
            .onTapGesture(count: 2) { editingInstrumentId = item.id }
    }

    private var editBinding: Binding<Ident?> {
        Binding<Ident?>(
            get: { editingInstrumentId.map { Ident(value: $0) } },
            set: { newValue in editingInstrumentId = newValue?.value }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(Self.tileName)
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
                if !viewModel.isLoading {
                    Text(viewModel.items.isEmpty ? "—" : String(viewModel.items.count))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Theme.primaryAccent)
                }
            }
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if viewModel.items.isEmpty {
                Text("All instruments are part of a theme")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DashboardTileLayout.rowSpacing) {
                        ForEach(viewModel.items, content: rowView)
                    }
                    .padding(.vertical, DashboardTileLayout.rowSpacing)
                }
                .frame(maxHeight: viewModel.items.count > 10 ? 220 : .infinity)
                .scrollIndicators(.visible)
            }
        }
        .padding(DashboardTileLayout.tilePadding)
        .dashboardTileBackground(cornerRadius: 12)
        .overlay(alignment: .leading) {
            Rectangle().fill(Color.numberRed).frame(width: 4).cornerRadius(2)
        }
        .onAppear { viewModel.load(db: dbManager) }
        .sheet(item: editBinding) { ident in
            InstrumentEditView(
                instrumentId: ident.value,
                isPresented: Binding(
                    get: { editingInstrumentId != nil },
                    set: { if !$0 { editingInstrumentId = nil } }
                )
            )
            .environmentObject(dbManager)
        }
    }
}

private struct Ident: Identifiable { let value: Int; var id: Int { value } }
