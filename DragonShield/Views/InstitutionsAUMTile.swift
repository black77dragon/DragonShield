import SwiftUI

struct InstitutionsAUMTile: DashboardTile {
    init() {}
    static let tileID = "institutions_aum"
    static let tileName = "Institutions AUM Summary"
    static let iconName = "building.2"

    struct Row: Identifiable {
        let id = UUID()
        let name: String
        let valueCHF: Double
    }

    @EnvironmentObject var dbManager: DatabaseManager
    @State private var rows: [Row] = []
    @State private var loading = false

    private static let chfFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = "'"
        f.maximumFractionDigits = 0
        f.usesGroupingSeparator = true
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Institutions AUM")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(Color(red: 28/255, green: 28/255, blue: 30/255))
            if loading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(rows) { item in
                            HStack {
                                Text(item.name)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text("\(Self.chfFormatter.string(from: NSNumber(value: item.valueCHF)) ?? "0") CHF")
                                    .fontWeight(.medium)
                                    .frame(alignment: .trailing)
                            }
                            .font(.system(size: 13))
                            .frame(height: 32)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.visible)
                .accessibilityLabel("Institutions AUM list")
                .frame(maxHeight: rows.count > 6 ? 200 : .infinity)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
        .onAppear(perform: calculate)
    }

    private func calculate() {
        loading = true
        DispatchQueue.global().async {
            let positions = dbManager.fetchPositionReports()
            var totals: [String: Double] = [:]
            for p in positions {
                guard let price = p.currentPrice else { continue }
                let currency = p.instrumentCurrency.uppercased()
                let valueOrig = p.quantity * price
                guard let conv = dbManager.convert(amount: valueOrig, from: currency, asOf: nil) else { continue }
                totals[p.institutionName, default: 0] += conv.value
            }
            let sorted = totals.sorted { $0.value > $1.value }
            let result = sorted.map { Row(name: $0.key, valueCHF: $0.value) }
            DispatchQueue.main.async {
                self.rows = result
                self.loading = false
            }
        }
    }
}
