import FirebaseMessaging
import Foundation
import UIKit
import UserNotifications

@MainActor
final class PushNotificationService {
  static let shared = PushNotificationService()

  private(set) var deviceToken: Data?
  private(set) var fcmToken: String?

  private let apnsTokenKey = "grokcast_apns_device_token"
  private let fcmTokenKey = "grokcast_fcm_token"

  private init() {}

  func registerForRemoteNotifications() {
    UIApplication.shared.registerForRemoteNotifications()
  }

  func didRegisterForRemoteNotifications(deviceToken: Data) {
    self.deviceToken = deviceToken
    Messaging.messaging().apnsToken = deviceToken

    // Tokens stay on-device until a push-register backend is configured.
    // Do not log token material in Release.
    let tokenString = deviceToken.map { String(format: "%02x", $0) }.joined()
    UserDefaults.standard.set(tokenString, forKey: apnsTokenKey)
    #if DEBUG
      print("[Push] APNs device token registered (\(tokenString.prefix(12))…)")
    #endif
  }

  func didFailToRegisterForRemoteNotifications(error: Error) {
    #if DEBUG
      print("[Push] APNs registration failed: \(error.localizedDescription)")
    #endif
  }

  func didReceiveFCMToken(_ token: String) {
    // Local persistence only — no upload endpoint is configured in this binary.
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
