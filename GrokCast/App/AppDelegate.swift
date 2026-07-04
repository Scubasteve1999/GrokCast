import BackgroundTasks
import FirebaseCore
import FirebaseMessaging
import UIKit
import UserNotifications

/// UIKit delegate adapter for BGTask registration, APNs, Firebase, and notification delegate wiring.
final class AppDelegate: NSObject, UIApplicationDelegate {
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
    didReceiveRemoteNotification userInfo: [AnyHashable: Any]
  ) async -> UIBackgroundFetchResult {
    await PushNotificationService.shared.didReceiveRemoteNotification(userInfo: userInfo)
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
      title: "Ask Grok",
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
    print("[FCM] Token: \(fcmToken.prefix(20))…")
    Task { @MainActor in
      PushNotificationService.shared.didReceiveFCMToken(fcmToken)
    }
  }
}
