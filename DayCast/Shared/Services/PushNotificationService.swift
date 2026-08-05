import FirebaseMessaging
import Foundation
import UIKit
import UserNotifications

@MainActor
final class PushNotificationService {
  static let shared = PushNotificationService()

  private(set) var deviceToken: Data?
  private(set) var fcmToken: String?

  private let apnsTokenKey = "daycast_apns_device_token"
  private let fcmTokenKey = "daycast_fcm_token"

  private init() {}

  func registerForRemoteNotifications() {
    UIApplication.shared.registerForRemoteNotifications()
  }

  func didRegisterForRemoteNotifications(deviceToken: Data) {
    self.deviceToken = deviceToken
    Messaging.messaging().apnsToken = deviceToken

    // Do not log token material in Release.
    let tokenString = deviceToken.map { String(format: "%02x", $0) }.joined()
    UserDefaults.standard.set(tokenString, forKey: apnsTokenKey)
    #if DEBUG
      print("[Push] APNs device token registered (\(tokenString.prefix(12))…)")
    #endif

    // Upload immediately rather than debounced: the token is the one thing the
    // push agent cannot proceed without. No-ops when the agent is unconfigured.
    Task { await PushRegistrationService.shared.sync() }
  }

  func didFailToRegisterForRemoteNotifications(error: Error) {
    #if DEBUG
      print("[Push] APNs registration failed: \(error.localizedDescription)")
    #endif
  }

  func didReceiveFCMToken(_ token: String) {
    // Persisted for Firebase console sends only. Server-side delivery goes through
    // APNs directly (`PushRegistrationService`), so nothing uploads this.
    fcmToken = token
    UserDefaults.standard.set(token, forKey: fcmTokenKey)
  }

  func didReceiveRemoteNotification(
    userInfo: [AnyHashable: Any]
  ) async -> UIBackgroundFetchResult {
    let start = CFAbsoluteTimeGetCurrent()

    if let aps = userInfo["aps"] as? [String: Any],
      aps["content-available"] as? Int == 1
    {
      let success = await WeatherStore.shared.performBackgroundRefresh(taskStart: start)
      return success ? .newData : .failed
    }

    return .noData
  }

  var persistedAPNsToken: String? {
    UserDefaults.standard.string(forKey: apnsTokenKey)
  }

  var persistedFCMToken: String? {
    UserDefaults.standard.string(forKey: fcmTokenKey)
  }
}
