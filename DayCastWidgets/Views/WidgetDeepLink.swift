import Foundation

enum WidgetDeepLink {
  static func url(hasActiveAlert: Bool) -> URL {
    hasActiveAlert ? DayCastDeepLinks.alertsURL : DayCastDeepLinks.todayURL
  }
}
