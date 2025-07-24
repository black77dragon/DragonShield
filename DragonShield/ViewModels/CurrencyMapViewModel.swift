import SwiftUI
import MapKit

struct CountryValue: Identifiable {
    let id = UUID()
    let country: String
    let currency: String
    let totalCHF: Double
    let polygon: [CLLocationCoordinate2D]
    var centroid: CLLocationCoordinate2D {
        let lat = polygon.map { $0.latitude }.reduce(0, +) / Double(polygon.count)
        let lon = polygon.map { $0.longitude }.reduce(0, +) / Double(polygon.count)
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

class CurrencyMapViewModel: ObservableObject {
    @Published var countryValues: [CountryValue] = []
    @Published var quantileBreaks: [Double] = []
    @Published var loading = false

    private let currencyToCountry: [String: String] = [
        "USD": "United States",
        "EUR": "Germany",
        "GBP": "United Kingdom",
        "CHF": "Switzerland",
        "JPY": "Japan",
        "CNY": "China"
    ]

    private let polygons: [String: [CLLocationCoordinate2D]] = [
        "United States": [
            CLLocationCoordinate2D(latitude: 25, longitude: -125),
            CLLocationCoordinate2D(latitude: 25, longitude: -66),
            CLLocationCoordinate2D(latitude: 49, longitude: -66),
            CLLocationCoordinate2D(latitude: 49, longitude: -125)
        ],
        "Germany": [
            CLLocationCoordinate2D(latitude: 47, longitude: 5),
            CLLocationCoordinate2D(latitude: 47, longitude: 15),
            CLLocationCoordinate2D(latitude: 55, longitude: 15),
            CLLocationCoordinate2D(latitude: 55, longitude: 5)
        ],
        "United Kingdom": [
            CLLocationCoordinate2D(latitude: 50, longitude: -8),
            CLLocationCoordinate2D(latitude: 50, longitude: 2),
            CLLocationCoordinate2D(latitude: 59, longitude: 2),
            CLLocationCoordinate2D(latitude: 59, longitude: -8)
        ],
        "Switzerland": [
            CLLocationCoordinate2D(latitude: 46, longitude: 5),
            CLLocationCoordinate2D(latitude: 46, longitude: 11),
            CLLocationCoordinate2D(latitude: 48, longitude: 11),
            CLLocationCoordinate2D(latitude: 48, longitude: 5)
        ],
        "Japan": [
            CLLocationCoordinate2D(latitude: 31, longitude: 129),
            CLLocationCoordinate2D(latitude: 31, longitude: 146),
            CLLocationCoordinate2D(latitude: 45, longitude: 146),
            CLLocationCoordinate2D(latitude: 45, longitude: 129)
        ],
        "China": [
            CLLocationCoordinate2D(latitude: 18, longitude: 73),
            CLLocationCoordinate2D(latitude: 18, longitude: 135),
            CLLocationCoordinate2D(latitude: 53, longitude: 135),
            CLLocationCoordinate2D(latitude: 53, longitude: 73)
        ]
    ]

    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        f.groupingSeparator = "'"
        return f
    }()

    func load(using db: DatabaseManager) {
        loading = true
        DispatchQueue.global().async {
            let positions = db.fetchPositionReports()
            var totals: [String: Double] = [:]
            var rateCache: [String: Double] = [:]
            for p in positions {
                guard let price = p.currentPrice else { continue }
                let currency = p.instrumentCurrency.uppercased()
                var value = p.quantity * price
                if currency != "CHF" {
                    if rateCache[currency] == nil {
                        rateCache[currency] = db.fetchExchangeRates(currencyCode: currency, upTo: nil).first?.rateToChf
                    }
                    if let rate = rateCache[currency] { value *= rate } else { continue }
                }
                totals[currency, default: 0] += value
            }
            let filtered = totals.filter { $0.value > 0 }
            let sortedVals = filtered.map { $0.value }.sorted()
            let breaks = (0...5).map { i -> Double in
                guard !sortedVals.isEmpty else { return 0 }
                let q = Double(i) / 5.0
                let idx = Int(Double(sortedVals.count - 1) * q)
                return sortedVals[idx]
            }
            var result: [CountryValue] = []
            for (currency, value) in filtered {
                if let country = self.currencyToCountry[currency], let poly = self.polygons[country] {
                    result.append(CountryValue(country: country, currency: currency, totalCHF: value, polygon: poly))
                }
            }
            DispatchQueue.main.async {
                self.countryValues = result
                self.quantileBreaks = breaks
                self.loading = false
            }
        }
    }

    func color(for value: Double) -> Color {
        guard quantileBreaks.count == 6 else { return Color.clear }
        let breaks = quantileBreaks
        let idx: Int
        if value <= breaks[1] { idx = 0 }
        else if value <= breaks[2] { idx = 1 }
        else if value <= breaks[3] { idx = 2 }
        else if value <= breaks[4] { idx = 3 }
        else { idx = 4 }
        let brightness = 0.4 + Double(idx) * 0.1
        return Color(hue: 210/360, saturation: 0.6, brightness: brightness)
    }

    func rangeText(for index: Int) -> String {
        guard quantileBreaks.count == 6 else { return "" }
        let lower = quantileBreaks[index]
        let upper = quantileBreaks[index + 1]
        let lText = Self.formatter.string(from: NSNumber(value: lower)) ?? "0"
        let uText = Self.formatter.string(from: NSNumber(value: upper)) ?? "0"
        return "\(lText)-\(uText)"
    }

    func formatted(value: Double) -> String {
        Self.formatter.string(from: NSNumber(value: value)) ?? "0"
    }
}
