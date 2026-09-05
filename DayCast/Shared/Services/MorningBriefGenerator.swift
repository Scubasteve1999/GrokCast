import Foundation

@MainActor
enum MorningBriefGenerator {

  static func generateIfStale(weatherStore: WeatherStore) async {
    guard !GrokBriefSafety.shared.isFeatureHidden else { return }
    guard MorningBriefNotificationService.persistedEnabled else { return }
    guard GrokAuthResolver.canAccessGrok(subscription: SubscriptionManager.shared) else { return }

    if GrokBriefCache.loadValidBrief(for: weatherStore) != nil { return }

    do {
      let brief = try await GrokBriefGenerator.generate(
        for: weatherStore, feature: .morningBrief)
      guard !GrokBriefSafety.shared.isBriefHidden(brief) else { return }
      guard let weather = weatherStore.currentWeather else { return }

      let location = weatherStore.currentLocation?.name ?? weather.location.name
      let unit = weatherStore.temperatureUnit
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
