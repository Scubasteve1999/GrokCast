import Foundation

// MARK: - SPC / severe-weather snapshot (immutable; owned by SevereWeatherStore)

/// SPC Day-1 categorical risk at a point (dn ladder from SPC categorical outlook).
enum SPCOutlookCategory: Int, Codable, Equatable, Hashable, Comparable, Sendable {
  case none = 0
  case generalThunderstorm = 2
  case marginal = 3
  case slight = 4
  case enhanced = 5
  case moderate = 6
  case high = 8

  static func < (lhs: SPCOutlookCategory, rhs: SPCOutlookCategory) -> Bool {
    lhs.rawValue < rhs.rawValue
  }

  init(dn: Int?) {
    guard let dn, let value = SPCOutlookCategory(rawValue: dn) else {
      self = .none
      return
    }
    self = value
  }

  var displayName: String {
    switch self {
    case .none: "None"
    case .generalThunderstorm: "Thunderstorm"
    case .marginal: "Marginal"
    case .slight: "Slight"
    case .enhanced: "Enhanced"
    case .moderate: "Moderate"
    case .high: "High"
    }
  }

  /// Short SPC-style label (TSTM / MRGL / SLGT / …).
  var shortLabel: String {
    switch self {
    case .none: "NONE"
    case .generalThunderstorm: "TSTM"
    case .marginal: "MRGL"
    case .slight: "SLGT"
    case .enhanced: "ENH"
    case .moderate: "MDT"
    case .high: "HIGH"
    }
  }
}

struct SPCDay1Outlook: Codable, Equatable, Hashable, Sendable {
  let category: SPCOutlookCategory
  let label: String?
  let labelDetail: String?
  let valid: String?
  let expire: String?
  let issue: String?
  /// Highest intersecting probabilistic tornado outlook (percent), if any.
  let tornadoProbability: Int?
  let hailProbability: Int?
  let windProbability: Int?

  static let empty = SPCDay1Outlook(
    category: .none,
    label: nil,
    labelDetail: nil,
    valid: nil,
    expire: nil,
    issue: nil,
    tornadoProbability: nil,
    hailProbability: nil,
    windProbability: nil
  )

  var isMeaningful: Bool {
    category != .none
  }

  var summaryLine: String {
    var parts = ["Day 1 \(category.displayName)"]
    if let t = tornadoProbability { parts.append("TOR \(t)%") }
    if let h = hailProbability { parts.append("HAIL \(h)%") }
    if let w = windProbability { parts.append("WIND \(w)%") }
    return parts.joined(separator: " · ")
  }
}

struct SPCMesoscaleDiscussion: Identifiable, Codable, Equatable, Hashable, Sendable {
  let id: String
  let number: String
  let info: String?
  let linkHTML: String?

  var title: String {
    var trimmed = number.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.uppercased().hasPrefix("MD") {
      trimmed = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    return trimmed.isEmpty ? "Mesoscale Discussion" : "MD \(trimmed)"
  }

  var detailLine: String? {
    guard let info, !info.isEmpty else { return nil }
    return info
  }
}

struct SPCLocalStormReport: Identifiable, Codable, Equatable, Hashable, Sendable {
  let id: String
  let description: String
  let locationDescription: String?
  let state: String?
  let magnitude: String?
  let units: String?
  let remarks: String?
  let reportedAt: Date?
  let latitude: Double?
  let longitude: Double?

  var title: String {
    let desc = description.trimmingCharacters(in: .whitespacesAndNewlines)
    return desc.isEmpty ? "Storm Report" : desc
  }

  var subtitle: String {
    var parts: [String] = []
    if let loc = locationDescription, !loc.isEmpty {
      if let state, !state.isEmpty {
        parts.append("\(loc), \(state)")
      } else {
        parts.append(loc)
      }
    } else if let state, !state.isEmpty {
      parts.append(state)
    }
    if let magnitude, !magnitude.isEmpty {
      if let units, !units.isEmpty {
        parts.append("\(magnitude) \(units)")
      } else {
        parts.append(magnitude)
      }
    }
    return parts.joined(separator: " · ")
  }
}

/// Immutable severe-weather snapshot for a selected location.
struct SevereWeatherContext: Codable, Equatable, Sendable {
  let locationID: String
  let fetchedAt: Date
  let day1Outlook: SPCDay1Outlook
  let mesoscaleDiscussions: [SPCMesoscaleDiscussion]
  let localStormReports: [SPCLocalStormReport]
  /// CAP alerts for this point, with soft polygon context when available.
  let alerts: [NWSAlert]

  static func empty(locationID: String = "", fetchedAt: Date = Date()) -> SevereWeatherContext {
    SevereWeatherContext(
      locationID: locationID,
      fetchedAt: fetchedAt,
      day1Outlook: .empty,
      mesoscaleDiscussions: [],
      localStormReports: [],
      alerts: []
    )
  }

  var hasSPCContent: Bool {
    day1Outlook.isMeaningful
      || !mesoscaleDiscussions.isEmpty
      || !localStormReports.isEmpty
  }

  var hasContent: Bool {
    hasSPCContent || !alerts.isEmpty
  }

  /// Outlook ≥ Slight, or any MD, or any Watch/Warning alert.
  var shouldShowTodayCard: Bool {
    if day1Outlook.category >= .slight { return true }
    if !mesoscaleDiscussions.isEmpty { return true }
    return alerts.contains { $0.isSevereEvent && !$0.isExpired }
  }
}
