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
}
