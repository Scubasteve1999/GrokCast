import CoreLocation
import Foundation
import MapboxMaps
import UIKit

/// DayCast-native 50 mi range ring: soft dark halo + crisp ice stroke, center mark,
/// glass-dark “50 mi” capsule. Not a RadarScope gray ring / white pill clone.
enum RadarRangeRingOverlay {
  static let sourceID = "range-ring-source"
  static let fillLayerID = "range-ring-fill"
  static let haloLayerID = "range-ring-halo"
  static let lineLayerID = "range-ring-line"
  static let centerLayerID = "range-ring-center"
  static let labelLayerID = "range-ring-label"
  /// Bump when the capsule or pip art changes so a live style cannot keep a stale image.
  static let paintVersion = "d1"
  static var labelImageID: String {
    "daycast-range-ring-label-\(RadarRangeRing.label)-\(paintVersion)"
  }
  static var centerImageID: String { "daycast-range-ring-center-\(paintVersion)" }

  /// Inner ice stroke — present on light and dark underlay, not a 3–4pt RadarScope clone.
  static let strokeWidth = 2.2
  /// Soft outer halo (wider + blurred).
  static let haloWidth = 5.5
  static let haloBlur = 1.2
  /// Interior wash. Low enough not to muddy 15+ dBZ cores.
  static let fillOpacity = 0.05

  /// Ice accent `#8BB8F0` at high alpha so the inner stroke reads as a real distance ring.
  private static let accent = UIColor(red: 139 / 255, green: 184 / 255, blue: 240 / 255, alpha: 0.92)
  private static let accentSolid = UIColor(red: 139 / 255, green: 184 / 255, blue: 240 / 255, alpha: 1)
  /// Cool dark halo — punches on Mapbox Light, stays quiet on dark underlay.
  private static let halo = UIColor(red: 8 / 255, green: 14 / 255, blue: 28 / 255, alpha: 0.58)
  private static let fill = UIColor(red: 139 / 255, green: 184 / 255, blue: 240 / 255, alpha: 1)
  private static let glass = UIColor(red: 5 / 255, green: 7 / 255, blue: 12 / 255, alpha: 0.94)
  private static let glassStroke = UIColor(red: 139 / 255, green: 184 / 255, blue: 240 / 255, alpha: 0.42)

  static func ensureLayers(on mapView: MapView) {
    guard let style = mapView.mapboxMap else { return }
    do {
      if !style.imageExists(withId: labelImageID) {
        try style.addImage(makeLabelImage(), id: labelImageID, sdf: false)
      }
      if !style.imageExists(withId: centerImageID) {
        try style.addImage(makeCenterImage(), id: centerImageID, sdf: false)
      }
      if !style.sourceExists(withId: sourceID) {
        var source = GeoJSONSource(id: sourceID)
        source.data = .featureCollection(FeatureCollection(features: []))
        try style.addSource(source)
      }

      if !style.layerExists(withId: fillLayerID) {
        var layer = FillLayer(id: fillLayerID, source: sourceID)
        applyFillStyle(&layer)
        if style.layerExists(withId: haloLayerID) {
          try style.addLayer(layer, layerPosition: .below(haloLayerID))
        } else {
          try style.addLayer(layer)
        }
      } else {
        try style.updateLayer(withId: fillLayerID, type: FillLayer.self, update: applyFillStyle)
      }

      if !style.layerExists(withId: haloLayerID) {
        var layer = LineLayer(id: haloLayerID, source: sourceID)
        applyHaloStyle(&layer)
        try style.addLayer(layer)
      } else {
        try style.updateLayer(withId: haloLayerID, type: LineLayer.self, update: applyHaloStyle)
      }

      if !style.layerExists(withId: lineLayerID) {
        var layer = LineLayer(id: lineLayerID, source: sourceID)
        applyStrokeStyle(&layer)
        try style.addLayer(layer)
      } else {
        try style.updateLayer(withId: lineLayerID, type: LineLayer.self, update: applyStrokeStyle)
      }

      if !style.layerExists(withId: centerLayerID) {
        var layer = SymbolLayer(id: centerLayerID, source: sourceID)
        applyCenterStyle(&layer)
        try style.addLayer(layer)
      } else {
        try style.updateLayer(withId: centerLayerID, type: SymbolLayer.self, update: applyCenterStyle)
      }

      if !style.layerExists(withId: labelLayerID) {
        var layer = SymbolLayer(id: labelLayerID, source: sourceID)
        applyLabelStyle(&layer)
        try style.addLayer(layer)
      } else {
        try style.updateLayer(withId: labelLayerID, type: SymbolLayer.self, update: applyLabelStyle)
      }
    } catch {
      radarLog("[RangeRing] ensureLayers failed: \(error)")
    }
  }

