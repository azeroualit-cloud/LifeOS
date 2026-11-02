import Foundation
import MapKit
import Combine

@MainActor final class NativeBloomPlaceClassifier: ObservableObject {
    @Published private(set) var running = false
    @Published private(set) var message: String?
    func classify(in store: NativeBloomStore) async {
        guard !running else { return }
        running = true; defer { running = false }
        let candidates = store.archive.items.filter {
            let place = $0.record("place")
            return !$0.flag("archived") && !place.isEmpty && (place["kind"] == nil || place["kind"] == .null)
        }.prefix(30)
        var updated = 0, failed = 0
        for row in candidates {
            if Task.isCancelled { message = "Ricerca interrotta. \(updated) luoghi classificati."; return }
            let place = row.record("place"), coordinate = CLLocationCoordinate2D(latitude: row.record("place").amount("latitude"), longitude: row.record("place").amount("longitude"))
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = place.text("name")
            request.region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 300, longitudinalMeters: 300)
            do {
                let response = try await MKLocalSearch(request: request).start()
                guard let result = response.mapItems.first(where: {
                    normalize($0.name ?? "") == normalize(place.text("name")) && CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude).distance(from: CLLocation(latitude: $0.placemark.coordinate.latitude, longitude: $0.placemark.coordinate.longitude)) <= 150
                }), let kind = category(result.pointOfInterestCategory) else { continue }
                if try store.setClassifiedPlaceKind(row.text("id"), expected: place, kind: kind.rawValue) { updated += 1 }
            } catch { failed += 1 }
        }
        message = "\(updated) luoghi classificati. \(failed) ricerche non completate. Le tipologie manuali sono conservate."
    }
    private func normalize(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "it_IT")).split(whereSeparator: { !$0.isLetter && !$0.isNumber }).joined(separator: " ")
    }
    private func category(_ value: MKPointOfInterestCategory?) -> NativeBloomPlaceKind? {
        guard let value else { return nil }
        switch value {
        case .restaurant: return .restaurant
        case .cafe: return .cafe
        case .store: return .shop
        case .hotel: return .stay
        case .museum: return .culture
        case .park, .nationalPark: return .nature
        case .beach: return .beach
        case .fitnessCenter, .stadium: return .sport
        default: return nil
        }
    }
}
