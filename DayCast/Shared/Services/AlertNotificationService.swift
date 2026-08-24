import Foundation
import UserNotifications

@MainActor
final class AlertNotificationService: NSObject, UNUserNotificationCenterDelegate {
  static let shared = AlertNotificationService()

  static let deepLinkURL = DayCastDeepLinks.alertsURL
  static let categoryIdentifier = "DAYCAST_SEVERE_ALERT"
  static let criticalCategoryIdentifier = "DAYCAST_CRITICAL_ALERT"

  private let center = UNUserNotificationCenter.current()

  private override init() {
    super.init()
    center.delegate = self
  }

  var authorizationStatus: UNAuthorizationStatus = .notDetermined

  func refreshAuthorizationStatus() async {
    let settings = await center.notificationSettings()
    authorizationStatus = settings.authorizationStatus
  }

  func requestAuthorization() async -> Bool {
    do {
      let granted = try await center.requestAuthorization(
        options: [.alert, .sound, .badge])
      await refreshAuthorizationStatus()
      return granted
    } catch {
      await refreshAuthorizationStatus()
      return false
    }
  }

  func notifyIfNeeded(for alerts: [NWSAlert], enabled: Bool, taskStart: CFAbsoluteTime? = nil) async
  {
    guard enabled else { return }
    await refreshAuthorizationStatus()
    guard authorizationStatus == .authorized || authorizationStatus == .provisional else {
      return
    }

    if !AlertHistoryStore.hasCompletedInitialAlertSync() {
      let severe = alerts.filter(\.isSevereEvent)
      AlertHistoryStore.markNotified(ids: severe.map(\.id))
      AlertHistoryStore.markInitialAlertSyncComplete()
      return
    }

    let severe = alerts.filter(\.isSevereEvent)
    guard !severe.isEmpty else { return }

    let notified = AlertHistoryStore.loadNotifiedIDs()
    let fresh = severe.filter { !notified.contains($0.id) }
    guard !fresh.isEmpty else { return }

    var successfullyNotified: [String] = []
    for alert in fresh {
      if let taskStart, CFAbsoluteTimeGetCurrent() - taskStart >= 20 {
        break
      }
      if await postNotification(for: alert, taskStart: taskStart) {
        successfullyNotified.append(alert.id)
      }
    }
    AlertHistoryStore.markNotified(ids: successfullyNotified)
  }

  @discardableResult
  private func postNotification(for alert: NWSAlert, taskStart: CFAbsoluteTime? = nil) async -> Bool
  {
    // Respect BG / silent-push budget so we don't post forever after expiration.
    if let taskStart, CFAbsoluteTimeGetCurrent() - taskStart >= 20 {
      return false
    }

    let content = UNMutableNotificationContent()

    if alert.isLifeThreatening {
      content.title = "\u{26A0}\u{FE0F} \(alert.event)"
      content.interruptionLevel = .timeSensitive
      DayCastNotificationSounds.apply(to: content)
      content.categoryIdentifier = Self.criticalCategoryIdentifier
    } else if alert.isWarning {
      content.title = alert.event
      content.interruptionLevel = .timeSensitive
      DayCastNotificationSounds.apply(to: content)
      content.categoryIdentifier = Self.categoryIdentifier
    } else {
      content.title = alert.event
      content.interruptionLevel = .timeSensitive
      DayCastNotificationSounds.apply(to: content)
      content.categoryIdentifier = Self.categoryIdentifier
    }

    content.subtitle = buildSubtitle(for: alert)
    content.body = buildBody(for: alert)
    content.threadIdentifier = "daycast-severe-alerts"
    content.userInfo = [
      "deepLink": Self.deepLinkURL.absoluteString,
      "alertId": alert.id,
    ]

    if let severity = alert.severity {
      content.userInfo["severity"] = severity
    }

    let request = UNNotificationRequest(
      identifier: "nws-\(alert.id)",
      content: content,
      trigger: nil
    )

    do {
      try await center.add(request)
      return true
    } catch {
      return false
    }
  }

  private func buildSubtitle(for alert: NWSAlert) -> String {
    var parts: [String] = []

    if let area = alert.areaDesc, !area.isEmpty {
      let trimmed = String(area.prefix(80))
      parts.append(trimmed)
    }

    if let expiry = alert.expiresRelativeText {
      parts.append(expiry)
    }

    return parts.joined(separator: " · ")
  }

  private func buildBody(for alert: NWSAlert) -> String {
    if let instruction = alert.instruction, !instruction.isEmpty {
      return String(instruction.prefix(300))
    }
    if let headline = alert.headline, !headline.isEmpty {
      return String(headline.prefix(300))
    }
    if let desc = alert.description, !desc.isEmpty {
      return String(desc.prefix(300))
    }
    return "Tap to view alert details in DayCast."
  }

  // MARK: - UNUserNotificationCenterDelegate

  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification
  ) async -> UNNotificationPresentationOptions {
    [.banner, .sound, .badge]
  }

  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse
  ) async {
    let url: URL
    switch response.actionIdentifier {
    case "OPEN_FORECAST":
      url = DayCastDeepLinks.forecastURL
    case "OPEN_GROK":
      url = DayCastDeepLinks.grokURL
      SkyCheckLanding.queueReadyToType()
    case "OPEN_ALERTS":
      url = DayCastDeepLinks.alertsURL
    case "VIEW_RADAR":
      url = DayCastDeepLinks.radarURL
    default:
      let userInfo = response.notification.request.content.userInfo
      if let link = userInfo["deepLink"] as? String, let parsed = URL(string: link) {
        url = parsed
      } else {
        url = DayCastDeepLinks.todayURL
      }
    }

    await MainActor.run {
      NotificationCenter.default.post(
        name: .dayCastDeepLink,
        object: nil,
        userInfo: ["url": url]
      )
    }
  }
}

extension Notification.Name {
  /// In-process deep-link handoff (raw value is the public scheme-family id).
  static let dayCastDeepLink = Notification.Name("daycast.deepLink")
}
