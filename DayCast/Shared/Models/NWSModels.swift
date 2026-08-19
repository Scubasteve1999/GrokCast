import CoreLocation
import Foundation

// MARK: - App-facing NWS Alert model (transient, for Today banners + Storm Spotter prompts)
// Codable for potential future persistence; Identifiable/Equatable for UI lists and store.

struct NWSAlert: Identifiable, Codable, Equatable, Hashable {
  let id: String
  let event: String
  let severity: String?  // "Minor", "Moderate", "Severe", "Extreme"
  let headline: String?
  let description: String?
  let instruction: String?
  let sent: Date?
  let expires: Date?
  let areaDesc: String?  // e.g. counties/zones affected

  // Optional representative point from NWS geometry (Point or first vertex of Polygon).
  // Populated for map pins in Radar tab (Phase 1/2). nil for non-geo or non-US alerts.
  let latitude: Double?
  let longitude: Double?

  /// True when this alert came from a point query that includes the selected location.
  let containsSelectedPoint: Bool
  /// Soft polygon metadata for Grok / UI (never drops the alert if geometry decode fails).
  let geometryVertexCount: Int?
  /// Compact bbox string like "34.9–35.2N, 90.1–89.7W" when a polygon is present.
  let geometryBBoxSummary: String?
  /// GeoJSON MultiPolygon coordinates `[polygon][ring][vertex][lon, lat]`.
  /// A single Polygon is stored as one-element MultiPolygon. Point-only alerts are nil.
  /// Absent on history decoded from older builds.
  let polygonCoordinates: [[[[Double]]]]?

  /// When DayCast first recorded this alert (for history sorting / retention).
  let firstSeen: Date

  init(
    id: String,
    event: String,
    severity: String?,
    headline: String?,
    description: String?,
    instruction: String?,
    sent: Date? = nil,
    expires: Date?,
    areaDesc: String?,
    latitude: Double?,
    longitude: Double?,
    containsSelectedPoint: Bool = true,
    geometryVertexCount: Int? = nil,
    geometryBBoxSummary: String? = nil,
    polygonCoordinates: [[[[Double]]]]? = nil,
    firstSeen: Date = Date()
  ) {
    self.id = id
    self.event = event
    self.severity = severity
    self.headline = headline
    self.description = description
    self.instruction = instruction
    self.sent = sent
    self.expires = expires
    self.areaDesc = areaDesc
    self.latitude = latitude
    self.longitude = longitude
    self.containsSelectedPoint = containsSelectedPoint
    self.geometryVertexCount = geometryVertexCount
    self.geometryBBoxSummary = geometryBBoxSummary
    self.polygonCoordinates = polygonCoordinates
    self.firstSeen = firstSeen
  }

  // Convenience for MapKit annotations (reuses SavedLocation pattern).
  var coordinate: CLLocationCoordinate2D? {
    guard let lat = latitude, let lon = longitude else { return nil }
    return CLLocationCoordinate2D(latitude: lat, longitude: lon)
  }

  // Numeric level for sorting/tinting (Extreme highest)
  var severityLevel: Int {
    switch (severity ?? "").lowercased() {
    case "extreme": return 4
    case "severe": return 3
    case "moderate": return 2
    case "minor": return 1
    default: return 0
    }
  }

  /// True when the NWS event name indicates a Warning or Watch (eligible for push notifications).
  var isSevereEvent: Bool {
    let lower = event.lowercased()
    return lower.contains("warning") || lower.contains("watch")
  }

  var isWarning: Bool {
    event.lowercased().contains("warning")
  }

  var isWatch: Bool {
    event.lowercased().contains("watch") && !isWarning
  }

  var isExpired: Bool {
    guard let expires else { return false }
    return expires < Date()
  }

  var isLifeThreatening: Bool {
    let lower = event.lowercased()
    return lower.contains("tornado warning")
      || lower.contains("hurricane warning")
      || lower.contains("extreme wind warning")
      || lower.contains("storm surge warning")
      || lower.contains("tsunami warning")
      || lower.contains("flash flood emergency")
      || (severity ?? "").lowercased() == "extreme"
  }

