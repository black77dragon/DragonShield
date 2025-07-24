import SwiftUI
import MapKit

struct CurrencyChoroplethMapView: NSViewRepresentable {
    @ObservedObject var viewModel: CurrencyMapViewModel

    func makeCoordinator() -> Coordinator { Coordinator(viewModel: viewModel) }

    func makeNSView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.isRotateEnabled = false
        map.isZoomEnabled = false
        map.isScrollEnabled = false
        map.pointOfInterestFilter = .excludingAll
        return map
    }

    func updateNSView(_ mapView: MKMapView, context: Context) {
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)
        for country in viewModel.countryValues {
            let polygon = MKPolygon(coordinates: country.polygon, count: country.polygon.count)
            polygon.title = country.country
            context.coordinator.data[polygon] = country
            mapView.addOverlay(polygon)
        }
        mapView.setVisibleMapRect(MKMapRect.world, animated: false)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var viewModel: CurrencyMapViewModel
        var data: [MKPolygon: CountryValue] = [:]
        init(viewModel: CurrencyMapViewModel) { self.viewModel = viewModel }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let poly = overlay as? MKPolygon, let info = data[poly] else {
                return MKOverlayRenderer()
            }
            let renderer = MKPolygonRenderer(polygon: poly)
            renderer.fillColor = NSColor(viewModel.color(for: info.totalCHF))
            renderer.strokeColor = .clear
            return renderer
        }

        func mapView(_ mapView: MKMapView, didSelect overlay: MKOverlay) {
            guard let poly = overlay as? MKPolygon, let info = data[poly] else { return }
            let annotation = MKPointAnnotation()
            annotation.coordinate = info.centroid
            annotation.title = "\(info.country) – \(info.currency)"
            annotation.subtitle = "\(viewModel.formatted(value: info.totalCHF)) CHF"
            mapView.addAnnotation(annotation)
            mapView.selectAnnotation(annotation, animated: true)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            let view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: nil)
            view.canShowCallout = true
            return view
        }
    }
}
