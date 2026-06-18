import Foundation
import UserNotifications

@MainActor
final class AlertNotificationService {
  static let shared = AlertNotificationService()
  
  private init() {}
  
  func requestAuthorization() async -> Bool {
    do {
      return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
    } catch {
      print("Notification authorization error: \(error)")
      return false
    }
  }
  
  func scheduleNotification(for alert: NWSAlert) async {
    let content = UNMutableNotificationContent()
    content.title = alert.event
    content.body = alert.headline ?? alert.areaDesc
    content.sound = .default
    content.categoryIdentifier = "weather.alert"
    
    let request = UNNotificationRequest(
      identifier: alert.id,
      content: content,
      trigger: nil
    )
    
    do {
      try await UNUserNotificationCenter.current().add(request)
    } catch {
      print("Failed to schedule notification: \(error)")
    }
  }
  
  func cancelNotification(for alertId: String) {
    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [alertId])
    UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [alertId])
  }
  
  func cancelAllNotifications() {
    UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    UNUserNotificationCenter.current().removeAllDeliveredNotifications()
  }
}
