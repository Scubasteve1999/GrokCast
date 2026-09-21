import Foundation

/// Origin of `server/refs-agreement`. Empty until Stephen deploys the worker.
/// No API key — the worker reads public NOAA GRIB and returns one point.
enum RefsAgreementConfiguration {
  /// Production origin, no trailing slash. Set after `npx wrangler deploy`.
  static let productionBaseURL = ""

  static let forceKey = "daycast.debug.forceRefsAgreement"
  static let debugBaseURLKey = "daycast.debug.refsAgreementBaseURL"

  static var baseURL: URL? {
    #if DEBUG
      if let override = UserDefaults.standard.string(forKey: debugBaseURLKey),
        !override.isEmpty,
        let url = URL(string: override)
      {
        return url
      }
    #endif
    let raw = productionBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !raw.isEmpty, let url = URL(string: raw) else { return nil }
    return url
  }
}
