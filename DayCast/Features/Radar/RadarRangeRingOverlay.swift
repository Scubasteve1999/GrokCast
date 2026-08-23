import CoreLocation
import Foundation
import MapboxMaps
import UIKit

/// DayCast-native 50 mi range ring: ice accent stroke + dark halo + glass capsule label.
/// Not a RadarScope gray ring / white pill clone.
enum RadarRangeRingOverlay {
  static let sourceID = "range-ring-source"
  static let haloLayerID = "range-ring-halo"
  static let lineLayerID = "range-ring-line"
  static let labelLayerID = "range-ring-label"
  /// Miles in the id so a 30→50 rebuild cannot keep a stale capsule image.
  static var labelImageID: String { "daycast-range-ring-label-\(RadarRangeRing.label)" }

  private static let accent = UIColor(red: 139 / 255, green: 184 / 255, blue: 240 / 255, alpha: 0.62)
  private static let halo = UIColor(red: 5 / 255, green: 7 / 255, blue: 12 / 255, alpha: 0.42)

  static func ensureLayers(on mapView: MapView) {
    guard let style = mapView.mapboxMap else { return }
    do {
      if !style.imageExists(withId: labelImageID) {
        try style.addImage(makeLabelImage(), id: labelImageID, sdf: false)
      }
      if !style.sourceExists(withId: sourceID) {
        var source = GeoJSONSource(id: sourceID)
        source.data = .featureCollection(FeatureCollection(features: []))
        try style.addSource(source)
      }
      if !style.layerExists(withId: haloLayerID) {
        var layer = LineLayer(id: haloLayerID, source: sourceID)
        layer.filter = Exp(.eq) {
          Exp(.geometryType)
          "LineString"
        }
        layer.lineColor = .constant(StyleColor(halo))
        layer.lineWidth = .constant(3.25)
        layer.lineOpacity = .constant(1)
        layer.lineJoin = .constant(.round)
        layer.lineCap = .constant(.round)
        try style.addLayer(layer)
      }
      if !style.layerExists(withId: lineLayerID) {
        var layer = LineLayer(id: lineLayerID, source: sourceID)
        layer.filter = Exp(.eq) {
          Exp(.geometryType)
          "LineString"
        }
        layer.lineColor = .constant(StyleColor(accent))
        layer.lineWidth = .constant(1.6)
        layer.lineOpacity = .constant(1)
        layer.lineJoin = .constant(.round)
        layer.lineCap = .constant(.round)
        try style.addLayer(layer)
      }
      if !style.layerExists(withId: labelLayerID) {
        var layer = SymbolLayer(id: labelLayerID, source: sourceID)
        layer.filter = Exp(.eq) {
          Exp(.geometryType)
          "Point"
        }
        layer.iconImage = .constant(.name(labelImageID))
        layer.iconAllowOverlap = .constant(true)
        layer.iconIgnorePlacement = .constant(true)
        layer.iconAnchor = .constant(.center)
        layer.iconPitchAlignment = .constant(.viewport)
        layer.iconRotationAlignment = .constant(.viewport)
        layer.iconSize = .constant(1)
        try style.addLayer(layer)
      }
    } catch {
      radarLog("[RangeRing] ensureLayers failed: \(error)")
    }
  }

  static func setVisible(_ visible: Bool, on mapView: MapView) {
    guard let style = mapView.mapboxMap else { return }
    let value = visible ? "visible" : "none"
    try? style.setLayerProperty(for: haloLayerID, property: "visibility", value: value)
    try? style.setLayerProperty(for: lineLayerID, property: "visibility", value: value)
    try? style.setLayerProperty(for: labelLayerID, property: "visibility", value: value)
  }

  static func apply(center: CLLocationCoordinate2D, on mapView: MapView) {
    guard let style = mapView.mapboxMap, style.isStyleLoaded else { return }
    guard CLLocationCoordinate2DIsValid(center) else { return }
    ensureLayers(on: mapView)

    let ring = RadarRangeRing.ringCoordinates(center: center)
    var ringFeature = Feature(geometry: LineString(ring))
    ringFeature.identifier = .string("range-ring")
    ringFeature.properties = [
      "kind": .string("ring"),
      "miles": .number(RadarRangeRing.radiusMiles),
    ]

    var labelFeature = Feature(geometry: Point(RadarRangeRing.labelCoordinate(center: center)))
    labelFeature.identifier = .string("range-ring-label")
    labelFeature.properties = [
      "kind": .string("label"),
      "label": .string(RadarRangeRing.label),
    ]

    style.updateGeoJSONSource(
      withId: sourceID,
      data: .featureCollection(FeatureCollection(features: [ringFeature, labelFeature]))
    )
    setVisible(true, on: mapView)
  }

  static func overlaySignature(center: CLLocationCoordinate2D) -> String {
    let lat = (center.latitude * 10_000).rounded() / 10_000
    let lon = (center.longitude * 10_000).rounded() / 10_000
    return "\(lat)|\(lon)|\(RadarRangeRing.radiusMiles)"
  }

  static func makeLabelImage() -> UIImage {
    let text = RadarRangeRing.label
    let font = UIFont.systemFont(ofSize: 12, weight: .regular)
    let attrs: [NSAttributedString.Key: Any] = [
      .font: font,
      .foregroundColor: UIColor.white.withAlphaComponent(0.92),
    ]
    let textSize = (text as NSString).size(withAttributes: attrs)
    let padX: CGFloat = 8
    let padY: CGFloat = 4
    let size = CGSize(
      width: ceil(textSize.width + padX * 2),
      height: ceil(textSize.height + padY * 2)
    )
    let format = UIGraphicsImageRendererFormat()
    format.scale = 3
    format.opaque = false
    let renderer = UIGraphicsImageRenderer(size: size, format: format)
    return renderer.image { _ in
      let rect = CGRect(origin: .zero, size: size).insetBy(dx: 0.5, dy: 0.5)
      let path = UIBezierPath(roundedRect: rect, cornerRadius: min(12, size.height / 2))
      UIColor(red: 30 / 255, green: 36 / 255, blue: 48 / 255, alpha: 0.94).setFill()
      path.fill()
      UIColor.white.withAlphaComponent(0.20).setStroke()
      path.lineWidth = 1
      path.stroke()
      let textOrigin = CGPoint(
        x: (size.width - textSize.width) / 2,
        y: (size.height - textSize.height) / 2
      )
      (text as NSString).draw(at: textOrigin, withAttributes: attrs)
    }
  }
}