  static func setVisible(_ visible: Bool, on mapView: MapView) {
    guard let style = mapView.mapboxMap else { return }
    let value = visible ? "visible" : "none"
    try? style.setLayerProperty(for: fillLayerID, property: "visibility", value: value)
    try? style.setLayerProperty(for: haloLayerID, property: "visibility", value: value)
    try? style.setLayerProperty(for: lineLayerID, property: "visibility", value: value)
    try? style.setLayerProperty(for: centerLayerID, property: "visibility", value: value)
    try? style.setLayerProperty(for: labelLayerID, property: "visibility", value: value)
  }

  static func apply(center: CLLocationCoordinate2D, on mapView: MapView) {
    guard let style = mapView.mapboxMap, style.isStyleLoaded else { return }
    guard CLLocationCoordinate2DIsValid(center) else { return }
    ensureLayers(on: mapView)

    let ring = RadarRangeRing.ringCoordinates(center: center)

    var fillFeature = Feature(geometry: Polygon([ring]))
    fillFeature.identifier = .string("range-ring-fill")
    fillFeature.properties = [
      "kind": .string("fill"),
      "miles": .number(RadarRangeRing.radiusMiles),
    ]

    var ringFeature = Feature(geometry: LineString(ring))
    ringFeature.identifier = .string("range-ring")
    ringFeature.properties = [
      "kind": .string("ring"),
      "miles": .number(RadarRangeRing.radiusMiles),
    ]

    var centerFeature = Feature(geometry: Point(center))
    centerFeature.identifier = .string("range-ring-center")
    centerFeature.properties = [
      "kind": .string("center"),
    ]

    var labelFeature = Feature(geometry: Point(RadarRangeRing.labelCoordinate(center: center)))
    labelFeature.identifier = .string("range-ring-label")
    labelFeature.properties = [
      "kind": .string("label"),
      "label": .string(RadarRangeRing.label),
    ]

    style.updateGeoJSONSource(
      withId: sourceID,
      data: .featureCollection(
        FeatureCollection(features: [fillFeature, ringFeature, centerFeature, labelFeature])
      )
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
    let font = UIFont.systemFont(ofSize: 12, weight: .medium)
    let attrs: [NSAttributedString.Key: Any] = [
      .font: font,
      .foregroundColor: UIColor.white.withAlphaComponent(0.94),
    ]
    let textSize = (text as NSString).size(withAttributes: attrs)
    let padX: CGFloat = 10
    let padY: CGFloat = 5
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
      glass.setFill()
      path.fill()
      glassStroke.setStroke()
      path.lineWidth = 1
      path.stroke()
      let textOrigin = CGPoint(
        x: (size.width - textSize.width) / 2,
        y: (size.height - textSize.height) / 2
      )
      (text as NSString).draw(at: textOrigin, withAttributes: attrs)
    }
  }