  var expiresRelativeText: String? {
    guard let expires, expires > Date() else { return nil }
    let interval = expires.timeIntervalSinceNow
    let hours = Int(interval) / 3600
    let minutes = (Int(interval) % 3600) / 60
    if hours > 0 {
      return "Expires in \(hours)h \(minutes)m"
    }
    return "Expires in \(minutes)m"
  }

  /// Best date for sorting history (sent preferred, then firstSeen).
  var sortDate: Date {
    sent ?? firstSeen
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case event
    case severity
    case headline
    case description
    case instruction
    case sent
    case expires
    case areaDesc
    case latitude
    case longitude
    case containsSelectedPoint
    case geometryVertexCount
    case geometryBBoxSummary
    case polygonCoordinates
    case firstSeen
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    event = try container.decode(String.self, forKey: .event)
    severity = try container.decodeIfPresent(String.self, forKey: .severity)
    headline = try container.decodeIfPresent(String.self, forKey: .headline)
    description = try container.decodeIfPresent(String.self, forKey: .description)
    instruction = try container.decodeIfPresent(String.self, forKey: .instruction)
    sent = try container.decodeIfPresent(Date.self, forKey: .sent)
    expires = try container.decodeIfPresent(Date.self, forKey: .expires)
    areaDesc = try container.decodeIfPresent(String.self, forKey: .areaDesc)
    latitude = try container.decodeIfPresent(Double.self, forKey: .latitude)
    longitude = try container.decodeIfPresent(Double.self, forKey: .longitude)
    containsSelectedPoint =
      try container.decodeIfPresent(Bool.self, forKey: .containsSelectedPoint) ?? true
    geometryVertexCount = try container.decodeIfPresent(Int.self, forKey: .geometryVertexCount)
    geometryBBoxSummary = try container.decodeIfPresent(String.self, forKey: .geometryBBoxSummary)
    polygonCoordinates = try container.decodeIfPresent([[[[Double]]]].self, forKey: .polygonCoordinates)
    firstSeen = try container.decodeIfPresent(Date.self, forKey: .firstSeen) ?? Date()
  }

  static func == (lhs: NWSAlert, rhs: NWSAlert) -> Bool {
    lhs.id == rhs.id
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(event, forKey: .event)
    try container.encodeIfPresent(severity, forKey: .severity)
    try container.encodeIfPresent(headline, forKey: .headline)
    try container.encodeIfPresent(description, forKey: .description)
    try container.encodeIfPresent(instruction, forKey: .instruction)
    try container.encodeIfPresent(sent, forKey: .sent)
    try container.encodeIfPresent(expires, forKey: .expires)
    try container.encodeIfPresent(areaDesc, forKey: .areaDesc)
    try container.encodeIfPresent(latitude, forKey: .latitude)
    try container.encodeIfPresent(longitude, forKey: .longitude)
    try container.encode(containsSelectedPoint, forKey: .containsSelectedPoint)
    try container.encodeIfPresent(geometryVertexCount, forKey: .geometryVertexCount)
    try container.encodeIfPresent(geometryBBoxSummary, forKey: .geometryBBoxSummary)
    try container.encodeIfPresent(polygonCoordinates, forKey: .polygonCoordinates)
    try container.encode(firstSeen, forKey: .firstSeen)
  }
}

/// Distinguishes "no alerts" from "couldn't check" so the Alerts tab never
/// shows a checkmark all-clear when NWS never answered for this city.
enum AlertsLoadState: Equatable {
  case pending
  case loaded
  case failed

  static func resolve(
    currentLocationID: UUID?,
    attemptedLocationID: UUID?,
    lastSucceeded: Bool
  ) -> AlertsLoadState {
    guard let currentLocationID, attemptedLocationID == currentLocationID else {
      return .pending
    }
    return lastSucceeded ? .loaded : .failed
  }
}

// MARK: - NWS API raw response models (Decodable only; not exposed in app model)

struct NWSAlertsResponse: Decodable {
  let features: [NWSAlertFeature]
}

