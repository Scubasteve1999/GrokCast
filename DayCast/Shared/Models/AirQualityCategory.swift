import SwiftUI

/// US AQI category + one-line health guidance (Open-Meteo `us_aqi`).
enum AirQualityCategory: Equatable, Sendable {
  case good
  case moderate
  case unhealthySensitive
  case unhealthy
  case veryUnhealthy
  case hazardous

  init(usAQI: Int) {
    switch usAQI {
    case ...50: self = .good
    case 51...100: self = .moderate
    case 101...150: self = .unhealthySensitive
    case 151...200: self = .unhealthy
    case 201...300: self = .veryUnhealthy
    default: self = .hazardous
    }
  }

  var title: String {
    switch self {
    case .good: "Good"
    case .moderate: "Moderate"
    case .unhealthySensitive: "Unhealthy for Sensitive Groups"
    case .unhealthy: "Unhealthy"
    case .veryUnhealthy: "Very Unhealthy"
    case .hazardous: "Hazardous"
    }
  }

  var guidance: String {
    switch self {
    case .good:
      return "Air quality is satisfactory for most people."
    case .moderate:
      return "Unusually sensitive people should consider limiting prolonged outdoor exertion."
    case .unhealthySensitive:
      return "Sensitive groups should reduce prolonged or heavy outdoor exertion."
    case .unhealthy:
      return "Everyone may begin to feel effects; sensitive groups should avoid outdoor exertion."
    case .veryUnhealthy:
      return "Health alert: avoid outdoor exertion; keep outdoor activity short."
    case .hazardous:
      return "Emergency conditions — remain indoors and follow local guidance."
    }
  }

  var color: Color {
    switch self {
    case .good: DesignTokens.Palette.success
    case .moderate: DesignTokens.Palette.warning
    case .unhealthySensitive: DesignTokens.Palette.accentWarm
    case .unhealthy: DesignTokens.Palette.danger
    case .veryUnhealthy: Color(hex: "#9F1239")
    case .hazardous: Color(hex: "#7F1D1D")
    }
  }
}
