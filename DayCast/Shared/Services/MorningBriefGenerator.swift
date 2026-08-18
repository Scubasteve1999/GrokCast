import Foundation

/// Shared UserDefaults cache for Grok's Take / morning brief so Today + notifications stay aligned.
@MainActor
enum GrokBriefCache {
  /// Coarse temp banding for cache identity (same token → same brief still valid).
  static let tempMismatchThreshold: Double = 8

  static func key(for store: WeatherStore) -> String? {
    guard let loc = store.currentLocation else { return nil }
    let day = Calendar.current.startOfDay(for: Date()).timeIntervalSince1970
    return "grok_brief_\(loc.id.uuidString)_\(Int(day))"
  }

  /// Identity token shared by `.task(id:)` and cache validation — only changes when
  /// the brief should be regenerated (condition change or ~8° temp band change).
  static func refreshToken(for store: WeatherStore) -> String {
    guard let weather = store.currentWeather else { return "pending" }
    let tempBucket = Int((weather.currentTemp / tempMismatchThreshold).rounded())
    return "\(tempBucket)_\(weather.conditionCode)"
  }

  private static func tokenKey(for cacheKey: String) -> String {
    cacheKey + "_wx"
  }

  /// Returns cached brief only if live weather still matches the token stored at save time.
  static func loadValidBrief(for store: WeatherStore) -> String? {
    guard let key = key(for: store),
      let text = UserDefaults.standard.string(forKey: key)
    else { return nil }

    guard store.currentWeather != nil else { return text }

    let savedToken = UserDefaults.standard.string(forKey: tokenKey(for: key))
    // Legacy entries without a weather token — force refresh against live conditions.
    guard let savedToken, savedToken == refreshToken(for: store) else { return nil }

    return GrokBriefText.visible(text)
  }

  static func save(_ text: String, for store: WeatherStore) {
    guard let key = key(for: store) else { return }
    UserDefaults.standard.set(text, forKey: key)
    UserDefaults.standard.set(refreshToken(for: store), forKey: tokenKey(for: key))
  }

  static func clear(for store: WeatherStore) {
    guard let key = key(for: store) else { return }
    UserDefaults.standard.removeObject(forKey: key)
    UserDefaults.standard.removeObject(forKey: tokenKey(for: key))
  }
}

/// A deterministic, forecast-only brief used when Grok completes without any text.
/// Keeping this separate from the AI prompt makes the fallback honest, useful, and testable.
enum LocalWeatherBrief {
  /// Deterministic alert copy when Grok's summary is blocked by the 4.7 filter.
  static func alertsSummary(locationName: String, alerts: [NWSAlert]) -> String {
    let events = alerts.prefix(5).map(\.event)
    guard !events.isEmpty else {
      return "No active alerts to summarize for \(locationName)."
    }
    let list = events.joined(separator: ", ")
    let noun = events.count == 1 ? "alert is" : "alerts are"
    return
      "Official take: \(events.count) active \(noun) in effect for \(locationName), including \(list). Check the Alerts tab and follow NWS guidance."
  }

  static func make(
    weather: DayCastWeather,
    unit: TemperatureUnit,
    locationName: String,
    activeAlerts: [String],
    now: Date = Date()
  ) -> String {
    let current =
      "\(locationName) is \(unit.format(weather.currentTemp)) and \(weather.conditionText.lowercased()), with a high of \(unit.formatShort(weather.high)) and low of \(unit.formatShort(weather.low))."

    let outfit = outfitGuidance(
      feelsLike: weather.feelsLike,
      unit: unit,
      uvIndex: weather.uvIndex,
      windSpeed: weather.windSpeed
    )

    if !activeAlerts.isEmpty {
      let alertList = activeAlerts.prefix(2).joined(separator: " and ")
      return
        "\(current) \(outfit) Active alerts include \(alertList); check the Alerts tab and follow local guidance."
    }

    guard let window = driestWindow(in: weather.hourly, now: now) else {
      return "\(current) \(outfit) Rain chance is currently \(weather.precipitationChance)%."
    }

    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = weather.locationTimeZone
    formatter.dateFormat = "h a"
    let start = formatter.string(from: window.start)
    let end = formatter.string(from: window.end)
    let timing: String
    if window.maxPrecipChance <= 20 {
      timing =
        "The driest outdoor window is \(start)–\(end), with rain odds staying at \(window.maxPrecipChance)% or lower."
    } else {
      timing =
        "The least-wet outdoor window is \(start)–\(end), though rain odds still reach \(window.maxPrecipChance)%."
    }
    return "\(current) \(outfit) \(timing)"
  }

  private struct OutdoorWindow {
    let start: Date
    let end: Date
    let maxPrecipChance: Int
  }

