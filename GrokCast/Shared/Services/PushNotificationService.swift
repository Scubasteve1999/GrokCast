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

    let tokenString = deviceToken.map { String(format: "%02x", $0) }.joined()
    UserDefaults.standard.set(tokenString, forKey: apnsTokenKey)
    print("[Push] APNs device token registered (\(tokenString.prefix(12))…)")
  }

  func didFailToRegisterForRemoteNotifications(error: Error) {
    print("[Push] APNs registration failed: \(error.localizedDescription)")
  }

  func didReceiveFCMToken(_ token: String) {
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
      let success = await WeatherStore.shared.performBackgroundAlertCheck(taskStart: start)
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
