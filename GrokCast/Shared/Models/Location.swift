import CoreLocation
import Foundation

struct SavedLocation: Identifiable, Codable, Equatable {
  let id: UUID
  var name: String
  var latitude: Double
  var longitude: Double
  var isCurrent: Bool

  var coordinate: CLLocationCoordinate2D {
    CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
  }

  init(
    id: UUID = UUID(), name: String, latitude: Double, longitude: Double, isCurrent: Bool = false
  ) {
    self.id = id
    self.name = name
    self.latitude = latitude
    self.longitude = longitude
    self.isCurrent = isCurrent
  }

  static func == (lhs: SavedLocation, rhs: SavedLocation) -> Bool {
    lhs.id == rhs.id
  }
}

extension SavedLocation {
  static var preview: SavedLocation {
    SavedLocation(name: "San Francisco", latitude: 37.7749, longitude: -122.4194)
  }

  /// Default tactical location (Olive Branch, MS) used for store init + Radar map fallback.
  /// Extracted to eliminate magic-value duplication across WeatherStore + RadarView (per review).
  /// Stable ID so repeated references to .oliveBranch have consistent identity.
  static let oliveBranch = SavedLocation(
    id: UUID(uuidString: "E5F8C2A1-3B4D-4E2F-9A1B-7C8D9E0F1A2B")!,
    name: "Olive Branch, MS",
    latitude: 34.9618,
    longitude: -89.8295
  )
}
