import MapKit

struct CountryShape {
    let code: String
    let name: String
    let currency: String
    let coordinates: [CLLocationCoordinate2D]
}

struct CountryShapes {
    static func shape(for currency: String) -> CountryShape? {
        shapes.first { $0.currency.uppercased() == currency.uppercased() }
    }

    static let shapes: [CountryShape] = [
        CountryShape(code: "US", name: "United States", currency: "USD",
                     coordinates: rectangle(latMin: 24, latMax: 49, lonMin: -125, lonMax: -66)),
        CountryShape(code: "CH", name: "Switzerland", currency: "CHF",
                     coordinates: rectangle(latMin: 45, latMax: 48, lonMin: 6, lonMax: 11)),
        CountryShape(code: "DE", name: "Germany", currency: "EUR",
                     coordinates: rectangle(latMin: 47, latMax: 55, lonMin: 5, lonMax: 16)),
        CountryShape(code: "GB", name: "United Kingdom", currency: "GBP",
                     coordinates: rectangle(latMin: 50, latMax: 59, lonMin: -8, lonMax: 2)),
        CountryShape(code: "JP", name: "Japan", currency: "JPY",
                     coordinates: rectangle(latMin: 31, latMax: 46, lonMin: 129, lonMax: 146)),
        CountryShape(code: "CA", name: "Canada", currency: "CAD",
                     coordinates: rectangle(latMin: 42, latMax: 83, lonMin: -141, lonMax: -52)),
        CountryShape(code: "AU", name: "Australia", currency: "AUD",
                     coordinates: rectangle(latMin: -44, latMax: -10, lonMin: 113, lonMax: 154)),
        CountryShape(code: "CN", name: "China", currency: "CNY",
                     coordinates: rectangle(latMin: 18, latMax: 54, lonMin: 73, lonMax: 135)),
        CountryShape(code: "IN", name: "India", currency: "INR",
                     coordinates: rectangle(latMin: 8, latMax: 37, lonMin: 68, lonMax: 97)),
        CountryShape(code: "BR", name: "Brazil", currency: "BRL",
                     coordinates: rectangle(latMin: -35, latMax: 5, lonMin: -74, lonMax: -34))
    ]

    private static func rectangle(latMin: Double, latMax: Double, lonMin: Double, lonMax: Double) -> [CLLocationCoordinate2D] {
        [
            CLLocationCoordinate2D(latitude: latMin, longitude: lonMin),
            CLLocationCoordinate2D(latitude: latMin, longitude: lonMax),
            CLLocationCoordinate2D(latitude: latMax, longitude: lonMax),
            CLLocationCoordinate2D(latitude: latMax, longitude: lonMin)
        ]
    }
}
