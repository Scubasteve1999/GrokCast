import Foundation

/// One-line “what should I do now?” under Today’s Now card. Template only — no Grok.
enum WeatherDecision {
  struct Result: Equatable {
    let sentence: String
  }

  static let maxCharacterCount = 140

  static func make(
    weather: DayCastWeather,
    unit: TemperatureUnit,
    alerts: [NWSAlert],
    minutecast: MinutecastSummary? = nil,
    now: Date = Date()
  ) -> Result {
    let grouped = NWSAlertGrouping.representatives(from: alerts)
    let raw = sentence(
      weather: weather,
      unit: unit,
      alerts: grouped,
      minutecast: minutecast
    )
    let isOfficialAlert = grouped.contains { $0.isLifeThreatening || $0.isWarning || $0.isWatch }
    if isOfficialAlert {
      if let screened = GrokContentFilter.acceptedText(
        raw, maxCharacterCount: GrokContentFilter.maxCharacterCount)
      {
        return Result(sentence: screened)
      }
      return Result(sentence: officialAlertFallback(alerts: grouped))
    }
    let screened =
      GrokContentFilter.acceptedText(raw, maxCharacterCount: maxCharacterCount)
      ?? fallbackSentence(weather: weather, unit: unit)
    return Result(sentence: screened)
  }

  static func sentence(
    weather: DayCastWeather,
    unit: TemperatureUnit,
    alerts: [NWSAlert],
    minutecast: MinutecastSummary?
  ) -> String {
    if let warning = alerts.first(where: { $0.isLifeThreatening || $0.isWarning }) {
      return warningSentence(warning)
    }
    if let watch = alerts.first(where: { $0.isWatch }) {
      return watchSentence(watch)
    }
    if let minutecast, isActionablePrecip(minutecast) {
      return precipSentence(minutecast, weather: weather, unit: unit)
    }
    if let aqi = weather.airQualityIndex, aqi >= 151 {
      return
        "Air quality looks unhealthy — consider keeping outdoor time short."
    }
    if let aqi = weather.airQualityIndex, aqi >= 101 {
      return
        "Air quality may bother sensitive groups — consider taking it easy outside."
    }
    if let uv = weather.currentUVIndex, uv >= 8 {
      return "UV looks very high — consider strong sun protection if you head out."
    }
    if weather.pollenLevel == "High" || weather.pollen?.category == "High" {
      return "Pollen looks high — sensitive groups may want to limit long outdoor time."
    }
    return conditionActionSentence(weather: weather, unit: unit)
  }

  // MARK: - Alerts

  private static func warningSentence(_ alert: NWSAlert) -> String {
    if let action = firstAction(alert) {
      return "\(alert.event) — \(action)"
    }
    return "\(alert.event) — follow NWS guidance now."
  }

  private static func watchSentence(_ alert: NWSAlert) -> String {
    if let action = firstAction(alert) {
      return "\(alert.event) — \(action)"
    }
    return "\(alert.event) — have a plan if conditions worsen."
  }

  private static func firstAction(_ alert: NWSAlert) -> String? {
    let body = AlertsActiveCopy.cardBody(
      event: alert.event,
      headline: alert.headline,
      instruction: alert.instruction,
      description: alert.description
    )
    guard let body, !body.isEmpty else { return nil }
    let first =
      body.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: true)
      .first
      .map(String.init)?
      .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if first.isEmpty { return nil }
    return first.hasSuffix(".") ? String(first.dropLast()) : first
  }

  // MARK: - Precip / conditions

  private static func isActionablePrecip(_ summary: MinutecastSummary) -> Bool {
    switch summary.kind {
    case .startsSoon, .ongoing, .stoppingSoon:
      return true
    case .clear:
      return false
    }
  }

  private static func precipSentence(
    _ summary: MinutecastSummary,
    weather: DayCastWeather,
    unit: TemperatureUnit
  ) -> String {
    let feelsF = feelsLikeFahrenheit(weather.feelsLike, unit: unit)
    switch summary.kind {
    case .startsSoon:
      if feelsF >= 50 {
        return "\(summary.message) — consider a rain layer."
      }
      return "\(summary.message) — consider a jacket."
    case .ongoing:
      return "\(summary.message) — stay dry if you can wait."
    case .stoppingSoon:
      return "\(summary.message) — holding off a few minutes may help."
    case .clear:
      return conditionActionSentence(weather: weather, unit: unit)
    }
  }

  static func conditionActionSentence(
    weather: DayCastWeather,
    unit: TemperatureUnit
  ) -> String {
    let feelsF = feelsLikeFahrenheit(weather.feelsLike, unit: unit)
    let humid = weather.humidity >= 60
    let uv = weather.currentUVIndex ?? 0
    let gusty =
      unit == .fahrenheit ? weather.windSpeed >= 25 : weather.windSpeed >= 40

    let condition: String
    let action: String
    switch feelsF {
    case ..<32:
      condition = "Bitter cold"
      action = "limit time outside and cover skin"
    case ..<45:
      condition = "Cold"
      action = "a warm layer should help"
    case ..<60:
      condition = humid ? "Cool and damp" : "Cool"
      action = "a light jacket should help"
    case ..<75:
      condition = humid ? "Mild and humid" : "Mild"
      action = "looks comfortable for being outside"
    case ..<85:
      condition = humid ? "Warm and humid" : "Warm"
      action = uv >= 6 ? "consider water and sun protection" : "consider bringing water"
    default:
      condition = humid ? "Hot and humid" : "Hot"
      action =
        uv >= 6
        ? "consider water, sun protection, and taking it easy"
        : "consider water and taking it easy"
    }

    var sentence = "\(condition) — \(action)."
    if gusty {
      sentence = String(sentence.dropLast()) + "; expect gusty wind."
    }
    return sentence
  }

  private static func officialAlertFallback(alerts: [NWSAlert]) -> String {
    if let warning = alerts.first(where: { $0.isLifeThreatening || $0.isWarning }) {
      return "\(warning.event) — follow NWS guidance now."
    }
    if let watch = alerts.first(where: { $0.isWatch }) {
      return "\(watch.event) — have a plan if conditions worsen."
    }
    return "Follow NWS guidance now."
  }

  private static func fallbackSentence(
    weather: DayCastWeather,
    unit: TemperatureUnit
  ) -> String {
    "\(weather.conditionText) — \(unit.formatShort(weather.feelsLike)) feels like."
  }

  private static func feelsLikeFahrenheit(_ value: Double, unit: TemperatureUnit) -> Double {
    unit == .fahrenheit ? value : (value * 9 / 5) + 32
  }
}
