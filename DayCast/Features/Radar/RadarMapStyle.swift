import MapboxMaps

/// Base map styles available on the Radar tab (Mapbox style URIs).
enum RadarBaseMapStyle: String, CaseIterable, Identifiable {
  case satelliteStreets
  case satellite
  case streets
  case dark

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .satelliteStreets: "Hybrid"
    case .satellite: "Satellite"
    case .streets: "Streets"
    case .dark: "Dark"
    }
  }

  var systemImage: String {
    switch self {
    case .satelliteStreets: "globe.americas.fill"
    case .satellite: "globe.americas"
    case .streets: "map.fill"
    case .dark: "moon.fill"
    }
  }

  var styleURI: StyleURI {
    switch self {
    case .satelliteStreets: .satelliteStreets
    case .satellite: .satellite
    case .streets: .streets
    case .dark: .dark
    }
  }

  /// Next style when cycling with the layers button.
  func cycled() -> RadarBaseMapStyle {
    let all = Self.allCases
    guard let idx = all.firstIndex(of: self) else { return .satelliteStreets }
    return all[(idx + 1) % all.count]
  }
}
