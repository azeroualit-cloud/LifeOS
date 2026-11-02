import SwiftUI
import MapKit

/// Native collision-based clustering follows zoom, while SwiftUI owns the note panel.
@MainActor
struct NativeBloomClusteredPlacesMap: UIViewRepresentable {
    let places: [NativeBloomPlaceMapAnnotation]
    let selectedID: String?
    let fitRequest: Int
    let select: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> MKMapView {
        let map = NativeBloomPlaceMapCanvas()
        map.delegate = context.coordinator
        map.preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .muted)
        map.pointOfInterestFilter = .excludingAll
        map.showsCompass = true
        map.showsScale = true
        map.register(NativeBloomPlacePinView.self, forAnnotationViewWithReuseIdentifier: "place")
        map.register(NativeBloomPlaceClusterView.self, forAnnotationViewWithReuseIdentifier: "cluster")
        return map
    }
    func updateUIView(_ map: MKMapView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        if coordinator.updateAnnotations(map, places: places) {
            coordinator.fit(map, annotations: places, animated: false)
        }
        if fitRequest != coordinator.lastFitRequest {
            coordinator.lastFitRequest = fitRequest
            coordinator.fit(map, annotations: map.annotations.filter { $0 is NativeBloomPlaceMapAnnotation }, animated: false)
        }
        if selectedID == nil {
            for annotation in map.selectedAnnotations { map.deselectAnnotation(annotation, animated: false) }
        }
    }
    static func dismantleUIView(_ map: MKMapView, coordinator: Coordinator) { map.delegate = nil }

    @MainActor
    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: NativeBloomClusteredPlacesMap
        var signature: [String] = []
        var lastFitRequest = 0
        init(_ parent: NativeBloomClusteredPlacesMap) { self.parent = parent }
        /// Metadata refreshes must not reset a camera the user has moved.
        func updateAnnotations(_ map: MKMapView, places: [NativeBloomPlaceMapAnnotation]) -> Bool {
            let geometry = places.map { "\($0.id):\($0.coordinate.latitude):\($0.coordinate.longitude)" }
            if geometry != signature {
                signature = geometry
                map.removeAnnotations(map.annotations)
                map.addAnnotations(places)
                return true
            }
            let byID = Dictionary(uniqueKeysWithValues: places.map { ($0.id, $0) })
            for case let current as NativeBloomPlaceMapAnnotation in map.annotations {
                guard let updated = byID[current.id], current.title != updated.title || current.count != updated.count || current.kind != updated.kind else { continue }
                current.title = updated.title; current.count = updated.count; current.kind = updated.kind
                (map.view(for: current) as? NativeBloomPlacePinView)?.configure(current)
            }
            for case let cluster as MKClusterAnnotation in map.annotations {
                if let view = map.view(for: cluster) as? NativeBloomPlaceClusterView { view.configure(cluster) }
            }
            return false
        }
        func fit(_ map: MKMapView, annotations: [MKAnnotation], animated: Bool) {
            guard !annotations.isEmpty else { return }
            if map.bounds.isEmpty {
                (map as? NativeBloomPlaceMapCanvas)?.fitOnLayout = { [weak self, weak map] in
                    guard let map else { return }
                    self?.fit(map, annotations: annotations, animated: animated)
                }
                return
            }
            var rect = MKMapRect.null
            for annotation in annotations {
                let point = MKMapPoint(annotation.coordinate)
                rect = rect.union(MKMapRect(x: point.x - 1500, y: point.y - 1500, width: 3000, height: 3000))
            }
            map.setVisibleMapRect(rect, edgePadding: UIEdgeInsets(top: NativeDesign.Layout.bloomMapFitTop, left: NativeDesign.Layout.bloomMapFitSide, bottom: NativeDesign.Layout.bloomMapFitBottom, right: NativeDesign.Layout.bloomMapFitSide), animated: animated)
        }
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if let cluster = annotation as? MKClusterAnnotation {
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: "cluster", for: cluster) as! NativeBloomPlaceClusterView
                view.configure(cluster)
                return view
            }
            guard let place = annotation as? NativeBloomPlaceMapAnnotation else { return nil }
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: "place", for: place) as! NativeBloomPlacePinView
            view.configure(place)
            return view
        }
        private func updateAccessibility(_ map: MKMapView) {
            for annotation in map.annotations {
                if let view = map.view(for: annotation) { view.isAccessibilityElement = view.cluster == nil }
            }
        }
        func mapView(_ mapView: MKMapView, didAdd views: [MKAnnotationView]) { updateAccessibility(mapView) }
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) { updateAccessibility(mapView) }
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let cluster = view.annotation as? MKClusterAnnotation {
                fit(mapView, annotations: cluster.memberAnnotations, animated: !UIAccessibility.isReduceMotionEnabled)
                mapView.deselectAnnotation(cluster, animated: false)
            } else if let place = view.annotation as? NativeBloomPlaceMapAnnotation {
                parent.select(place.id)
            }
        }
    }
}

