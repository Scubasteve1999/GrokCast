import Foundation

/// App Store links carried by shared content, tagged so installs can be traced
/// back to the surface that produced them.
///
/// Shares used to end at "Shared from DayCast" with no link at all, so a
/// recipient had no route to the app and the share loop could not be measured.
/// The `ct` campaign token surfaces in App Store Connect → Analytics →
/// Acquisition, which is where install attribution actually lives; no SDK and
/// no tracking of the person sharing is involved.
enum ShareAttribution {
  static let appStoreID = "6780682022"

  /// Provider token from App Store Connect (Analytics → Acquisition → Campaigns).
  /// Not a secret — it appears in every public campaign link — so it belongs in
  /// tracked source. Attribution reports do not populate without it.
  static let providerToken: String? = "128792554"

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
    // `/app/apple-store/id…` is the path App Store Connect itself generates for
    // campaign links. Matching it exactly avoids betting attribution on the
    // assumption that only the query parameters matter.
    var components = URLComponents(
      string: "https://apps.apple.com/app/apple-store/id\(appStoreID)")!
    // Ordered pt, ct, mt to mirror App Store Connect's own output exactly.
    var items: [URLQueryItem] = []
    if let providerToken, !providerToken.isEmpty {
      items.append(URLQueryItem(name: "pt", value: providerToken))
    }
    items.append(URLQueryItem(name: "ct", value: surface.rawValue))
    items.append(URLQueryItem(name: "mt", value: "8"))
    components.queryItems = items
    return components.url!
  }

  /// Sign-off line appended to shared text.
  static func footer(for surface: Surface) -> String {
    "Shared from DayCast — \(appStoreURL(for: surface).absoluteString)"
  }
}
