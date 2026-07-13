import Foundation
import UserNotifications

struct MorningBriefContent {
  var briefBody: String
  var locationName: String?
  var temperature: String?
  var condition: String?
}

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

  static func scheduleIfEnabled(briefBody: String?) async {
    let content = MorningBriefContent(briefBody: briefBody ?? "")
    await scheduleIfEnabled(content: content)
  }

  static func scheduleIfEnabled(content brief: MorningBriefContent) async {
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
    content.title = greeting(for: hour, location: brief.locationName)
    content.subtitle = subtitle(temperature: brief.temperature, condition: brief.condition)
    let trimmed = brief.briefBody.trimmingCharacters(in: .whitespacesAndNewlines)
    content.body =
      trimmed.isEmpty
      ? "Open SpotterCast for today's weather and AI take."
      : String(trimmed.prefix(220))
    GrokCastNotificationSounds.apply(to: content)
    content.categoryIdentifier = categoryIdentifier
    content.threadIdentifier = "grokcast-morning-brief"
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

  private static func greeting(for hour: Int, location: String?) -> String {
    let place = location ?? "your area"
    switch hour {
    case 7...9: return "Good morning — \(place)"
    case 10...11: return "Morning update — \(place)"
    default: return "Weather brief — \(place)"
    }
  }

  private static func subtitle(temperature: String?, condition: String?) -> String {
    switch (temperature, condition) {
    case let (temp?, cond?): return "\(temp) · \(cond)"
    case let (temp?, nil): return temp
    case let (nil, cond?): return cond
    case (nil, nil): return ""
    }
  }
}
