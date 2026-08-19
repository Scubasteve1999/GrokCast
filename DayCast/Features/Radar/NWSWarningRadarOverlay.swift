import CoreLocation
import Foundation
import MapboxMaps
import UIKit

/// Mapbox GeoJSON fill+line for NWS warning polygons (same pattern as `FireRadarOverlay`).
/// Does not use the MapsGL alerts weather layer — HUD and boxes share `displayableActiveAlerts`.
enum NWSWarningRadarOverlay {
  static let sourceID = "nws-warning-source"
  static let fillLayerID = "nws-warning-fill"
  static let lineLayerID = "nws-warning-line"

  static func ensureLayers(on mapView: MapView) {
    guard let style = mapView.mapboxMap else { return }
    do {
      if !style.sourceExists(withId: sourceID) {
        var source = GeoJSONSource(id: sourceID)
        source.data = .featureCollection(FeatureCollection(features: []))
        try style.addSource(source)
      }
      if !style.layerExists(withId: fillLayerID) {
        var fill = FillLayer(id: fillLayerID, source: sourceID)
        fill.fillColor = .expression(
          Exp(.toColor) {
            Exp(.get) { "fillHex" }
          }
        )
        fill.fillOpacity = .constant(0.18)
        fill.fillAntialias = .constant(true)
        try style.addLayer(fill)
      }
      if !style.layerExists(withId: lineLayerID) {
        var line = LineLayer(id: lineLayerID, source: sourceID)
        line.lineColor = .expression(
          Exp(.toColor) {
            Exp(.get) { "lineHex" }
          }
        )
        line.lineWidth = .constant(2)
        line.lineOpacity = .constant(0.95)
        try style.addLayer(line)
      }
    } catch {
      radarLog("[NWSWarning] ensureLayers failed: \(error)")
    }
  }

  static func apply(alerts: [NWSAlert], on mapView: MapView) {
    guard let style = mapView.mapboxMap, style.isStyleLoaded else { return }
    ensureLayers(on: mapView)
    let features = RadarWarningPolygon.drawn(from: alerts).compactMap(mapboxFeature(from:))
    style.updateGeoJSONSource(
      withId: sourceID,
      data: .featureCollection(FeatureCollection(features: features))
    )
  }

  private static func mapboxFeature(from drawn: RadarWarningPolygon.Drawn) -> Feature? {
    guard let geometry = geometry(from: drawn.coordinates) else { return nil }
    var feature = Feature(geometry: geometry)
    feature.identifier = .string(drawn.id)
    feature.properties = [
      "fillHex": .string(drawn.fillHex),
      "lineHex": .string(drawn.lineHex),
      "event": .string(drawn.event),
      "kind": .string(drawn.kind.rawValue),
    ]
    return feature
  }

  private static func geometry(from coordinates: [[[[Double]]]]) -> Geometry? {
    let polygons: [Polygon] = coordinates.compactMap { rings in
      let turfRings: [[LocationCoordinate2D]] = rings.compactMap { ring in
        let coords = ring.compactMap { pair -> LocationCoordinate2D? in
          guard pair.count >= 2 else { return nil }
          return LocationCoordinate2D(latitude: pair[1], longitude: pair[0])
        }
        return coords.count >= 3 ? coords : nil
      }
      guard turfRings.contains(where: { $0.count >= 3 }) else { return nil }
      return Polygon(turfRings)
    }
    if polygons.count == 1 {
      return .polygon(polygons[0])
    }
    if polygons.count > 1 {
      return .multiPolygon(MultiPolygon(polygons))
    }
    return nil
  }
}
