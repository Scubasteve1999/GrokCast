import CoreLocation
import Foundation

struct GeographicBounds: Equatable, Sendable {
  var west: Double
  var south: Double
  var east: Double
  var north: Double

  /// `west,south,east,north` for FIRMS area API.
  var firmsAreaCoordinates: String {
    "\(west),\(south),\(east),\(north)"
  }

  static func square(around center: CLLocationCoordinate2D, halfSpanDegrees: Double) -> GeographicBounds {
    GeographicBounds(
      west: max(-180, center.longitude - halfSpanDegrees),
      south: max(-90, center.latitude - halfSpanDegrees),
      east: min(180, center.longitude + halfSpanDegrees),
      north: min(90, center.latitude + halfSpanDegrees)
    )
  }
}

struct FireHotspot: Identifiable, Equatable, Sendable {
  let id: String
  let latitude: Double
  let longitude: Double
  let brightness: Double?
  let frp: Double?
  let confidence: String?
  let acqDate: String?
  let acqTime: String?
  let satellite: String?
  let detectedAt: Date?

  var coordinate: CLLocationCoordinate2D {
    CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
  }

  /// Age in hours for dimming; nil if unknown.
  func ageHours(now: Date = Date()) -> Double? {
    guard let detectedAt else { return nil }
    return max(0, now.timeIntervalSince(detectedAt) / 3600)
  }
}

struct FireIncident: Identifiable, Equatable, Sendable {
  let id: String
  let name: String?
  let latitude: Double?
  let longitude: Double?
  let acres: Double?
  let percentContained: Double?
  let cause: String?
  let discoveryDate: Date?
  let updatedAt: Date?
  let irwinID: String?

  var displayName: String {
    let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return trimmed.isEmpty ? "Unnamed fire" : trimmed
  }

  var coordinate: CLLocationCoordinate2D? {
    guard let latitude, let longitude else { return nil }
    return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
  }
}

struct FirePerimeter: Identifiable, Equatable, Sendable {
  let id: String
  let incidentName: String?
  let acres: Double?
  let percentContained: Double?
  let updatedAt: Date?
  /// Encoded GeoJSON geometry object (Polygon / MultiPolygon).
  let geometryJSONData: Data
}

enum FireFetchQuietReason: Equatable, Sendable {
  case missingKey
  case quotaExceeded
  case network
  case empty
}

struct FireSnapshot: Equatable, Sendable {
  var hotspots: [FireHotspot] = []
  var incidents: [FireIncident] = []
  var perimeters: [FirePerimeter] = []
  var lastUpdated: Date?
  var firmsQuietReason: FireFetchQuietReason?
  var nifcQuietReason: FireFetchQuietReason?
}