@MainActor
private final class NativeBloomPlaceMapCanvas: MKMapView {
    var fitOnLayout: (() -> Void)?
    override func layoutSubviews() {
        super.layoutSubviews()
        if !bounds.isEmpty, let fit = fitOnLayout { fitOnLayout = nil; fit() }
    }
}

final class NativeBloomPlaceMapAnnotation: NSObject, MKAnnotation {
    let id: String
    let coordinate: CLLocationCoordinate2D
    var title: String?
    var count: Int
    var kind: NativeBloomPlaceKind
    init(id: String, place: NativeBloomPlace, count: Int) {
        self.id = id; coordinate = CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
        title = place.name; self.count = count; kind = place.resolvedKind
    }
}

/// MapKit can retain hidden/offscreen annotation views while reclustering. Expose
/// only a visible UIKit target and derive its screen geometry from the actual view.
@MainActor
class NativeBloomPlaceAnnotationView: MKAnnotationView {
    override var isAccessibilityElement: Bool {
        get {
            guard super.isAccessibilityElement, cluster == nil, window != nil, !bounds.isEmpty else { return false }
            var ancestor: UIView? = self
            while let view = ancestor {
                guard !view.isHidden, view.alpha > 0.01 else { return false }
                if let map = view as? MKMapView {
                    return map.bounds.contains(convert(CGPoint(x: bounds.midX, y: bounds.midY), to: map))
                }
                ancestor = view.superview
            }
            return false
        }
        set { super.isAccessibilityElement = newValue }
    }
    override var accessibilityFrame: CGRect {
        get { UIAccessibility.convertToScreenCoordinates(bounds, in: self) }
        set { super.accessibilityFrame = newValue }
    }
    override var accessibilityActivationPoint: CGPoint {
        get { CGPoint(x: accessibilityFrame.midX, y: accessibilityFrame.midY) }
        set { super.accessibilityActivationPoint = newValue }
    }
}

/// Full touch bounds include all decoration, so native collision grouping is reliable.
@MainActor
final class NativeBloomPlaceClusterView: NativeBloomPlaceAnnotationView {
    private let countLabel = UILabel()
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        frame = CGRect(x: 0, y: 0, width: 56, height: 56)
        displayPriority = .required
        collisionMode = .rectangle
        countLabel.frame = CGRect(x: 4, y: 4, width: 48, height: 48)
        countLabel.backgroundColor = UIColor(NativeDesign.accent)
        countLabel.textColor = UIColor { $0.userInterfaceStyle == .dark ? .black : .white }
        countLabel.font = .preferredFont(forTextStyle: .headline)
        countLabel.adjustsFontSizeToFitWidth = true
        countLabel.minimumScaleFactor = 0.6
        countLabel.textAlignment = .center
        countLabel.layer.cornerRadius = 24
        countLabel.layer.borderWidth = 2
        countLabel.layer.borderColor = UIColor(NativeDesign.canvas).cgColor
        countLabel.clipsToBounds = true
        addSubview(countLabel)
        isAccessibilityElement = true; accessibilityTraits = .button
        accessibilityIdentifier = "map-cluster"
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func configure(_ cluster: MKClusterAnnotation) {
        let places = cluster.memberAnnotations.compactMap { $0 as? NativeBloomPlaceMapAnnotation }
        let notes = places.reduce(0) { $0 + $1.count }
        countLabel.text = "\(places.count)"
        accessibilityLabel = "\(places.count) luoghi, \(NativeBloomMapLabels.noteCount(notes))"
        accessibilityHint = "Il numero indica i luoghi raggruppati. Tocca per ingrandire"
    }
}

@MainActor
final class NativeBloomPlacePinView: NativeBloomPlaceAnnotationView {
    private let ring = UIView()
    private let glyph = UIImageView()
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        clusteringIdentifier = "bloom-places"
        collisionMode = .rectangle
        displayPriority = .defaultLow
        ring.frame = CGRect(x: 6, y: 6, width: 32, height: 32)
        ring.backgroundColor = UIColor(NativeDesign.canvas)
        ring.layer.cornerRadius = 16
        ring.layer.borderWidth = 2
        ring.layer.borderColor = UIColor(NativeDesign.accent).cgColor
        glyph.frame = CGRect(x: 12, y: 12, width: 20, height: 20)
        glyph.contentMode = .scaleAspectFit
        glyph.tintColor = UIColor(NativeDesign.accent)
        addSubview(ring); addSubview(glyph)
        isAccessibilityElement = true; accessibilityTraits = .button
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        ring.layer.borderWidth = selected ? 4 : 2
    }
    func configure(_ place: NativeBloomPlaceMapAnnotation) {
        glyph.image = UIImage(systemName: place.kind.symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold))
        accessibilityIdentifier = "map-marker-\(place.id)"
        accessibilityLabel = "\(place.title ?? "Luogo"), \(place.kind.label), \(NativeBloomMapLabels.noteCount(place.count))"
        accessibilityHint = "Mostra le note salvate in questo luogo"
    }
}

private enum NativeBloomMapLabels { static func noteCount(_ count: Int) -> String { count == 1 ? "1 nota" : "\(count) note" } }