  /// Ice pip + short cardinal ticks at the confirmed center. Viewport-locked, not a GPS puck.
  static func makeCenterImage() -> UIImage {
    let size = CGSize(width: 22, height: 22)
    let format = UIGraphicsImageRendererFormat()
    format.scale = 3
    format.opaque = false
    let renderer = UIGraphicsImageRenderer(size: size, format: format)
    return renderer.image { _ in
      let c = CGPoint(x: size.width / 2, y: size.height / 2)

      let haloDisc = UIBezierPath(ovalIn: CGRect(x: 1.2, y: 1.2, width: 19.6, height: 19.6))
      UIColor(red: 5 / 255, green: 7 / 255, blue: 12 / 255, alpha: 0.55).setFill()
      haloDisc.fill()

      accentSolid.setStroke()
      let ticks = UIBezierPath()
      ticks.lineWidth = 1.35
      ticks.lineCapStyle = .round
      let inner: CGFloat = 5.6
      let outer: CGFloat = 9.4
      let dirs: [(CGFloat, CGFloat)] = [(0, -1), (1, 0), (0, 1), (-1, 0)]
      for (dx, dy) in dirs {
        ticks.move(to: CGPoint(x: c.x + dx * inner, y: c.y + dy * inner))
        ticks.addLine(to: CGPoint(x: c.x + dx * outer, y: c.y + dy * outer))
      }
      ticks.stroke()

      let ring = UIBezierPath(ovalIn: CGRect(x: c.x - 4.5, y: c.y - 4.5, width: 9, height: 9))
      ring.lineWidth = 1.55
      accentSolid.setStroke()
      ring.stroke()

      let core = UIBezierPath(ovalIn: CGRect(x: c.x - 1.65, y: c.y - 1.65, width: 3.3, height: 3.3))
      accentSolid.setFill()
      core.fill()

      let glint = UIBezierPath(ovalIn: CGRect(x: c.x - 0.5, y: c.y - 0.85, width: 1.05, height: 1.05))
      UIColor.white.withAlphaComponent(0.82).setFill()
      glint.fill()
    }
  }

  private static func lineStringFilter() -> Exp {
    Exp(.eq) {
      Exp(.geometryType)
      "LineString"
    }
  }

  private static func polygonFilter() -> Exp {
    Exp(.eq) {
      Exp(.geometryType)
      "Polygon"
    }
  }

  private static func kindFilter(_ kind: String) -> Exp {
    Exp(.eq) {
      Exp(.get) { "kind" }
      kind
    }
  }

  private static func applyFillStyle(_ layer: inout FillLayer) {
    layer.filter = polygonFilter()
    layer.fillColor = .constant(StyleColor(fill))
    layer.fillOpacity = .constant(fillOpacity)
    layer.fillAntialias = .constant(true)
  }

  private static func applyHaloStyle(_ layer: inout LineLayer) {
    layer.filter = lineStringFilter()
    layer.lineColor = .constant(StyleColor(halo))
    layer.lineWidth = .constant(haloWidth)
    layer.lineBlur = .constant(haloBlur)
    layer.lineOpacity = .constant(1)
    layer.lineJoin = .constant(.round)
    layer.lineCap = .constant(.round)
  }

  private static func applyStrokeStyle(_ layer: inout LineLayer) {
    layer.filter = lineStringFilter()
    layer.lineColor = .constant(StyleColor(accent))
    layer.lineWidth = .constant(strokeWidth)
    layer.lineBlur = .constant(0)
    layer.lineOpacity = .constant(1)
    layer.lineJoin = .constant(.round)
    layer.lineCap = .constant(.round)
  }

  private static func applyCenterStyle(_ layer: inout SymbolLayer) {
    layer.filter = kindFilter("center")
    layer.iconImage = .constant(.name(centerImageID))
    layer.iconAllowOverlap = .constant(true)
    layer.iconIgnorePlacement = .constant(true)
    layer.iconAnchor = .constant(.center)
    layer.iconPitchAlignment = .constant(.viewport)
    layer.iconRotationAlignment = .constant(.viewport)
    layer.iconSize = .constant(1)
  }

  private static func applyLabelStyle(_ layer: inout SymbolLayer) {
    layer.filter = kindFilter("label")
    layer.iconImage = .constant(.name(labelImageID))
    layer.iconAllowOverlap = .constant(true)
    layer.iconIgnorePlacement = .constant(true)
    layer.iconAnchor = .constant(.center)
    layer.iconPitchAlignment = .constant(.viewport)
    layer.iconRotationAlignment = .constant(.viewport)
    layer.iconSize = .constant(1)
  }
}
