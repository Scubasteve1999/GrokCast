import Foundation

/// Shared deep-link URLs for the main app and widget extension.
enum SpotterCastDeepLinks {
  static let scheme = "grokcast"
  static let todayHost = "today"
  static let alertsHost = "alerts"

  static let todayURL: URL = {
    guard let url = URL(string: "\(scheme)://\(todayHost)") else {
      preconditionFailure("grokcast://today must be a valid URL")
    }
    return url
  }()

  static let alertsURL: URL = {
    guard let url = URL(string: "\(scheme)://\(alertsHost)") else {
      preconditionFailure("grokcast://alerts must be a valid URL")
    }
    return url
  }()
}