  private static func driestWindow(in hourly: [HourlyForecast], now: Date) -> OutdoorWindow? {
    let upcoming = Array(hourly.filter { $0.time >= now }.prefix(12))
    guard upcoming.count >= 3 else { return nil }

    let windows = (0...(upcoming.count - 3)).map { index in
      Array(upcoming[index...(index + 2)])
    }
    let daylightWindows = windows.filter { window in
      window.allSatisfy { $0.isDay != false }
    }
    let candidates = daylightWindows.isEmpty ? windows : daylightWindows
    guard
      let best = candidates.min(by: { lhs, rhs in
        let lhsMax = lhs.map(\.precipChance).max() ?? 100
        let rhsMax = rhs.map(\.precipChance).max() ?? 100
        return lhsMax == rhsMax ? lhs[0].time < rhs[0].time : lhsMax < rhsMax
      })
    else { return nil }

    return OutdoorWindow(
      start: best[0].time,
      end: best[2].time.addingTimeInterval(60 * 60),
      maxPrecipChance: best.map(\.precipChance).max() ?? 0
    )
  }

  private static func outfitGuidance(
    feelsLike: Double,
    unit: TemperatureUnit,
    uvIndex: Double,
    windSpeed: Double
  ) -> String {
    let feelsLikeFahrenheit =
      unit == .fahrenheit ? feelsLike : (feelsLike * 9 / 5) + 32
    var guidance: String
    switch feelsLikeFahrenheit {
    case ..<40:
      guidance = "Bundle up with a warm outer layer."
    case ..<55:
      guidance = "A jacket or warm layer will help."
    case ..<70:
      guidance = "A light layer should be comfortable."
    case ..<85:
      guidance = "Comfortable, breathable layers should work well."
    default:
      guidance = "Dress light and bring water."
    }

    if uvIndex >= 6 {
      guidance += " Add sun protection."
    }
    if windSpeed >= (unit == .fahrenheit ? 25 : 40) {
      guidance += " Expect gusty conditions."
    }
    return guidance
  }
}

@MainActor
enum MorningBriefGenerator {

  static func generateIfStale(weatherStore: WeatherStore) async {
    guard !GrokBriefSafety.shared.isFeatureHidden else { return }
    guard MorningBriefNotificationService.persistedEnabled else { return }
    guard GrokAuthResolver.canAccessGrok(subscription: SubscriptionManager.shared) else { return }

    if GrokBriefCache.loadValidBrief(for: weatherStore) != nil { return }

    guard let weather = weatherStore.currentWeather else { return }

    let location = weatherStore.currentLocation?.name ?? weather.location.name
    let unit = weatherStore.temperatureUnit
    let alerts = weatherStore.displayableActiveAlerts.prefix(3).map(\.event)
      .joined(separator: ", ")
    let locationKey = weatherStore.currentLocation?.id.uuidString
    let severe = SevereWeatherStore.shared.context
    let severeBlock: String = {
      guard severe.locationID == locationKey,
        let block = GrokPrompts.severeContextBlock(context: severe)
      else { return "" }
      return "\n\(block)"
    }()
    let shortTerm = ShortTermPrecipStore.shared.context
    let shortTermBlock: String = {
      guard shortTerm.locationID == locationKey,
        let block = GrokPrompts.shortTermPrecipBlock(
          context: shortTerm,
          openMeteoSlots: weather.minutely15
        )
      else { return "" }
      return "\n\(block)"
    }()

    let system = """
      You are a helpful weather assistant inside DayCast. Write a practical 2–4 sentence weather brief for \(location).
      Current: \(unit.format(weather.currentTemp)), feels \(unit.format(weather.feelsLike)), \(weather.conditionText).
      Today high/low: \(unit.formatShort(weather.high)) / \(unit.formatShort(weather.low)).
      Precip chance now: \(weather.precipitationChance)%.
      Active alerts: \(alerts.isEmpty ? "none" : alerts).\(severeBlock)\(shortTermBlock)
      Include outfit hint, best outdoor window, and anything worth watching. No markdown, no hashtags. Do not use internal labels such as "Forecast-only take", "SEVERE CONTEXT", or MD numbers.
      """

    do {
      let auth = try GrokAuthResolver.resolve(
        for: .chat, feature: .morningBrief, subscription: SubscriptionManager.shared)
      let config = GrokBuildConfiguration(auth: auth)
      let messages = [
        GrokBuildMessage(role: "system", content: system),
        GrokBuildMessage(role: "user", content: "Give me today's weather take."),
      ]

      var result = ""
      for try await token in GrokBuildService(configuration: config).streamChat(
        messages: messages, auth: auth)
      {
        result += token
      }

      let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
      let raw =
        trimmed.isEmpty
        ? LocalWeatherBrief.make(
          weather: weather,
          unit: unit,
          locationName: location,
          activeAlerts: weatherStore.displayableActiveAlerts.prefix(3).map(\.event)
        )
        : trimmed
      guard
        let brief = GrokBriefText.finalize(
          raw: raw,
          weather: weather,
          unit: unit,
          locationName: location,
          activeAlerts: weatherStore.displayableActiveAlerts.prefix(3).map(\.event)
        ),
        !GrokBriefSafety.shared.isBriefHidden(brief)
      else { return }

      GrokBriefCache.save(brief, for: weatherStore)

      let content = MorningBriefContent(
        briefBody: brief,
        locationName: location,
        temperature: unit.format(weather.currentTemp),
        condition: weather.conditionText
      )
      await MorningBriefNotificationService.scheduleIfEnabled(content: content)
      print("[MorningBrief] Generated fresh brief (\(brief.count) chars)")
    } catch {
      print("[MorningBrief] Generation failed (non-fatal): \(error.localizedDescription)")
    }
  }
}
