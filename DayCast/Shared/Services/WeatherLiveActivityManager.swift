import ActivityKit
import Foundation

@MainActor
enum WeatherLiveActivityManager {
  private static var currentActivity: Activity<WeatherLiveActivityAttributes>?

  static var isSupported: Bool {
    ActivityAuthorizationInfo().areActivitiesEnabled
  }

  static func sync(
    weather: DayCastWeather,
    score: DayCastScore,
    minutecast: MinutecastSummary,
    locationName: String,
    temperatureText: String,
    enabled: Bool,
    alerts: [NWSAlert] = []
  ) {
    guard enabled, isSupported else {
      end()
      return
    }

    adoptExistingActivityIfNeeded()

    let content = makeContentState(
      weather: weather,
      score: score,
      minutecast: minutecast,
      locationName: locationName,
      temperatureText: temperatureText,
      alerts: alerts
    )

    // No ActivityKit push server yet (`pushType: nil`). Keep the activity fresh via
    // foreground + BGAppRefresh weather sync; staleDate matches that cadence (~2h).
    let staleDate = Date().addingTimeInterval(2 * 60 * 60)

    if let activity = currentActivity {
      Task {
        await activity.update(ActivityContent(state: content, staleDate: staleDate))
      }
      return
    }

    let attributes = WeatherLiveActivityAttributes()
    if let activity = try? Activity.request(
      attributes: attributes,
      content: ActivityContent(state: content, staleDate: staleDate),
      pushType: nil
    ) {
      currentActivity = activity
    }
  }

  static func end() {
    let activities = Activity<WeatherLiveActivityAttributes>.activities
    currentActivity = nil
    guard !activities.isEmpty else { return }
    Task {
      for activity in activities {
        await activity.end(nil, dismissalPolicy: .immediate)
      }
    }
  }

  /// Reattach after app relaunch when the system still has a live activity running.
  private static func adoptExistingActivityIfNeeded() {
    guard currentActivity == nil else { return }
    currentActivity = Activity<WeatherLiveActivityAttributes>.activities.first
  }

  // MARK: - Variant selection

  /// Builds ContentState with severe-alert / radar-event / standard presentation.
  static func makeContentState(
    weather: DayCastWeather,
    score: DayCastScore,
    minutecast: MinutecastSummary,
    locationName: String,
    temperatureText: String,
    alerts: [NWSAlert]
  ) -> WeatherLiveActivityAttributes.ContentState {
    if let alert = topSevereAlert(from: alerts) {
      return WeatherLiveActivityAttributes.ContentState(
        locationName: locationName,
        temperatureText: temperatureText,
        conditionText: weather.conditionText,
        score: score.value,
        scoreLabel: score.label,
        minutecastMessage: minutecast.message,
        symbolName: severeSymbol(for: alert),
        variant: .severeAlert,
        headline: alert.event,
        detail: alert.expiresRelativeText ?? alert.headline ?? minutecast.message,
        severityLevel: alert.severityLevel
      )
    }

    if minutecast.kind == .startsSoon || minutecast.kind == .ongoing {
      let headline: String =
        minutecast.kind == .startsSoon ? "Rain Starting Soon" : "Rain Nearby"
      return WeatherLiveActivityAttributes.ContentState(
        locationName: locationName,
        temperatureText: temperatureText,
        conditionText: weather.conditionText,
        score: score.value,
        scoreLabel: score.label,
        minutecastMessage: minutecast.message,
        symbolName: minutecast.icon.isEmpty ? "cloud.rain.fill" : minutecast.icon,
        variant: .radarEvent,
        headline: headline,
        detail: minutecast.message,
        severityLevel: 0
      )
    }

    return WeatherLiveActivityAttributes.ContentState(
      locationName: locationName,
      temperatureText: temperatureText,
      conditionText: weather.conditionText,
      score: score.value,
      scoreLabel: score.label,
      minutecastMessage: minutecast.message,
      symbolName: weather.symbolName,
      variant: .standard,
      headline: nil,
      detail: nil,
      severityLevel: 0
    )
  }

  /// Highest-severity Warning/Watch, life-threatening first.
  private static func topSevereAlert(from alerts: [NWSAlert]) -> NWSAlert? {
    let severe = alerts.filter { $0.isSevereEvent && !$0.isExpired }
    guard !severe.isEmpty else { return nil }
    return severe.max { a, b in
      if a.isLifeThreatening != b.isLifeThreatening {
        return !a.isLifeThreatening && b.isLifeThreatening
      }
      if a.severityLevel != b.severityLevel {
        return a.severityLevel < b.severityLevel
      }
      // Prefer warnings over watches when level ties.
      if a.isWarning != b.isWarning {
        return !a.isWarning && b.isWarning
      }
      return false
    }
  }

  private static func severeSymbol(for alert: NWSAlert) -> String {
    if alert.isLifeThreatening {
      return "exclamationmark.triangle.fill"
    }
    if alert.isWarning || alert.severityLevel >= 3 {
      return "exclamationmark.triangle.fill"
    }
    return "exclamationmark.circle.fill"
  }
}
