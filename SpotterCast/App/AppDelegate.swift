import BackgroundTasks
import UIKit
import UserNotifications

/// UIKit delegate adapter for BGTask registration and notification delegate wiring.
final class AppDelegate: NSObject, UIApplicationDelegate {
  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    // Register only at launch. Scheduling happens in applicationDidEnterBackground —
    // submitting here often fails with BGTaskScheduler.Error.unavailable (error 1),
    // especially on Simulator while the app is still foregrounded.
    BackgroundAlertRefreshService.register()

    Task { @MainActor in
      await AlertNotificationService.shared.refreshAuthorizationStatus()
    }

    return true
  }

  func applicationDidEnterBackground(_ application: UIApplication) {
    BackgroundAlertRefreshService.scheduleAlertRefreshTask()
  }
}
