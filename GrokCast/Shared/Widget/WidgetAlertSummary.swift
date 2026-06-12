import Foundation

/// Lightweight NWS alert summary shared with widgets via App Group (not full alert history).
struct WidgetAlertSummary: Codable, Equatable {
  let locationID: UUID
  let topEvent: String
  let topSeverityLevel: Int
  let topIsWarning: Bool
  let topIsWatch: Bool
  let activeCount: Int
  /// Expiration of the highest-severity alert (display refresh boundary).
  let topExpires: Date?
  /// Latest expiration across all active alerts at write time (activity boundary).
  let anyActiveUntil: Date?
  let updatedAt: Date

  /// Pre-migration summaries without expiry metadata expire after this window.
  static let legacySummaryTTL: TimeInterval = 12 * 3600

  init(
    locationID: UUID,
    topEvent: String,
    topSeverityLevel: Int,
    topIsWarning: Bool = false,
    topIsWatch: Bool = false,
    activeCount: Int,
    topExpires: Date? = nil,
    anyActiveUntil: Date? = nil,
    updatedAt: Date = Date()
  ) {
    self.locationID = locationID
    self.topEvent = topEvent
    self.topSeverityLevel = topSeverityLevel
    self.topIsWarning = topIsWarning
    self.topIsWatch = topIsWatch
    self.activeCount = activeCount
    self.topExpires = topExpires
    self.anyActiveUntil = anyActiveUntil
    self.updatedAt = updatedAt
  }

  /// True when at least one alert from the persisted batch is still active at `date`.
  func isActive(relativeTo date: Date = Date()) -> Bool {
    guard activeCount > 0 else { return false }
    if let anyActiveUntil, anyActiveUntil < date { return false }
    // Legacy summaries without expiry metadata expire after 12h from `updatedAt`.
    if anyActiveUntil == nil && topExpires == nil {
      if date.timeIntervalSince(updatedAt) > Self.legacySummaryTTL { return false }
    }
    return true
  }

  /// True when the top-severity alert's display text should refresh (e.g. show count fallback).
  func isTopEventExpired(relativeTo date: Date) -> Bool {
    guard let topExpires else { return false }
    return topExpires < date
  }

  /// Widget-facing alert label; falls back to count when the top alert has expired but others remain.
  func displayText(relativeTo date: Date) -> String {
    if isTopEventExpired(relativeTo: date), activeCount > 1 {
      return "\(activeCount) active alerts"
    }
    if activeCount > 1 {
      return "\(topEvent) +\(activeCount - 1)"
    }
    return topEvent
  }

  private enum CodingKeys: String, CodingKey {
    case locationID
    case topEvent
    case topSeverityLevel
    case topIsWarning
    case topIsWatch
    case activeCount
    case topExpires
    case anyActiveUntil
    case updatedAt
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    locationID = try container.decode(UUID.self, forKey: .locationID)
    topEvent = try container.decode(String.self, forKey: .topEvent)
    topSeverityLevel = try container.decode(Int.self, forKey: .topSeverityLevel)
    topIsWarning = try container.decodeIfPresent(Bool.self, forKey: .topIsWarning) ?? false
    topIsWatch = try container.decodeIfPresent(Bool.self, forKey: .topIsWatch) ?? false
    activeCount = try container.decode(Int.self, forKey: .activeCount)
    topExpires = try container.decodeIfPresent(Date.self, forKey: .topExpires)
    anyActiveUntil =
      try container.decodeIfPresent(Date.self, forKey: .anyActiveUntil) ?? topExpires
    updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(locationID, forKey: .locationID)
    try container.encode(topEvent, forKey: .topEvent)
    try container.encode(topSeverityLevel, forKey: .topSeverityLevel)
    try container.encode(topIsWarning, forKey: .topIsWarning)
    try container.encode(topIsWatch, forKey: .topIsWatch)
    try container.encode(activeCount, forKey: .activeCount)
    try container.encodeIfPresent(topExpires, forKey: .topExpires)
    try container.encodeIfPresent(anyActiveUntil, forKey: .anyActiveUntil)
    try container.encode(updatedAt, forKey: .updatedAt)
  }

  static var preview: WidgetAlertSummary {
    let warningExpires = Calendar.current.date(byAdding: .hour, value: 2, to: Date())
    let advisoryExpires = Calendar.current.date(byAdding: .hour, value: 4, to: Date())
    return WidgetAlertSummary(
      locationID: SavedLocation.oliveBranch.id,
      topEvent: "Severe Thunderstorm Warning",
      topSeverityLevel: 3,
      topIsWarning: true,
      activeCount: 2,
      topExpires: warningExpires,
      anyActiveUntil: advisoryExpires
    )
  }
}
