import ActivityKit
import Foundation

struct WeatherLiveActivityAttributes: ActivityAttributes {
  /// Which Lock Screen / Dynamic Island presentation to use.
  /// Priority when building: severeAlert > radarEvent > standard.
  enum Variant: String, Codable, Hashable {
    case standard
    case severeAlert
    case radarEvent
  }

  struct ContentState: Codable, Hashable {
    var locationName: String
    var temperatureText: String
    var conditionText: String
    /// Kept on the ActivityKit payload for in-flight decode. Glance chrome
    /// does not lead with Score — see `WeatherLiveActivityChrome`.
    var score: Int
    var scoreLabel: String
    var minutecastMessage: String
    var symbolName: String
    /// Presentation mode. Defaults to `.standard` for older in-flight activities.
    var variant: Variant
    /// Primary event line (e.g. "Tornado Warning" or "Rain Starting Soon").
    var headline: String?
    /// Secondary line (expires text, Minutecast message).
    var detail: String?
    /// NWS severity 0–4 for tinting (0 when not an alert).
    var severityLevel: Int

    init(
      locationName: String,
      temperatureText: String,
      conditionText: String,
      score: Int,
      scoreLabel: String,
      minutecastMessage: String,
      symbolName: String,
      variant: Variant = .standard,
      headline: String? = nil,
      detail: String? = nil,
      severityLevel: Int = 0
    ) {
      self.locationName = locationName
      self.temperatureText = temperatureText
      self.conditionText = conditionText
      self.score = score
      self.scoreLabel = scoreLabel
      self.minutecastMessage = minutecastMessage
      self.symbolName = symbolName
      self.variant = variant
      self.headline = headline
      self.detail = detail
      self.severityLevel = severityLevel
    }
  }
}

/// Lock Screen / Dynamic Island copy. Score stays on `ContentState` for
/// ActivityKit decode; these helpers prefer condition, alerts, and Next 2 Hours.
enum WeatherLiveActivityChrome {
  static func compactTrailingText(
    for state: WeatherLiveActivityAttributes.ContentState
  ) -> String {
    switch state.variant {
    case .severeAlert:
      return "!"
    case .radarEvent, .standard:
      return state.temperatureText
    }
  }

  static func lockScreenPrimary(
    for state: WeatherLiveActivityAttributes.ContentState
  ) -> String {
    switch state.variant {
    case .severeAlert:
      return state.headline ?? "Severe Weather"
    case .radarEvent:
      return state.headline ?? "Radar"
    case .standard:
      return state.conditionText
    }
  }

  static func lockScreenSecondary(
    for state: WeatherLiveActivityAttributes.ContentState
  ) -> String? {
    switch state.variant {
    case .severeAlert:
      return nonempty(state.detail)
    case .radarEvent:
      return nonempty(state.detail) ?? nonempty(state.minutecastMessage)
    case .standard:
      return nonempty(state.minutecastMessage)
    }
  }

  static func expandedPrimary(
    for state: WeatherLiveActivityAttributes.ContentState
  ) -> String {
    switch state.variant {
    case .severeAlert:
      return state.headline ?? "Severe Weather"
    case .radarEvent:
      return nonempty(state.detail) ?? state.minutecastMessage
    case .standard:
      return state.conditionText
    }
  }

  static func expandedSecondary(
    for state: WeatherLiveActivityAttributes.ContentState
  ) -> String? {
    switch state.variant {
    case .severeAlert:
      return nonempty(state.detail) ?? nonempty(state.minutecastMessage)
    case .radarEvent:
      return nil
    case .standard:
      return nonempty(state.minutecastMessage)
    }
  }

  private static func nonempty(_ value: String?) -> String? {
    guard let value else { return nil }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
}
