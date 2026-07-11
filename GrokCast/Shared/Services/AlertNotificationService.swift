import Foundation
import UserNotifications

/// Local notifications for new severe NWS alerts (Warnings + Watches).
@MainActor
final class AlertNotificationService: NSObject, UNUserNotificationCenterDelegate {
  static let shared = AlertNotificationService()

  static let deepLinkURL = GrokCastDeepLinks.alertsURL
  static let categoryIdentifier = "GROKCAST_SEVERE_ALERT"

  private let center = UNUserNotificationCenter.current()

  private override init() {
    super.init()
    center.delegate = self
    registerCategory()
  }

  var authorizationStatus: UNAuthorizationStatus = .notDetermined

  func refreshAuthorizationStatus() async {
    let settings = await center.notificationSettings()
    authorizationStatus = settings.authorizationStatus
  }

  /// Requests notification permission with a clear explanation for severe weather alerts.
  func requestAuthorization() async -> Bool {
    do {
      let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
      await refreshAuthorizationStatus()
      return granted
    } catch {
      print("🔔 [Alerts] notification permission failed: \(error.localizedDescription)")
      await refreshAuthorizationStatus()
      return false
    }
  }

  /// Sends local notifications for new severe alerts not yet notified.
  /// - Parameter taskStart: When set (background BG task), successful posts emit `[DIAG]` logs.
  func notifyIfNeeded(for alerts: [NWSAlert], enabled: Bool, taskStart: CFAbsoluteTime? = nil) async
  {
    guard enabled else { return }
    await refreshAuthorizationStatus()
    guard authorizationStatus == .authorized || authorizationStatus == .provisional else {
      return
    }

    // First authorized pass: always mark initial sync complete (even when severe is empty).
    // Prevents a later first-severe alert from being silently suppressed as "already notified."
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
      if await postNotification(for: alert, taskStart: taskStart) {
        successfullyNotified.append(alert.id)
      }
    }
    AlertHistoryStore.markNotified(ids: successfullyNotified)
  }

  @discardableResult
  private func postNotification(for alert: NWSAlert, taskStart: CFAbsoluteTime? = nil) async -> Bool
  {
    let content = UNMutableNotificationContent()
    content.title = alert.event
    if let headline = alert.headline, !headline.isEmpty {
      content.subtitle = headline
    }
    if let area = alert.areaDesc, !area.isEmpty {
      content.body = area
    } else if let headline = alert.headline, !headline.isEmpty {
      content.body = headline
    } else {
      content.body = "Tap to view alert details in SpotterCast."
    }
    content.sound = .default
    content.categoryIdentifier = Self.categoryIdentifier
    content.userInfo = ["deepLink": Self.deepLinkURL.absoluteString]

    let request = UNNotificationRequest(
      identifier: "nws-\(alert.id)",
      content: content,
      trigger: nil
    )

    do {
      try await center.add(request)
      if let start = taskStart {
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        print(
          String(
            format: "[DIAG t=%.3f] bg-alerts notification posted: %@ (%@)",
            elapsed,
            alert.event,
            alert.id
          )
        )
      }
      return true
    } catch {
      print("🔔 [Alerts] failed to schedule notification: \(error.localizedDescription)")
      return false
    }
  }

  private func registerCategory() {
    let open = UNNotificationAction(
      identifier: "OPEN_ALERTS",
      title: "View Alerts",
      options: [.foreground]
    )
    let category = UNNotificationCategory(
      identifier: Self.categoryIdentifier,
      actions: [open],
      intentIdentifiers: [],
      options: []
    )
    center.setNotificationCategories([category])
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
    let userInfo = response.notification.request.content.userInfo
    if let link = userInfo["deepLink"] as? String, let url = URL(string: link) {
      await MainActor.run {
        NotificationCenter.default.post(
          name: .grokCastOpenAlertsTab,
          object: nil,
          userInfo: ["url": url]
        )
      }
    }
  }
}

extension Notification.Name {
  static let grokCastOpenAlertsTab = Notification.Name("grokcast.openAlertsTab")
}
