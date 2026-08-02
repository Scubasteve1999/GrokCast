import Foundation

/// App Store links carried by shared content, tagged so installs can be traced
/// back to the surface that produced them.
///
/// Shares used to end at "Shared from SpotterCast" with no link at all, so a
/// recipient had no route to the app and the share loop could not be measured.
/// The `ct` campaign token surfaces in App Store Connect → Analytics →
/// Acquisition, which is where install attribution actually lives; no SDK and
/// no tracking of the person sharing is involved.
enum ShareAttribution {
  static let appStoreID = "6780682022"

  /// Provider token from App Store Connect (Analytics → Campaigns → "Provider
  /// Token"). Campaign attribution reports only populate once this is set; the
  /// link works regardless, so shipping without it costs reach nothing.
  static let providerToken: String? = nil

  /// Where a share originated. Raw values become campaign tokens, so keep them
  /// stable — renaming one splits its history in App Store Connect.
  enum Surface: String {
    case todayCard = "share_today"
    case alertsSummary = "share_alerts"
    case radarExplanation = "share_radar"
    case stormReport = "share_storm_report"
    case stormPhoto = "share_storm_photo"
  }

  static func appStoreURL(for surface: Surface) -> URL {
    var components = URLComponents(string: "https://apps.apple.com/app/id\(appStoreID)")!
    var items = [URLQueryItem(name: "ct", value: surface.rawValue)]
    if let providerToken, !providerToken.isEmpty {
      items.append(URLQueryItem(name: "pt", value: providerToken))
    }
    items.append(URLQueryItem(name: "mt", value: "8"))
    components.queryItems = items
    return components.url!
  }

  /// Sign-off line appended to shared text.
  static func footer(for surface: Surface) -> String {
    "Shared from SpotterCast — \(appStoreURL(for: surface).absoluteString)"
  }
}
