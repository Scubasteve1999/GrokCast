import ActivityKit
import Foundation

@MainActor
enum WeatherLiveActivityManager {
  private static var currentActivity: Activity<WeatherLiveActivityAttributes>?

  static var isSupported: Bool {
    ActivityAuthorizationInfo().areActivitiesEnabled
  }

  static func sync(
    weather: GrokCastWeather,
    score: GrokCastScore,
    minutecast: MinutecastSummary,
    locationName: String,
    temperatureText: String,
    enabled: Bool
  ) {
    guard enabled, isSupported else {
      end()
      return
    }

    adoptExistingActivityIfNeeded()

    let content = WeatherLiveActivityAttributes.ContentState(
      locationName: locationName,
      temperatureText: temperatureText,
      conditionText: weather.conditionText,
      score: score.value,
      scoreLabel: score.label,
      minutecastMessage: minutecast.message,
      symbolName: weather.symbolName
    )

    if let activity = currentActivity {
      Task {
        await activity.update(
          ActivityContent(state: content, staleDate: Date().addingTimeInterval(30 * 60))
        )
      }
      return
    }

    let attributes = WeatherLiveActivityAttributes()
    if let activity = try? Activity.request(
      attributes: attributes,
      content: ActivityContent(state: content, staleDate: Date().addingTimeInterval(30 * 60)),
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
}