struct NWSAlertFeature: Decodable {
  let id: String?  // NWS-provided alert identifier (often a full URN/URL)
  let properties: NWSAlertProperties
  let geometry: NWSGeometry?  // for Radar map pins (rep point)
}

struct NWSAlertProperties: Decodable {
  let event: String
  let severity: String?
  let urgency: String?
  let certainty: String?
  let headline: String?
  let description: String?
  let instruction: String?
  let sent: String?
  let expires: String?
  let areaDesc: String?
  // Future: effective, onset, status, messageType, category, etc.
}

// MARK: - GeoJSON geometry (rep point for pins + rings for Live Radar warning boxes)
// NWS uses [longitude, latitude] order in coordinates arrays.
struct NWSGeometry: Decodable {
  let type: String?
  /// Representative (lat, lon) suitable for a map pin. Extracted from Point or first coord of first Polygon ring.
  let representativePoint: (latitude: Double, longitude: Double)?
  /// Vertex count across decoded rings (soft; nil when geometry absent/unparsed).
  let vertexCount: Int?
  /// Compact bbox summary for prompts ("covers area including selected location").
  let bboxSummary: String?
  /// GeoJSON MultiPolygon coordinates. Polygon is wrapped as `[rings]`. Point is nil.
  let polygonCoordinates: [[[[Double]]]]?

  private enum CodingKeys: String, CodingKey {
    case type
    case coordinates
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    // try? to keep tolerant (bad "type" value won't poison whole alerts batch decode in NWSService; matches NWSValueUnit + obs paths).
    type = try? container.decodeIfPresent(String.self, forKey: .type)
    let extracted = NWSGeometry.extractGeometry(from: container)
    representativePoint = extracted.point
    vertexCount = extracted.vertexCount
    bboxSummary = extracted.bboxSummary
    polygonCoordinates = extracted.polygonCoordinates
  }

  private static func extractGeometry(from container: KeyedDecodingContainer<CodingKeys>) -> (
    point: (latitude: Double, longitude: Double)?,
    vertexCount: Int?,
    bboxSummary: String?,
    polygonCoordinates: [[[[Double]]]]?
  ) {
    // Point: "coordinates": [lon, lat]
    if let coords = try? container.decode([Double].self, forKey: .coordinates), coords.count >= 2 {
      return (
        point: (latitude: coords[1], longitude: coords[0]),
        vertexCount: 1,
        bboxSummary: nil,
        polygonCoordinates: nil
      )
    }
    // Polygon: "coordinates": [[[lon, lat], ...], ...]
    if let rings = try? container.decode([[[Double]]].self, forKey: .coordinates) {
      let summary = summarizeRings(rings)
      return (
        summary.point,
        summary.vertexCount,
        summary.bboxSummary,
        summary.vertexCount == nil ? nil : [rings]
      )
    }
    // MultiPolygon
    if let multi = try? container.decode([[[[Double]]]].self, forKey: .coordinates) {
      let rings = multi.flatMap { $0 }
      let summary = summarizeRings(rings)
      return (
        summary.point,
        summary.vertexCount,
        summary.bboxSummary,
        summary.vertexCount == nil ? nil : multi
      )
    }
    return (nil, nil, nil, nil)
  }

  private static func summarizeRings(_ rings: [[[Double]]]) -> (
    point: (latitude: Double, longitude: Double)?,
    vertexCount: Int?,
    bboxSummary: String?
  ) {
    var count = 0
    var minLat = Double.greatestFiniteMagnitude
    var maxLat = -Double.greatestFiniteMagnitude
    var minLon = Double.greatestFiniteMagnitude
    var maxLon = -Double.greatestFiniteMagnitude
    var firstPoint: (latitude: Double, longitude: Double)?

    for ring in rings {
      for coord in ring where coord.count >= 2 {
        let lon = coord[0]
        let lat = coord[1]
        count += 1
        if firstPoint == nil { firstPoint = (lat, lon) }
        minLat = min(minLat, lat)
        maxLat = max(maxLat, lat)
        minLon = min(minLon, lon)
        maxLon = max(maxLon, lon)
      }
    }

    guard count > 0, let firstPoint else { return (nil, nil, nil) }
    let loLat = min(minLat, maxLat)
    let hiLat = max(minLat, maxLat)
    let loLon = min(minLon, maxLon)
    let hiLon = max(minLon, maxLon)
    let bbox = String(
      format: "%.1f%@–%.1f%@, %.1f%@–%.1f%@",
      abs(loLat), loLat >= 0 ? "N" : "S",
      abs(hiLat), hiLat >= 0 ? "N" : "S",
      abs(loLon), loLon >= 0 ? "E" : "W",
      abs(hiLon), hiLon >= 0 ? "E" : "W"
    )
    return (firstPoint, count, bbox)
  }

