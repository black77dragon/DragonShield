import SwiftUI
import MapKit

struct CurrencyMapView: View {
    let entries: [CurrencyMapEntry]
    let quantiles: [Double]
    @State private var selected: CurrencyMapEntry?
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 20, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 140, longitudeDelta: 360)
    )

    private func coordinate(for country: String) -> CLLocationCoordinate2D {
        switch country {
        case "United States": return .init(latitude: 37.0902, longitude: -95.7129)
        case "Germany": return .init(latitude: 51.1657, longitude: 10.4515)
        case "United Kingdom": return .init(latitude: 55.3781, longitude: -3.4360)
        case "Switzerland": return .init(latitude: 46.8182, longitude: 8.2275)
        case "Japan": return .init(latitude: 36.2048, longitude: 138.2529)
        case "Canada": return .init(latitude: 56.1304, longitude: -106.3468)
        case "Australia": return .init(latitude: -25.2744, longitude: 133.7751)
        case "China": return .init(latitude: 35.8617, longitude: 104.1954)
        case "Hong Kong": return .init(latitude: 22.3193, longitude: 114.1694)
        case "India": return .init(latitude: 20.5937, longitude: 78.9629)
        default: return .init(latitude: 0, longitude: 0)
        }
    }

    private func color(for value: Double) -> Color {
        guard !quantiles.isEmpty else { return Color.blue.opacity(0.3) }
        switch value {
        case ..<quantiles[0]: return Color.blue.opacity(0.3)
        case ..<quantiles[1]: return Color.blue.opacity(0.45)
        case ..<quantiles[2]: return Color.blue.opacity(0.6)
        case ..<quantiles[3]: return Color.blue.opacity(0.75)
        default: return Color.blue
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            Map(coordinateRegion: $region) {
                ForEach(entries) { entry in
                    let coord = coordinate(for: entry.country)
                    Annotation(entry.country, coordinate: coord) {
                        Circle()
                            .fill(color(for: entry.totalCHF))
                            .frame(width: 16, height: 16)
                            .onTapGesture { selected = entry }
                    }
                }
            }
            .frame(height: 160)
            .cornerRadius(8)
            .alert(item: $selected) { sel in
                Alert(title: Text(sel.country), message: Text("\(sel.currency): \(Int(sel.totalCHF).formatted()) CHF"))
            }

            HStack(spacing: 4) {
                Rectangle()
                    .fill(LinearGradient(colors: [Color.blue.opacity(0.3), Color.blue], startPoint: .leading, endPoint: .trailing))
                    .frame(height: 10)
                if let min = entries.map({ $0.totalCHF }).min(), let max = entries.map({ $0.totalCHF }).max() {
                    Text("\(Int(min))")
                        .font(.caption2)
                    Spacer()
                    Text("\(Int(max))")
                        .font(.caption2)
                }
            }
        }
    }
}
