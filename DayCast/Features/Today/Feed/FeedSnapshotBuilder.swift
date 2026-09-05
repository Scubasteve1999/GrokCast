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
      hasSunriseOrSunset: hasSun,
      showFireCard: showFireCard,
      isNowWet: NowHeroReconcile.isNowWet(
        conditionCode: weather.conditionCode, summary: summary),
      hasLocalBriefing: hasLocalBriefing
    )
  }
}
