import Foundation

enum UVCategory: Equatable, Sendable {
  case low
  case moderate
  case high
  case veryHigh
  case extreme

  init(index: Double) {
    switch index {
    case ..<3: self = .low
    case ..<6: self = .moderate
    case ..<8: self = .high
    case ..<11: self = .veryHigh
    default: self = .extreme
    }
  }

  var title: String {
    switch self {
    case .low: "Low"
    case .moderate: "Moderate"
    case .high: "High"
    case .veryHigh: "Very High"
    case .extreme: "Extreme"
    }
  }
}

enum HourlyDetailMetrics {
  static let unknown = "—"

  struct Row: Equatable, Identifiable {
    let label: String
    let value: String
    var id: String { label }
  }

  /// Selected-hour facts. Missing provider fields stay `—` rather than invented numbers.
  static func rows(hour: HourlyForecast, unit: TemperatureUnit) -> [Row] {
    [
      Row(label: "Temp", value: unit.formatShort(hour.temp)),
      Row(label: "Feels", value: hour.feelsLike.map(unit.formatShort) ?? unknown),
      Row(label: "Precip", value: precipValue(hour)),
      Row(label: "Wind", value: windValue(hour, unit: unit)),
      Row(label: "Humidity", value: hour.humidity.map { "\($0)%" } ?? unknown),
      Row(label: "UV", value: hour.uvIndex.map { "\(Int(round($0)))" } ?? unknown),
      Row(label: "Visibility", value: visibilityValue(hour.visibilityMeters, unit: unit)),
      Row(label: "Pressure", value: pressureValue(hour.pressureHPa, unit: unit)),
      Row(label: "Clouds", value: hour.cloudCoverPercent.map { "\($0)%" } ?? unknown),
    ]
  }

  static func accessibilityLabel(hour: HourlyForecast, unit: TemperatureUnit) -> String {
    rows(hour: hour, unit: unit)
      .map { "\($0.label) \($0.value)" }
      .joined(separator: ", ")
  }

  private static func precipValue(_ hour: HourlyForecast) -> String {
    if let amount = precipAmountText(liquid: hour.liquidPrecip, snow: hour.snowfall ?? 0) {
      return "\(hour.precipChance)% \(amount)"
    }
    return "\(hour.precipChance)%"
  }

  private static func windValue(_ hour: HourlyForecast, unit: TemperatureUnit) -> String {
    guard let speed = hour.windSpeed else { return unknown }
    let speedText = unit.formatWind(speed)
    guard let degrees = hour.windDirection else { return speedText }
    return "\(speedText) \(compassAbbr(degrees))"
  }

  static func visibilityValue(_ meters: Double?, unit: TemperatureUnit) -> String {
    guard let meters else { return unknown }
    switch unit {
    case .fahrenheit:
      let miles = meters / 1609.34
      if miles >= 10 { return "\(Int(round(miles))) mi" }
      return String(format: "%.1f mi", miles)
    case .celsius:
      let km = meters / 1000
      if km >= 10 { return "\(Int(round(km))) km" }
      return String(format: "%.1f km", km)
    }
  }

  static func pressureValue(_ hPa: Double?, unit: TemperatureUnit) -> String {
    guard let hPa else { return unknown }
    switch unit {
    case .fahrenheit:
      return String(format: "%.2f inHg", hPa * 0.02953)
    case .celsius:
      return "\(Int(round(hPa))) hPa"
    }
  }

  static func compassAbbr(_ degrees: Int) -> String {
    let dirs = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
    let index = Int((Double(degrees % 360) / 45.0).rounded()) % dirs.count
    return dirs[index]
  }
}

enum PrecipOutlookCopy {
  static let title = "Next 2 Hours"

  /// Type-on-photo rain line. Timing when wet; chance when dry. Never MinuteCast.
  static func heroLine(summary: MinutecastSummary, rainChance: Int) -> String {
    switch summary.kind {
    case .clear:
      return "\(title) rain chance \(max(0, rainChance))%"
    case .startsSoon, .ongoing, .stoppingSoon:
      return summary.message
    }
  }

  /// VoiceOver for next-hour timing. Product name is “Next 2 Hours”, not Minutecast.
  static func stripAccessibilityLabel(
    message: String,
    disagreementCaption: String? = nil
  ) -> String {
    let caption = disagreementCaption?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if caption.isEmpty {
      return "\(title). \(message)"
    }
    return "\(title). \(message). \(caption)"
  }
}

enum PrecipFeedVisibility {
  /// Wet Next 2 Hours content. Drives story-day radar teaser copy, not feed order.
  static func hasContent(summary: MinutecastSummary) -> Bool {
    switch summary.kind {
    case .clear:
      return false
    case .startsSoon, .ongoing, .stoppingSoon:
      return true
    }
  }
}

/// Open-Meteo current can stay Clear while HRRR/minutecast is already wet.
/// Rain now owns the hero face. Rain later stays on the Next 2 Hours line.
enum NowHeroReconcile {
  struct Face: Equatable {
    let conditionText: String
    let symbolName: String
  }

  static func face(
    conditionCode: Int,
    conditionText: String,
    symbolName: String,
    summary: MinutecastSummary
  ) -> Face {
    let wmo = WeatherCondition(fromWMO: conditionCode)
    if wmo.isPrecipitating {
      return Face(conditionText: conditionText, symbolName: symbolName)
    }
    switch summary.kind {
    case .ongoing, .stoppingSoon:
      return Face(conditionText: WeatherCondition.rain.displayText, symbolName: summary.icon)
    case .clear, .startsSoon:
      return Face(conditionText: conditionText, symbolName: symbolName)
    }
  }

  static func isNowWet(conditionCode: Int, summary: MinutecastSummary) -> Bool {
    if WeatherCondition(fromWMO: conditionCode).isPrecipitating {
      return true
    }
    switch summary.kind {
    case .ongoing, .stoppingSoon:
      return true
    case .clear, .startsSoon:
      return false
    }
  }
}

enum ConditionsCopy {
  static let title = "Conditions"

  static func humiditySupport(_ humidity: Int) -> String {
    switch humidity {
    case ..<30: "Dry"
    case ..<60: "Moderate"
    default: "High"
    }
  }

  static func precipTile(
    weather: DayCastWeather,
    unit: TemperatureUnit,
    now: Date = Date()
  ) -> (value: String, support: String) {
    let hourAgo = now.addingTimeInterval(-3600)
    let amount = weather.minutely15
      .filter { $0.time >= hourAgo && $0.time <= now }
      .reduce(0.0) { $0 + $1.precipitation }
    if amount >= 0.01 {
      let value =
        unit == .fahrenheit
        ? String(format: "%.2f in", amount)
        : String(format: "%.1f mm", amount)
      return (value, "Over the last hour")
    }
    if amount > 0 {
      return ("Trace", "Over the last hour")
    }
    return ("\(weather.precipitationChance)%", "Chance")
  }
}
