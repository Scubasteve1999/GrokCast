import Foundation

enum WidgetDeepLink {
  static func url(hasActiveAlert: Bool) -> URL {
    hasActiveAlert ? GrokCastDeepLinks.alertsURL : GrokCastDeepLinks.todayURL
  }
}
