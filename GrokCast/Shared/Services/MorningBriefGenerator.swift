import Foundation

/// Shared UserDefaults cache for Grok's Take / morning brief so Today + notifications stay aligned.
@MainActor
enum GrokBriefCache {
  /// Discard cached copy when live temp diverges this much from the temp at write time.
  static let tempMismatchThreshold: Double = 8

  static func key(for store: WeatherStore) -> String? {
    guard let loc = store.currentLocation else { return nil }
    let day = Calendar.current.startOfDay(for: Date()).timeIntervalSince1970
    return "grok_brief_\(loc.id.uuidString)_\(Int(day))"
  }

  private static func tempKey(for cacheKey: String) -> String {
    cacheKey + "_temp"
  }

  /// Returns cached brief only if it still matches today's live weather within threshold.
  static func loadValidBrief(for store: WeatherStore) -> String? {
    guard let key = key(for: store),
      let text = UserDefaults.standard.string(forKey: key)
    else { return nil }

    if let cachedTemp = UserDefaults.standard.object(forKey: tempKey(for: key)) as? Double,
      let current = store.currentWeather?.currentTemp,
      abs(current - cachedTemp) > tempMismatchThreshold
    {
      return nil
    }
    return text
  }

  static func save(_ text: String, for store: WeatherStore) {
    guard let key = key(for: store) else { return }
    UserDefaults.standard.set(text, forKey: key)
    if let temp = store.currentWeather?.currentTemp {
      UserDefaults.standard.set(temp, forKey: tempKey(for: key))
    }
  }
}

@MainActor
enum MorningBriefGenerator {

  static func generateIfStale(weatherStore: WeatherStore) async {
    guard MorningBriefNotificationService.persistedEnabled else { return }
    guard GrokAuthResolver.canAccessGrok(subscription: SubscriptionManager.shared) else { return }

    if GrokBriefCache.loadValidBrief(for: weatherStore) != nil { return }

    guard let weather = weatherStore.currentWeather else { return }

    let location = weatherStore.currentLocation?.name ?? weather.location.name
    let unit = weatherStore.temperatureUnit
    let alerts = weatherStore.displayableActiveAlerts.prefix(3).map(\.event)
      .joined(separator: ", ")

    let system = """
      You are a helpful weather assistant inside SpotterCast. Write a practical 2–4 sentence weather brief for \(location).
      Current: \(unit.format(weather.currentTemp)), feels \(unit.format(weather.feelsLike)), \(weather.conditionText).
      Today high/low: \(unit.formatShort(weather.high)) / \(unit.formatShort(weather.low)).
      Precip chance now: \(weather.precipitationChance)%.
      Active alerts: \(alerts.isEmpty ? "none" : alerts).
      Include outfit hint, best outdoor window, and anything worth watching. No markdown, no hashtags.
      """

    do {
      let auth = try GrokAuthResolver.resolve(subscription: SubscriptionManager.shared)
      let config = GrokBuildConfiguration(auth: auth)
      let messages = [
        GrokBuildMessage(role: "system", content: system),
        GrokBuildMessage(role: "user", content: "Give me Grok's take on today's weather."),
      ]

      var result = ""
      for try await token in GrokBuildService(configuration: config).streamChat(
        messages: messages, auth: auth)
      {
        result += token
      }

      let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmed.isEmpty else { return }

      GrokBriefCache.save(trimmed, for: weatherStore)

      let content = MorningBriefContent(
        briefBody: trimmed,
        locationName: location,
        temperature: unit.format(weather.currentTemp),
        condition: weather.conditionText
      )
      await MorningBriefNotificationService.scheduleIfEnabled(content: content)
      print("[MorningBrief] Generated fresh AI brief (\(trimmed.count) chars)")
    } catch {
      print("[MorningBrief] Generation failed (non-fatal): \(error.localizedDescription)")
    }
  }
}
