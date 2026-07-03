import Foundation

/// “Go outside” index — 0–100 derived from comfort, precip, wind, UV, AQI, and alerts.
struct GrokCastScore: Equatable {
  let value: Int
  let label: String
  let subtitle: String
  let icon: String

  var accentTier: ScoreTier {
    switch value {
    case 75...: .great
    case 50..<75: .okay
    default: .poor
    }
  }

  enum ScoreTier {
    case great, okay, poor
  }
}

enum GrokCastScoreCalculator {
  static func score(
    for weather: GrokCastWeather,
    alerts: [NWSAlert],
    units: TemperatureUnit = .fahrenheit
  ) -> GrokCastScore {
    var points = 72.0

    let temp = weather.feelsLike
    switch units {
    case .fahrenheit:
      if (62...78).contains(temp) { points += 14 }
      else if (50...85).contains(temp) { points += 6 }
      else if temp < 32 || temp > 95 { points -= 22 }
      else { points -= 12 }
    case .celsius:
      if (17...26).contains(temp) { points += 14 }
      else if (10...29).contains(temp) { points += 6 }
      else if temp < 0 || temp > 35 { points -= 22 }
      else { points -= 12 }
    }

    if weather.precipitationChance < 15 { points += 10 }
    else if weather.precipitationChance > 60 { points -= 26 }
    else if weather.precipitationChance > 30 { points -= 12 }

    switch units {
    case .fahrenheit:
      if weather.windSpeed > 25 { points -= 16 }
      else if weather.windSpeed > 15 { points -= 6 }
    case .celsius:
      if weather.windSpeed > 40 { points -= 16 }
      else if weather.windSpeed > 24 { points -= 6 }
    }

    if weather.uvIndex > 8 { points -= 10 }
    else if weather.uvIndex > 5 { points -= 4 }

    if let aqi = weather.airQualityIndex {
      if aqi > 150 { points -= 18 }
      else if aqi > 100 { points -= 10 }
    }

    let active = alerts.filter { !$0.isExpired }
    for alert in active {
      points -= Double(min(alert.severityLevel, 4)) * 5
    }

    let value = max(0, min(100, Int(points.rounded())))

    let label: String
    let subtitle: String
    let icon: String
    switch value {
    case 80...:
      label = "Go Outside"
      subtitle = "Great conditions for being out"
      icon = "figure.walk"
    case 60..<80:
      label = "Pretty Good"
      subtitle = "Fine for most outdoor plans"
      icon = "sun.max.fill"
    case 40..<60:
      label = "Mixed Bag"
      subtitle = "Check the details before heading out"
      icon = "cloud.sun.fill"
    default:
      label = "Stay Cozy"
      subtitle = "Weather or alerts suggest staying in"
      icon = "house.fill"
    }

    return GrokCastScore(value: value, label: label, subtitle: subtitle, icon: icon)
  }
}
