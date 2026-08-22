#if DEBUG
import CoreLocation
import Foundation
import MapboxMaps
import UIKit

/// Spike-only ImageSource for the Mac-painted NOAA composite PNG.
/// Live default stays MapsGL. Release compiles this file empty.
@MainActor
enum MRMSDebugOverlay {
  static let sourceID = "mrms-debug-source"
  static let layerID = "mrms-debug-layer"

  /// Same corners as `scratch/radar-mrms-spike-2026-08-22/overlay/overlay.json`.
  private static let coordinates: [[Double]] = [
    [-129.995, 54.995],
    [-60.005, 54.995],
    [-60.005, 20.005],
    [-129.995, 20.005],
  ]

  private static let overlayPath =
    "/Users/bigstevedev/Projects/GrokCast/scratch/radar-mrms-spike-2026-08-22/overlay/conus-mercator.png"

  static func shouldShow(radarState: RadarState) -> Bool {
    guard radarState.debugNationalOverlay else { return false }
    guard radarState.showRadarOverlay else { return false }
    guard !radarState.showsFuture else { return false }
    return !radarState.selectedProduct.isSiteProduct
  }

  static func apply(visible: Bool, opacity: Double, on mapView: MapView) {
    guard let style = mapView.mapboxMap, style.isStyleLoaded else { return }
    if !visible {
      setVisible(false, on: mapView)
      return
    }
    guard FileManager.default.fileExists(atPath: overlayPath) else {
      radarLog("[MRMSDebug] overlay PNG missing at \(overlayPath)")
      setVisible(false, on: mapView)
      return
    }
    ensureLayers(on: mapView)
    do {
      try style.updateLayer(withId: layerID, type: RasterLayer.self) { layer in
        layer.visibility = .constant(.visible)
        layer.rasterOpacity = .constant(opacity)
        layer.rasterResampling = .constant(.nearest)
      }
    } catch {
      radarLog("[MRMSDebug] updateLayer failed: \(error)")
    }
  }

  static func ensureLayers(on mapView: MapView) {
    guard let style = mapView.mapboxMap else { return }
    let fileURL = URL(fileURLWithPath: overlayPath)
    do {
      if !style.sourceExists(withId: sourceID) {
        var source = ImageSource(id: sourceID)
        source.coordinates = coordinates
        source.url = fileURL.absoluteString
        try style.addSource(source)
      }
      if !style.layerExists(withId: layerID) {
        var layer = RasterLayer(id: layerID, source: sourceID)
        layer.rasterResampling = .constant(.nearest)
        layer.rasterFadeDuration = .constant(0)
        layer.rasterOpacity = .constant(RadarPreferences.defaultRadarOpacity)
        layer.rasterSaturation = .constant(0)
        layer.rasterContrast = .constant(0)
        layer.rasterBrightnessMin = .constant(0)
        layer.rasterHueRotate = .constant(0)
        layer.visibility = .constant(.none)
        try style.addLayer(layer)
      }
    } catch {
      radarLog("[MRMSDebug] ensureLayers failed: \(error)")
    }
  }

  static func setVisible(_ visible: Bool, on mapView: MapView) {
    guard let style = mapView.mapboxMap, style.layerExists(withId: layerID) else { return }
    try? style.updateLayer(withId: layerID, type: RasterLayer.self) { layer in
      layer.visibility = .constant(visible ? .visible : .none)
    }
  }
}
#endif
