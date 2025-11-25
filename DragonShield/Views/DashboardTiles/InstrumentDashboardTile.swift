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
    @State private var instrumentSearch: String = ""
    @State private var showInstrumentPicker = false
    // Selection opens dashboard immediately; no extra action button required

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(Self.tileName)
                    .font(.headline)
                Spacer()
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Choose Instrument")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                HStack(spacing: 8) {
                    Text(selectedInstrumentDisplay)
                        .foregroundColor(selectedInstrumentDisplay == "No instrument selected" ? .secondary : .primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button("Choose Instrument…") {
                        instrumentSearch = selectedInstrumentDisplay == "No instrument selected" ? "" : selectedInstrumentDisplay
                        showInstrumentPicker = true
                    }
                }
                .frame(minWidth: 360, alignment: .leading)
            }
        }
        .padding(DashboardTileLayout.tilePadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .dashboardTileBackground(cornerRadius: 16)
        .onAppear(perform: loadInstruments)
        .accessibilityElement(children: .combine)
        .sheet(isPresented: $showInstrumentPicker) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Choose Instrument")
                    .font(.headline)
                FloatingSearchPicker(
                    title: "Choose Instrument",
                    placeholder: "Search instruments",
                    items: instrumentPickerItems,
                    selectedId: instrumentPickerBinding,
                    showsClearButton: true,
                    emptyStateText: "No instruments",
                    query: $instrumentSearch,
                    onSelection: { item in
                        if let value = item.id as? Int {
                            selectedInstrumentId = value
                            openInstrument(value)
                        }
                        showInstrumentPicker = false
                    },
                    onClear: {
                        instrumentPickerBinding.wrappedValue = nil
                    },
                    onSubmit: { _ in
                        if let id = selectedInstrumentId {
                            openInstrument(id)
                            showInstrumentPicker = false
                        }
                    },
                    selectsFirstOnSubmit: false
                )
                .frame(minWidth: 360)
                HStack {
                    Spacer()
                    Button("Close") { showInstrumentPicker = false }
                }
            }
            .padding(16)
            .frame(width: 520)
            .onAppear {
                loadInstruments()
            }
        }
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

    private var instrumentPickerItems: [FloatingSearchPicker.Item] {
        instruments.map { ins in
            let display = instrumentDisplayData(for: ins)
            return FloatingSearchPicker.Item(
                id: AnyHashable(ins.id),
                title: display.title,
                subtitle: display.subtitle,
                searchText: searchText(for: ins)
            )
        }
    }

    private var instrumentPickerBinding: Binding<AnyHashable?> {
        Binding<AnyHashable?>(
            get: { selectedInstrumentId.map { AnyHashable($0) } },
            set: { newValue in
                if let value = newValue as? Int {
                    selectedInstrumentId = value
                    instrumentSearch = instrumentDisplay(for: value) ?? ""
                } else {
                    selectedInstrumentId = nil
                    instrumentSearch = ""
                }
            }
        )
    }

    private var selectedInstrumentDisplay: String {
        if let id = selectedInstrumentId, let display = instrumentDisplay(for: id) {
            return display
        }
        let trimmed = instrumentSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "No instrument selected" : trimmed
    }

    private func instrumentDisplay(for id: Int) -> String? {
        guard let match = instruments.first(where: { $0.id == id }) else { return nil }
        let data = instrumentDisplayData(for: match)
        if let subtitle = data.subtitle {
            return "\(data.title) • \(subtitle)"
        }
        return data.title
    }
}
