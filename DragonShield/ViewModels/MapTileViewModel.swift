import SwiftUI
import MapKit

struct CountryExposure: Identifiable {
    let id = UUID()
    let country: String
    let currency: String
    let totalCHF: Double
    var polygon: MKPolygon?
    var fillColor: Color = .blue
}

final class MapTileViewModel: ObservableObject {
    @Published var countries: [CountryExposure] = []
    @Published var legend: [ClosedRange<Double>] = []
    @Published var loading = false

    private let currencyToCountry: [String: String] = [
        "USD": "United States",
        "EUR": "Germany",
        "GBP": "United Kingdom",
        "CHF": "Switzerland"
    ]

    func load(using db: DatabaseManager) {
        loading = true
        DispatchQueue.global().async {
            let positions = db.fetchPositionReports()
            var totals: [String: Double] = [:]
            var rateCache: [String: Double] = [:]
            for p in positions {
                guard let price = p.currentPrice else { continue }
                let code = p.instrumentCurrency.uppercased()
                var value = p.quantity * price
                if code != "CHF" {
                    if rateCache[code] == nil {
                        rateCache[code] = db.fetchExchangeRates(currencyCode: code, upTo: nil).first?.rateToChf
                    }
                    guard let rate = rateCache[code] else { continue }
                    value *= rate
                }
                totals[code, default: 0] += value
            }

            var exposures: [CountryExposure] = []
            for (code, value) in totals {
                guard let country = self.currencyToCountry[code], value > 0 else { continue }
                exposures.append(CountryExposure(country: country, currency: code, totalCHF: value))
            }

            let values = exposures.map { $0.totalCHF }.sorted()
            guard values.count > 0 else {
                DispatchQueue.main.async { self.countries = []; self.loading = false }
                return
            }

            let breakCount = 5
            var ranges: [ClosedRange<Double>] = []
            for i in 0..<breakCount {
                let start = values[Int(Double(i) / Double(breakCount) * Double(values.count - 1))]
                let end = values[Int(Double(i + 1) / Double(breakCount) * Double(values.count - 1))]
                ranges.append(start...end)
            }
            let colors: [Color] = (0..<breakCount).map { i in
                Color.blue.opacity(Double(i + 1) / Double(breakCount))
            }

            exposures = exposures.map { exp in
                var c = exp
                if let idx = ranges.firstIndex(where: { $0.contains(exp.totalCHF) }) {
                    c.fillColor = colors[idx]
                }
                return c
            }

            if let polygons = self.loadPolygons() {
                exposures = exposures.map { exp in
                    var item = exp
                    item.polygon = polygons[exp.country]
                    return item
                }
            }

            DispatchQueue.main.async {
                self.legend = ranges
                self.countries = exposures
                self.loading = false
            }
        }
    }

    private func loadPolygons() -> [String: MKPolygon]? {
        guard let url = Bundle.main.url(forResource: "countries_simple", withExtension: "geojson") else { return nil }
        guard let data = try? Data(contentsOf: url) else { return nil }
        guard let features = try? MKGeoJSONDecoder().decode(data) as? [MKGeoJSONFeature] else { return nil }
        var result: [String: MKPolygon] = [:]
        for feature in features {
            guard let name = feature.properties.flatMap({ try? JSONSerialization.jsonObject(with: $0) }) as? [String: Any],
                  let admin = name["ADMIN"] as? String else { continue }
            for case let polygon as MKPolygon in feature.geometry {
                result[admin] = polygon
            }
        }
        return result
    }
}
