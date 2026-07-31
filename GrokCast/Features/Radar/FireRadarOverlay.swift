import CoreLocation
import Foundation
import MapboxMaps
import UIKit

/// Mapbox GeoJSON sources/layers for Fire overlay (independent of precip rasters).
enum FireRadarOverlay {
  static let hotspotsSourceID = "fire-hotspots-source"
  static let hotspotsLayerID = "fire-hotspots-layer"
  static let perimetersSourceID = "fire-perimeters-source"
  static let perimetersFillLayerID = "fire-perimeters-fill"
  static let perimetersLineLayerID = "fire-perimeters-line"

  private static let hotOrange = UIColor(red: 1.0, green: 0.45, blue: 0.12, alpha: 1)
  private static let fillOrange = UIColor(red: 1.0, green: 0.35, blue: 0.1, alpha: 1)

  static func ensureLayers(on mapView: MapView) {
    guard let style = mapView.mapboxMap else { return }
    do {
      if !style.sourceExists(withId: hotspotsSourceID) {
        var source = GeoJSONSource(id: hotspotsSourceID)
        source.data = .featureCollection(FeatureCollection(features: []))
        try style.addSource(source)
      }
      if !style.layerExists(withId: hotspotsLayerID) {
        var layer = CircleLayer(id: hotspotsLayerID, source: hotspotsSourceID)
        layer.circleRadius = .expression(
          Exp(.interpolate) {
            Exp(.linear)
            Exp(.get) { "frp" }
            0
            4
            40
            7
            120
            10
          }
        )
        layer.circleColor = .expression(
          Exp(.interpolate) {
            Exp(.linear)
            Exp(.get) { "frp" }
            0
            UIColor(red: 1, green: 0.8, blue: 0.25, alpha: 1)
            25
            hotOrange
            90
            UIColor(red: 0.9, green: 0.12, blue: 0.08, alpha: 1)
          }
        )
        layer.circleOpacity = .expression(
          Exp(.interpolate) {
            Exp(.linear)
            Exp(.get) { "ageHours" }
            0
            0.95
            8
            0.5
            36
            0.22
          }
        )
        layer.circleStrokeWidth = .constant(0.6)
        layer.circleStrokeColor = .constant(StyleColor(.white))
        try style.addLayer(layer)
      }

      if !style.sourceExists(withId: perimetersSourceID) {
        var source = GeoJSONSource(id: perimetersSourceID)
        source.data = .featureCollection(FeatureCollection(features: []))
        try style.addSource(source)
      }
      if !style.layerExists(withId: perimetersFillLayerID) {
        var fill = FillLayer(id: perimetersFillLayerID, source: perimetersSourceID)
        fill.fillColor = .constant(StyleColor(fillOrange))
        fill.fillOpacity = .constant(0.22)
        try style.addLayer(fill)
      }
      if !style.layerExists(withId: perimetersLineLayerID) {
        var line = LineLayer(id: perimetersLineLayerID, source: perimetersSourceID)
        line.lineColor = .constant(StyleColor(hotOrange))
        line.lineWidth = .constant(1.5)
        try style.addLayer(line)
      }
    } catch {
      print("[FireRadar] ensureLayers failed: \(error)")
    }
  }

  static func setVisible(_ visible: Bool, on mapView: MapView) {
    guard let style = mapView.mapboxMap else { return }
    let value = visible ? "visible" : "none"
    try? style.setLayerProperty(for: hotspotsLayerID, property: "visibility", value: value)
    try? style.setLayerProperty(for: perimetersFillLayerID, property: "visibility", value: value)
    try? style.setLayerProperty(for: perimetersLineLayerID, property: "visibility", value: value)
  }

  static func apply(snapshot: FireSnapshot, visible: Bool, on mapView: MapView) {
    guard let style = mapView.mapboxMap, style.isStyleLoaded else { return }
    ensureLayers(on: mapView)

    let hotspotFeatures = snapshot.hotspots.map { spot -> Feature in
      var feature = Feature(geometry: Point(spot.coordinate))
      feature.identifier = .string(spot.id)
      feature.properties = [
        "frp": .number(spot.frp ?? 0),
        "ageHours": .number(spot.ageHours() ?? 3),
        "confidence": .string(spot.confidence ?? ""),
      ]
      return feature
    }

    let perimeterFeatures = snapshot.perimeters.compactMap { feature(fromPerimeter: $0) }

    style.updateGeoJSONSource(
      withId: hotspotsSourceID,
      data: .featureCollection(FeatureCollection(features: hotspotFeatures))
    )
    style.updateGeoJSONSource(
      withId: perimetersSourceID,
      data: .featureCollection(FeatureCollection(features: perimeterFeatures))
    )
    setVisible(visible, on: mapView)
  }

  private static func feature(fromPerimeter perimeter: FirePerimeter) -> Feature? {
    guard
      let geometryObject = try? JSONSerialization.jsonObject(with: perimeter.geometryJSONData),
      let wrapped = try? JSONSerialization.data(withJSONObject: [
        "type": "Feature",
        "id": perimeter.id,
        "properties": [
          "name": perimeter.incidentName ?? "",
          "acres": perimeter.acres ?? 0,
        ],
        "geometry": geometryObject,
      ]),
      let decoded = try? JSONDecoder().decode(Feature.self, from: wrapped)
    else { return nil }
    return decoded
  }
}
