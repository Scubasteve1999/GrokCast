import Foundation
import UserNotifications

/// Schedules a repeating local notification with the latest cached Grok morning brief.
@MainActor
enum MorningBriefNotificationService {
  static let enabledKey = "grokcast_morning_brief_enabled"
  static let hourKey = "grokcast_morning_brief_hour"
  static let requestIdentifier = "grokcast.morning.brief"
  static let categoryIdentifier = "GROKCAST_MORNING_BRIEF"

  static var persistedEnabled: Bool {
    UserDefaults.standard.bool(forKey: enabledKey)
  }

  static var persistedHour: Int {
    let h = UserDefaults.standard.integer(forKey: hourKey)
    return (7...11).contains(h) ? h : 7
  }

  static func registerCategory() {
    let open = UNNotificationAction(
      identifier: "OPEN_TODAY",
      title: "Open GrokCast",
      options: [.foreground]
    )
    let category = UNNotificationCategory(
      identifier: categoryIdentifier,
      actions: [open],
      intentIdentifiers: [],
      options: []
    )
    UNUserNotificationCenter.current().setNotificationCategories([category])
  }

  static func scheduleIfEnabled(briefBody: String?) async {
    guard persistedEnabled else {
      cancel()
      return
    }
    await AlertNotificationService.shared.refreshAuthorizationStatus()
    let status = AlertNotificationService.shared.authorizationStatus
    guard status == .authorized || status == .provisional else { return }

    let hour = persistedHour
    var date = DateComponents()
    date.hour = hour
    date.minute = 0

    let content = UNMutableNotificationContent()
    content.title = "GrokCast Morning Brief"
    let trimmed = briefBody?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    content.body =
      trimmed.isEmpty
      ? "Open GrokCast for today's weather and Grok's take."
      : String(trimmed.prefix(220))
    GrokCastNotificationSounds.apply(to: content)
    content.categoryIdentifier = categoryIdentifier
    content.userInfo = ["deepLink": GrokCastDeepLinks.todayURL.absoluteString]

    let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
    let request = UNNotificationRequest(
      identifier: requestIdentifier,
      content: content,
      trigger: trigger
    )

    let center = UNUserNotificationCenter.current()
    center.removePendingNotificationRequests(withIdentifiers: [requestIdentifier])
    try? await center.add(request)
  }

  static func cancel() {
    UNUserNotificationCenter.current().removePendingNotificationRequests(
      withIdentifiers: [requestIdentifier])
  }
}
