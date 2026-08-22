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

  /// Polar Metal sits immediately below the first of these that exists in
  /// style order (bottom→top), so settlement + road labels paint above precip.
  /// Fill / road casings stay under. Missing IDs are skipped.
  /// Live Light (iPhone 16) matched `road-label-simple`; `road-label` and
  /// settlement-* stay in the list for other styles.
  static let polarUnderlayBelowCandidateIDs = [
    "road-label",
    "road-label-simple",
    "settlement-subdivision-label",
    "settlement-minor-label",
    "settlement-major-label",
    "settlement-label",
  ]

  /// Same settlement + road labels as the polar underlay candidates. Full
  /// opacity + halo so names punch through wet Site Doppler. Skip missing.
  static let quietWorkstationPunchedLabelIDs = polarUnderlayBelowCandidateIDs

  /// Mapbox style-spec paint keys (kebab-case). Probed on Maps SDK examples
  /// (`"text-halo-width": 2`, `"text-halo-color": "#ffffff"`); missing layers
  /// are skipped. Width 2.5 + near-white halo punches through 15–35 dBZ.
  static let quietWorkstationLabelTextOpacity = 1.0
  static let quietWorkstationLabelHaloWidth = 2.5
  static let quietWorkstationLabelHaloBlur = 0.2
  static let quietWorkstationLabelHaloColor = "#f5f5f5"

  /// First matching candidate in `styleLayerIDs` (style order). Nil if none.
  static func polarUnderlayBelowLayerID(in styleLayerIDs: [String]) -> String? {
    let wanted = Set(polarUnderlayBelowCandidateIDs)
    return styleLayerIDs.first { wanted.contains($0) }
  }

  static func polarUnderlayLayerPosition(on mapView: MapView) -> LayerPosition? {
    let ids = mapView.mapboxMap.allLayerIdentifiers.map(\.id)
    guard let below = polarUnderlayBelowLayerID(in: ids) else { return nil }
    return .below(below)
  }

  /// Light-v11 only. Hybrid/Satellite keep their own labels. Missing IDs are skipped.
  /// Re-applied from `onStyleLoaded` (initial load + base-map cycle).
  func applyQuietWorkstation(to mapView: MapView) {
    guard self == .light else { return }
    for id in Self.quietWorkstationHiddenLayerIDs {
      guard mapView.mapboxMap.layerExists(withId: id) else { continue }
      try? mapView.mapboxMap.setLayerProperty(for: id, property: "visibility", value: "none")
    }
    var punched: [String] = []
    for id in Self.quietWorkstationPunchedLabelIDs {
      guard mapView.mapboxMap.layerExists(withId: id) else { continue }
      try? mapView.mapboxMap.setLayerProperty(
        for: id, property: "text-opacity", value: Self.quietWorkstationLabelTextOpacity)
      try? mapView.mapboxMap.setLayerProperty(
        for: id, property: "text-halo-color", value: Self.quietWorkstationLabelHaloColor)
      try? mapView.mapboxMap.setLayerProperty(
        for: id, property: "text-halo-width", value: Self.quietWorkstationLabelHaloWidth)
      try? mapView.mapboxMap.setLayerProperty(
        for: id, property: "text-halo-blur", value: Self.quietWorkstationLabelHaloBlur)
      punched.append(id)
    }
    if !punched.isEmpty {
      radarLog("[Mapbox] punched labels \(punched.joined(separator: ","))")
    }
  }
}