  /// Legacy helper name used by older call sites.
  private static func extractRepresentativePoint(from container: KeyedDecodingContainer<CodingKeys>)
    -> (latitude: Double, longitude: Double)?
  {
    extractGeometry(from: container).point
  }
}

// MARK: - NWS Observation (ground-truth from nearest station, for Today + Storm Spotter prompts)
// Minimal fields for this slice. Transient (in-memory). Additive only.

struct NWSObservation: Codable, Equatable {
  let stationId: String
  let observedAt: Date
  let temperatureF: Double?
  let windSpeedMph: Double?
  let windDirectionDegrees: Int?
  // Future: humidity, dewpoint, pressure, etc. if useful for prompt/UI
}

// MARK: - Raw NWS API response models for observations and points (Decodable only)

struct NWSPointsResponse: Decodable {
  let properties: NWSPointsProperties
}

struct NWSPointsProperties: Decodable {
  let observationStations: String  // URL to the stations collection (e.g. /gridpoints/.../stations) - not an array anymore
  // Grid fields for --grid-system / --primary-source (optional for tolerant non-US + obs compatibility)
  let gridId: String?
  let gridX: Int?
  let gridY: Int?
  let forecast: String?  // direct /forecast URL (often grid equivalent); impl derives strictly from grid* for exact flow
}

struct NWSObservationResponse: Decodable {
  let properties: NWSObservationProperties
}

struct NWSObservationProperties: Decodable {
  let station: String?  // full station URL (we extract ID)
  let timestamp: String
  let temperature: NWSValueUnit?
  let windSpeed: NWSValueUnit?
  let windDirection: NWSValueUnit?
  // Add more as needed: relativeHumidity, dewpoint, etc.
}

struct NWSValueUnit: Decodable {
  let value: Double?
  let unitCode: String?

  private enum CodingKeys: String, CodingKey {
    case value
    case unitCode
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    // Handle value as Double, Int, or null
    if let d = try? container.decodeIfPresent(Double.self, forKey: .value) {
      value = d
    } else if let i = try? container.decodeIfPresent(Int.self, forKey: .value) {
      value = Double(i)
    } else {
      value = nil
    }
    unitCode = try? container.decodeIfPresent(String.self, forKey: .unitCode)
  }
}

// MARK: - NWS Stations collection response (to get list of stations from the observationStations URL)

struct NWSStationsResponse: Decodable {
  let features: [NWSStationFeature]
}

struct NWSStationFeature: Decodable {
  let id: String  // full station URL, e.g. https://api.weather.gov/stations/KOLV
}

// MARK: - NWS Grid Forecast response models (tolerant decoders for /gridpoints/.../forecast ; periods drive mapping to existing models)
struct NWSForecastResponse: Decodable {
  let properties: NWSForecastProperties
}

struct NWSForecastProperties: Decodable {
  let periods: [NWSForecastPeriod]
}

struct NWSForecastPeriod: Decodable {
  let number: Int
  let name: String
  let startTime: String
  let endTime: String
  let isDaytime: Bool
  let temperature: Int?
  let temperatureUnit: String?
  let windSpeed: String?
  let windDirection: String?
  let icon: String?
  let shortForecast: String?
  let detailedForecast: String?
  let probabilityOfPrecipitation: NWSValueUnit?

  /// PoP as 0–100 for UI; NWS may omit or null the value on dry periods.
  var precipChancePercent: Int {
    guard let value = probabilityOfPrecipitation?.value else { return 0 }
    return max(0, min(100, Int(value.rounded())))
  }
}
