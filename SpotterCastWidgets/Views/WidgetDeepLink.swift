import Foundation

enum WidgetDeepLink {
  static func url(hasActiveAlert: Bool) -> URL {
    hasActiveAlert ? SpotterCastDeepLinks.alertsURL : SpotterCastDeepLinks.todayURL
  }
}
