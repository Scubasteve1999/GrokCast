import BackgroundTasks
import FirebaseCore
import FirebaseMessaging
import UIKit
import UserNotifications

/// UIKit delegate adapter for BGTask registration, APNs, Firebase, and notification delegate wiring.
final class AppDelegate: NSObject, UIApplicationDelegate {
  /// Silent-push handlers must call `fetchCompletionHandler` within ~30s.
  private nonisolated static let remoteNotificationBudgetSeconds: CFAbsoluteTime = 25

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    FirebaseApp.configure()
    Messaging.messaging().delegate = self

    BackgroundAlertRefreshService.register()
    registerAllNotificationCategories()

    Task { @MainActor in
      await AlertNotificationService.shared.refreshAuthorizationStatus()
      PushNotificationService.shared.registerForRemoteNotifications()
    }

    return true
  }

  func applicationDidEnterBackground(_ application: UIApplication) {
    BackgroundAlertRefreshService.scheduleAlertRefreshTask()
  }

  // MARK: - APNs

  func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    Task { @MainActor in
      PushNotificationService.shared.didRegisterForRemoteNotifications(deviceToken: deviceToken)
    }
  }

  func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    Task { @MainActor in
      PushNotificationService.shared.didFailToRegisterForRemoteNotifications(error: error)
    }
  }

  func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    let start = CFAbsoluteTimeGetCurrent()
    Task { @MainActor in
      let result = await Self.withRemoteNotificationBudget(startedAt: start) {
        await PushNotificationService.shared.didReceiveRemoteNotification(userInfo: userInfo)
      }
      completionHandler(result)
    }
  }

  /// Runs work but always returns by `remoteNotificationBudgetSeconds`, even if work is still running.
  private static func withRemoteNotificationBudget(
    startedAt: CFAbsoluteTime,
    operation: @escaping @MainActor () async -> UIBackgroundFetchResult
  ) async -> UIBackgroundFetchResult {
    await withTaskGroup(of: UIBackgroundFetchResult.self) { group in
      group.addTask { @MainActor in
        await operation()
      }
      group.addTask {
        let elapsed = CFAbsoluteTimeGetCurrent() - startedAt
        let remaining = max(0, remoteNotificationBudgetSeconds - elapsed)
        try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
        return .failed
      }
      let first = await group.next() ?? .failed
      group.cancelAll()
      return first
    }
  }

  // MARK: - Notification categories

  private func registerAllNotificationCategories() {
    let viewAlerts = UNNotificationAction(
      identifier: "OPEN_ALERTS",
      title: "View Details",
      options: [.foreground]
    )
    let viewRadar = UNNotificationAction(
      identifier: "VIEW_RADAR",
      title: "View Radar",
      options: [.foreground]
    )

    let severeAlert = UNNotificationCategory(
      identifier: AlertNotificationService.categoryIdentifier,
      actions: [viewAlerts, viewRadar],
      intentIdentifiers: [],
      options: []
    )
    let criticalAlert = UNNotificationCategory(
      identifier: AlertNotificationService.criticalCategoryIdentifier,
      actions: [viewAlerts, viewRadar],
      intentIdentifiers: [],
      options: []
    )

    let viewForecast = UNNotificationAction(
      identifier: "OPEN_FORECAST",
      title: "Full Forecast",
      options: [.foreground]
    )
    let askGrok = UNNotificationAction(
      identifier: "OPEN_GROK",
      title: "Ask AI",
      options: [.foreground]
    )
    let morningBrief = UNNotificationCategory(
      identifier: MorningBriefNotificationService.categoryIdentifier,
      actions: [viewForecast, askGrok],
      intentIdentifiers: [],
      options: []
    )

    let viewToday = UNNotificationAction(
      identifier: "OPEN_TODAY",
      title: "View Today",
      options: [.foreground]
    )
    let rainAlert = UNNotificationCategory(
      identifier: RainAlertService.categoryIdentifier,
      actions: [viewToday, viewRadar],
      intentIdentifiers: [],
      options: []
    )

    UNUserNotificationCenter.current().setNotificationCategories([
      severeAlert, criticalAlert, morningBrief, rainAlert,
    ])
  }
}

// MARK: - Firebase Cloud Messaging

extension AppDelegate: MessagingDelegate {
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    guard let fcmToken else { return }
    Task { @MainActor in
      PushNotificationService.shared.didReceiveFCMToken(fcmToken)
    }
  }
}
