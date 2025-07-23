import SwiftUI

struct Top10PositionsTile: DashboardTile {
    @EnvironmentObject var dbManager: DatabaseManager
    @StateObject private var viewModel = PositionsViewModel()
    @State private var excludeRealEstate = false

    init() {}
    static let tileID = "top_positions"
    static let tileName = "Top 10 Positions by Asset Value (CHF)"
    static let iconName = "list.number"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Text(Self.tileName)
                    .font(.headline)
                Spacer()
                Image("Top10Icon")
                    .resizable()
                    .frame(width: 24, height: 24)
                    .accessibilityLabel("Top 10 positions icon")
            }
            Toggle("Exclude Own Real Estate", isOn: $excludeRealEstate)
                .accessibilityLabel("Exclude Own Real Estate")
            if viewModel.calculating {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(viewModel.top10PositionsCHF.enumerated()), id: \.
element.id) { index, item in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.instrument)
                                        .fontWeight(.semibold)
                                        .lineLimit(1)
                                    Text(String(format: "%.2f CHF", item.valueCHF))
                                        .font(.caption)
                                        .foregroundColor(Color(red: 30/255, green: 58/255, blue: 138/255))
                                }
                                Spacer()
                                Text(item.currency)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(4)
                            .background(index == 0 ? Color(red: 191/255, green: 219/255, blue: 254/255) : Color.clear)
                            .cornerRadius(6)
                        }
                    }
                }
                .frame(maxHeight: viewModel.top10PositionsCHF.count > 6 ? 220 : .infinity)
            }
        }
        .padding(16)
        .background(Theme.surface)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
        .onAppear {
            viewModel.calculateTop10Positions(db: dbManager, excludingRealEstate: excludeRealEstate)
        }
        .onChange(of: excludeRealEstate) { value in
            viewModel.calculateTop10Positions(db: dbManager, excludingRealEstate: value)
        }
        .accessibilityElement(children: .combine)
    }
}
