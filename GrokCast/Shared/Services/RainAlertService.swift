import Foundation
import UserNotifications

@MainActor
enum RainAlertService {
  static let categoryIdentifier = "GROKCAST_RAIN_ALERT"

  private static let lastAlertKey = "grokcast_rain_alert_last"
  private static let cooldownSeconds: TimeInterval = 30 * 60

  static func checkAndNotify(weather: GrokCastWeather, units: TemperatureUnit) async {
    let summary = MinutecastEngine.summary(from: weather.minutely15, units: units)

    switch summary.kind {
    case .startsSoon:
      await postIfCooledDown(
        title: "Rain Starting Soon",
        body: summary.message,
        identifier: "rain-starting"
      )
    case .stoppingSoon:
      await postIfCooledDown(
        title: "Rain Ending Soon",
        body: summary.message,
        identifier: "rain-stopping"
      )
    case .clear, .ongoing:
      break
    }
  }

  private static func postIfCooledDown(title: String, body: String, identifier: String) async {
    let now = Date()
    if let last = UserDefaults.standard.object(forKey: lastAlertKey) as? Date,
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
    content.sound = .default
    content.interruptionLevel = .timeSensitive
    content.categoryIdentifier = categoryIdentifier
    content.threadIdentifier = "grokcast-rain-alerts"
    content.userInfo = ["deepLink": GrokCastDeepLinks.todayURL.absoluteString]

    let request = UNNotificationRequest(
      identifier: "grokcast.rain.\(identifier).\(Int(now.timeIntervalSince1970))",
      content: content,
      trigger: nil
    )

    do {
      try await UNUserNotificationCenter.current().add(request)
      UserDefaults.standard.set(now, forKey: lastAlertKey)
    } catch {}
  }
}
