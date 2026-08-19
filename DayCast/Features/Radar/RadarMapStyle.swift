import MapboxMaps

/// Base map styles available on the Radar tab (licensed Mapbox style URIs).
/// Default is Light: a quiet gray workstation canvas so NWS reflectivity reads.
enum RadarBaseMapStyle: String, CaseIterable, Identifiable {
  case light
  case satelliteStreets
  case satellite
  case streets
  case dark

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .light: "Light"
    case .satelliteStreets: "Hybrid"
    case .satellite: "Satellite"
    case .streets: "Streets"
    case .dark: "Dark"
    }
  }

  var systemImage: String {
    switch self {
    case .light: "square.stack.3d.up.fill"
    case .satelliteStreets: "globe.americas.fill"
    case .satellite: "globe.americas"
    case .streets: "map.fill"
    case .dark: "moon.fill"
    }
  }

  var styleURI: StyleURI {
    switch self {
    case .light: .light
    case .satelliteStreets: .satelliteStreets
    case .satellite: .satellite
    case .streets: .streets
    case .dark: .dark
    }
  }

  /// Next style when cycling with the layers button.
  func cycled() -> RadarBaseMapStyle {
    let all = Self.allCases
    guard let idx = all.firstIndex(of: self) else { return .light }
    return all[(idx + 1) % all.count]
  }

  /// POI/transit labels fight the bins. City and road names stay.
  static let quietWorkstationHiddenLayerIDs = [
    "poi-label",
    "transit-label",
    "airport-label",
    "natural-point-label",
  ]

  /// Light-v11 only. Hybrid/Satellite keep their own labels. Missing IDs are skipped.
  func applyQuietWorkstation(to mapView: MapView) {
    guard self == .light else { return }
    for id in Self.quietWorkstationHiddenLayerIDs {
      guard mapView.mapboxMap.layerExists(withId: id) else { continue }
      try? mapView.mapboxMap.setLayerProperty(for: id, property: "visibility", value: "none")
    }
    for id in ["road-label", "settlement-subdivision-label"] {
      guard mapView.mapboxMap.layerExists(withId: id) else { continue }
      try? mapView.mapboxMap.setLayerProperty(for: id, property: "text-opacity", value: 0.62)
    }
  }
}
