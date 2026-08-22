import CoreLocation
import Foundation

/// Camera for Live open. Wet Site Doppler stays local; dry National zooms out
/// from the user until precip is in frame or a CONUS-ish max — never jumps
/// the center to a random storm.
enum RadarLiveCameraPolicy {
  /// ~120 mi scale-bar frame used for Site Doppler / wet local.
  static let localZoom: Double = 6.0
  /// Dry National never keeps the empty local frame — mosaic tile centers
  /// can report a nearby number while the rain sits on the far edge.
  static let dryNationalMaxZoom: Double = 5.2
  /// Apple Precipitation-card-ish CONUS from a Memphis-centered phone.
  static let conusZoom: Double = 3.6
  /// 120 miles — precip inside this stays “wet local”.
  static let localPrecipRadiusMeters: CLLocationDistance = 190_000
  /// Typical iPhone portrait width in points (Mapbox zoom is point-based).
  static let viewportPoints: Double = 390
  /// Padding so a cell is inside the frame, not glued to the edge.
  static let fitPadding: Double = 1.25

  static func cameraZoom(
    presentingNationalBecauseDry: Bool,
    userPinnedSiteDoppler: Bool,
    nearestPrecipMeters: CLLocationDistance?,
    latitude: Double
  ) -> Double {
    if userPinnedSiteDoppler { return localZoom }
    if !presentingNationalBecauseDry { return localZoom }
    let fitted = zoomToFit(
      nearestPrecipMeters: nearestPrecipMeters, latitude: latitude)
    return min(dryNationalMaxZoom, max(conusZoom, fitted))
  }

  /// Center stays on the user. Zoom out until `distance` fits, floor at CONUS.
  static func zoomToFit(
    nearestPrecipMeters: CLLocationDistance?,
    latitude: Double
  ) -> Double {
    guard let distance = nearestPrecipMeters, distance.isFinite, distance > 0 else {
      return conusZoom
    }
    if distance <= localPrecipRadiusMeters { return localZoom }
    let needed = distance * fitPadding
    let cosLat = max(0.2, cos(latitude * .pi / 180))
    let ratio = 156_543.03392 * cosLat * viewportPoints / (2 * needed)
    let zoom = log2(max(ratio, 1))
    return min(localZoom, max(conusZoom, zoom))
  }

  #if DEBUG
  /// Simulator screenshot hook. `DAYCAST_RADAR_ZOOM` plus optional lat/lon.
  static func debugCamera() -> (center: CLLocationCoordinate2D, zoom: Double)? {
    let env = ProcessInfo.processInfo.environment
    let args = ProcessInfo.processInfo.arguments
    func arg(_ flag: String) -> String? {
      guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
      return args[i + 1]
    }
    guard
      let zoom = env["DAYCAST_RADAR_ZOOM"].flatMap(Double.init)
        ?? arg("-radarZoom").flatMap(Double.init)
    else { return nil }
    let lat = env["DAYCAST_RADAR_LAT"].flatMap(Double.init)
      ?? arg("-radarLat").flatMap(Double.init) ?? 38.906
    let lon = env["DAYCAST_RADAR_LON"].flatMap(Double.init)
      ?? arg("-radarLon").flatMap(Double.init) ?? -95.179
    return (CLLocationCoordinate2D(latitude: lat, longitude: lon), zoom)
  }
  #endif

  static func visibleRadiusMeters(zoom: Double, latitude: Double) -> CLLocationDistance {
    let cosLat = max(0.2, cos(latitude * .pi / 180))
    let metersPerPoint = 156_543.03392 * cosLat / pow(2, zoom)
    return metersPerPoint * (viewportPoints / 2)
  }
}

/// One Live-open / recenter camera request. `respectUserPan` skips apply after
/// the user has dragged or pinched this session.
struct RadarCameraRequest: Equatable {
  let id: UUID
  let latitude: Double
  let longitude: Double
  let zoom: Double
  let animated: Bool
  let respectUserPan: Bool

  var center: CLLocationCoordinate2D {
    CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
  }

  init(
    id: UUID = UUID(),
    center: CLLocationCoordinate2D,
    zoom: Double,
    animated: Bool,
    respectUserPan: Bool
  ) {
    self.id = id
    self.latitude = center.latitude
    self.longitude = center.longitude
    self.zoom = zoom
    self.animated = animated
    self.respectUserPan = respectUserPan
  }
}
