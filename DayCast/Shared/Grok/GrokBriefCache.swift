import Foundation

/// Shared UserDefaults cache for Today's Take / morning brief / widget one-liner.
@MainActor
enum GrokBriefCache {
  /// Coarse temp banding for cache identity (same token → same brief still valid).
  static let tempMismatchThreshold: Double = 8
  static let oneLinerMaxCharacters = 120

  /// Injectable for tests. Production uses `.standard`.
  static var defaults: UserDefaults = .standard

  static func key(locationID: UUID, now: Date = Date()) -> String {
    let day = Calendar.current.startOfDay(for: now).timeIntervalSince1970
    return "grok_brief_\(locationID.uuidString)_\(Int(day))"
  }

  static func key(for store: WeatherStore) -> String? {
    guard let loc = store.currentLocation else { return nil }
    return key(locationID: loc.id)
  }

  static func refreshToken(temp: Double, conditionCode: Int) -> String {
    let tempBucket = Int((temp / tempMismatchThreshold).rounded())
    return "\(tempBucket)_\(conditionCode)"
  }

  static func refreshToken(for weather: DayCastWeather) -> String {
    refreshToken(temp: weather.currentTemp, conditionCode: weather.conditionCode)
  }

  /// Identity token shared by `.task(id:)` and cache validation — only changes when
  /// the brief should be regenerated (condition change or ~8° temp band change).
  static func refreshToken(for store: WeatherStore) -> String {
    guard let weather = store.currentWeather else { return "pending" }
    return refreshToken(for: weather)
  }

  private static func tokenKey(for cacheKey: String) -> String {
    cacheKey + "_wx"
  }

  /// Returns cached brief only if live weather still matches the token stored at save time.
  static func loadValidBrief(
    locationID: UUID,
    weather: DayCastWeather?,
    now: Date = Date()
  ) -> String? {
    let cacheKey = key(locationID: locationID, now: now)
    guard let text = defaults.string(forKey: cacheKey) else { return nil }

    if let weather {
      let savedToken = defaults.string(forKey: tokenKey(for: cacheKey))
      // Legacy entries without a weather token — force refresh against live conditions.
      guard let savedToken, savedToken == refreshToken(for: weather) else { return nil }
    }

    return GrokContentFilter.acceptedText(GrokBriefText.visible(text))
  }

  static func loadValidBrief(for store: WeatherStore) -> String? {
    guard let loc = store.currentLocation else { return nil }
    return loadValidBrief(locationID: loc.id, weather: store.currentWeather)
  }

  /// Widget / Live Activity / notification one-liner — same weather-token rule as the full brief.
  static func loadValidOneLiner(
    locationID: UUID,
    weather: DayCastWeather?,
    now: Date = Date()
  ) -> String? {
    guard let text = loadValidBrief(locationID: locationID, weather: weather, now: now) else {
      return nil
    }
    return String(text.prefix(oneLinerMaxCharacters))
  }

  static func loadValidOneLiner(for store: WeatherStore) -> String? {
    guard let loc = store.currentLocation else { return nil }
    return loadValidOneLiner(locationID: loc.id, weather: store.currentWeather)
  }

  static func save(
    _ text: String,
    locationID: UUID,
    weather: DayCastWeather?,
    now: Date = Date()
  ) {
    let cacheKey = key(locationID: locationID, now: now)
    defaults.set(text, forKey: cacheKey)
    defaults.set(
      weather.map { refreshToken(for: $0) } ?? "pending",
      forKey: tokenKey(for: cacheKey)
    )
  }

  static func save(_ text: String, for store: WeatherStore) {
    guard let loc = store.currentLocation else { return }
    save(text, locationID: loc.id, weather: store.currentWeather)
  }

  static func clear(locationID: UUID, now: Date = Date()) {
    let cacheKey = key(locationID: locationID, now: now)
    defaults.removeObject(forKey: cacheKey)
    defaults.removeObject(forKey: tokenKey(for: cacheKey))
  }

  static func clear(for store: WeatherStore) {
    guard let loc = store.currentLocation else { return }
    clear(locationID: loc.id)
  }
}
