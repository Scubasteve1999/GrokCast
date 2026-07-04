import Foundation

/// Shared deep-link URLs for the main app and widget extension.
enum GrokCastDeepLinks {
  static let scheme = "grokcast"
  static let todayHost = "today"
  static let alertsHost = "alerts"
  static let forecastHost = "forecast"
  static let grokHost = "grok"

  static let todayURL = makeURL(todayHost)
  static let alertsURL = makeURL(alertsHost)
  static let forecastURL = makeURL(forecastHost)
  static let grokURL = makeURL(grokHost)

  private static func makeURL(_ host: String) -> URL {
    guard let url = URL(string: "\(scheme)://\(host)") else {
      preconditionFailure("\(scheme)://\(host) must be a valid URL")
    }
    return url
  }
}
