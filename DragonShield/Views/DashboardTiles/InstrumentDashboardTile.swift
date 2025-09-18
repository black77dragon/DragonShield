import SwiftUI

struct InstrumentDashboardTile: DashboardTile {
    init() {}
    static let tileID = "instrument_dashboard"
    static let tileName = "Instrument Dashboard"
    static let iconName = "square.grid.3x1.folder.badge.plus"

    @EnvironmentObject var dbManager: DatabaseManager
    @Environment(\.openWindow) private var openWindow

    @State private var instruments: [DatabaseManager.InstrumentRow] = []
    @State private var selectedInstrumentId: Int? = nil
    @State private var tileFrame: CGRect = .zero
    @State private var pickerFieldFrame: CGRect = .zero
    // Selection opens dashboard immediately; no extra action button required

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(Self.tileName)
                    .font(.system(size: 18, weight: .bold))
                Spacer()
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Select Instrument").font(.caption).foregroundColor(.secondary)
                let pickerItems = instruments.map { ins in
                    let display = instrumentDisplayData(for: ins)
                    return FloatingSearchPicker.Item(
                        id: AnyHashable(ins.id),
                        title: display.title,
                        subtitle: display.subtitle,
                        searchText: searchText(for: ins)
                    )
                }
                FloatingSearchPicker(
                    placeholder: "Search instruments",
                    items: pickerItems,
                    selectedId: Binding<AnyHashable?>(
                        get: { selectedInstrumentId.map { AnyHashable($0) } },
                        set: { newValue in
                            selectedInstrumentId = newValue as? Int
                        }
                    ),
                    maxDropdownHeight: instrumentDropdownMaxHeight,
                    onFieldFrameChange: { pickerFieldFrame = $0 },
                    onSelection: { item in
                        if let value = item.id as? Int {
                            openInstrument(value)
                        }
                    },
                    onClear: { selectedInstrumentId = nil },
                    selectsFirstOnSubmit: false
                )
                .frame(minWidth: 360)
                .accessibilityLabel("Instrument Selector")
            }
        }
        .frame(minHeight: 440, alignment: .topLeading)
        .padding(DashboardTileLayout.tilePadding)
        .dashboardTileBackground(cornerRadius: 16)
        .onAppear(perform: loadInstruments)
        .accessibilityElement(children: .combine)
        .background(
            GeometryReader { proxy in
                Color.clear.preference(key: TileFramePreferenceKey.self, value: proxy.frame(in: .global))
            }
        )
        .onPreferenceChange(TileFramePreferenceKey.self) { tileFrame = $0 }
    }

    private func loadInstruments() {
        instruments = dbManager.fetchAssets()
    }

    private func instrumentDisplayData(for ins: DatabaseManager.InstrumentRow) -> (title: String, subtitle: String?) {
        var subtitleParts: [String] = []
        if let ticker = ins.tickerSymbol, !ticker.isEmpty {
            subtitleParts.append(ticker.uppercased())
        }
        if let isin = ins.isin, !isin.isEmpty {
            subtitleParts.append(isin.uppercased())
        }
        subtitleParts.append(ins.currency.uppercased())
        let subtitle = subtitleParts.isEmpty ? nil : subtitleParts.joined(separator: " • ")
        return (title: ins.name, subtitle: subtitle)
    }

    private func searchText(for ins: DatabaseManager.InstrumentRow) -> String {
        var parts: [String] = [ins.name]
        if let ticker = ins.tickerSymbol?.trimmingCharacters(in: .whitespacesAndNewlines), !ticker.isEmpty {
            parts.append(ticker.uppercased())
        }
        if let isin = ins.isin?.trimmingCharacters(in: .whitespacesAndNewlines), !isin.isEmpty {
            parts.append(isin.uppercased())
        }
        if let valor = ins.valorNr?.trimmingCharacters(in: .whitespacesAndNewlines), !valor.isEmpty {
            parts.append(valor.uppercased())
        }
        parts.append(ins.currency.uppercased())
        return parts.joined(separator: " ")
    }

    private func openInstrument(_ id: Int) {
        openWindow(id: "instrumentDashboard", value: id)
    }

    private var instrumentDropdownMaxHeight: CGFloat? {
        guard tileFrame != .zero, pickerFieldFrame != .zero else { return nil }
        let bottomLimit = tileFrame.maxY - 2
        let dropdownGap: CGFloat = 6
        let dropdownTop = pickerFieldFrame.maxY + dropdownGap
        return max(0, bottomLimit - dropdownTop)
    }
}

private struct TileFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}
