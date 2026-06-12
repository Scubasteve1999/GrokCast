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

  /// When GrokCast first recorded this alert (for history sorting / retention).
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
    try container.encode(firstSeen, forKey: .firstSeen)
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

// MARK: - Minimal GeoJSON geometry support (Phase 1/2 only: extract rep point for pins; full boundaries Phase 3)
// NWS uses [longitude, latitude] order in coordinates arrays.
struct NWSGeometry: Decodable {
  let type: String?
  /// Representative (lat, lon) suitable for a map pin. Extracted from Point or first coord of first Polygon ring.
  let representativePoint: (latitude: Double, longitude: Double)?

  private enum CodingKeys: String, CodingKey {
    case type
    case coordinates
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    // try? to keep tolerant (bad "type" value won't poison whole alerts batch decode in NWSService; matches NWSValueUnit + obs paths).
    type = try? container.decodeIfPresent(String.self, forKey: .type)
    representativePoint = NWSGeometry.extractRepresentativePoint(from: container)
  }

  private static func extractRepresentativePoint(from container: KeyedDecodingContainer<CodingKeys>)
    -> (latitude: Double, longitude: Double)?
  {
    // Point: "coordinates": [lon, lat]
    if let coords = try? container.decode([Double].self, forKey: .coordinates), coords.count >= 2 {
      return (latitude: coords[1], longitude: coords[0])
    }
    // Polygon: "coordinates": [[[lon, lat], ...], ...]
    if let rings = try? container.decode([[[Double]]].self, forKey: .coordinates),
      let firstRing = rings.first,
      let firstCoord = firstRing.first,
      firstCoord.count >= 2
    {
      return (latitude: firstCoord[1], longitude: firstCoord[0])
    }
    // MultiPolygon or other: take first available for minimal Phase1/2 support
    if let multi = try? container.decode([[[[Double]]]].self, forKey: .coordinates),
      let firstPoly = multi.first,
      let firstRing = firstPoly.first,
      let firstCoord = firstRing.first,
      firstCoord.count >= 2
    {
      return (latitude: firstCoord[1], longitude: firstCoord[0])
    }
    return nil
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
