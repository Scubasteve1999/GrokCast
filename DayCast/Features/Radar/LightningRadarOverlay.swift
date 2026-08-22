import CoreLocation
import Foundation
import MapboxMaps
import UIKit

/// Mapbox GeoJSON SymbolLayer bolts for recent CG strikes (independent of precip paint).
/// Bright = newest, dim = older. Same source/layer pattern as `FireRadarOverlay`.
enum LightningRadarOverlay {
  static let sourceID = "lightning-strikes-source"
  static let layerID = "lightning-strikes-bolts"
  static let legacyCircleLayerID = "lightning-strikes-layer"
  static let iconImageID = "daycast-lightning-bolt"

  /// Newest CG: ice-white. Age fade: pale ice → cool gray. Never amber / orange / red.
  static let boltColorNewest = UIColor(red: 250 / 255, green: 253 / 255, blue: 255 / 255, alpha: 1)
  static let boltColorMid = UIColor(red: 224 / 255, green: 236 / 255, blue: 248 / 255, alpha: 1)
  static let boltColorOldest = UIColor(red: 176 / 255, green: 190 / 255, blue: 208 / 255, alpha: 1)

  static var boltColorExpression: Exp {
    Exp(.interpolate) {
      Exp(.linear)
      Exp(.get) { "ageMinutes" }
      0
      boltColorNewest
      8
      boltColorMid
      20
      boltColorOldest
    }
  }

  static func ensureLayers(on mapView: MapView) {
    guard let style = mapView.mapboxMap else { return }
    do {
      if style.layerExists(withId: legacyCircleLayerID) {
        try? style.removeLayer(withId: legacyCircleLayerID)
      }
      if !style.imageExists(withId: iconImageID) {
        try style.addImage(makeBoltImage(), id: iconImageID, sdf: true)
      }
      if !style.sourceExists(withId: sourceID) {
        var source = GeoJSONSource(id: sourceID)
        source.data = .featureCollection(FeatureCollection(features: []))
        try style.addSource(source)
      }
      if !style.layerExists(withId: layerID) {
        var layer = SymbolLayer(id: layerID, source: sourceID)
        layer.iconImage = .constant(.name(iconImageID))
        layer.iconAllowOverlap = .constant(true)
        layer.iconIgnorePlacement = .constant(true)
        layer.iconPadding = .constant(0)
        layer.iconAnchor = .constant(.center)
        layer.iconPitchAlignment = .constant(.viewport)
        layer.iconRotationAlignment = .constant(.viewport)
        layer.iconRotate = .expression(
          Exp(.get) { "yaw" }
        )
        layer.iconSize = .expression(
          Exp(.interpolate) {
            Exp(.linear)
            Exp(.get) { "ageMinutes" }
            0
            1.35
            8
            1.12
            20
            0.88
          }
        )
        layer.iconColor = .expression(boltColorExpression)
        layer.iconOpacity = .expression(
          Exp(.interpolate) {
            Exp(.linear)
            Exp(.get) { "ageMinutes" }
            0
            1.0
            8
            0.78
            20
            0.42
          }
        )
        // Dark halo so bolts punch through green precip and yellow warning fill.
        layer.iconHaloColor = .constant(
          StyleColor(UIColor(red: 5 / 255, green: 7 / 255, blue: 12 / 255, alpha: 1))
        )
        layer.iconHaloWidth = .expression(
          Exp(.interpolate) {
            Exp(.linear)
            Exp(.get) { "ageMinutes" }
            0
            1.6
            8
            1.1
            20
            0.6
          }
        )
        layer.iconHaloBlur = .constant(0.25)
        layer.symbolSortKey = .expression(
          Exp(.get) { "sortKey" }
        )
        try style.addLayer(layer)
      } else {
        try style.updateLayer(withId: layerID, type: SymbolLayer.self) { layer in
          layer.iconColor = .expression(boltColorExpression)
        }
      }
    } catch {
      radarLog("[LightningRadar] ensureLayers failed: \(error)")
    }
  }

  static func setVisible(_ visible: Bool, on mapView: MapView) {
    guard let style = mapView.mapboxMap else { return }
    let value = visible ? "visible" : "none"
    try? style.setLayerProperty(for: layerID, property: "visibility", value: value)
  }

  static func apply(snapshot: LightningSnapshot, visible: Bool, on mapView: MapView) {
    guard let style = mapView.mapboxMap, style.isStyleLoaded else { return }
    ensureLayers(on: mapView)

    let now = Date()
    let features = snapshot.strikes.map { strike -> Feature in
      var feature = Feature(geometry: Point(strike.coordinate))
      feature.identifier = .string(strike.id)
      let age = strike.ageMinutes(now: now)
      feature.properties = [
        "ageMinutes": .number(age),
        "pulseType": .string(strike.pulseType),
        "yaw": .number(yawDegrees(for: strike.id)),
        "sortKey": .number(-age),
      ]
      return feature
    }

    style.updateGeoJSONSource(
      withId: sourceID,
      data: .featureCollection(FeatureCollection(features: features))
    )
    setVisible(visible, on: mapView)
  }

  static func overlaySignature(from snapshot: LightningSnapshot, visible: Bool) -> String {
    let newest = snapshot.strikes.first?.time.timeIntervalSince1970 ?? 0
    return "\(visible)|\(snapshot.strikes.count)|\(newest)|\(snapshot.lastUpdated?.timeIntervalSince1970 ?? 0)"
  }

  /// Stable yaw so dense bolts do not stamp as one identical glyph.
  static func yawDegrees(for id: String) -> Double {
    var hash: UInt64 = 5381
    for byte in id.utf8 {
      hash = ((hash &<< 5) &+ hash) &+ UInt64(byte)
    }
    return Double(Int(hash % 41) - 20)
  }

  /// White silhouette for Mapbox SDF recolor (ice-white age fade + dark halo).
  static func makeBoltImage() -> UIImage {
    let size = CGSize(width: 32, height: 32)
    let format = UIGraphicsImageRendererFormat()
    format.scale = 3
    format.opaque = false
    let renderer = UIGraphicsImageRenderer(size: size, format: format)
    return renderer.image { _ in
      let inset: CGFloat = 2
      let r = CGRect(origin: .zero, size: size).insetBy(dx: inset, dy: inset)
      let path = UIBezierPath()
      path.move(to: CGPoint(x: r.minX + r.width * 0.58, y: r.minY))
      path.addLine(to: CGPoint(x: r.minX + r.width * 0.12, y: r.minY + r.height * 0.50))
      path.addLine(to: CGPoint(x: r.minX + r.width * 0.46, y: r.minY + r.height * 0.50))
      path.addLine(to: CGPoint(x: r.minX + r.width * 0.30, y: r.maxY))
      path.addLine(to: CGPoint(x: r.minX + r.width * 0.90, y: r.minY + r.height * 0.34))
      path.addLine(to: CGPoint(x: r.minX + r.width * 0.52, y: r.minY + r.height * 0.34))
      path.close()
      UIColor.white.setFill()
      path.fill()
    }
  }
}
