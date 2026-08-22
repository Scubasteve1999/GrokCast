import CoreLocation
import Foundation
import MapboxMaps
import UIKit

/// Mapbox GeoJSON CircleLayer for recent CG strikes (independent of precip paint).
/// Bright = newest, dim = older. Same source/layer pattern as `FireRadarOverlay`.
enum LightningRadarOverlay {
  static let sourceID = "lightning-strikes-source"
  static let layerID = "lightning-strikes-layer"

  static func ensureLayers(on mapView: MapView) {
    guard let style = mapView.mapboxMap else { return }
    do {
      if !style.sourceExists(withId: sourceID) {
        var source = GeoJSONSource(id: sourceID)
        source.data = .featureCollection(FeatureCollection(features: []))
        try style.addSource(source)
      }
      if !style.layerExists(withId: layerID) {
        var layer = CircleLayer(id: layerID, source: sourceID)
        layer.circleRadius = .expression(
          Exp(.interpolate) {
            Exp(.linear)
            Exp(.get) { "ageMinutes" }
            0
            5.5
            8
            4.0
            20
            3.0
          }
        )
        layer.circleColor = .expression(
          Exp(.interpolate) {
            Exp(.linear)
            Exp(.get) { "ageMinutes" }
            0
            UIColor(red: 1.0, green: 0.97, blue: 0.55, alpha: 1)
            6
            UIColor(red: 1.0, green: 0.72, blue: 0.18, alpha: 1)
            14
            UIColor(red: 1.0, green: 0.38, blue: 0.08, alpha: 1)
            20
            UIColor(red: 0.75, green: 0.18, blue: 0.06, alpha: 1)
          }
        )
        layer.circleOpacity = .expression(
          Exp(.interpolate) {
            Exp(.linear)
            Exp(.get) { "ageMinutes" }
            0
            0.95
            8
            0.55
            20
            0.18
          }
        )
        layer.circleStrokeWidth = .constant(0.5)
        layer.circleStrokeColor = .constant(StyleColor(.white))
        try style.addLayer(layer)
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
      feature.properties = [
        "ageMinutes": .number(strike.ageMinutes(now: now)),
        "pulseType": .string(strike.pulseType),
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
}
