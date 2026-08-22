import CoreLocation
import Foundation

/// Geodesic 30-mile range ring around Home / the selected city.
/// Geometry only — Mapbox paint lives in `RadarRangeRingOverlay`.
enum RadarRangeRing {
  static let radiusMiles = 30.0
  static let metersPerMile = 1609.344
  static let radiusMeters = radiusMiles * metersPerMile
  static var label: String { RadarChromeCopy.rangeRingLabel }
  /// Southeast of center so the capsule sits on the ring, away from top-trailing HUD.
  static let labelBearingDegrees = 135.0
  static let steps = 72
  static let earthRadiusMeters = 6_371_000.0

  static func destination(
    from origin: CLLocationCoordinate2D,
    distanceMeters: Double,
    bearingDegrees: Double
  ) -> CLLocationCoordinate2D {
    let angularDistance = distanceMeters / earthRadiusMeters
    let bearing = bearingDegrees * .pi / 180
    let lat1 = origin.latitude * .pi / 180
    let lon1 = origin.longitude * .pi / 180
    let sinLat1 = sin(lat1)
    let cosLat1 = cos(lat1)
    let sinAngular = sin(angularDistance)
    let cosAngular = cos(angularDistance)
    let sinLat2 = sinLat1 * cosAngular + cosLat1 * sinAngular * cos(bearing)
    let lat2 = asin(min(1, max(-1, sinLat2)))
    let lon2 =
      lon1
      + atan2(
        sin(bearing) * sinAngular * cosLat1,
        cosAngular - sinLat1 * sinLat2
      )
    return CLLocationCoordinate2D(
      latitude: lat2 * 180 / .pi,
      longitude: lon2 * 180 / .pi
    )
  }

  /// Closed ring (first point repeated at the end).
  static func ringCoordinates(
    center: CLLocationCoordinate2D,
    steps: Int = steps
  ) -> [CLLocationCoordinate2D] {
    let count = max(8, steps)
    var coords: [CLLocationCoordinate2D] = []
    coords.reserveCapacity(count + 1)
    for i in 0..<count {
      let bearing = Double(i) * 360.0 / Double(count)
      coords.append(
        destination(from: center, distanceMeters: radiusMeters, bearingDegrees: bearing)
      )
    }
    if let first = coords.first {
      coords.append(first)
    }
    return coords
  }

  static func labelCoordinate(center: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
    destination(
      from: center,
      distanceMeters: radiusMeters,
      bearingDegrees: labelBearingDegrees
    )
  }
}
