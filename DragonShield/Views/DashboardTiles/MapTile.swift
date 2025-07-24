import SwiftUI
import MapKit

struct MapTile: DashboardTile {
    init() {}
    static let tileID = "map"
    static let tileName = "Position Value by Currency"
    static let iconName = "map"

    @EnvironmentObject var dbManager: DatabaseManager
    @StateObject private var viewModel = MapTileViewModel()
    @State private var tooltip: CountryExposure?

    var body: some View {
        DashboardCard(title: Self.tileName) {
            if viewModel.loading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: 150)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ChoroplethMap(countries: viewModel.countries, tooltip: $tooltip)
                        .frame(maxWidth: .infinity)
                        .aspectRatio(2, contentMode: .fit)
                        .cornerRadius(4)
                    LegendView(ranges: viewModel.legend)
                }
            }
        }
        .onAppear { viewModel.load(using: dbManager) }
        .popover(item: $tooltip) { item in
            VStack(alignment: .leading, spacing: 4) {
                Text(item.country).bold()
                Text(item.currency)
                Text(Self.formatCHF(item.totalCHF))
            }
            .padding(8)
        }
        .accessibilityElement(children: .combine)
    }

    private static func formatCHF(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        f.groupingSeparator = "'"
        f.usesGroupingSeparator = true
        return f.string(from: NSNumber(value: value)) ?? "0"
    }
}

struct ChoroplethMap: UIViewRepresentable {
    var countries: [CountryExposure]
    @Binding var tooltip: CountryExposure?

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.isRotateEnabled = false
        map.isZoomEnabled = false
        map.isScrollEnabled = false
        map.camera = MKMapCamera(lookingAtCenter: CLLocationCoordinate2D(latitude: 20, longitude: 0), fromDistance: 20000000, pitch: 0, heading: 0)
        return map
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        uiView.removeOverlays(uiView.overlays)
        for c in countries {
            if let poly = c.polygon {
                poly.title = c.country
                uiView.addOverlay(poly)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: ChoroplethMap
        init(_ parent: ChoroplethMap) { self.parent = parent }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let poly = overlay as? MKPolygon,
                  let country = poly.title else { return MKOverlayRenderer(overlay: overlay) }
            let renderer = MKPolygonRenderer(polygon: poly)
            if let exposure = parent.countries.first(where: { $0.country == country }) {
                renderer.fillColor = UIColor(exposure.fillColor)
                renderer.strokeColor = UIColor.secondaryLabel
                renderer.lineWidth = 0.5
            }
            return renderer
        }

        func mapView(_ mapView: MKMapView, didSelect overlay: MKOverlay) {
            guard let poly = overlay as? MKPolygon,
                  let title = poly.title,
                  let exposure = parent.countries.first(where: { $0.country == title }) else { return }
            parent.tooltip = exposure
        }

        func mapView(_ mapView: MKMapView, didDeselect overlay: MKOverlay) {
            parent.tooltip = nil
        }
    }
}

struct LegendView: View {
    var ranges: [ClosedRange<Double>]
    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        f.groupingSeparator = "'"
        f.usesGroupingSeparator = true
        return f
    }()

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(ranges.enumerated()), id: \._offset) { index, range in
                Rectangle()
                    .fill(Color.blue.opacity(Double(index + 1) / Double(ranges.count)))
                    .frame(width: 20, height: 10)
            }
            Spacer()
            if let first = ranges.first, let last = ranges.last {
                Text(Self.formatter.string(from: NSNumber(value: first.lowerBound)) ?? "")
                Text("-")
                Text(Self.formatter.string(from: NSNumber(value: last.upperBound)) ?? "")
            }
        }
        .font(.caption2)
    }
}
