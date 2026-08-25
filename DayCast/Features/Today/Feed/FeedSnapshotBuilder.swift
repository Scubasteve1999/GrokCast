import Foundation

enum FeedSnapshotBuilder {
  static func make(
    weather: DayCastWeather?,
    alerts: [NWSAlert],
    showFireCard: Bool = false,
    showAIInsight: Bool = true,
    hasSevereContext: Bool = false,
    hasLocalBriefing: Bool = false
  ) -> FeedSnapshot {
    guard let weather else { return .empty }

    let summary = MinutecastEngine.summary(from: weather.minutely15, units: .fahrenheit)
    let hasPrecip = PrecipFeedVisibility.hasContent(summary: summary)
    let hasNextEvent = PrecipFeedVisibility.showsCard(summary: summary)

    let hasSun: Bool = {
      guard let today = weather.daily.first else { return false }
      return today.sunrise != nil || today.sunset != nil
    }()

    return FeedSnapshot(
      hasWeather: true,
      alertCount: alerts.count,
      hasHourly: !weather.hourly.isEmpty,
      hasDaily: !weather.daily.isEmpty,
      hasPrecipContent: hasPrecip,
      hasNextEvent: hasNextEvent,
      hasAQI: weather.airQualityIndex != nil,
      hasSunriseOrSunset: hasSun,
      showFireCard: showFireCard,
      showAIInsight: showAIInsight,
      hasSevereContext: hasSevereContext,
      isNowWet: RadarFeedCopy.isLocalWet(WeatherCondition(fromWMO: weather.conditionCode)),
      hasLocalBriefing: hasLocalBriefing
    )
  }
}
