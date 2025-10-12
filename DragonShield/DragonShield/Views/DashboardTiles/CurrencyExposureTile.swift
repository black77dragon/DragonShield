import SwiftUI
import Charts

struct CurrencyExposureTile: DashboardTile {
    init() {}
    static let tileID = "currency_exposure"
    static let tileName = "Portfolio by Currency"
    static let iconName = "dollarsign.circle"

    @EnvironmentObject var dbManager: DatabaseManager
    @StateObject private var viewModel = CurrencyExposureViewModel()

    private func color(for code: String) -> Color {
        Theme.currencyColors[code] ?? .gray
    }

    var body: some View {
        DashboardCard(title: Self.tileName, titleFont: .system(size: 18, weight: .bold)) {
            if viewModel.loading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                HStack(alignment: .top) {
                    Chart(viewModel.currencyExposure, id: \.currencyCode) { item in
                        SectorMark(
                            angle: .value("Share", item.percentage),
                            innerRadius: .ratio(0.6)
                        )
                        .foregroundStyle(color(for: item.currencyCode))
                    }
                    .chartLegend(.hidden)
                    .frame(width: 100, height: 100)

                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(viewModel.currencyExposure) { item in
                            HStack {
                                Text(item.currencyCode)
                                    .frame(width: 40, alignment: .leading)
                                Text(String(format: "%.0f%%", item.percentage))
                                    .frame(width: 50, alignment: .trailing)
                                Text(String(format: "%.0f CHF", item.totalCHF))
                                    .frame(alignment: .trailing)
                            }
                            .foregroundColor(item.percentage > 50 ? .orange : .primary)
                        }
                    }
                    .font(.caption)
                    Spacer()
                }
            }
        }
        .onAppear { viewModel.calculate(db: dbManager) }
        .accessibilityElement(children: .combine)
    }
}
