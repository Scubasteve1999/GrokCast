import Foundation
import UserNotifications

/// Local notifications when Minutecast flips to rain starting / ending soon.
///
/// Fired from foreground weather refresh and background refresh when
/// `WeatherStore.rainAlertsEnabled` is on. Cooldown + kind-transition rules
/// keep repeats quiet without blocking start→stop transitions.
@MainActor
enum RainAlertService {
  static let categoryIdentifier = "DAYCAST_RAIN_ALERT"

  private static let lastAlertKey = "daycast_rain_alert_last"
  private static let lastKindKey = "daycast_rain_alert_last_kind"
  /// Same event kind will not re-notify within this window.
  private static let cooldownSeconds: TimeInterval = 30 * 60

  static func checkAndNotify(
    weather: DayCastWeather,
    units: TemperatureUnit,
    taskStart: CFAbsoluteTime? = nil
  ) async {
    if let taskStart, CFAbsoluteTimeGetCurrent() - taskStart >= 20 { return }

    let summary = MinutecastEngine.summary(from: weather.minutely15, units: units)
    let previousKind = UserDefaults.standard.string(forKey: lastKindKey)

    switch summary.kind {
    case .startsSoon:
      await postIfNeeded(
        title: "Rain Starting Soon",
        body: summary.message,
        kindKey: "startsSoon",
        previousKind: previousKind,
        deepLink: DayCastDeepLinks.radarURL,
        taskStart: taskStart
      )
    case .stoppingSoon:
      await postIfNeeded(
        title: "Rain Ending Soon",
        body: summary.message,
        kindKey: "stoppingSoon",
        previousKind: previousKind,
        deepLink: DayCastDeepLinks.todayURL,
        taskStart: taskStart
      )
    case .clear, .ongoing:
      UserDefaults.standard.set(kindString(summary.kind), forKey: lastKindKey)
    }
  }

  private static func postIfNeeded(
    title: String,
    body: String,
    kindKey: String,
    previousKind: String?,
    deepLink: URL,
    taskStart: CFAbsoluteTime?
  ) async {
    if let taskStart, CFAbsoluteTimeGetCurrent() - taskStart >= 20 { return }

    let now = Date()
    let sameKind = previousKind == kindKey
    if sameKind,
      let last = UserDefaults.standard.object(forKey: lastAlertKey) as? Date,
      now.timeIntervalSince(last) < cooldownSeconds
    {
      return
    }

    let settings = await UNUserNotificationCenter.current().notificationSettings()
    guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    else { return }

    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    DayCastNotificationSounds.apply(to: content)
    content.interruptionLevel = .timeSensitive
    content.categoryIdentifier = categoryIdentifier
    content.threadIdentifier = "daycast-rain-alerts"
    content.userInfo = ["deepLink": deepLink.absoluteString]

    let request = UNNotificationRequest(
      identifier: "daycast.rain.\(kindKey).\(Int(now.timeIntervalSince1970))",
      content: content,
      trigger: nil
    )

    do {
      try await UNUserNotificationCenter.current().add(request)
      UserDefaults.standard.set(now, forKey: lastAlertKey)
      UserDefaults.standard.set(kindKey, forKey: lastKindKey)
    } catch {}
  }

  private static func kindString(_ kind: MinutecastSummary.Kind) -> String {
    switch kind {
    case .clear: return "clear"
    case .startsSoon: return "startsSoon"
    case .ongoing: return "ongoing"
    case .stoppingSoon: return "stoppingSoon"
    }
  }
}
