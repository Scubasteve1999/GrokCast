import Foundation
import UserNotifications

enum GrokCastNotificationSounds {
  static let enabledKey = "grokcast_notification_sounds_enabled"

  static var isEnabled: Bool {
    if UserDefaults.standard.object(forKey: enabledKey) == nil { return true }
    return UserDefaults.standard.bool(forKey: enabledKey)
  }

  static func apply(to content: UNMutableNotificationContent) {
    content.sound = isEnabled ? .default : nil
  }
}
