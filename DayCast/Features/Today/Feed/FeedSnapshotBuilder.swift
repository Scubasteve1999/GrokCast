import Foundation

enum FeedSnapshotBuilder {
  static func make(
    weather: DayCastWeather?,
    alerts: [NWSAlert],
    showFireCard: Bool = false,
    hasLocalBriefing: Bool = false
  ) -> FeedSnapshot {
    guard let weather else { return .empty }

    let summary = MinutecastEngine.summary(from: weather.minutely15, units: .fahrenheit)
    let hasPrecip = PrecipFeedVisibility.hasContent(summary: summary)
    let hasAQAlert = alerts.contains { NearbyTileCopy.isAirQualityAlert($0.event) }

    return FeedSnapshot(
      hasWeather: true,
      alertCount: alerts.count,
      hasHourly: !weather.hourly.isEmpty,
      hasDaily: !weather.daily.isEmpty,
      hasPrecipContent: hasPrecip,
      showFireCard: showFireCard,
      showHealth: ConditionsVisibility.shouldShow(
        aqi: weather.airQualityIndex,
        visibilityMeters: weather.visibilityMeters,
        hasNWSAirQualityAlert: hasAQAlert
      ),
      isNowWet: NowHeroReconcile.isNowWet(
        conditionCode: weather.conditionCode, summary: summary),
      hasLocalBriefing: hasLocalBriefing,
      hasRadarRelevantAlert: alerts.contains(where: \.isRadarRelevant)
    )
  }
}
