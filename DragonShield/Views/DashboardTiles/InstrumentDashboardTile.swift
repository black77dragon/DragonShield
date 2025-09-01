import SwiftUI

struct InstrumentDashboardTile: DashboardTile {
    init() {}
    static let tileID = "instrument_dashboard"
    static let tileName = "Instrument Dashboard"
    static let iconName = "square.grid.3x1.folder.badge.plus"

    @EnvironmentObject var dbManager: DatabaseManager
    @Environment(\.openWindow) private var openWindow

    @State private var instruments: [DatabaseManager.InstrumentRow] = []
    @State private var instrumentQuery: String = ""
    @State private var selectedInstrumentId: Int? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(Self.tileName)
                    .font(.system(size: 18, weight: .bold))
                Spacer()
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Select Instrument").font(.caption).foregroundColor(.secondary)
                MacComboBox(
                    items: instrumentDisplayItems(),
                    text: $instrumentQuery,
                    onSelectIndex: { originalIndex in
                        guard originalIndex >= 0 && originalIndex < instruments.count else { return }
                        let ins = instruments[originalIndex]
                        selectedInstrumentId = ins.id
                        openInstrument(ins.id)
                    }
                )
                .frame(minWidth: 360)
                .accessibilityLabel("Instrument Selector")
                // When focused, MacComboBox already opens the popup and filters as you type.
                // Ensure we start from a full list view.
                .onAppear { instrumentQuery = "" }
                HStack(spacing: 8) {
                    Spacer()
                    Button {
                        if let id = selectedInstrumentId { openInstrument(id) }
                    } label: {
                        Label("Open Dashboard", systemImage: "arrow.up.right.square")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(selectedInstrumentId == nil)
                }
            }
        }
        .padding(DashboardTileLayout.tilePadding)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
        .onAppear(perform: loadInstruments)
        .accessibilityElement(children: .combine)
    }

    private func loadInstruments() {
        instruments = dbManager.fetchAssets()
    }

    private func instrumentDisplayItems() -> [String] {
        instruments.map(displayString(for:))
    }

    private func displayString(for ins: DatabaseManager.InstrumentRow) -> String {
        var parts: [String] = [ins.name]
        if let t = ins.tickerSymbol, !t.isEmpty { parts.append(t.uppercased()) }
        if let i = ins.isin, !i.isEmpty { parts.append(i.uppercased()) }
        return parts.joined(separator: " • ")
    }

    private func openInstrument(_ id: Int) {
        openWindow(id: "instrumentDashboard", value: id)
    }
}
