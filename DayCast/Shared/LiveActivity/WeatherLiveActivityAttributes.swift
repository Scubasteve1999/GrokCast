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
